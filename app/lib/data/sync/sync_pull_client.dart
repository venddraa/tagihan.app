import 'dart:convert';
import 'dart:io';

import 'package:tagihan_vendra/data/local/app_database.dart';
import 'package:tagihan_vendra/data/local/sync_operation.dart';
import 'package:tagihan_vendra/data/sync/sync_http.dart';
import 'package:tagihan_vendra/domain/entity_id.dart';

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

final class SyncPullPage {
  const SyncPullPage({
    required this.changes,
    required this.nextCursor,
    required this.hasMore,
  });

  final List<RemoteSyncChange> changes;
  final int nextCursor;
  final bool hasMore;
}

final class SyncPullClient {
  factory SyncPullClient({
    required AppDatabase database,
    required Uri serviceBaseUri,
    SyncJSONGet? getJSON,
  }) {
    return SyncPullClient._(
      database,
      serviceBaseUri,
      getJSON ?? getSyncJSONWithDartIO,
    );
  }

  SyncPullClient._(this._database, this._serviceBaseUri, this._getJSON);

  final AppDatabase _database;
  final Uri _serviceBaseUri;
  final SyncJSONGet _getJSON;

  Future<SyncPullPage> fetchNextPage({int limit = 100}) async {
    if (limit < 1 || limit > 100) {
      throw RangeError.range(limit, 1, 100, 'limit');
    }
    final state = await _database.getLocalSyncState();
    final endpoint = _serviceBaseUri
        .resolve('/v1/sync/pull')
        .replace(
          queryParameters: {
            'after': state.lastPulledSequence.toString(),
            'limit': limit.toString(),
          },
        );
    final response = await _getJSON(endpoint);
    if (response.statusCode != HttpStatus.ok) {
      throw SyncUnavailableException(
        'Sync service merespons HTTP ${response.statusCode}.',
      );
    }
    return _decodePullPage(
      response.body,
      after: state.lastPulledSequence,
      limit: limit,
    );
  }
}

SyncPullPage _decodePullPage(
  String responseBody, {
  required int after,
  required int limit,
}) {
  try {
    final decoded = jsonDecode(responseBody);
    if (decoded is! Map<String, dynamic> ||
        decoded['protocol_version'] != syncProtocolVersion ||
        decoded['changes'] is! List<dynamic> ||
        decoded['next_cursor'] is! int ||
        decoded['has_more'] is! bool) {
      throw const FormatException();
    }
    final rawChanges = decoded['changes'] as List<dynamic>;
    if (rawChanges.length > limit) {
      throw const FormatException();
    }

    var previousSequence = after;
    final changes = <RemoteSyncChange>[];
    for (final rawChange in rawChanges) {
      if (rawChange is! Map<String, dynamic>) {
        throw const FormatException();
      }
      final serverSequence = rawChange['server_sequence'];
      final operationId = rawChange['operation_id'];
      final entityType = rawChange['entity_type'];
      final entityId = rawChange['entity_id'];
      final version = rawChange['version'];
      final payload = rawChange['payload'];
      final createdAtValue = rawChange['created_at'];
      if (serverSequence is! int ||
          serverSequence <= previousSequence ||
          operationId is! String ||
          entityType is! String ||
          entityId is! String ||
          version is! int ||
          version < 1 ||
          payload is! Map<String, dynamic> ||
          payload['id'] != entityId ||
          payload['version'] != version ||
          createdAtValue is! String) {
        throw const FormatException();
      }
      final createdAt = DateTime.parse(createdAtValue);
      if (!createdAt.isUtc) {
        throw const FormatException();
      }
      changes.add(
        RemoteSyncChange(
          serverSequence: serverSequence,
          operationId: EntityId.fromString(operationId),
          entityType: SyncEntityType.values.byName(entityType),
          entityId: EntityId.fromString(entityId),
          version: version,
          payload: Map<String, Object?>.unmodifiable(payload),
          createdAt: createdAt,
        ),
      );
      previousSequence = serverSequence;
    }

    final nextCursor = decoded['next_cursor'] as int;
    final expectedCursor = changes.isEmpty ? after : previousSequence;
    final hasMore = decoded['has_more'] as bool;
    if (nextCursor != expectedCursor ||
        nextCursor < after ||
        (hasMore && changes.length != limit)) {
      throw const FormatException();
    }
    return SyncPullPage(
      changes: List.unmodifiable(changes),
      nextCursor: nextCursor,
      hasMore: hasMore,
    );
  } on Object catch (error) {
    if (error is SyncProtocolException) rethrow;
    throw const SyncProtocolException(
      'Response pull sync service tidak valid.',
    );
  }
}
