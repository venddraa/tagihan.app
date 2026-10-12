final class EntityId {
  EntityId._(this.value);

  static final RegExp _uuidV7Pattern = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    caseSensitive: false,
  );

  final String value;

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
