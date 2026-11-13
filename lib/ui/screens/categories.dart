import 'package:material_ui/material_ui.dart';

import '../../logic/models.dart';
import '../../state/app_state.dart';
import '../sheets/other_sheets.dart';
import '../widgets/common.dart';

Future<void> openCategoriesPage(BuildContext context) {
  return Navigator.of(context)
      .push<void>(MaterialPageRoute(builder: (_) => const CategoriesPage()));
}

class CategoriesPage extends StatefulWidget {
  const CategoriesPage({super.key});

  @override
  State<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends State<CategoriesPage> {
  TxnKind _kind = TxnKind.expense;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final list = state.categoriesOf(_kind);
    return Scaffold(
      appBar: AppBar(title: const Text('Categories')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showCategorySheet(context, kind: _kind),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New category'),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          8,
          16,
          120 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          SegmentedButton<TxnKind>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: TxnKind.expense, label: Text('Expense')),
              ButtonSegment(value: TxnKind.income, label: Text('Income')),
            ],
            selected: {_kind},
            onSelectionChanged: (s) => setState(() => _kind = s.first),
          ),
          const SizedBox(height: 16),
          Card(
            child: Column(
              children: [
                for (final c in list)
                  Semantics(
                    button: true,
                    label:
                        '${c.name}${c.isFallback ? ', default category' : ''}. Tap to edit.',
                    excludeSemantics: true,
                    onTap: () =>
                        showCategorySheet(context, category: c, kind: _kind),
                    child: InkWell(
                      onTap: () =>
                          showCategorySheet(context, category: c, kind: _kind),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 64),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: Row(
                            children: [
                              CategoryAvatar(category: c),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(c.name, style: text.titleMedium),
                                    if (c.isFallback)
                                      Text(
                                        'Default \u00B7 receives deleted categories',
                                        style: text.bodyMedium?.copyWith(
                                          color: cs.onSurfaceVariant,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: Color(c.colorValue),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                Icons.chevron_right_rounded,
                                color: cs.onSurfaceVariant,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
