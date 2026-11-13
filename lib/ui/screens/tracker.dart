import 'package:material_ui/material_ui.dart';

import '../../logic/dates.dart';
import '../../logic/models.dart';
import '../../logic/money.dart';
import '../../state/app_state.dart';
import '../sheets/txn_sheet.dart';
import '../theme.dart';
import '../widgets/common.dart';

enum KindFilter { all, expense, income }

class FilterState {
  const FilterState({this.kind = KindFilter.all, this.categoryId});

  final KindFilter kind;
  final String? categoryId;

  bool get isActive => kind != KindFilter.all || categoryId != null;
}

sealed class _Row {
  const _Row();
}

class _DayRow extends _Row {
  const _DayRow(this.day, this.spent, this.income);
  final DateTime day;
  final int spent;
  final int income;
}

class _TxnRow extends _Row {
  const _TxnRow(this.txn);
  final Txn txn;
}

class TrackerScreen extends StatefulWidget {
  const TrackerScreen({super.key});

  @override
  State<TrackerScreen> createState() => _TrackerScreenState();
}

class _TrackerScreenState extends State<TrackerScreen> {
  late DateTime _month;
  final TextEditingController _search = TextEditingController();
  String _query = '';
  FilterState _filter = const FilterState();

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _openFilter() async {
    final result = await showSheet<FilterState>(
      context,
      (_) => _FilterSheet(initial: _filter),
    );
    if (result != null) setState(() => _filter = result);
  }

