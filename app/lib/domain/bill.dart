import 'package:tagihan_vendra/domain/calendar_date.dart';
import 'package:tagihan_vendra/domain/entity_id.dart';
import 'package:tagihan_vendra/domain/money.dart';

enum BillingCycle { oneTime, weekly, monthly, yearly }

enum BillStatus { active, paused, archived }

final class Bill {
  Bill({
    required this.id,
    required this.name,
    required this.amount,
    required this.billingCycle,
    required this.nextDueDate,
    required this.startDate,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.version,
    this.category,
    this.notes,
    this.deletedAt,
  }) {
    if (name.trim().isEmpty) {
      throw ArgumentError.value(name, 'name', 'Nama tagihan wajib diisi.');
    }
    if (nextDueDate.isBefore(startDate)) {
      throw ArgumentError.value(
        nextDueDate,
        'nextDueDate',
        'Jatuh tempo berikutnya tidak boleh sebelum tanggal mulai.',
      );
    }
    _validateMetadata();
  }

  final EntityId id;
  final String name;
  final String? category;
  final Money amount;
  final BillingCycle billingCycle;
  final CalendarDate nextDueDate;
  final CalendarDate startDate;
  final BillStatus status;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final int version;

  bool get isDeleted => deletedAt != null;

  bool get isActive => status == BillStatus.active && !isDeleted;

  void _validateMetadata() {
    if (!createdAt.isUtc || !updatedAt.isUtc || deletedAt?.isUtc == false) {
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
