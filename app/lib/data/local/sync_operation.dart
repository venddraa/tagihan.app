import 'dart:convert';

import 'package:tagihan_vendra/domain/bill.dart';
import 'package:tagihan_vendra/domain/entity_id.dart';
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
