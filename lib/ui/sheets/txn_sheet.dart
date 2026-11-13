import 'package:material_ui/material_ui.dart';

import '../../logic/dates.dart';
import '../../logic/defaults.dart';
import '../../logic/ids.dart';
import '../../logic/models.dart';
import '../../logic/money.dart';
import '../../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Opens the add / edit sheet for an expense or income.
Future<void> showTxnSheet(BuildContext context, {Txn? txn, TxnKind? kind}) {
  return showSheet<void>(context, (_) => TxnSheet(txn: txn, kind: kind));
}

class TxnSheet extends StatefulWidget {
  const TxnSheet({super.key, this.txn, this.kind});

  final Txn? txn;
  final TxnKind? kind;

  @override
  State<TxnSheet> createState() => _TxnSheetState();
}

class _TxnSheetState extends State<TxnSheet> {
  late TxnKind _kind;
  late String _categoryId;
  late DateTime _date;
  late final TextEditingController _amount;
  late final TextEditingController _note;
  String? _error;

  bool get _isEdit => widget.txn != null;

  @override
  void initState() {
    super.initState();
    final t = widget.txn;
    _kind = t?.kind ?? widget.kind ?? TxnKind.expense;
    _categoryId = t?.categoryId ?? _defaultCategory(_kind);
    _date = t?.date ?? dateOnly(DateTime.now());
    _amount = TextEditingController(
      text: t == null ? '' : centsToInput(t.amountCents),
    );
    _note = TextEditingController(text: t?.note ?? '');
  }

  String _defaultCategory(TxnKind kind) =>
      kind == TxnKind.income ? fallbackIncomeId : fallbackExpenseId;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = dateOnly(picked));
  }

  void _save() {
    final cents = parseCents(_amount.text);
    if (cents == null || cents <= 0) {
      setState(() => _error = 'Enter an amount above 0');
      return;
    }
    final state = AppScope.read(context);
    final existing = widget.txn;
    if (existing == null) {
      state.addTxn(
        Txn(
          id: newId(),
          kind: _kind,
          amountCents: cents,
          categoryId: _categoryId,
          date: _date,
          note: _note.text.trim(),
        ),
      );
    } else {
      state.updateTxn(
        existing.copyWith(
          kind: _kind,
          amountCents: cents,
          categoryId: _categoryId,
          date: _date,
          note: _note.text.trim(),
        ),
      );
    }
    Navigator.pop(context);
  }

  void _delete() {
    final existing = widget.txn;
    if (existing == null) return;
    final state = AppScope.read(context);
    final messenger = ScaffoldMessenger.of(context);
    final removed = state.deleteTxn(existing.id);
    Navigator.pop(context);
    if (removed != null) showUndoDelete(messenger, state, removed);
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final categories = state.categoriesOf(_kind);
    final today = state.today;

    return SheetBody(
      title: _isEdit ? 'Edit transaction' : 'New transaction',
      children: [
        SegmentedButton<TxnKind>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: TxnKind.expense, label: Text('Expense')),
            ButtonSegment(value: TxnKind.income, label: Text('Income')),
          ],
          selected: {_kind},
          onSelectionChanged: (s) => setState(() {
            _kind = s.first;
            if (!state.categoriesOf(_kind).any((c) => c.id == _categoryId)) {
              _categoryId = _defaultCategory(_kind);
            }
          }),
        ),
        const SizedBox(height: 16),
        AmountField(
          controller: _amount,
          symbol: state.symbol,
          autofocus: !_isEdit,
          errorText: _error,
          onChanged: (_) {
            if (_error != null) setState(() => _error = null);
          },
        ),
        const SizedBox(height: 20),
        Text('Category', style: text.labelLarge),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final c in categories)
              ChoiceChip(
                showCheckmark: false,
                avatar: Icon(
                  categoryIcon(c.iconKey),
                  size: 18,
                  color: Color(c.colorValue),
                ),
                label: Text(c.name),
                selected: c.id == _categoryId,
                selectedColor: cs.primaryContainer,
                onSelected: (_) => setState(() => _categoryId = c.id),
              ),
          ],
        ),
        const SizedBox(height: 20),
        Text('Date', style: text.labelLarge),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            OutlinedButton.icon(
              onPressed: _pickDate,
              icon: const Icon(Icons.calendar_today_rounded, size: 18),
              label: Text(formatDayLabel(_date, today)),
            ),
            if (!isSameDay(_date, today))
              TextButton(
                onPressed: () => setState(() => _date = today),
                child: const Text('Today'),
              ),
            if (!isSameDay(_date, addDays(today, -1)))
              TextButton(
                onPressed: () => setState(() => _date = addDays(today, -1)),
                child: const Text('Yesterday'),
              ),
          ],
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _note,
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.done,
          maxLength: 80,
          decoration: fieldDecoration(
            context,
            label: 'Note (optional)',
            hint: 'What was it for?',
          ).copyWith(counterText: ''),
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _save,
          child: Text(
            _isEdit
                ? 'Save changes'
                : (_kind == TxnKind.income ? 'Add income' : 'Add expense'),
          ),
        ),
        if (_isEdit) ...[
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _delete,
            style: TextButton.styleFrom(foregroundColor: cs.error),
            icon: const Icon(Icons.delete_outline_rounded),
            label: const Text('Delete'),
          ),
        ],
      ],
    );
  }
}

/// Shows "Deleted" with an Undo action that restores the transaction.
void showUndoDelete(
  ScaffoldMessengerState messenger,
  AppState state,
  Txn removed,
) {
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text('Deleted ${state.money(removed.amountCents)}'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => state.restoreTxn(removed),
        ),
      ),
    );
}
