// Security rules tests. Run with `npm test` (starts the Firestore emulator).
import { after, before, beforeEach, describe, test } from 'node:test';
import { readFileSync } from 'node:fs';
import { assertFails, assertSucceeds, initializeTestEnvironment } from '@firebase/rules-unit-testing';
import {
  Timestamp,
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  query,
  serverTimestamp,
  setDoc,
  updateDoc,
  where,
} from 'firebase/firestore';

const DAY_MS = 24 * 60 * 60 * 1000;
const dayKey = (d) => d.getFullYear() * 10000 + (d.getMonth() + 1) * 100 + d.getDate();

let env;
const db = (uid) => (uid ? env.authenticatedContext(uid) : env.unauthenticatedContext()).firestore();
const expenseRef = (firestore, owner, id = 'e1') => doc(firestore, 'users', owner, 'expenses', id);

/// A valid new expense as the app writes it, with optional overrides.
const expense = (overrides = {}) => ({
  itemName: 'Groceries',
  amountPaise: 35000,
  occurredAt: Timestamp.now(),
  localDate: dayKey(new Date()),
  paymentType: 'upi',
  createdAt: serverTimestamp(),
  updatedAt: serverTimestamp(),
  ...overrides,
});

/// Writes alice's expense with rules disabled, for read/update/delete tests.
const seedAlice = () =>
  env.withSecurityRulesDisabled((ctx) =>
    setDoc(expenseRef(ctx.firestore(), 'alice'), { ...expense(), createdAt: Timestamp.now(), updatedAt: Timestamp.now() }),
  );

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-expense-manager',
    firestore: { rules: readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8') },
  });
});
after(() => env.cleanup());
beforeEach(() => env.clearFirestore());

describe('ownership', () => {
  test('a user can create and read their own expense', async () => {
    await assertSucceeds(setDoc(expenseRef(db('alice'), 'alice'), expense()));
    await assertSucceeds(getDoc(expenseRef(db('alice'), 'alice')));
  });

  test('a user can query their own expenses by date range', async () => {
    await seedAlice();
    const today = dayKey(new Date());
    const q = query(
      collection(db('alice'), 'users', 'alice', 'expenses'),
      where('localDate', '>=', today),
      where('localDate', '<=', today),
    );
    await assertSucceeds(getDocs(q));
  });

  test("a user cannot read another user's expenses", async () => {
    await seedAlice();
    await assertFails(getDoc(expenseRef(db('bob'), 'alice')));
    await assertFails(getDocs(collection(db('bob'), 'users', 'alice', 'expenses')));
  });

  test("a user cannot create, update or delete another user's expenses", async () => {
    await seedAlice();
    await assertFails(setDoc(expenseRef(db('bob'), 'alice', 'e2'), expense()));
    await assertFails(updateDoc(expenseRef(db('bob'), 'alice'), { amountPaise: 1, updatedAt: serverTimestamp() }));
    await assertFails(deleteDoc(expenseRef(db('bob'), 'alice')));
  });

  test('signed-out clients are denied', async () => {
    await seedAlice();
    await assertFails(getDoc(expenseRef(db(null), 'alice')));
    await assertFails(setDoc(expenseRef(db(null), 'alice', 'e2'), expense()));
  });

  test('nothing outside users/{uid}/expenses is writable', async () => {
    await assertFails(setDoc(doc(db('alice'), 'users', 'alice'), { name: 'x' }));
    await assertFails(setDoc(doc(db('alice'), 'totals', 'alice'), { total: 1 }));
  });
});

describe('validation', () => {
  const invalid = {
    'zero amount': { amountPaise: 0 },
    'negative amount': { amountPaise: -100 },
    'fractional paise': { amountPaise: 12.5 },
    'amount as string': { amountPaise: '350' },
    'amount above ₹10,00,000': { amountPaise: 100000001 },
    'empty item name': { itemName: '' },
    'whitespace item name': { itemName: '   ' },
    'item name over 60 chars': { itemName: 'x'.repeat(61) },
    'extra ownership field': { uid: 'alice' },
    'client-chosen createdAt': { createdAt: Timestamp.now() },
    'localDate as string': { localDate: '2026-10-28' },
    'empty payment type': { paymentType: '' },
    'unknown payment type': { paymentType: 'paypal' },
    'payment type label instead of key': { paymentType: 'Bank Transfer' },
  };
  for (const [name, overrides] of Object.entries(invalid)) {
    test(`rejects ${name}`, () => assertFails(setDoc(expenseRef(db('alice'), 'alice'), expense(overrides))));
  }

  test('rejects a missing field', async () => {
    const { localDate, ...withoutDate } = expense();
    await assertFails(setDoc(expenseRef(db('alice'), 'alice'), withoutDate));
  });

  test('accepts the maximum amount and a 60-char name', () =>
    assertSucceeds(setDoc(expenseRef(db('alice'), 'alice'), expense({ amountPaise: 100000000, itemName: 'x'.repeat(60) }))));
});

