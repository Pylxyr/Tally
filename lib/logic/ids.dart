import 'dart:math';

final Random _rng = Random();
int _counter = 0;

/// Short unique id. Roughly sortable by creation time.
String newId() {
  _counter = (_counter + 1) % 1296;
  final t = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
  final c = _counter.toRadixString(36).padLeft(2, '0');
  final r = _rng.nextInt(46656).toRadixString(36).padLeft(3, '0');
  return '$t$c$r';
}
