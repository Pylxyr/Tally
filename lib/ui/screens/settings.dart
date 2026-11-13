import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../logic/dates.dart';
import '../../state/app_state.dart';
import '../sheets/other_sheets.dart';
import '../widgets/common.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _export(BuildContext context) async {
    final state = AppScope.read(context);
    final messenger = ScaffoldMessenger.of(context);
    if (state.txns.isEmpty) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Nothing to export yet')));
      return;
    }
    try {
      final dir = await getTemporaryDirectory();
      final name = 'tally-export-${dateKey(DateTime.now())}.csv';
      final file = File('${dir.path}/$name');
      await file.writeAsString(state.csv(), flush: true);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'text/csv', name: name)],
          subject: 'Tally export',
        ),
      );
    } catch (_) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Could not create the export')),
        );
    }
  }

  Future<void> _deleteAll(BuildContext context) async {
    final state = AppScope.read(context);
    final ok = await confirm(
      context,
      title: 'Delete all data?',
      message: 'This removes every transaction, category change, budget and recurring bill from this phone. It cannot be undone.',
      confirmLabel: 'Delete everything',
    );
    if (ok) state.deleteAllData();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 16),
            child: Semantics(
              header: true,
              child: Text('Settings', style: text.headlineMedium),
            ),
          ),
          const SectionTitle('Appearance'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SegmentedButton<String>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: 'system',
                    label: Text('System'),
                    icon: Icon(Icons.brightness_auto_rounded),
                  ),
                  ButtonSegment(
                    value: 'light',
                    label: Text('Light'),
                    icon: Icon(Icons.light_mode_rounded),
                  ),
                  ButtonSegment(
                    value: 'dark',
                    label: Text('Dark'),
                    icon: Icon(Icons.dark_mode_rounded),
                  ),
                ],
                selected: {state.settings.themeModeKey},
                onSelectionChanged: (s) => state.setThemeMode(s.first),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const SectionTitle('Money'),
          Card(
            child: ListTile(
              minTileHeight: 64,
              leading: const Icon(Icons.payments_rounded),
              title: const Text('Currency symbol'),
              subtitle: const Text('Shown before every amount'),
              trailing: Text(
                state.symbol,
                style: text.titleLarge?.copyWith(color: cs.primary),
              ),
              onTap: () => showCurrencySheet(context),
            ),
          ),
          const SizedBox(height: 16),
          const SectionTitle('Your data'),
          Card(
            child: Column(
              children: [
                ListTile(
                  minTileHeight: 64,
                  leading: const Icon(Icons.ios_share_rounded),
                  title: const Text('Export as CSV'),
                  subtitle: const Text('Share every transaction as a file'),
                  onTap: () => _export(context),
                ),
                const Divider(indent: 16, endIndent: 16),
                ListTile(
                  minTileHeight: 64,
                  leading: Icon(Icons.delete_forever_rounded, color: cs.error),
                  title: Text(
                    'Delete all data',
                    style: TextStyle(color: cs.error),
                  ),
                  subtitle: const Text('Start again from scratch'),
                  onTap: () => _deleteAll(context),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 20, 8, 0),
            child: Text(
              'Tally keeps everything on this phone. It has no accounts and '
              'never connects to the internet.',
              textAlign: TextAlign.center,
              style: text.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}
