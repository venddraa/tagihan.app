import 'dart:convert';

import 'package:tagihan_vendra/domain/bill.dart';
import 'package:tagihan_vendra/domain/calendar_date.dart';
import 'package:tagihan_vendra/domain/entity_id.dart';
import 'package:tagihan_vendra/domain/money.dart';
import 'package:tagihan_vendra/domain/payment.dart';

const syncProtocolVersion = 1;

enum SyncEntityType { bill, payment }

enum SyncOperationType {
  billCreate('bill.create'),
  billUpdate('bill.update'),
  billArchive('bill.archive'),
  paymentRecord('payment.record');

  const SyncOperationType(this.wireName);

  final String wireName;

  static SyncOperationType fromWireName(String value) {
    return values.firstWhere(
      (type) => type.wireName == value,
      orElse: () => throw FormatException(
        'Operation type database tidak dikenal.',
        value,
      ),
    );
  }
}

enum SyncConflictResolution { keepLocal, useRemote }

final class SyncConflictEntry {
  const SyncConflictEntry({
    required this.serverSequence,
    required this.entityType,
    required this.entityId,
    required this.reason,
    required this.localVersion,
    required this.remoteVersion,
    required this.localPayload,
    required this.remotePayload,
    required this.detectedAt,
  });

  final int serverSequence;
  final SyncEntityType entityType;
  final EntityId entityId;
  final String reason;
  final int? localVersion;
  final int remoteVersion;
  final Map<String, Object?>? localPayload;
  final Map<String, Object?> remotePayload;
  final DateTime detectedAt;
}

final class SyncConflictGroup {
  const SyncConflictGroup({required this.operationId, required this.entries});

  final EntityId operationId;
  final List<SyncConflictEntry> entries;

  DateTime get detectedAt => entries.first.detectedAt;
}

final class PendingSyncOperation {
  const PendingSyncOperation({
    required this.localSequence,
    required this.operationId,
    required this.entityType,
    required this.entityId,
    required this.operationType,
    required this.baseVersion,
    required this.payloadJson,
    required this.createdAt,
  });

  final int localSequence;
  final EntityId operationId;
  final SyncEntityType entityType;
  final EntityId entityId;
  final SyncOperationType operationType;
  final int baseVersion;
  final String payloadJson;
  final DateTime createdAt;

  Map<String, Object?> decodePayload() {
    return (jsonDecode(payloadJson) as Map<String, dynamic>).cast();
  }
}

final class LocalSyncState {
  const LocalSyncState({
    required this.deviceId,
    required this.lastPulledSequence,
    required this.createdAt,
  });

  final EntityId deviceId;
  final int lastPulledSequence;
  final DateTime createdAt;
}

final class PreparedSyncBootstrap {
  const PreparedSyncBootstrap({
    required this.bootstrapId,
    required this.requestBody,
  });

  final EntityId bootstrapId;
  final String requestBody;
}

final class RemoteSyncChange {
  const RemoteSyncChange({
    required this.serverSequence,
    required this.operationId,
    required this.entityType,
    required this.entityId,
    required this.version,
    required this.payload,
    required this.createdAt,
  });

  final int serverSequence;
  final EntityId operationId;
  final SyncEntityType entityType;
  final EntityId entityId;
  final int version;
  final Map<String, Object?> payload;
  final DateTime createdAt;
}

final class SyncApplySummary {
  const SyncApplySummary({
    required this.applied,
    required this.ignored,
    required this.conflicts,
    required this.nextCursor,
  });

  final int applied;
  final int ignored;
  final int conflicts;
  final int nextCursor;
}

String encodeBillSnapshot(Bill bill) => jsonEncode(_billSnapshot(bill));

String encodePaymentSnapshot(Payment payment) =>
    jsonEncode(_paymentSnapshot(payment));

String encodePaymentRecord({
  required Payment payment,
  required Bill bill,
  required int billBaseVersion,
}) {
  return jsonEncode({
    'payment': _paymentSnapshot(payment),
    'bill': _billSnapshot(bill),
    'bill_base_version': billBaseVersion,
  });
}

Bill decodeBillSnapshot(Map<String, Object?> payload) {
  try {
    return Bill(
      id: EntityId.fromString(_requiredValue<String>(payload, 'id')),
      name: _requiredValue<String>(payload, 'name'),
      category: _nullableString(payload, 'category'),
      amount: Money(
        minorUnits: _requiredValue<int>(payload, 'amount_minor_units'),
        currency: _currencyFromWire(
          _requiredValue<String>(payload, 'currency'),
        ),
      ),
      billingCycle: _billingCycleFromWire(
        _requiredValue<String>(payload, 'billing_cycle'),
      ),
      nextDueDate: CalendarDate.parse(
        _requiredValue<String>(payload, 'next_due_date'),
      ),
      startDate: CalendarDate.parse(
        _requiredValue<String>(payload, 'start_date'),
      ),
      status: _billStatusFromWire(_requiredValue<String>(payload, 'status')),
      notes: _nullableString(payload, 'notes'),
      createdAt: _utcDateTime(payload, 'created_at'),
      updatedAt: _utcDateTime(payload, 'updated_at'),
      deletedAt: _nullableUtcDateTime(payload, 'deleted_at'),
      version: _requiredValue<int>(payload, 'version'),
    );
  } on FormatException {
    rethrow;
  } on Object catch (_) {
    throw const FormatException('Snapshot Bill tidak valid.');
  }
}

