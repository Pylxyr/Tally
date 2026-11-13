import 'package:material_ui/material_ui.dart';

import '../../logic/budget_math.dart';
import '../../logic/dates.dart';
import '../../logic/models.dart';
import '../../logic/money.dart';
import '../../state/app_state.dart';
import '../sheets/other_sheets.dart';
import '../sheets/txn_sheet.dart';
import '../theme.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key, required this.onOpenTracker});

  final VoidCallback onOpenTracker;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final today = state.today;
    final hasAny = state.txns.isNotEmpty;

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 16),
            child: Semantics(
              header: true,
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: '${monthNames[today.month - 1]} '),
                    TextSpan(
                      text: '${today.year}',
                      style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                style: text.headlineMedium,
              ),
            ),
          ),
          const _HeroCard(),
          const SizedBox(height: 16),
          if (!hasAny)
            Card(
              child: EmptyState(
                icon: Icons.receipt_long_rounded,
                title: 'No spending yet',
                message: 'Add your first expense to see how your month is going. Everything stays on this phone.',
                actions: [
                  FilledButton.icon(
                    onPressed: () => showTxnSheet(context),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Add an expense'),
                  ),
                  OutlinedButton(
                    onPressed: state.loadSampleData,
                    child: const Text('Load sample data'),
                  ),
                ],
              ),
            )
          else ...[
            const _CategoryDonutCard(),
            const SizedBox(height: 16),
            const _TopCategoriesCard(),
            const SizedBox(height: 16),
            const _WeekCard(),
            const SizedBox(height: 16),
            _RecentCard(onSeeAll: onOpenTracker),
          ],
        ],
      ),
    );
  }
}

// ---- hero -----------------------------------------------------------------------

class _HeroCard extends StatelessWidget {
  const _HeroCard();

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final budget = state.settings.monthlyBudgetCents;

    if (budget <= 0) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: cs.primary,
          borderRadius: BorderRadius.circular(Radii.hero),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Set a monthly budget',
              style: text.headlineSmall?.copyWith(color: cs.onPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              'Then Tally can tell you how much you can still spend today.',
              style: text.bodyLarge?.copyWith(color: cs.onPrimary),
            ),
            const SizedBox(height: 16),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: cs.onPrimary,
                foregroundColor: cs.primary,
              ),
              onPressed: () => editMonthlyBudget(context),
              child: const Text('Set budget'),
            ),
          ],
        ),
      );
    }

    final today = state.today;
    final txns = state.txns;
    final safe = safeToSpendToday(
      budgetCents: budget,
      txns: txns,
      today: today,
    );
    final limit = dailyLimit(budgetCents: budget, txns: txns, today: today);
    final spentToday = spentOnDay(txns, today);
    final spentMonth = spentInMonth(txns, today);
    final pace = paceFor(
      budgetCents: budget,
      spentCents: spentMonth,
      today: today,
    );

    final negative = safe < 0;
    final bg = negative ? cs.error : cs.primary;
    final fg = negative ? cs.onError : cs.onPrimary;
    final units = floorToUnits(safe);
    final heroText = state.money(units * 100);

    final String limitLine = limit <= 0
        ? 'This month\u2019s budget is used up.'
        : 'Daily limit ${state.money(limit.floor())} \u00B7 ${state.money(spentToday)} spent today';

    final String paceLine;
    if (pace.deltaCents.abs() < 100) {
      paceLine = 'Right on pace';
    } else if (pace.deltaCents > 0) {
      paceLine = '${state.money(pace.deltaCents)} over an even pace';
    } else {
      paceLine = '${state.money(-pace.deltaCents)} under an even pace';
    }

    final percent = (pace.spentFraction * 100).round();

    return AnimatedContainer(
      duration: motion(context, 300),
      curve: Curves.easeOut,
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(Radii.hero),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            container: true,
            label:
                'Safe to spend today: ${negative ? 'over by ${state.money(-units * 100)}' : heroText}. $limitLine',
            child: ExcludeSemantics(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Safe to spend today',
                    style: text.titleMedium?.copyWith(color: fg),
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    width: double.infinity,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: TweenAnimationBuilder<double>(
                        tween: Tween<double>(end: units.toDouble()),
                        duration: motion(context, 450),
                        curve: Curves.easeOutCubic,
                        builder: (context, value, _) => Text(
                          state.money(value.round() * 100),
                          maxLines: 1,
                          style: TextStyle(
                            color: fg,
                            fontSize: 64,
                            height: 1.1,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -1.5,
                            fontFeatures: tabularFigures,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(limitLine, style: text.bodyMedium?.copyWith(color: fg)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${state.money(spentMonth)} of ${state.money(budget)}',
                  style: text.titleSmall?.copyWith(
                    color: fg,
                    fontFeatures: tabularFigures,
                  ),
                ),
              ),
              Text('$percent%', style: text.titleSmall?.copyWith(color: fg)),
            ],
          ),
          const SizedBox(height: 6),
          MonthBar(
            spentFraction: pace.spentFraction,
            paceFraction: pace.paceFraction,
            fillColor: fg,
            trackColor: fg.withValues(alpha: 0.28),
            edgeColor: bg,
            semanticsLabel:
                'Month budget: $percent percent spent. The marker shows an even pace at ${(pace.paceFraction * 100).round()} percent. $paceLine.',
          ),
          const SizedBox(height: 6),
          Text(
            '$paceLine \u00B7 day ${today.day} of ${daysInMonth(today.year, today.month)}',
            style: text.bodyMedium?.copyWith(color: fg),
          ),
        ],
      ),
    );
  }
}

