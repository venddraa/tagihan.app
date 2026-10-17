import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tagihan_vendra/data/local/app_database.dart';
import 'package:tagihan_vendra/data/local/sync_operation.dart';
import 'package:tagihan_vendra/data/sync/sync_http.dart';
import 'package:tagihan_vendra/data/sync/sync_pull_client.dart';

void main() {
  late AppDatabase database;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    final bootstrap = await database.prepareSyncBootstrap(
      now: DateTime.utc(2026, 10, 17),
    );
    await database.completeSyncBootstrap(
      bootstrapId: bootstrap!.bootstrapId,
      serverSequences: const [7],
    );
  });

  tearDown(() => database.close());

  test('meminta halaman setelah cursor lokal dan membaca perubahan', () async {
    final client = SyncPullClient(
      database: database,
      serviceBaseUri: Uri.parse('http://127.0.0.1:8787'),
      getJSON: (uri) async {
        expect(
          uri.toString(),
          'http://127.0.0.1:8787/v1/sync/pull?after=7&limit=2',
        );
        return SyncHTTPResponse(
          statusCode: 200,
          body: jsonEncode({
            'protocol_version': 1,
            'changes': [
              _change(
                sequence: 8,
                entityType: 'payment',
                entityId: '0199e7d0-0000-7000-8000-000000000011',
              ),
              _change(
                sequence: 9,
                entityType: 'bill',
                entityId: '0199e7d0-0000-7000-8000-000000000010',
                version: 2,
              ),
            ],
            'next_cursor': 9,
            'has_more': true,
          }),
        );
      },
    );

    final page = await client.fetchNextPage(limit: 2);

    expect(page.nextCursor, 9);
    expect(page.hasMore, isTrue);
    expect(page.changes, hasLength(2));
    expect(page.changes.first.serverSequence, 8);
    expect(page.changes.first.entityType, SyncEntityType.payment);
    expect(page.changes.last.entityType, SyncEntityType.bill);
    expect(page.changes.last.version, 2);
    expect(page.changes.first.operationId, page.changes.last.operationId);
    expect((await database.getLocalSyncState()).lastPulledSequence, 7);
  });

  test('menerima halaman kosong tanpa memajukan cursor lokal', () async {
    final client = SyncPullClient(
      database: database,
      serviceBaseUri: Uri.parse('http://127.0.0.1:8787'),
      getJSON: (uri) async => const SyncHTTPResponse(
        statusCode: 200,
        body: '''{
          "protocol_version": 1,
          "changes": [],
          "next_cursor": 7,
          "has_more": false
        }''',
      ),
    );

    final page = await client.fetchNextPage();

    expect(page.changes, isEmpty);
    expect(page.nextCursor, 7);
    expect(page.hasMore, isFalse);
    expect((await database.getLocalSyncState()).lastPulledSequence, 7);
  });

  test(
    'menolak urutan change dan cursor response yang tidak konsisten',
    () async {
      final invalidBodies = [
        jsonEncode({
          'protocol_version': 1,
          'changes': [
            _change(
              sequence: 7,
              entityType: 'bill',
              entityId: '0199e7d0-0000-7000-8000-000000000010',
            ),
          ],
          'next_cursor': 7,
          'has_more': false,
        }),
        jsonEncode({
          'protocol_version': 1,
          'changes': [
            _change(
              sequence: 8,
              entityType: 'bill',
              entityId: '0199e7d0-0000-7000-8000-000000000010',
            ),
          ],
          'next_cursor': 9,
          'has_more': false,
        }),
        jsonEncode({
          'protocol_version': 1,
          'changes': [
            _change(
              sequence: 8,
              entityType: 'bill',
              entityId: '0199e7d0-0000-7000-8000-000000000010',
              payloadId: '0199e7d0-0000-7000-8000-000000000099',
            ),
          ],
          'next_cursor': 8,
          'has_more': false,
        }),
      ];

      for (final body in invalidBodies) {
        final client = SyncPullClient(
          database: database,
          serviceBaseUri: Uri.parse('http://127.0.0.1:8787'),
          getJSON: (uri) async => SyncHTTPResponse(statusCode: 200, body: body),
        );

        await expectLater(
          client.fetchNextPage(),
          throwsA(isA<SyncProtocolException>()),
        );
      }
      expect((await database.getLocalSyncState()).lastPulledSequence, 7);
    },
  );

  test('HTTP gagal tidak mengubah cursor lokal', () async {
    final client = SyncPullClient(
      database: database,
      serviceBaseUri: Uri.parse('http://127.0.0.1:8787'),
      getJSON: (uri) async => const SyncHTTPResponse(
        statusCode: 503,
        body: '{"error":{"code":"database_unavailable"}}',
      ),
    );

    await expectLater(
      client.fetchNextPage(),
      throwsA(isA<SyncUnavailableException>()),
    );

    expect((await database.getLocalSyncState()).lastPulledSequence, 7);
  });

  test('limit di luar kontrak ditolak sebelum request', () async {
    var called = false;
    final client = SyncPullClient(
      database: database,
      serviceBaseUri: Uri.parse('http://127.0.0.1:8787'),
      getJSON: (uri) async {
        called = true;
        throw StateError('Tidak boleh dipanggil.');
      },
    );

    await expectLater(client.fetchNextPage(limit: 0), throwsRangeError);
    await expectLater(client.fetchNextPage(limit: 101), throwsRangeError);
    expect(called, isFalse);
  });
}

Map<String, Object?> _change({
  required int sequence,
  required String entityType,
  required String entityId,
  String? payloadId,
  int version = 1,
}) {
  return {
    'server_sequence': sequence,
    'operation_id': '0199e7d0-0000-7000-8000-000000000020',
    'entity_type': entityType,
    'entity_id': entityId,
    'version': version,
    'payload': {'id': payloadId ?? entityId, 'version': version},
    'created_at': '2026-10-17T00:00:00Z',
  };
}
