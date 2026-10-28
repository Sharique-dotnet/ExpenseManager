import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../app/widgets.dart';
import '../../core/dates.dart';
import '../../core/money.dart';
import 'expense.dart';
import 'expense_providers.dart';
import 'expense_repository.dart';
import 'expense_widgets.dart';

/// Opens the add/edit sheet and confirms the outcome with a snackbar.
/// [messenger] overrides where the confirmation appears.
Future<void> showExpenseForm(
  BuildContext context, {
  Expense? existing,
  DateTime? initialDate,
  ScaffoldMessengerState? messenger,
}) async {
  messenger ??= ScaffoldMessenger.of(context);
  final message = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => ExpenseForm(existing: existing, initialDate: initialDate),
  );
  if (message != null) messenger.showSnackBar(SnackBar(content: Text(message)));
}

final _amountInput = RegExp(r'^\d{0,8}(\.\d{0,2})?$');

class ExpenseForm extends ConsumerStatefulWidget {
  const ExpenseForm({super.key, this.existing, this.initialDate});

  final Expense? existing;

  /// Prefilled date for new expenses (defaults to today; future dates clamp to today).
  final DateTime? initialDate;

  @override
  ConsumerState<ExpenseForm> createState() => _ExpenseFormState();
}

class _ExpenseFormState extends ConsumerState<ExpenseForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _amount;
  late final String _id;
  late DateTime _date;

  /// Starts empty for new and legacy expenses; the user must choose.
  PaymentType? _paymentType;
  late TimeOfDay _time;
  String? _timeNote;
  String? _saveError;
  bool _saving = false;
  bool _submitted = false;

  bool get _isEdit => widget.existing != null;
  DateTime get _occurredAt => combine(_date, _time.hour, _time.minute);

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    final now = DateTime.now();
    _name = TextEditingController(text: existing?.itemName);
    _amount = TextEditingController(text: existing == null ? '' : paiseToInput(existing.amountPaise));
    _paymentType = existing?.paymentType;
    _id = existing?.id ?? ref.read(expenseRepositoryProvider).newId();
    if (existing != null) {
      _date = dateOfKey(existing.localDate);
      _time = TimeOfDay.fromDateTime(existing.occurredAt);
    } else {
      final requested = dateOnly(widget.initialDate ?? now);
      _date = requested.isAfter(dateOnly(now)) ? dateOnly(now) : requested;
      // Current time is valid both for today (it's "now") and any past date.
      _time = TimeOfDay.fromDateTime(now);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: dateOnly(now), // no future dates
      helpText: 'Expense date',
    );
    if (picked == null || !mounted) return;
    setState(() {
      _date = picked;
      _timeNote = null;
      if (_occurredAt.isAfter(now)) {
        _time = TimeOfDay.fromDateTime(now);
        _timeNote = 'Time moved to now, since it can’t be in the future.';
      }
    });
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time, helpText: 'Expense time');
    if (picked == null || !mounted) return;
    setState(() {
      _time = picked;
      _timeNote = null;
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _submitted = true);
    final formValid = _formKey.currentState!.validate();
    if (!formValid || validateOccurredAt(_occurredAt, DateTime.now()) != null) return;

    final draft = ExpenseDraft(
      itemName: _name.text.trim(),
      amountPaise: parsePaise(_amount.text)!,
      occurredAt: _occurredAt,
      paymentType: _paymentType!,
    );
    final repo = ref.read(expenseRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      final confirmed = await waitForServer(
        _isEdit ? repo.update(_id, draft) : repo.create(_id, draft),
        onLateError: (_) {
          if (messenger.mounted) {
            messenger.showSnackBar(
              const SnackBar(content: Text("An offline change couldn't be synced and was undone.")),
            );
          }
        },
      );
      if (!mounted) return;
      Navigator.pop(
        context,
        confirmed ? (_isEdit ? 'Expense updated' : 'Expense saved') : 'Saved on this device. Will sync when online.',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _saveError = "Couldn't save. ${describeError(e)}";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final today = dateOnly(DateTime.now());
    final timeError = validateOccurredAt(_occurredAt, DateTime.now());
    final dateLabel = formatPickerDate(_date, today);

    return PopScope(
      canPop: !_saving,
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(Space.page, 0, Space.page, Space.lg),
          child: Form(
            key: _formKey,
            autovalidateMode: _submitted ? AutovalidateMode.onUserInteraction : AutovalidateMode.disabled,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(_isEdit ? 'Edit expense' : 'Add expense', style: text.headlineMedium)),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: _saving ? null : () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: Space.lg),
                TextFormField(
                  controller: _name,
                  autofocus: !_isEdit,
                  enabled: !_saving,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.next,
                  maxLength: maxItemNameLength,
                  buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                  decoration: const InputDecoration(labelText: 'Item', hintText: 'Tea, lunch, petrol…'),
                  validator: (v) => validateItemName(v ?? ''),
                ),
                const SizedBox(height: Space.md),
                TextFormField(
                  controller: _amount,
                  enabled: !_saving,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  textInputAction: TextInputAction.done,
                  inputFormatters: [
                    TextInputFormatter.withFunction((old, next) => _amountInput.hasMatch(next.text) ? next : old),
                  ],
                  style: text.titleMedium,
                  decoration: InputDecoration(
                    labelText: 'Amount',
                    hintText: '0.00',
                    prefixIcon: Padding(
                      padding: const EdgeInsets.only(left: Space.lg, right: Space.sm),
                      child: Text('₹', style: text.titleMedium!.copyWith(color: AppColors.moss)),
                    ),
                    prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                  ),
                  validator: (v) => validateAmount(v ?? ''),
                  onFieldSubmitted: (_) => _save(),
                ),
                const SizedBox(height: Space.md),
                DropdownButtonFormField<PaymentType>(
                  initialValue: _paymentType,
                  decoration: const InputDecoration(labelText: 'Payment type'),
                  hint: const Text('Select'),
                  borderRadius: BorderRadius.circular(Radii.input),
                  dropdownColor: AppColors.white,
                  items: [
                    for (final type in PaymentType.values) DropdownMenuItem(value: type, child: Text(type.label)),
                  ],
                  onChanged: _saving ? null : (type) => setState(() => _paymentType = type),
                  validator: validatePaymentType,
                ),
                const SizedBox(height: Space.md),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _PickerField(label: 'Date', value: dateLabel, onTap: _saving ? null : _pickDate),
                    ),
                    const SizedBox(width: Space.md),
                    Expanded(
                      child: _PickerField(
                        label: 'Time',
                        value: formatTime(_occurredAt),
                        onTap: _saving ? null : _pickTime,
                        errorText: timeError,
                      ),
                    ),
                  ],
                ),
                if (_timeNote != null && timeError == null) ...[
                  const SizedBox(height: Space.sm),
                  Text(_timeNote!, style: text.bodySmall),
                ],
                if (_saveError != null) ...[const SizedBox(height: Space.lg), InlineError(_saveError!)],
                const SizedBox(height: Space.xl),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox.square(
                          dimension: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.white),
                        )
                      : Text(_isEdit ? 'Save changes' : 'Save expense'),
                ),
                const SizedBox(height: Space.sm),
                TextButton(onPressed: _saving ? null : () => Navigator.pop(context), child: const Text('Cancel')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Tappable field that looks like a text input and opens a picker.
class _PickerField extends StatelessWidget {
  const _PickerField({required this.label, required this.value, this.onTap, this.errorText});

  final String label;
  final String value;
  final VoidCallback? onTap;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$label, $value',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Radii.input),
        child: InputDecorator(
          decoration: InputDecoration(labelText: label, errorText: errorText, errorMaxLines: 2),
          child: Text(
            value,
            style: Theme.of(context).textTheme.bodyLarge,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}