// ---- category donut -------------------------------------------------------------

class _CategoryDonutCard extends StatelessWidget {
  const _CategoryDonutCard();

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final today = state.today;
    final ranked = spendingByCategory(state.txns, today);
    final total = ranked.fold<int>(0, (sum, e) => sum + e.value);

    final slices = <DonutSlice>[];
    var shown = 0;
    for (final e in ranked.take(5)) {
      final c = state.categoryById(e.key);
      slices.add(DonutSlice(e.value.toDouble(), Color(c.colorValue)));
      shown += e.value;
    }
    if (total - shown > 0) {
      slices.add(DonutSlice((total - shown).toDouble(), cs.outline));
    }

    final summary = ranked.isEmpty
        ? 'No spending yet this month.'
        : 'Spending by category: ${[for (final e in ranked.take(5)) '${state.categoryById(e.key).name} ${(e.value * 100 / total).round()} percent'].join(', ')}.';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Where it went', style: text.titleLarge),
            const SizedBox(height: 16),
            Center(
              child: DonutChart(
                slices: slices,
                trackColor: cs.surfaceContainer,
                semanticsLabel: summary,
                center: ranked.isEmpty
                    ? Text(
                        'Nothing spent yet',
                        textAlign: TextAlign.center,
                        style: text.bodyMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Spent',
                            style: text.labelLarge?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              state.money(total),
                              style: text.titleLarge?.copyWith(
                                fontSize: 24,
                                fontFeatures: tabularFigures,
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---- top categories -------------------------------------------------------------

class _TopCategoriesCard extends StatelessWidget {
  const _TopCategoriesCard();

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final ranked = spendingByCategory(state.txns, state.today);
    final total = ranked.fold<int>(0, (sum, e) => sum + e.value);
    final top = ranked.take(5).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Top categories', style: text.titleLarge),
            const SizedBox(height: 8),
            if (top.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'Your biggest categories this month show up here.',
                  style: text.bodyLarge?.copyWith(color: cs.onSurfaceVariant),
                ),
              ),
            for (final e in top)
              _TopRow(
                category: state.categoryById(e.key),
                amount: state.money(e.value),
                percent: total == 0 ? 0 : (e.value * 100 / total).round(),
                fraction: top.first.value == 0 ? 0 : e.value / top.first.value,
              ),
          ],
        ),
      ),
    );
  }
}

class _TopRow extends StatelessWidget {
  const _TopRow({
    required this.category,
    required this.amount,
    required this.percent,
    required this.fraction,
  });

  final Category category;
  final String amount;
  final int percent;
  final double fraction;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final color = Color(category.colorValue);
    return Semantics(
      label: '${category.name}, $amount, $percent percent of spending',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            CategoryAvatar(category: category, size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          category.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.titleMedium,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        amount,
                        style: text.titleMedium?.copyWith(
                          fontFeatures: tabularFigures,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: SimpleBar(
                          fraction: fraction,
                          color: color,
                          trackColor: cs.surfaceContainer,
                          height: 8,
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 40,
                        child: Text(
                          '$percent%',
                          textAlign: TextAlign.end,
                          style: text.labelLarge?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---- last 7 days ----------------------------------------------------------------

class _WeekCard extends StatelessWidget {
  const _WeekCard();

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final days = lastDaysSpending(state.txns, state.today);
    final total = days.fold<int>(0, (sum, d) => sum + d.cents);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                children: [
                  Expanded(child: Text('Last 7 days', style: text.titleLarge)),
                  Text(
                    state.money(total),
                    style: text.titleMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontFeatures: tabularFigures,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            WeekBars(days: days, format: state.money),
          ],
        ),
      ),
    );
  }
}

// ---- recent ---------------------------------------------------------------------

class _RecentCard extends StatelessWidget {
  const _RecentCard({required this.onSeeAll});

  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final text = Theme.of(context).textTheme;
    final recent = [...state.txns]
      ..sort((a, b) {
        final c = b.date.compareTo(a.date);
        return c != 0 ? c : b.id.compareTo(a.id);
      });
    final shown = recent.take(5).toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 8, 4),
              child: Row(
                children: [
                  Expanded(child: Text('Recent', style: text.titleLarge)),
                  TextButton(onPressed: onSeeAll, child: const Text('See all')),
                ],
              ),
            ),
            for (final t in shown)
              JustAdded(
                key: ValueKey(t.id),
                active: state.lastAddedId == t.id,
                child: TxnTile(
                  txn: t,
                  onTap: () => showTxnSheet(context, txn: t),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
