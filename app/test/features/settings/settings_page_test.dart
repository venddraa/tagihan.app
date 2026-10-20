import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tagihan_vendra/app/tagihan_vendra_app.dart';
import 'package:tagihan_vendra/data/local/app_database.dart';
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
    await tester.pumpAndSettle();

    expect(find.text('Sinkronisasi perangkat'), findsOneWidget);
    expect(_textValue(tester, 'sync-status-label'), 'Siap offline');
    expect(_textValue(tester, 'sync-pending-count'), '1');
    expect(_textValue(tester, 'sync-conflict-count'), '0');

    await tester.tap(find.byKey(const ValueKey('sync-now-button')));
    await tester.pumpAndSettle();

    expect(_textValue(tester, 'sync-status-label'), 'Tersinkron');
    expect(_textValue(tester, 'sync-pending-count'), '0');
    expect(_textValue(tester, 'sync-last-time'), isNot('Belum ada'));
    expect(pushRequests, 1);
    expect(pullRequests, 1);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
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
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('sync-now-button')));
    await tester.pumpAndSettle();

    expect(_textValue(tester, 'sync-status-label'), 'Hub tidak tersedia');
    expect(_textValue(tester, 'sync-pending-count'), '1');
    expect(find.textContaining('Data lokal tetap aman.'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
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

Bill _bill() {
  return Bill(
    id: EntityId.fromString('0199e7d0-0000-7000-8000-000000000001'),
    name: 'Spotify',
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
