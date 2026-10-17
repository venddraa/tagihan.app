import 'dart:convert';
import 'dart:io';

import 'package:tagihan_vendra/data/local/app_database.dart';
import 'package:tagihan_vendra/data/local/sync_operation.dart';
import 'package:tagihan_vendra/data/sync/sync_http.dart';

enum SyncBootstrapStatus { accepted, duplicate, alreadyCompleted }

final class SyncBootstrapResult {
  const SyncBootstrapResult({
    required this.status,
    required this.serverSequences,
  });

  final SyncBootstrapStatus status;
  final List<int> serverSequences;
}

final class SyncBootstrapRejectedException implements Exception {
  const SyncBootstrapRejectedException(this.message);

  final String message;

  @override
  String toString() => message;
}

final class SyncBootstrapClient {
  factory SyncBootstrapClient({
    required AppDatabase database,
    required Uri serviceBaseUri,
    SyncJSONPost? postJSON,
  }) {
    return SyncBootstrapClient._(
      database,
      serviceBaseUri,
      postJSON ?? postSyncJSONWithDartIO,
    );
  }

  SyncBootstrapClient._(this._database, this._serviceBaseUri, this._postJSON);

  final AppDatabase _database;
  final Uri _serviceBaseUri;
  final SyncJSONPost _postJSON;

  Future<SyncBootstrapResult> bootstrapIfNeeded() async {
    final prepared = await _database.prepareSyncBootstrap();
    if (prepared == null) {
      return const SyncBootstrapResult(
        status: SyncBootstrapStatus.alreadyCompleted,
        serverSequences: [],
      );
    }

    final response = await _postJSON(
      _serviceBaseUri.resolve('/v1/sync/bootstrap'),
      prepared.requestBody,
    );
    if (response.statusCode == HttpStatus.conflict) {
      throw const SyncBootstrapRejectedException(
        'Sync hub sudah berisi data dan tidak dapat menerima bootstrap.',
      );
    }
    if (response.statusCode != HttpStatus.ok) {
      throw SyncUnavailableException(
        'Sync service merespons HTTP ${response.statusCode}.',
      );
    }

    final decoded = _decodeBootstrapResponse(
      response.body,
      expectedBootstrapId: prepared.bootstrapId.value,
    );
    await _database.completeSyncBootstrap(
      bootstrapId: prepared.bootstrapId,
      serverSequences: decoded.serverSequences,
    );
    return decoded;
  }
}

SyncBootstrapResult _decodeBootstrapResponse(
  String responseBody, {
  required String expectedBootstrapId,
}) {
  try {
    final decoded = jsonDecode(responseBody);
    if (decoded is! Map<String, dynamic> ||
        decoded['protocol_version'] != syncProtocolVersion ||
        decoded['bootstrap_id'] != expectedBootstrapId ||
        decoded['status'] is! String ||
        decoded['server_sequences'] is! List<dynamic>) {
      throw const FormatException();
    }
    final status = switch (decoded['status']) {
      'accepted' => SyncBootstrapStatus.accepted,
      'duplicate' => SyncBootstrapStatus.duplicate,
      _ => throw const FormatException(),
    };
    final sequenceValues = decoded['server_sequences'] as List<dynamic>;
    if (sequenceValues.any((value) => value is! int || value < 1)) {
      throw const FormatException();
    }
    final serverSequences = sequenceValues.cast<int>();
    if (serverSequences.toSet().length != serverSequences.length) {
      throw const FormatException();
    }
    return SyncBootstrapResult(
      status: status,
      serverSequences: List.unmodifiable(serverSequences),
    );
  } on Object catch (error) {
    if (error is SyncProtocolException) rethrow;
    throw const SyncProtocolException(
      'Response bootstrap sync service tidak valid.',
    );
  }
}