describe('dates', () => {
  test('rejects a future occurrence time', () =>
    assertFails(setDoc(expenseRef(db('alice'), 'alice'), expense({ occurredAt: Timestamp.fromMillis(Date.now() + 60 * 60 * 1000) }))));

  test('rejects a future local date', () => {
    const future = new Date(Date.now() + 2 * DAY_MS);
    return assertFails(setDoc(expenseRef(db('alice'), 'alice'), expense({ localDate: dayKey(future) })));
  });

  test('accepts an earlier time today', () =>
    assertSucceeds(setDoc(expenseRef(db('alice'), 'alice'), expense({ occurredAt: Timestamp.fromMillis(Date.now() - 60 * 1000) }))));

  test('accepts a historical date', () => {
    const past = new Date(2024, 1, 29, 18, 30); // leap day
    return assertSucceeds(
      setDoc(expenseRef(db('alice'), 'alice'), expense({ occurredAt: Timestamp.fromDate(past), localDate: dayKey(past) })),
    );
  });

  test('rejects dates before 2000', () => {
    const old = new Date(1999, 11, 31);
    return assertFails(
      setDoc(expenseRef(db('alice'), 'alice'), expense({ occurredAt: Timestamp.fromDate(old), localDate: dayKey(old) })),
    );
  });
});

describe('payment type', () => {
  test('accepts each supported type', async () => {
    for (const [i, type] of ['cash', 'upi', 'bank_transfer'].entries()) {
      await assertSucceeds(setDoc(expenseRef(db('alice'), 'alice', `p${i}`), expense({ paymentType: type })));
    }
  });

  test('rejects a new expense without one', async () => {
    const { paymentType, ...legacy } = expense();
    await assertFails(setDoc(expenseRef(db('alice'), 'alice'), legacy));
  });

  test('legacy docs stay readable and deletable, and editing them requires a type', async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      const { paymentType, ...legacy } = expense();
      await setDoc(expenseRef(ctx.firestore(), 'alice'), { ...legacy, createdAt: Timestamp.now(), updatedAt: Timestamp.now() });
    });
    const ref = expenseRef(db('alice'), 'alice');
    await assertSucceeds(getDoc(ref));
    await assertFails(updateDoc(ref, { amountPaise: 100, updatedAt: serverTimestamp() }));
    await assertSucceeds(updateDoc(ref, { amountPaise: 100, paymentType: 'cash', updatedAt: serverTimestamp() }));
    await assertSucceeds(deleteDoc(ref));
  });
});

describe('updates', () => {
  test('the owner can edit fields and delete', async () => {
    await seedAlice();
    const ref = expenseRef(db('alice'), 'alice');
    await assertSucceeds(updateDoc(ref, { itemName: 'Vegetables', amountPaise: 12050, updatedAt: serverTimestamp() }));
    await assertSucceeds(deleteDoc(ref));
  });

  test('an update cannot change createdAt or skip updatedAt', async () => {
    await seedAlice();
    const ref = expenseRef(db('alice'), 'alice');
    await assertFails(updateDoc(ref, { createdAt: serverTimestamp(), updatedAt: serverTimestamp() }));
    await assertFails(updateDoc(ref, { amountPaise: 100 }));
  });

  test('an update cannot move an expense into the future', async () => {
    await seedAlice();
    const ref = expenseRef(db('alice'), 'alice');
    await assertFails(
      updateDoc(ref, { occurredAt: Timestamp.fromMillis(Date.now() + DAY_MS), updatedAt: serverTimestamp() }),
    );
  });
});
