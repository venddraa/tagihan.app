import 'dart:async';
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tagihan_vendra/data/local/app_database.dart';
import 'package:tagihan_vendra/data/sync/sync_bootstrap_client.dart';
import 'package:tagihan_vendra/data/sync/sync_coordinator.dart';
import 'package:tagihan_vendra/data/sync/sync_pull_client.dart';
import 'package:tagihan_vendra/data/sync/sync_push_client.dart';
import 'package:tagihan_vendra/domain/bill.dart';
import 'package:tagihan_vendra/domain/calendar_date.dart';
import 'package:tagihan_vendra/domain/entity_id.dart';
import 'package:tagihan_vendra/domain/money.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() => database.close());

  test('initializeHub wajib menerima bootstrap client', () {
    expect(
      () => SyncCoordinator(
        database: database,
        pushClient: _pushClient(database),
        pullClient: _pullClient(database),
        bootstrapPolicy: SyncBootstrapPolicy.initializeHub,
      ),
      throwsArgumentError,
    );
  });

  test('push lalu pull menghasilkan status synced', () async {
    await database.insertBill(_bill(1));
    final events = <String>[];
    final statuses = <SyncRuntimeStatus>[];
    final coordinator = SyncCoordinator(
      database: database,
      pushClient: _pushClient(
        database,
        onRequest: (operations) {
          events.add('push');
        },
      ),
      pullClient: _pullClient(
        database,
        onRequest: (uri) {
          events.add('pull');
        },
      ),
    );
    addTearDown(coordinator.close);
    final subscription = coordinator.statusChanges.listen(statuses.add);
    addTearDown(subscription.cancel);

    final result = await coordinator.synchronize();

    expect(events, ['push', 'pull']);
    expect(result.phase, SyncRuntimePhase.synced);
    expect(result.pendingChanges, 0);
    expect(result.conflicts, 0);
    expect(result.lastSyncAt, isNotNull);
    expect(result.lastSyncAt!.isUtc, isTrue);
    expect(statuses.map((status) => status.phase), [
      SyncRuntimePhase.syncing,
      SyncRuntimePhase.synced,
    ]);
    expect(await database.countPendingSyncOperations(), 0);
  });

  test('bootstrap hub dijalankan sebelum push dan pull', () async {
    final events = <String>[];
    final bootstrapClient = SyncBootstrapClient(
      database: database,
      serviceBaseUri: _serviceBaseUri,
      postJSON: (uri, body) async {
        events.add('bootstrap');
        final request = jsonDecode(body) as Map<String, dynamic>;
        return SyncHTTPResponse(
          statusCode: 200,
          body: jsonEncode({
            'protocol_version': 1,
            'bootstrap_id': request['bootstrap_id'],
            'status': 'accepted',
            'server_sequences': <int>[],
          }),
        );
      },
    );
    final coordinator = SyncCoordinator(
      database: database,
      bootstrapPolicy: SyncBootstrapPolicy.initializeHub,
      bootstrapClient: bootstrapClient,
      pushClient: _pushClient(
        database,
        onRequest: (operations) {
          events.add('push');
        },
      ),
      pullClient: _pullClient(
        database,
        onRequest: (uri) {
          events.add('pull');
        },
      ),
    );
    addTearDown(coordinator.close);

    final result = await coordinator.synchronize();

    expect(events, ['bootstrap', 'pull']);
    expect(result.phase, SyncRuntimePhase.synced);
  });

  test('mengirim seluruh outbox dalam beberapa batch', () async {
    for (var index = 1; index <= 101; index++) {
      await database.insertBill(_bill(index));
    }
    final batchSizes = <int>[];
    final coordinator = SyncCoordinator(
      database: database,
      pushClient: _pushClient(
        database,
        onRequest: (operations) {
          batchSizes.add(operations.length);
        },
      ),
      pullClient: _pullClient(database),
    );
    addTearDown(coordinator.close);

    final result = await coordinator.synchronize();

    expect(batchSizes, [100, 1]);
    expect(result.phase, SyncRuntimePhase.synced);
    expect(result.pendingChanges, 0);
  });

  test('conflict mempertahankan outbox dan dilaporkan ke runtime', () async {
    await database.insertBill(_bill(1));
    final coordinator = SyncCoordinator(
      database: database,
      pushClient: _pushClient(database, resultStatus: 'conflict'),
      pullClient: _pullClient(database),
    );
    addTearDown(coordinator.close);

    final result = await coordinator.synchronize();

    expect(result.phase, SyncRuntimePhase.conflict);
    expect(result.pendingChanges, 1);
    expect(result.conflicts, 1);
    expect(await database.countPendingSyncOperations(), 1);
  });

  test('hub offline menjaga data lokal dan tidak menjalankan pull', () async {
    await database.insertBill(_bill(1));
    var pullCalled = false;
    final coordinator = SyncCoordinator(
      database: database,
      pushClient: SyncPushClient(
        database: database,
        serviceBaseUri: _serviceBaseUri,
        postJSON: (uri, body) async {
          throw const SyncUnavailableException();
        },
      ),
      pullClient: _pullClient(
        database,
        onRequest: (uri) {
          pullCalled = true;
        },
      ),
    );
    addTearDown(coordinator.close);

    final result = await coordinator.synchronize();

    expect(result.phase, SyncRuntimePhase.offline);
    expect(result.pendingChanges, 1);
    expect(pullCalled, isFalse);
    expect(await database.countPendingSyncOperations(), 1);
  });

  test('dua pemanggilan bersamaan berbagi satu proses sync', () async {
    await database.insertBill(_bill(1));
    final requestStarted = Completer<void>();
    final allowResponse = Completer<void>();
    var pushRequests = 0;
    var pullRequests = 0;
    final coordinator = SyncCoordinator(
      database: database,
      pushClient: _pushClient(
        database,
        beforeResponse: () async {
          pushRequests++;
          requestStarted.complete();
          await allowResponse.future;
        },
      ),
      pullClient: _pullClient(
        database,
        onRequest: (uri) {
          pullRequests++;
        },
      ),
    );
    addTearDown(coordinator.close);

    final first = coordinator.synchronize();
    final second = coordinator.synchronize();
    expect(identical(first, second), isTrue);
    await requestStarted.future;
    allowResponse.complete();

    expect((await first).phase, SyncRuntimePhase.synced);
    expect(await second, same(coordinator.status));
    expect(pushRequests, 1);
    expect(pullRequests, 1);
  });
}