  List<_Row> _rows(AppState state) {
    final q = _query.trim().toLowerCase();
    final items = <Txn>[];
    for (final t in state.txns) {
      if (!isSameMonth(t.date, _month)) continue;
      if (_filter.kind == KindFilter.expense && t.kind != TxnKind.expense) {
        continue;
      }
      if (_filter.kind == KindFilter.income && t.kind != TxnKind.income) {
        continue;
      }
      if (_filter.categoryId != null && t.categoryId != _filter.categoryId) {
        continue;
      }
      if (q.isNotEmpty) {
        final name = state.categoryFor(t).name.toLowerCase();
        if (!t.note.toLowerCase().contains(q) && !name.contains(q)) continue;
      }
      items.add(t);
    }
    items.sort((a, b) {
      final c = dayKey(b.date).compareTo(dayKey(a.date));
      return c != 0 ? c : b.id.compareTo(a.id);
    });

    final rows = <_Row>[];
    var i = 0;
    while (i < items.length) {
      final day = items[i].date;
      var spent = 0;
      var income = 0;
      var j = i;
      while (j < items.length && isSameDay(items[j].date, day)) {
        if (items[j].kind == TxnKind.expense) {
          spent += items[j].amountCents;
        } else {
          income += items[j].amountCents;
        }
        j++;
      }
      rows.add(_DayRow(day, spent, income));
      for (var k = i; k < j; k++) {
        rows.add(_TxnRow(items[k]));
      }
      i = j;
    }
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final today = state.today;
    final isCurrent = isSameMonth(_month, today);
    final rows = _rows(state);

    var spent = 0;
    var income = 0;
    for (final r in rows) {
      if (r is _DayRow) {
        spent += r.spent;
        income += r.income;
      }
    }
    final filtering = _query.trim().isNotEmpty || _filter.isActive;
    final monthHasAny = state.txns.any((t) => isSameMonth(t.date, _month));

    Widget body;
    if (rows.isEmpty) {
      body = SliverToBoxAdapter(
        child: Card(
          child: filtering && monthHasAny
              ? EmptyState(
                  icon: Icons.search_off_rounded,
                  title: 'No matches',
                  message:
                      'Nothing in ${monthNames[_month.month - 1]} fits '
                      'your search or filters.',
                  actions: [
                    OutlinedButton(
                      onPressed: () => setState(() {
                        _search.clear();
                        _query = '';
                        _filter = const FilterState();
                      }),
                      child: const Text('Clear search and filters'),
                    ),
                  ],
                )
              : EmptyState(
                  icon: Icons.event_note_rounded,
                  title: 'Nothing in ${monthNames[_month.month - 1]}',
                  message: isCurrent
                      ? 'Tap Add to log an expense or income.'
                      : 'No expenses or income were logged in this month.',
                ),
        ),
      );
    } else {
      body = SliverList.builder(
        itemCount: rows.length,
        itemBuilder: (context, index) {
          final row = rows[index];
          switch (row) {
            case _DayRow():
              return Padding(
                key: ValueKey('day-${dayKey(row.day)}'),
                padding: EdgeInsets.fromLTRB(8, index == 0 ? 0 : 20, 8, 6),
                child: Semantics(
                  header: true,
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          formatDayLabel(row.day, today),
                          style: text.titleSmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                      if (row.spent > 0)
                        Text(
                          state.money(row.spent),
                          style: text.titleSmall?.copyWith(
                            color: cs.onSurfaceVariant,
                            fontFeatures: tabularFigures,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            case _TxnRow():
              return _SwipeRow(
                key: ValueKey(row.txn.id),
                txn: row.txn,
                state: state,
              );
          }
        },
      );
    }

    return SafeArea(
      bottom: false,
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            sliver: SliverList.list(
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 8),
                  child: Semantics(
                    header: true,
                    child: Text('Tracker', style: text.headlineMedium),
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      tooltip: 'Previous month',
                      onPressed: () =>
                          setState(() => _month = addMonths(_month, -1)),
                      icon: const Icon(Icons.chevron_left_rounded),
                    ),
                    Expanded(
                      child: Semantics(
                        button: !isCurrent,
                        hint: isCurrent ? null : 'Jump to the current month',
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: isCurrent
                              ? null
                              : () => setState(
                                  () => _month = DateTime(
                                    today.year,
                                    today.month,
                                  ),
                                ),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: 48),
                            child: Center(
                              child: Text(
                                formatMonth(_month),
                                style: text.titleLarge,
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Next month',
                      onPressed: isCurrent
                          ? null
                          : () => setState(() => _month = addMonths(_month, 1)),
                      icon: const Icon(Icons.chevron_right_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _search,
                        textInputAction: TextInputAction.search,
                        onChanged: (v) => setState(() => _query = v),
                        decoration: fieldDecoration(
                          context,
                          hint: 'Search notes and categories',
                          prefixIcon: const Icon(Icons.search_rounded),
                          suffixIcon: _query.isEmpty
                              ? null
                              : IconButton(
                                  tooltip: 'Clear search',
                                  icon: const Icon(Icons.close_rounded),
                                  onPressed: () => setState(() {
                                    _search.clear();
                                    _query = '';
                                  }),
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      tooltip: _filter.isActive
                          ? 'Filters (active)'
                          : 'Filters',
                      onPressed: _openFilter,
                      icon: Badge(
                        isLabelVisible: _filter.isActive,
                        child: const Icon(Icons.tune_rounded),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (rows.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
                    child: Semantics(
                      container: true,
                      label:
                          'Spent ${state.money(spent)}. Income ${state.money(income)}.',
                      excludeSemantics: true,
                      child: Row(
                        children: [
                          _Total(
                            label: 'Spent',
                            value: state.money(spent),
                            color: cs.onSurface,
                          ),
                          const SizedBox(width: 24),
                          _Total(
                            label: 'Income',
                            value: state.money(income),
                            color: cs.primary,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
            sliver: body,
          ),
        ],
      ),
    );
  }
}

class _Total extends StatelessWidget {
  const _Total({required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: text.labelLarge?.copyWith(color: cs.onSurfaceVariant),
        ),
        Text(
          value,
          style: text.titleLarge?.copyWith(
            color: color,
            fontFeatures: tabularFigures,
          ),
        ),
      ],
    );
  }
}

/// A transaction row that can be swiped away. Tapping edits it.
class _SwipeRow extends StatelessWidget {
  const _SwipeRow({super.key, required this.txn, required this.state});

  final Txn txn;
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final messenger = ScaffoldMessenger.of(context);
    return JustAdded(
      active: state.lastAddedId == txn.id,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Dismissible(
            key: ValueKey(txn.id),
            direction: DismissDirection.endToStart,
            resizeDuration: motion(context, 220),
            movementDuration: motion(context, 220),
            background: Container(
              color: cs.errorContainer,
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 24),
              child: Icon(
                Icons.delete_outline_rounded,
                color: cs.onErrorContainer,
              ),
            ),
            onDismissed: (_) {
              final removed = state.deleteTxn(txn.id);
              if (removed != null) showUndoDelete(messenger, state, removed);
            },
            child: Material(
              color: cs.surfaceContainerLow,
              child: TxnTile(
                txn: txn,
                onTap: () => showTxnSheet(context, txn: txn),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({required this.initial});

  final FilterState initial;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late KindFilter _kind;
  String? _categoryId;

  @override
  void initState() {
    super.initState();
    _kind = widget.initial.kind;
    _categoryId = widget.initial.categoryId;
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final categories = categoriesFor(state, _kind);
    return SheetBody(
      title: 'Filter',
      children: [
        SegmentedButton<KindFilter>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: KindFilter.all, label: Text('All')),
            ButtonSegment(value: KindFilter.expense, label: Text('Expenses')),
            ButtonSegment(value: KindFilter.income, label: Text('Income')),
          ],
          selected: {_kind},
          onSelectionChanged: (s) => setState(() {
            _kind = s.first;
            if (_categoryId != null &&
                !categoriesFor(state, _kind).any((c) => c.id == _categoryId)) {
              _categoryId = null;
            }
          }),
        ),
        const SizedBox(height: 20),
        Text('Category', style: text.labelLarge),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            ChoiceChip(
              showCheckmark: false,
              label: const Text('All categories'),
              selected: _categoryId == null,
              selectedColor: cs.primaryContainer,
              onSelected: (_) => setState(() => _categoryId = null),
            ),
            for (final c in categories)
              ChoiceChip(
                showCheckmark: false,
                avatar: Icon(
                  categoryIcon(c.iconKey),
                  size: 18,
                  color: Color(c.colorValue),
                ),
                label: Text(c.name),
                selected: _categoryId == c.id,
                selectedColor: cs.primaryContainer,
                onSelected: (_) => setState(() => _categoryId = c.id),
              ),
          ],
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: () => Navigator.pop(
            context,
            FilterState(kind: _kind, categoryId: _categoryId),
          ),
          child: const Text('Show results'),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => Navigator.pop(context, const FilterState()),
          child: const Text('Reset filters'),
        ),
      ],
    );
  }

  List<Category> categoriesFor(AppState state, KindFilter kind) => [
    for (final c in state.categories)
      if (kind == KindFilter.all ||
          (kind == KindFilter.expense && c.kind == TxnKind.expense) ||
          (kind == KindFilter.income && c.kind == TxnKind.income))
        c,
  ];
}
