import 'dart:convert';

import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tagihan_vendra/app/tagihan_vendra_app.dart';
import 'package:tagihan_vendra/data/local/app_database.dart';
import 'package:tagihan_vendra/data/local/sync_operation.dart';
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
    database = AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
  });

  tearDown(() => database.close());

  testWidgets('menampilkan pending lalu menjalankan sync manual', (
    tester,
  ) async {
    await database.insertBill(_bill());
    var pushRequests = 0;
    var pullRequests = 0;
    final coordinator = _coordinator(
      database,
      onPush: () {
        pushRequests++;
      },
      onPull: () {
        pullRequests++;
      },
    );
    addTearDown(coordinator.close);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      TagihanVendraApp(database: database, syncCoordinator: coordinator),
    );
    await tester.tap(find.byKey(const ValueKey('desktop-destination-3')));
    await _pumpUntilFound(tester, find.text('Sinkronisasi perangkat'));
    await _pumpUntilTextValue(tester, 'sync-pending-count', '1');

    expect(find.text('Sinkronisasi perangkat'), findsOneWidget);
    expect(_textValue(tester, 'sync-status-label'), 'Siap offline');
    expect(_textValue(tester, 'sync-pending-count'), '1');
    expect(_textValue(tester, 'sync-conflict-count'), '0');

    await tester.tap(find.byKey(const ValueKey('sync-now-button')));
    await _pumpUntilTextValue(tester, 'sync-status-label', 'Tersinkron');

    expect(_textValue(tester, 'sync-status-label'), 'Tersinkron');
    expect(_textValue(tester, 'sync-pending-count'), '0');
    expect(_textValue(tester, 'sync-last-time'), isNot('Belum ada'));
    expect(pushRequests, 1);
    expect(pullRequests, 1);
    expect(tester.takeException(), isNull);

    await _disposeApp(tester);
  });

  testWidgets('kegagalan hub tampil sebagai offline pada layar sempit', (
    tester,
  ) async {
    await database.insertBill(_bill());
    final coordinator = _coordinator(database, offline: true);
    addTearDown(coordinator.close);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      TagihanVendraApp(database: database, syncCoordinator: coordinator),
    );
    await tester.tap(find.byKey(const ValueKey('compact-destination-3')));
    await _pumpUntilFound(tester, find.text('Sinkronisasi perangkat'));
    await tester.tap(find.byKey(const ValueKey('sync-now-button')));
    await _pumpUntilTextValue(
      tester,
      'sync-status-label',
      'Hub tidak tersedia',
    );

    expect(_textValue(tester, 'sync-status-label'), 'Hub tidak tersedia');
    expect(_textValue(tester, 'sync-pending-count'), '1');
    expect(find.textContaining('Data lokal tetap aman.'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await _disposeApp(tester);
  });

  testWidgets('menampilkan dua versi dan menerapkan pilihan sync hub', (
    tester,
  ) async {
    final operationId = EntityId.fromString(
      '0199e7d0-0000-7000-8000-000000000020',
    );
    final local = _bill(amount: 59990);
    final remote = _bill(amount: 69990);
    await database.insertBill(local);
    await database.applyRemoteSyncPage(
      changes: [
        RemoteSyncChange(
          serverSequence: 1,
          operationId: operationId,
          entityType: SyncEntityType.bill,
          entityId: remote.id,
          version: remote.version,
          payload: (jsonDecode(
            encodeBillSnapshot(remote),
          ) as Map<String, dynamic>).cast(),
          createdAt: DateTime.utc(2026, 10, 17),
        ),
      ],
      nextCursor: 1,
    );
    final coordinator = _coordinator(database);
    addTearDown(coordinator.close);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      TagihanVendraApp(database: database, syncCoordinator: coordinator),
    );
    await tester.tap(find.byKey(const ValueKey('desktop-destination-3')));
    await _pumpUntilFound(
      tester,
      find.byKey(const ValueKey('sync-conflict-section')),
    );
    await _pumpUntilTextValue(tester, 'sync-conflict-count', '1');

    expect(find.byKey(const ValueKey('sync-conflict-section')), findsOneWidget);
    expect(find.textContaining('Rp59.990'), findsOneWidget);
    expect(find.textContaining('Rp69.990'), findsOneWidget);
    expect(_textValue(tester, 'sync-conflict-count'), '1');

    final useRemote = find.byKey(ValueKey('use-remote-${operationId.value}'));
    await tester.ensureVisible(useRemote);
    await tester.tap(useRemote);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirm-use-remote')));
    await _pumpUntilMissing(
      tester,
      find.byKey(const ValueKey('sync-conflict-section')),
    );
    await _pumpUntilTextValue(tester, 'sync-conflict-count', '0');

    expect(find.byKey(const ValueKey('sync-conflict-section')), findsNothing);
    expect(_textValue(tester, 'sync-conflict-count'), '0');
    expect((await database.findBillById(local.id))!.amount.minorUnits, 69990);
    expect(await database.getPendingSyncOperations(), isEmpty);
    expect(tester.takeException(), isNull);

    await _disposeApp(tester);
  });
}

