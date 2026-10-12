final class CalendarDate implements Comparable<CalendarDate> {
  CalendarDate._(this.year, this.month, this.day);

  final int year;
  final int month;
  final int day;

  factory CalendarDate(int year, int month, int day) {
    final normalized = DateTime.utc(year, month, day);

    if (normalized.year != year ||
        normalized.month != month ||
        normalized.day != day) {
      throw ArgumentError.value(
        '$year-$month-$day',
        'date',
        'Tanggal kalender tidak valid.',
      );
    }

    return CalendarDate._(year, month, day);
  }

  factory CalendarDate.fromDateTime(DateTime dateTime) {
    return CalendarDate(dateTime.year, dateTime.month, dateTime.day);
  }

  factory CalendarDate.parse(String value) {
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value);
    if (match == null) {
      throw FormatException(
        'Tanggal harus menggunakan format YYYY-MM-DD.',
        value,
      );
    }

    return CalendarDate(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
    );
  }

  DateTime toUtcDateTime() => DateTime.utc(year, month, day);

  bool isBefore(CalendarDate other) => compareTo(other) < 0;

  bool isAfter(CalendarDate other) => compareTo(other) > 0;

  @override
  int compareTo(CalendarDate other) {
    return toUtcDateTime().compareTo(other.toUtcDateTime());
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CalendarDate &&
          year == other.year &&
          month == other.month &&
          day == other.day;

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() {
    final paddedMonth = month.toString().padLeft(2, '0');
    final paddedDay = day.toString().padLeft(2, '0');
    return '$year-$paddedMonth-$paddedDay';
  }
}