final Uri _serviceBaseUri = Uri.parse('http://127.0.0.1:8787');

SyncPushClient _pushClient(
  AppDatabase database, {
  String resultStatus = 'accepted',
  void Function(List<dynamic> operations)? onRequest,
  Future<void> Function()? beforeResponse,
}) {
  return SyncPushClient(
    database: database,
    serviceBaseUri: _serviceBaseUri,
    postJSON: (uri, body) async {
      final request = jsonDecode(body) as Map<String, dynamic>;
      final operations = request['operations'] as List<dynamic>;
      onRequest?.call(operations);
      await beforeResponse?.call();
      return SyncHTTPResponse(
        statusCode: 200,
        body: jsonEncode({
          'protocol_version': 1,
          'results': [
            for (final operation in operations)
              {
                'operation_id':
                    (operation as Map<String, dynamic>)['operation_id'],
                'status': resultStatus,
                'server_sequences': resultStatus == 'accepted'
                    ? <int>[1]
                    : <int>[],
                if (resultStatus == 'conflict')
                  'error_code': 'version_conflict',
              },
          ],
        }),
      );
    },
  );
}

SyncPullClient _pullClient(
  AppDatabase database, {
  void Function(Uri uri)? onRequest,
}) {
  return SyncPullClient(
    database: database,
    serviceBaseUri: _serviceBaseUri,
    getJSON: (uri) async {
      onRequest?.call(uri);
      final after = int.parse(uri.queryParameters['after']!);
      return SyncHTTPResponse(
        statusCode: 200,
        body: jsonEncode({
          'protocol_version': 1,
          'changes': <Object?>[],
          'next_cursor': after,
          'has_more': false,
        }),
      );
    },
  );
}

Bill _bill(int number) {
  final suffix = number.toString().padLeft(12, '0');
  return Bill(
    id: EntityId.fromString('0199e7d0-0000-7000-8000-$suffix'),
    name: 'Tagihan $number',
    amount: Money(minorUnits: 59990, currency: Currency.idr),
    billingCycle: BillingCycle.monthly,
    nextDueDate: CalendarDate(2026, 10, 25),
    startDate: CalendarDate(2026, 1, 25),
    status: BillStatus.active,
    createdAt: DateTime.utc(2026, 10, 1),
    updatedAt: DateTime.utc(2026, 10, 1),
    version: 1,
  );
}
