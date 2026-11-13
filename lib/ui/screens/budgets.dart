import 'package:material_ui/material_ui.dart';

import '../../logic/budget_math.dart';
import '../../logic/models.dart';
import '../../state/app_state.dart';
import '../sheets/other_sheets.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';
import 'categories.dart';
import 'recurring.dart';

class BudgetsScreen extends StatelessWidget {
  const BudgetsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final today = state.today;
    final budget = state.settings.monthlyBudgetCents;
    final spent = spentInMonth(state.txns, today);
    final byCategory = {
      for (final e in spendingByCategory(state.txns, today)) e.key: e.value,
    };
    final over = budget > 0 && spent > budget;
    final remaining = budget - spent;

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 16),
            child: Semantics(
              header: true,
              child: Text('Budgets', style: text.headlineMedium),
            ),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text('Monthly budget', style: text.titleLarge),
                      ),
                      TextButton(
                        onPressed: () => editMonthlyBudget(context),
                        child: Text(budget > 0 ? 'Edit' : 'Set budget'),
                      ),
                    ],
                  ),
                  if (budget <= 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 4, bottom: 8),
                      child: Text(
                        'Set a budget to see how much you can spend each day.',
                        style: text.bodyLarge?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    )
                  else ...[
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        state.money(budget),
                        style: text.displaySmall?.copyWith(
                          fontFeatures: tabularFigures,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SimpleBar(
                      fraction: spent / budget,
                      color: over ? cs.error : cs.primary,
                      trackColor: cs.surfaceContainer,
                      height: 14,
                    ),
                    const SizedBox(height: 10),
                    Semantics(
                      container: true,
                      child: Text(
                        over
                            ? '${state.money(spent)} spent \u00B7 ${state.money(-remaining)} over'
                            : '${state.money(spent)} spent \u00B7 ${state.money(remaining)} left',
                        style: text.titleMedium?.copyWith(
                          color: over ? cs.error : cs.onSurface,
                          fontFeatures: tabularFigures,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const SectionTitle('By category'),
          Card(
            child: Column(
              children: [
                for (final c in state.categoriesOf(TxnKind.expense))
                  _CategoryBudgetRow(
                    category: c,
                    spent: byCategory[c.id] ?? 0,
                    limit: state.categoryBudgets[c.id],
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const SectionTitle('Manage'),
          Card(
            child: Column(
              children: [
                ListTile(
                  minTileHeight: 64,
                  leading: const Icon(Icons.category_rounded),
                  title: const Text('Categories'),
                  subtitle: const Text('Add, rename, recolour or delete'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => openCategoriesPage(context),
                ),
                const Divider(indent: 16, endIndent: 16),
                ListTile(
                  minTileHeight: 64,
                  leading: const Icon(Icons.event_repeat_rounded),
                  title: const Text('Recurring bills'),
                  subtitle: Text(
                    state.bills.isEmpty
                        ? 'Added automatically on their due day'
                        : '${state.bills.length} ${state.bills.length == 1 ? 'bill' : 'bills'}',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => openRecurringPage(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryBudgetRow extends StatelessWidget {
  const _CategoryBudgetRow({
    required this.category,
    required this.spent,
    required this.limit,
  });

  final Category category;
  final int spent;
  final int? limit;

  Future<void> _edit(BuildContext context) async {
    final state = AppScope.read(context);
    final result = await showAmountSheet(
      context,
      title: '${category.name} limit',
      label: 'Monthly limit',
      message:
          'Get a warning when ${category.name.toLowerCase()} spending '
          'passes this amount in a month.',
      initialCents: limit,
      removeLabel: limit == null ? null : 'Remove limit',
    );
    if (result == null) return;
    state.setCategoryBudget(category.id, result.cents);
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final limit = this.limit;
    final over = limit != null && spent > limit;
    final summary = limit == null
        ? '${state.money(spent)} spent \u00B7 No limit'
        : over
        ? '${state.money(spent)} of ${state.money(limit)} \u00B7 ${state.money(spent - limit)} over'
        : '${state.money(spent)} of ${state.money(limit)}';
    return Semantics(
      button: true,
      onTap: () => _edit(context),
      label:
          '${category.name}. $summary. Tap to ${limit == null ? 'set' : 'change'} the limit.',
      excludeSemantics: true,
      child: InkWell(
        onTap: () => _edit(context),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 72),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                CategoryAvatar(category: category),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.titleMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        summary,
                        style: text.bodyMedium?.copyWith(
                          color: over ? cs.error : cs.onSurfaceVariant,
                          fontWeight: over ? FontWeight.w700 : null,
                        ),
                      ),
                      if (limit != null) ...[
                        const SizedBox(height: 8),
                        SimpleBar(
                          fraction: spent / limit,
                          color: over ? cs.error : Color(category.colorValue),
                          trackColor: cs.surfaceContainer,
                          height: 8,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  limit == null ? Icons.add_rounded : Icons.edit_rounded,
                  color: cs.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
