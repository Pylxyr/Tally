import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../logic/models.dart';

/// Reads and writes all app data as one JSON file in the app's private
/// documents folder. Nothing leaves the device.
class Store {
  Store(this.file);

  final File file;

  /// Set when the saved file could not be read and was set aside.
  bool recoveredFromCorruption = false;

  Future<void> _chain = Future<void>.value();

  static Future<Store> open() async {
    final dir = await getApplicationDocumentsDirectory();
    return Store(File('${dir.path}/tally_data.json'));
  }

  Future<AppData?> read() async {
    if (!await file.exists()) return null;
    try {
      final text = await file.readAsString();
      final json = jsonDecode(text) as Map<String, dynamic>;
      return AppData.fromJson(json);
    } catch (_) {
      // Keep the unreadable file instead of overwriting it.
      try {
        final stamp = DateTime.now().millisecondsSinceEpoch;
        await file.rename('${file.path}.unreadable-$stamp');
      } catch (_) {}
      recoveredFromCorruption = true;
      return null;
    }
  }

  /// Queues a save. Writes happen one at a time, via a temp file and rename,
  /// so a crash mid-write cannot leave a half-written data file.
  Future<void> save(AppData data) {
    final text = jsonEncode(data.toJson());
    _chain = _chain.then((_) async {
      try {
        final tmp = File('${file.path}.tmp');
        await tmp.writeAsString(text, flush: true);
        await tmp.rename(file.path);
      } catch (_) {
        // Saving is best effort; the next change will try again.
      }
    });
    return _chain;
  }
}