const _serviceBaseUri = 'http://127.0.0.1:8787';

SyncCoordinator _coordinator(
  AppDatabase database, {
  bool offline = false,
  VoidCallback? onPush,
  VoidCallback? onPull,
}) {
  return SyncCoordinator(
    database: database,
    pushClient: SyncPushClient(
      database: database,
      serviceBaseUri: Uri.parse(_serviceBaseUri),
      postJSON: (uri, body) async {
        onPush?.call();
        if (offline) throw const SyncUnavailableException();
        final request = jsonDecode(body) as Map<String, dynamic>;
        final operations = request['operations'] as List<dynamic>;
        return SyncHTTPResponse(
          statusCode: 200,
          body: jsonEncode({
            'protocol_version': 1,
            'results': [
              for (final operation in operations)
                {
                  'operation_id':
                      (operation as Map<String, dynamic>)['operation_id'],
                  'status': 'accepted',
                  'server_sequences': [1],
                },
            ],
          }),
        );
      },
    ),
    pullClient: SyncPullClient(
      database: database,
      serviceBaseUri: Uri.parse(_serviceBaseUri),
      getJSON: (uri) async {
        onPull?.call();
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
    ),
  );
}

String _textValue(WidgetTester tester, String key) {
  return tester.widget<Text>(find.byKey(ValueKey(key))).data!;
}

Future<void> _disposeApp(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

Future<void> _pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  int maximumPumps = 100,
}) async {
  for (var pump = 0; pump < maximumPumps; pump++) {
    await tester.pump(const Duration(milliseconds: 20));
    if (finder.evaluate().isNotEmpty) return;
  }
  fail('Widget yang ditunggu tidak muncul setelah $maximumPumps pump.');
}

Future<void> _pumpUntilMissing(
  WidgetTester tester,
  Finder finder, {
  int maximumPumps = 100,
}) async {
  for (var pump = 0; pump < maximumPumps; pump++) {
    await tester.pump(const Duration(milliseconds: 20));
    if (finder.evaluate().isEmpty) return;
  }
  fail('Widget masih tampil setelah $maximumPumps pump.');
}

Future<void> _pumpUntilTextValue(
  WidgetTester tester,
  String key,
  String expected, {
  int maximumPumps = 100,
}) async {
  final finder = find.byKey(ValueKey(key));
  for (var pump = 0; pump < maximumPumps; pump++) {
    await tester.pump(const Duration(milliseconds: 20));
    if (finder.evaluate().isNotEmpty &&
        tester.widget<Text>(finder).data == expected) {
      return;
    }
  }
  fail('Teks $key tidak berubah menjadi "$expected".');
}

Bill _bill({int amount = 59990}) {
  return Bill(
    id: EntityId.fromString('0199e7d0-0000-7000-8000-000000000001'),
    name: 'Spotify',
    amount: Money(minorUnits: amount, currency: Currency.idr),
    billingCycle: BillingCycle.monthly,
    nextDueDate: CalendarDate(2026, 10, 25),
    startDate: CalendarDate(2026, 1, 25),
    status: BillStatus.active,
    createdAt: DateTime.utc(2026, 10, 1),
    updatedAt: DateTime.utc(2026, 10, 1),
    version: 1,
  );
}
