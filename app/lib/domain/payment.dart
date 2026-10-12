import 'package:tagihan_vendra/domain/calendar_date.dart';
import 'package:tagihan_vendra/domain/entity_id.dart';
import 'package:tagihan_vendra/domain/money.dart';

final class Payment {
  Payment({
    required this.id,
    required this.billId,
    required this.amount,
    required this.dueDate,
    required this.paidAt,
    required this.createdAt,
    required this.updatedAt,
    required this.version,
    this.notes,
    this.deletedAt,
  }) {
    _validateMetadata();
  }

  final EntityId id;
  final EntityId billId;
  final Money amount;
  final CalendarDate dueDate;
  final DateTime paidAt;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final int version;

  bool get isDeleted => deletedAt != null;

  void _validateMetadata() {
    if (!paidAt.isUtc ||
        !createdAt.isUtc ||
        !updatedAt.isUtc ||
        deletedAt?.isUtc == false) {
      throw ArgumentError('Timestamp entity harus menggunakan UTC.');
    }
    if (updatedAt.isBefore(createdAt)) {
      throw ArgumentError('updatedAt tidak boleh sebelum createdAt.');
    }
    if (deletedAt != null &&
        (deletedAt!.isBefore(createdAt) || deletedAt!.isAfter(updatedAt))) {
      throw ArgumentError(
        'deletedAt harus berada di antara createdAt dan updatedAt.',
      );
    }
    if (version < 1) {
      throw RangeError.range(version, 1, null, 'version');
    }
  }
}
