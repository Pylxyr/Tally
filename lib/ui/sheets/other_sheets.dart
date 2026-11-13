import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../logic/defaults.dart';
import '../../logic/models.dart';
import '../../logic/money.dart';
import '../../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

// ---- amount (monthly budget or category limit) -----------------------------

/// Result of [showAmountSheet]. A null [cents] means "remove the limit".
class AmountResult {
  const AmountResult(this.cents);
  final int? cents;
}

Future<AmountResult?> showAmountSheet(
  BuildContext context, {
  required String title,
  required String label,
  String? message,
  int? initialCents,
  String? removeLabel,
}) {
  return showSheet<AmountResult>(
    context,
    (_) => _AmountSheet(
      title: title,
      label: label,
      message: message,
      initialCents: initialCents,
      removeLabel: removeLabel,
    ),
  );
}

class _AmountSheet extends StatefulWidget {
  const _AmountSheet({
    required this.title,
    required this.label,
    this.message,
    this.initialCents,
    this.removeLabel,
  });

  final String title;
  final String label;
  final String? message;
  final int? initialCents;
  final String? removeLabel;

  @override
  State<_AmountSheet> createState() => _AmountSheetState();
}

class _AmountSheetState extends State<_AmountSheet> {
  late final TextEditingController _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    final c = widget.initialCents;
    _controller = TextEditingController(
      text: c == null || c <= 0 ? '' : centsToInput(c),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final cents = parseCents(_controller.text);
    if (cents == null || cents <= 0) {
      setState(() => _error = 'Enter an amount above 0');
      return;
    }
    Navigator.pop(context, AmountResult(cents));
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final cs = Theme.of(context).colorScheme;
    return SheetBody(
      title: widget.title,
      children: [
        if (widget.message != null) ...[
          Text(
            widget.message!,
            style: Theme.of(context).textTheme.bodyLarge
                ?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
        ],
        AmountField(
          controller: _controller,
          symbol: state.symbol,
          label: widget.label,
          autofocus: true,
          errorText: _error,
          onChanged: (_) {
            if (_error != null) setState(() => _error = null);
          },
        ),
        const SizedBox(height: 20),
        FilledButton(onPressed: _save, child: const Text('Save')),
        if (widget.removeLabel != null) ...[
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.pop(context, const AmountResult(null)),
            style: TextButton.styleFrom(foregroundColor: cs.error),
            child: Text(widget.removeLabel!),
          ),
        ],
      ],
    );
  }
}

// ---- currency -----------------------------------------------------------------

const List<String> currencyPresets = [
  '\u20B1',
  '\$',
  '\u20AC',
  '\u00A3',
  '\u00A5',
  '\u20B9',
  '\u20A9',
  '\u0E3F',
  'Rp',
  'RM',
];

/// Chips for common currency symbols plus a field for any other symbol.
class CurrencyPicker extends StatefulWidget {
  const CurrencyPicker({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final String value;
  final ValueChanged<String> onChanged;

  @override
  State<CurrencyPicker> createState() => _CurrencyPickerState();
}

class _CurrencyPickerState extends State<CurrencyPicker> {
  late final TextEditingController _custom;

  @override
  void initState() {
    super.initState();
    _custom = TextEditingController(
      text: currencyPresets.contains(widget.value) ? '' : widget.value,
    );
  }

  @override
  void dispose() {
    _custom.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final s in currencyPresets)
              ChoiceChip(
                showCheckmark: false,
                label: Text(s, style: const TextStyle(fontSize: 18)),
                selected: widget.value == s,
                selectedColor: cs.primaryContainer,
                onSelected: (_) {
                  _custom.clear();
                  widget.onChanged(s);
                },
              ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _custom,
          maxLength: 4,
          inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'\s'))],
          decoration: fieldDecoration(
            context,
            label: 'Other symbol',
            hint: 'For example Kr',
          ).copyWith(counterText: ''),
          onChanged: (v) {
            final t = v.trim();
            if (t.isNotEmpty) widget.onChanged(t);
          },
        ),
      ],
    );
  }
}

