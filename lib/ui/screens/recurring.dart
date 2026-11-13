import 'package:material_ui/material_ui.dart';

import '../../logic/models.dart';
import '../../logic/money.dart';
import '../../state/app_state.dart';
import '../sheets/other_sheets.dart';
import '../widgets/common.dart';

Future<void> openRecurringPage(BuildContext context) {
  return Navigator.of(context)
      .push<void>(MaterialPageRoute(builder: (_) => const RecurringPage()));
}

class RecurringPage extends StatelessWidget {
  const RecurringPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final bills = state.bills;
    return Scaffold(
      appBar: AppBar(title: const Text('Recurring bills')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showBillSheet(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New bill'),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          8,
          16,
          120 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 16),
            child: Text(
              'Each bill is added as an expense on its due day. Tally adds '
              'them when you open the app, including any you missed.',
              style: text.bodyLarge?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
          if (bills.isEmpty)
            Card(
              child: EmptyState(
                icon: Icons.event_repeat_rounded,
                title: 'No recurring bills',
                message: 'Add rent, subscriptions or loan payments once and they log themselves.',
                actions: [
                  FilledButton.icon(
                    onPressed: () => showBillSheet(context),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Add a bill'),
                  ),
                ],
              ),
            )
          else
            Card(
              child: Column(
                children: [for (final b in bills) _BillRow(bill: b)],
              ),
            ),
        ],
      ),
    );
  }
}

class _BillRow extends StatelessWidget {
  const _BillRow({required this.bill});

  final RecurringBill bill;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final cat = state.categoryById(bill.categoryId);
    final detail =
        '${state.money(bill.amountCents)} \u00B7 ${ordinal(bill.dayOfMonth)} of each month \u00B7 ${cat.name}';
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 72),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              button: true,
              label:
                  '${bill.name}. $detail. ${bill.active ? '' : 'Paused. '}Tap to edit.',
              excludeSemantics: true,
              onTap: () => showBillSheet(context, bill: bill),
              child: InkWell(
                onTap: () => showBillSheet(context, bill: bill),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                  child: Row(
                    children: [
                      CategoryAvatar(category: cat),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              bill.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: text.titleMedium?.copyWith(
                                color: bill.active
                                    ? cs.onSurface
                                    : cs.onSurfaceVariant,
                              ),
                            ),
                            Text(
                              bill.active ? detail : 'Paused \u00B7 $detail',
                              style: text.bodyMedium?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Semantics(
              label: '${bill.name} active',
              child: Switch(
                value: bill.active,
                onChanged: (v) => state.setBillActive(bill.id, v),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
