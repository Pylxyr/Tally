import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../logic/backup.dart';
import '../../logic/csv_import.dart';
import '../../logic/dates.dart';
import '../../logic/ids.dart';
import '../../state/app_state.dart';
import '../sheets/other_sheets.dart';
import '../widgets/common.dart';
import 'about.dart';

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

  Future<void> _importCsv(BuildContext context) async {
    final state = AppScope.read(context);
    final messenger = ScaffoldMessenger.of(context);
    void say(String message) => messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));

    final CsvImportPlan plan;
    try {
      final picked = await FilePicker.pickFile();
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      if (bytes.length > maxCsvBytes) {
        throw const CsvImportException('That file is too big to import.');
      }
      plan = planCsvImport(
        utf8.decode(bytes, allowMalformed: true),
        state.data,
        newId: newId,
      );
    } on CsvImportException catch (e) {
      say(e.message);
      return;
    } catch (_) {
      say('Could not read that file');
      return;
    }
    if (plan.txns.isEmpty) {
      say(
        plan.duplicates > 0
            ? 'Nothing new: all ${plan.duplicates} transactions are already here'
            : 'No transactions found in that file',
      );
      return;
    }
    if (!context.mounted) return;

    final extra = StringBuffer();
    if (plan.duplicates > 0) {
      extra.write(' ${plan.duplicates} already here will be left out.');
    }
    if (plan.skipped > 0) {
      extra.write(' ${_count(plan.skipped, 'row', 'rows')} could not be read.');
    }
    if (plan.newCategories.isNotEmpty) {
      final names = [for (final c in plan.newCategories.take(6)) c.name];
      final more = plan.newCategories.length - names.length;
      extra.write(
        ' New categories: ${names.join(', ')}${more > 0 ? ' and $more more' : ''}.',
      );
    }
    final ok = await confirm(
      context,
      title: 'Import from CSV?',
      message:
          '${_count(plan.txns.length, 'transaction', 'transactions')} will be '
          'added.$extra Everything already in Tally stays as it is.',
      confirmLabel: 'Import',
      destructive: false,
    );
    if (!ok) return;
    state.applyCsvImport(plan);
    say('Imported ${_count(plan.txns.length, 'transaction', 'transactions')}');
  }

  Future<void> _backup(BuildContext context) async {
    final state = AppScope.read(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final dir = await getTemporaryDirectory();
      final name = backupFileName(DateTime.now());
      final file = File('${dir.path}/$name');
      await file.writeAsBytes(state.backupBytes(), flush: true);
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile(file.path, mimeType: 'application/octet-stream', name: name),
          ],
          subject: 'Tally backup',
        ),
      );
    } catch (_) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Could not create the backup')),
        );
    }
  }

  String _count(int n, String one, String many) => '$n ${n == 1 ? one : many}';

  Future<void> _restore(BuildContext context) async {
    final state = AppScope.read(context);
    final messenger = ScaffoldMessenger.of(context);
    void say(String message) => messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));

    final BackupContents backup;
    try {
      final picked = await FilePicker.pickFile();
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      if (bytes.length > maxBackupBytes) {
        throw const BackupException('That file is too big to be a Tally backup.');
      }
      backup = decodeBackup(bytes);
    } on BackupException catch (e) {
      say(e.message);
      return;
    } catch (_) {
      say('Could not read that file');
      return;
    }
    if (!context.mounted) return;

    final data = backup.data;
    final made = backup.exportedAt;
    final ok = await confirm(
      context,
      title: 'Restore this backup?',
      message:
          'It holds ${_count(data.txns.length, 'transaction', 'transactions')}, '
          '${_count(data.bills.length, 'recurring bill', 'recurring bills')} and '
          '${_count(data.categories.length, 'category', 'categories')}'
          '${made == null ? '' : ', made on ${dateKey(made.toLocal())}'}. '
          'Restoring replaces everything on this phone. Back up first if you '
          'want to keep what is here now.',
      confirmLabel: 'Replace my data',
    );
    if (!ok) return;
    await state.replaceAllData(data);
    say('Backup restored');
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
                  leading: const Icon(Icons.file_download_rounded),
                  title: const Text('Import from CSV'),
                  subtitle: const Text('Add transactions from a Tally CSV file'),
                  onTap: () => _importCsv(context),
                ),
                const Divider(indent: 16, endIndent: 16),
                ListTile(
                  minTileHeight: 64,
                  leading: const Icon(Icons.backup_rounded),
                  title: const Text('Back up to a file'),
                  subtitle: const Text('Everything, to restore later or move phones'),
                  onTap: () => _backup(context),
                ),
                const Divider(indent: 16, endIndent: 16),
                ListTile(
                  minTileHeight: 64,
                  leading: const Icon(Icons.restore_rounded),
                  title: const Text('Restore from a backup'),
                  subtitle: const Text('Replaces what is on this phone'),
                  onTap: () => _restore(context),
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
          const SizedBox(height: 16),
          const SectionTitle('About'),
          Card(
            child: ListTile(
              minTileHeight: 64,
              leading: const Icon(Icons.info_outline_rounded),
              title: const Text('About Tally'),
              subtitle: const Text('Version, privacy and source code'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.of(context).push(aboutRoute(context)),
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