Future<void> showCurrencySheet(BuildContext context) {
  return showSheet<void>(context, (_) => const _CurrencySheet());
}

class _CurrencySheet extends StatelessWidget {
  const _CurrencySheet();

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return SheetBody(
      title: 'Currency symbol',
      children: [
        CurrencyPicker(value: state.symbol, onChanged: state.setCurrency),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Done'),
        ),
      ],
    );
  }
}

// ---- category -----------------------------------------------------------------

Future<void> showCategorySheet(
  BuildContext context, {
  Category? category,
  required TxnKind kind,
}) {
  return showSheet<void>(
    context,
    (_) => _CategorySheet(category: category, kind: kind),
  );
}

class _CategorySheet extends StatefulWidget {
  const _CategorySheet({this.category, required this.kind});

  final Category? category;
  final TxnKind kind;

  @override
  State<_CategorySheet> createState() => _CategorySheetState();
}

class _CategorySheetState extends State<_CategorySheet> {
  late final TextEditingController _name;
  late int _color;
  String? _error;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.category?.name ?? '');
    _color = widget.category?.colorValue ?? categoryPalette.first;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Give the category a name');
      return;
    }
    final state = AppScope.read(context);
    final clash = state.categories.any(
      (c) =>
          c.kind == widget.kind &&
          c.id != widget.category?.id &&
          c.name.toLowerCase() == name.toLowerCase(),
    );
    if (clash) {
      setState(() => _error = 'You already have a category with that name');
      return;
    }
    final existing = widget.category;
    if (existing == null) {
      state.addCategory(name, _color, widget.kind);
    } else {
      state.updateCategory(existing.id, name: name, colorValue: _color);
    }
    Navigator.pop(context);
  }

  Future<void> _delete() async {
    final existing = widget.category;
    if (existing == null) return;
    final state = AppScope.read(context);
    final count = state.txnCountFor(existing.id);
    final other = widget.kind == TxnKind.income ? 'Other income' : 'Other';
    final ok = await confirm(
      context,
      title: 'Delete "${existing.name}"?',
      message: count == 0
          ? 'This category has no transactions.'
          : 'Its $count ${count == 1 ? 'transaction moves' : 'transactions move'} to "$other".',
      confirmLabel: 'Delete',
    );
    if (!ok || !mounted) return;
    state.deleteCategory(existing.id);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final existing = widget.category;
    return SheetBody(
      title: existing == null ? 'New category' : 'Edit category',
      children: [
        TextField(
          controller: _name,
          autofocus: existing == null,
          maxLength: 24,
          textCapitalization: TextCapitalization.sentences,
          decoration: fieldDecoration(
            context,
            label: 'Name',
            errorText: _error,
          ).copyWith(counterText: ''),
          onChanged: (_) {
            if (_error != null) setState(() => _error = null);
          },
        ),
        const SizedBox(height: 20),
        Text('Colour', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: [
            for (var i = 0; i < categoryPalette.length; i++)
              _Swatch(
                color: Color(categoryPalette[i]),
                selected: _color == categoryPalette[i],
                label: 'Colour ${i + 1}',
                onTap: () => setState(() => _color = categoryPalette[i]),
              ),
          ],
        ),
        const SizedBox(height: 20),
        FilledButton(onPressed: _save, child: const Text('Save')),
        if (existing != null && !existing.isFallback) ...[
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _delete,
            style: TextButton.styleFrom(foregroundColor: cs.error),
            icon: const Icon(Icons.delete_outline_rounded),
            label: const Text('Delete category'),
          ),
        ],
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.color,
    required this.selected,
    required this.label,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Center(
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: selected
                    ? Border.all(color: cs.onSurface, width: 3)
                    : null,
              ),
              child: selected
                  ? const Icon(
                      Icons.check_rounded,
                      size: 20,
                      color: Colors.white,
                    )
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}

// ---- recurring bill -----------------------------------------------------------

Future<void> showBillSheet(BuildContext context, {RecurringBill? bill}) {
  return showSheet<void>(context, (_) => _BillSheet(bill: bill));
}

class _BillSheet extends StatefulWidget {
  const _BillSheet({this.bill});

  final RecurringBill? bill;

  @override
  State<_BillSheet> createState() => _BillSheetState();
}

class _BillSheetState extends State<_BillSheet> {
  late final TextEditingController _name;
  late final TextEditingController _amount;
  late final TextEditingController _day;
  late String _categoryId;
  String? _nameError;
  String? _amountError;
  String? _dayError;

  @override
  void initState() {
    super.initState();
    final b = widget.bill;
    _name = TextEditingController(text: b?.name ?? '');
    _amount = TextEditingController(
      text: b == null ? '' : centsToInput(b.amountCents),
    );
    _day = TextEditingController(text: b == null ? '' : '${b.dayOfMonth}');
    _categoryId = b?.categoryId ?? 'bills';
  }

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    _day.dispose();
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();
    final cents = parseCents(_amount.text);
    final day = int.tryParse(_day.text.trim());
    setState(() {
      _nameError = name.isEmpty ? 'Give the bill a name' : null;
      _amountError = (cents == null || cents <= 0)
          ? 'Enter an amount above 0'
          : null;
      _dayError = (day == null || day < 1 || day > 31)
          ? 'Enter a day from 1 to 31'
          : null;
    });
    if (_nameError != null || _amountError != null || _dayError != null) {
      return;
    }
    final state = AppScope.read(context);
    final existing = widget.bill;
    if (existing == null) {
      state.addBill(
        name: name,
        amountCents: cents!,
        categoryId: _categoryId,
        dayOfMonth: day!,
      );
    } else {
      state.updateBill(
        existing.copyWith(
          name: name,
          amountCents: cents!,
          categoryId: _categoryId,
          dayOfMonth: day!,
        ),
      );
    }
    Navigator.pop(context);
  }

  Future<void> _delete() async {
    final existing = widget.bill;
    if (existing == null) return;
    final ok = await confirm(
      context,
      title: 'Delete "${existing.name}"?',
      message: 'No more expenses will be added. Ones already added stay in your history.',
      confirmLabel: 'Delete',
    );
    if (!ok || !mounted) return;
    AppScope.read(context).deleteBill(existing.id);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final existing = widget.bill;
    return SheetBody(
      title: existing == null ? 'New recurring bill' : 'Edit recurring bill',
      children: [
        TextField(
          controller: _name,
          autofocus: existing == null,
          maxLength: 40,
          textCapitalization: TextCapitalization.sentences,
          decoration: fieldDecoration(
            context,
            label: 'Name',
            hint: 'Rent, internet, phone plan',
            errorText: _nameError,
          ).copyWith(counterText: ''),
        ),
        const SizedBox(height: 16),
        AmountField(
          controller: _amount,
          symbol: state.symbol,
          errorText: _amountError,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _day,
          keyboardType: TextInputType.number,
          maxLength: 2,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: fieldDecoration(
            context,
            label: 'Due day of the month',
            hint: '1 to 31',
            helperText: 'In shorter months it is added on the last day.',
            errorText: _dayError,
          ).copyWith(counterText: ''),
        ),
        const SizedBox(height: 20),
        Text('Category', style: text.labelLarge),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final c in state.categoriesOf(TxnKind.expense))
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
        FilledButton(onPressed: _save, child: const Text('Save')),
        if (existing != null) ...[
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _delete,
            style: TextButton.styleFrom(foregroundColor: cs.error),
            icon: const Icon(Icons.delete_outline_rounded),
            label: const Text('Delete bill'),
          ),
        ],
      ],
    );
  }
}

// ---- monthly budget -----------------------------------------------------------

Future<void> editMonthlyBudget(BuildContext context) async {
  final state = AppScope.read(context);
  final result = await showAmountSheet(
    context,
    title: 'Monthly budget',
    label: 'Budget for each month',
    message: 'Tally uses this to work out how much you can still spend today.',
    initialCents: state.settings.monthlyBudgetCents,
  );
  final cents = result?.cents;
  if (cents != null) state.setBudget(cents);
}
