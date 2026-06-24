import 'dart:math';

final Random _random = Random.secure();

String newIdempotencyKey({DateTime? now, int? randomValue}) {
  final timestamp = (now ?? DateTime.now().toUtc()).microsecondsSinceEpoch;
  final random = (randomValue ?? _random.nextInt(1 << 32)).toRadixString(16);
  return 'mobile-$timestamp-$random';
}
