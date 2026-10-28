import 'package:intl/intl.dart';

/// Largest single expense: ₹10,00,000.00. Mirrored in firestore.rules.
const maxAmountPaise = 100000000;

final _indianGrouping = NumberFormat('#,##,##0', 'en_IN');

/// 35000 → "₹350.00", 12345678 → "₹1,23,456.78". Integer-only, no floating point.
String formatInr(int paise) {
  final sign = paise < 0 ? '-' : '';
  final abs = paise.abs();
  final fraction = (abs % 100).toString().padLeft(2, '0');
  return '$sign₹${_indianGrouping.format(abs ~/ 100)}.$fraction';
}

/// Short label for tight spaces (calendar cells): ₹120, ₹1.2k, ₹3.4L, ₹1.1Cr.
String formatInrCompact(int paise) {
  final rupees = (paise / 100).round();
  const units = [(10000000, 'Cr'), (100000, 'L'), (1000, 'k')];
  for (var i = 0; i < units.length; i++) {
    final (size, suffix) = units[i];
    if (rupees < size) continue;
    final tenths = (rupees * 10 / size).round();
    // 99,960 rounds to "100k"; promote it to the next unit ("1L") instead.
    if (tenths >= 1000 && i > 0) {
      final (bigger, biggerSuffix) = units[i - 1];
      return '₹${_tenths((rupees * 10 / bigger).round())}$biggerSuffix';
    }
    return '₹${_tenths(tenths)}$suffix';
  }
  return '₹$rupees';
}

String _tenths(int tenths) => tenths % 10 == 0 ? '${tenths ~/ 10}' : '${tenths ~/ 10}.${tenths % 10}';

final _amountPattern = RegExp(r'^(\d+)(?:\.(\d{0,2}))?$');

/// Parses user input such as "120", "120.5", "1,250.75" into paise.
/// Returns null for anything that isn't a plain non-negative amount with ≤ 2 decimals.
int? parsePaise(String input) {
  final match = _amountPattern.firstMatch(input.trim().replaceAll(',', ''));
  if (match == null) return null;
  final whole = match.group(1)!;
  if (whole.length > 9) return null; // keeps int math far from overflow
  final fraction = (match.group(2) ?? '').padRight(2, '0');
  return int.parse(whole) * 100 + int.parse(fraction);
}

/// Plain editable text for an amount: 35000 → "350", 35050 → "350.50".
String paiseToInput(int paise) =>
    paise % 100 == 0 ? '${paise ~/ 100}' : '${paise ~/ 100}.${(paise % 100).toString().padLeft(2, '0')}';

String? validateAmount(String input) {
  if (input.trim().isEmpty) return 'Enter an amount';
  final paise = parsePaise(input);
  if (paise == null) return 'Enter a valid amount, like 120 or 99.50';
  if (paise <= 0) return 'Amount must be more than ₹0';
  if (paise > maxAmountPaise) return 'Amount can be at most ${formatInr(maxAmountPaise)}';
  return null;
}
