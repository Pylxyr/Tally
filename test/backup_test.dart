import 'package:flutter_test/flutter_test.dart';
import 'package:tally/logic/backup.dart';
import 'package:tally/logic/dates.dart';
import 'package:tally/logic/defaults.dart';
import 'package:tally/logic/models.dart';

AppData _sample() {
  final data = freshData();
  data.settings = data.settings.copyWith(
    currencySymbol: '\$',
    monthlyBudgetCents: 123400,
    onboarded: true,
  );
  data.txns.add(
    Txn(
      id: 't1',
      kind: TxnKind.expense,
      amountCents: 450662,
      categoryId: fallbackExpenseId,
      date: DateTime(2026, 11, 13),
      note: 'Diesel, "premium"',
    ),
  );
  data.categoryBudgets[fallbackExpenseId] = 5000;
  return data;
}

void main() {
  group('backup file', () {
    test('round trips everything', () {
      final now = DateTime.utc(2026, 11, 18, 1, 2, 3);
      final bytes = encodeBackup(_sample(), now: now);
      final back = decodeBackup(bytes);
      expect(back.exportedAt, now);
      expect(back.data.settings.currencySymbol, '\$');
      expect(back.data.settings.monthlyBudgetCents, 123400);
      expect(back.data.txns, hasLength(1));
      expect(back.data.txns.single.amountCents, 450662);
      expect(back.data.txns.single.note, 'Diesel, "premium"');
      expect(back.data.categoryBudgets[fallbackExpenseId], 5000);
    });

    test('starts with the Tally header and is not plain JSON', () {
      final bytes = encodeBackup(_sample());
      expect(String.fromCharCodes(bytes.sublist(0, 7)), 'TALLYBK');
      expect(bytes[7], backupFormatVersion);
      expect(String.fromCharCodes(bytes).contains('"txns"'), isFalse);
    });

    test('refuses files that are not Tally backups', () {
      expect(() => decodeBackup([]), throwsA(isA<BackupException>()));
      expect(
        () => decodeBackup('{"txns":[]}'.codeUnits),
        throwsA(isA<BackupException>()),
      );
    });

    test('refuses a newer format with a clear message', () {
      final bytes = encodeBackup(_sample());
      bytes[7] = backupFormatVersion + 1;
      expect(
        () => decodeBackup(bytes),
        throwsA(
          isA<BackupException>().having(
            (e) => e.message,
            'message',
            contains('newer version'),
          ),
        ),
      );
    });

    test('refuses damaged data', () {
      final good = encodeBackup(_sample());
      final damaged = [...good.sublist(0, 8), 1, 2, 3, 4, 5, 6, 7, 8];
      expect(
        () => decodeBackup(damaged),
        throwsA(
          isA<BackupException>().having(
            (e) => e.message,
            'message',
            contains('damaged'),
          ),
        ),
      );
    });

    test('drops repeated transaction ids and keeps the Other categories', () {
      final data = _sample();
      data.txns.add(data.txns.first);
      data.categories.removeWhere((c) => c.isFallback);
      final back = decodeBackup(encodeBackup(data)).data;
      expect(back.txns, hasLength(1));
      expect(back.categories.any((c) => c.id == fallbackExpenseId), isTrue);
      expect(back.categories.any((c) => c.id == fallbackIncomeId), isTrue);
    });

    test('file name uses the day and the .tally extension', () {
      expect(
        backupFileName(DateTime(2026, 11, 18)),
        'tally-backup-${dateKey(DateTime(2026, 11, 18))}.tally',
      );
    });
  });
}