Payment decodePaymentSnapshot(Map<String, Object?> payload) {
  try {
    return Payment(
      id: EntityId.fromString(_requiredValue<String>(payload, 'id')),
      billId: EntityId.fromString(_requiredValue<String>(payload, 'bill_id')),
      amount: Money(
        minorUnits: _requiredValue<int>(payload, 'amount_minor_units'),
        currency: _currencyFromWire(
          _requiredValue<String>(payload, 'currency'),
        ),
      ),
      dueDate: CalendarDate.parse(_requiredValue<String>(payload, 'due_date')),
      paidAt: _utcDateTime(payload, 'paid_at'),
      notes: _nullableString(payload, 'notes'),
      createdAt: _utcDateTime(payload, 'created_at'),
      updatedAt: _utcDateTime(payload, 'updated_at'),
      deletedAt: _nullableUtcDateTime(payload, 'deleted_at'),
      version: _requiredValue<int>(payload, 'version'),
    );
  } on FormatException {
    rethrow;
  } on Object catch (_) {
    throw const FormatException('Snapshot Payment tidak valid.');
  }
}

Map<String, Object?> _billSnapshot(Bill bill) {
  return {
    'id': bill.id.value,
    'name': bill.name,
    'category': bill.category,
    'amount_minor_units': bill.amount.minorUnits,
    'currency': bill.amount.currency.code,
    'billing_cycle': switch (bill.billingCycle) {
      BillingCycle.oneTime => 'one_time',
      BillingCycle.weekly => 'weekly',
      BillingCycle.monthly => 'monthly',
      BillingCycle.yearly => 'yearly',
    },
    'next_due_date': bill.nextDueDate.toString(),
    'start_date': bill.startDate.toString(),
    'status': bill.status.name,
    'notes': bill.notes,
    'created_at': bill.createdAt.toIso8601String(),
    'updated_at': bill.updatedAt.toIso8601String(),
    'deleted_at': bill.deletedAt?.toIso8601String(),
    'version': bill.version,
  };
}

Map<String, Object?> _paymentSnapshot(Payment payment) {
  return {
    'id': payment.id.value,
    'bill_id': payment.billId.value,
    'amount_minor_units': payment.amount.minorUnits,
    'currency': payment.amount.currency.code,
    'due_date': payment.dueDate.toString(),
    'paid_at': payment.paidAt.toIso8601String(),
    'notes': payment.notes,
    'created_at': payment.createdAt.toIso8601String(),
    'updated_at': payment.updatedAt.toIso8601String(),
    'deleted_at': payment.deletedAt?.toIso8601String(),
    'version': payment.version,
  };
}

T _requiredValue<T>(Map<String, Object?> payload, String key) {
  final value = payload[key];
  if (value is! T) {
    throw FormatException('Field $key tidak valid.');
  }
  return value;
}

String? _nullableString(Map<String, Object?> payload, String key) {
  final value = payload[key];
  if (value != null && value is! String) {
    throw FormatException('Field $key tidak valid.');
  }
  return value as String?;
}

DateTime _utcDateTime(Map<String, Object?> payload, String key) {
  final value = DateTime.parse(_requiredValue<String>(payload, key));
  if (!value.isUtc) {
    throw FormatException('Field $key harus menggunakan UTC.');
  }
  return value;
}

DateTime? _nullableUtcDateTime(Map<String, Object?> payload, String key) {
  final value = _nullableString(payload, key);
  if (value == null) return null;
  final parsed = DateTime.parse(value);
  if (!parsed.isUtc) {
    throw FormatException('Field $key harus menggunakan UTC.');
  }
  return parsed;
}

Currency _currencyFromWire(String value) {
  return Currency.values.firstWhere(
    (currency) => currency.code == value,
    orElse: () => throw FormatException('Currency tidak dikenal.', value),
  );
}

BillingCycle _billingCycleFromWire(String value) {
  return switch (value) {
    'one_time' => BillingCycle.oneTime,
    'weekly' => BillingCycle.weekly,
    'monthly' => BillingCycle.monthly,
    'yearly' => BillingCycle.yearly,
    _ => throw FormatException('Billing cycle tidak dikenal.', value),
  };
}

BillStatus _billStatusFromWire(String value) {
  return BillStatus.values.firstWhere(
    (status) => status.name == value,
    orElse: () => throw FormatException('Status Bill tidak dikenal.', value),
  );
}
