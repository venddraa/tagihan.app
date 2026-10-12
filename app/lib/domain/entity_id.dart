import 'dart:math';

final class EntityId {
  EntityId._(this.value);

  static final RegExp _uuidV7Pattern = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    caseSensitive: false,
  );

  final String value;

  factory EntityId.generate({DateTime? now, Random? random}) {
    final timestamp = (now ?? DateTime.now()).toUtc().millisecondsSinceEpoch;
    if (timestamp < 0 || timestamp > 0xffffffffffff) {
      throw RangeError.range(timestamp, 0, 0xffffffffffff, 'timestamp');
    }

    final secureRandom = random ?? Random.secure();
    final bytes = List<int>.generate(16, (_) => secureRandom.nextInt(256));

    for (var index = 5; index >= 0; index--) {
      bytes[index] = (timestamp >> ((5 - index) * 8)) & 0xff;
    }

    bytes[6] = (bytes[6] & 0x0f) | 0x70;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;

    final hex = bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    return EntityId.fromString(
      '${hex.substring(0, 8)}-'
      '${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-'
      '${hex.substring(16, 20)}-'
      '${hex.substring(20)}',
    );
  }

  factory EntityId.fromString(String value) {
    if (!_uuidV7Pattern.hasMatch(value)) {
      throw FormatException('Entity ID harus berupa UUIDv7 yang valid.', value);
    }

    return EntityId._(value.toLowerCase());
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is EntityId && value == other.value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}
