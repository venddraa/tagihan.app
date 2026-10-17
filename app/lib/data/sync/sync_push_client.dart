import 'dart:convert';
import 'dart:io';

import 'package:tagihan_vendra/data/local/app_database.dart';
import 'package:tagihan_vendra/data/local/sync_operation.dart';
import 'package:tagihan_vendra/data/sync/sync_http.dart';
import 'package:tagihan_vendra/domain/entity_id.dart';

export 'package:tagihan_vendra/data/sync/sync_http.dart';

final class SyncPushSummary {
  const SyncPushSummary({
    required this.sent,
    required this.completed,
    required this.conflicts,
    required this.rejected,
  });

  final int sent;
  final int completed;
  final int conflicts;
  final int rejected;

  bool get hadWork => sent > 0;
}

final class SyncPushClient {
  factory SyncPushClient({
    required AppDatabase database,
    required Uri serviceBaseUri,
    SyncJSONPost? postJSON,
  }) {
    return SyncPushClient._(
      database,
      serviceBaseUri,
      postJSON ?? postSyncJSONWithDartIO,
    );
  }

  SyncPushClient._(this._database, this._serviceBaseUri, this._postJSON);

  final AppDatabase _database;
  final Uri _serviceBaseUri;
  final SyncJSONPost _postJSON;

  Future<SyncPushSummary> pushPending() async {
    final operations = await _database.getPendingSyncOperations();
    if (operations.isEmpty) {
      return const SyncPushSummary(
        sent: 0,
        completed: 0,
        conflicts: 0,
        rejected: 0,
      );
    }

    final state = await _database.getLocalSyncState();
    final requestBody = jsonEncode({
      'protocol_version': syncProtocolVersion,
      'device_id': state.deviceId.value,
      'operations': operations.map(_operationRequest).toList(growable: false),
    });
    final response = await _postJSON(
      _serviceBaseUri.resolve('/v1/sync/push'),
      requestBody,
    );
    if (response.statusCode != HttpStatus.ok) {
      throw SyncUnavailableException(
        'Sync service merespons HTTP ${response.statusCode}.',
      );
    }

    final results = _decodeResults(
      response.body,
      expectedOperationIds: operations
          .map((operation) => operation.operationId.value)
          .toSet(),
    );
    final completedIds = results
        .where(
          (result) =>
              result.status == _PushStatus.accepted ||
              result.status == _PushStatus.duplicate,
        )
        .map((result) => result.operationId);
    final completed = await _database.acknowledgeSyncOperations(completedIds);

    return SyncPushSummary(
      sent: operations.length,
      completed: completed,
      conflicts: results
          .where((result) => result.status == _PushStatus.conflict)
          .length,
      rejected: results
          .where((result) => result.status == _PushStatus.rejected)
          .length,
    );
  }
}

Map<String, Object?> _operationRequest(PendingSyncOperation operation) {
  return {
    'operation_id': operation.operationId.value,
    'entity_type': operation.entityType.name,
    'entity_id': operation.entityId.value,
    'operation_type': operation.operationType.wireName,
    'base_version': operation.baseVersion,
    'payload': operation.decodePayload(),
    'created_at': operation.createdAt.toUtc().toIso8601String(),
  };
}

enum _PushStatus { accepted, duplicate, conflict, rejected }

final class _PushResult {
  const _PushResult({required this.operationId, required this.status});

  final EntityId operationId;
  final _PushStatus status;
}

List<_PushResult> _decodeResults(
  String responseBody, {
  required Set<String> expectedOperationIds,
}) {
  try {
    final decoded = jsonDecode(responseBody);
    if (decoded is! Map<String, dynamic> ||
        decoded['protocol_version'] != syncProtocolVersion ||
        decoded['results'] is! List<dynamic>) {
      throw const FormatException();
    }

    final seen = <String>{};
    final results = <_PushResult>[];
    for (final value in decoded['results'] as List<dynamic>) {
      if (value is! Map<String, dynamic>) {
        throw const FormatException();
      }
      final operationId = value['operation_id'];
      final status = value['status'];
      if (operationId is! String ||
          status is! String ||
          !expectedOperationIds.contains(operationId) ||
          !seen.add(operationId)) {
        throw const FormatException();
      }
      results.add(
        _PushResult(
          operationId: EntityId.fromString(operationId),
          status: _PushStatus.values.byName(status),
        ),
      );
    }
    if (seen.length != expectedOperationIds.length) {
      throw const FormatException();
    }
    return results;
  } on Object catch (error) {
    if (error is SyncProtocolException) rethrow;
    throw const SyncProtocolException('Response sync service tidak valid.');
  }
}
