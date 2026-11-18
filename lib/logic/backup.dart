/// Tally backup files. Pure Dart so the format is easy to test.
///
/// A backup is a `.tally` file made of an 8 byte header ("TALLYBK" plus a
/// format version byte) followed by the gzip-compressed JSON of all app data.
/// Only Tally writes and reads this layout, and a file without the header is
/// refused. It is not encrypted: it keeps your data readable by the app, not
/// secret from someone who has the file.
library;

import 'dart:convert';
import 'dart:io' show gzip;
import 'dart:typed_data';

import 'dates.dart';
import 'defaults.dart';
import 'models.dart';

const String backupExtension = 'tally';

/// The newest file layout this version of the app can read and write.
const int backupFormatVersion = 1;

/// Larger files are refused before anything is decoded.
const int maxBackupBytes = 50 * 1024 * 1024;

// "TALLYBK", then one byte for the format version.
const List<int> _magic = [0x54, 0x41, 0x4C, 0x4C, 0x59, 0x42, 0x4B];
const int _headerLength = 8;

/// A backup that could not be used. [message] is safe to show to the person.
class BackupException implements Exception {
  const BackupException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// What a backup file holds.
class BackupContents {
  const BackupContents({required this.data, this.exportedAt});

  final AppData data;

  /// When the backup was made, if the file says.
  final DateTime? exportedAt;
}

String backupFileName(DateTime now) =>
    'tally-backup-${dateKey(now)}.$backupExtension';

/// Packs all app data into the bytes of a `.tally` file.
Uint8List encodeBackup(AppData data, {DateTime? now}) {
  final envelope = <String, dynamic>{
    'app': 'tally',
    'exportedAt': (now ?? DateTime.now()).toUtc().toIso8601String(),
    'data': data.toJson(),
  };
  final packed = gzip.encode(utf8.encode(jsonEncode(envelope)));
  return Uint8List.fromList([..._magic, backupFormatVersion, ...packed]);
}

bool _hasMagic(List<int> bytes) {
  for (var i = 0; i < _magic.length; i++) {
    if (bytes[i] != _magic[i]) return false;
  }
  return true;
}

/// Reads the bytes of a `.tally` file. Throws [BackupException] with a
/// readable message when the file is not a usable Tally backup.
BackupContents decodeBackup(List<int> bytes) {
  if (bytes.length <= _headerLength || !_hasMagic(bytes)) {
    throw const BackupException('This is not a Tally backup file.');
  }
  final version = bytes[_headerLength - 1];
  if (version < 1) {
    throw const BackupException('This is not a Tally backup file.');
  }
  if (version > backupFormatVersion) {
    throw const BackupException(
      'This backup was made by a newer version of Tally. '
      'Update the app and try again.',
    );
  }
  try {
    final text = utf8.decode(gzip.decode(bytes.sublist(_headerLength)));
    final envelope = jsonDecode(text);
    if (envelope is! Map || envelope['app'] != 'tally') {
      throw const FormatException('Not a Tally envelope');
    }
    final data = AppData.fromJson(
      (envelope['data'] as Map).cast<String, dynamic>(),
    );
    _tidy(data);
    final stamp = envelope['exportedAt'];
    return BackupContents(
      data: data,
      exportedAt: stamp is String ? DateTime.tryParse(stamp) : null,
    );
  } catch (_) {
    throw const BackupException(
      'This backup file is damaged and could not be read.',
    );
  }
}

/// Drops repeated ids and makes sure the "Other" categories exist.
void _tidy(AppData data) {
  final categoryIds = <String>{};
  data.categories.removeWhere((c) => !categoryIds.add(c.id));
  final txnIds = <String>{};
  data.txns.removeWhere((t) => !txnIds.add(t.id));
  final billIds = <String>{};
  data.bills.removeWhere((b) => !billIds.add(b.id));
  ensureFallbackCategories(data);
}
