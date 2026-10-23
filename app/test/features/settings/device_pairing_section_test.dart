import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tagihan_vendra/data/local/app_database.dart';
import 'package:tagihan_vendra/data/sync/pairing_admin_client.dart';
import 'package:tagihan_vendra/data/sync/sync_http.dart';
import 'package:tagihan_vendra/features/settings/device_pairing_section.dart';

const requestId = '0199e7d0-0000-7000-8000-000000000088';
const deviceId = '0199e7d0-0000-7000-8000-000000000002';

void main() {
  late AppDatabase database;
  setUp(() => database = AppDatabase(NativeDatabase.memory()));
  tearDown(() => database.close());

  testWidgets('membuat undangan lalu membersihkan undangan yang dibatalkan', (
    tester,
  ) async {
    const invitationId = '0199e7d0-0000-7000-8000-000000000077';
    var active = false;
    final client = PairingAdminClient(
      readCredential: () async => List.filled(43, 'A').join(),
      request: (uri, {required method, body, headers = const {}}) async {
        if (uri.path == '/v1/admin/pairing/invitations') {
          active = true;
          return SyncHTTPResponse(
            statusCode: 201,
            body: jsonEncode({
              'protocol_version': 1,
              'invitation': {
                'protocol_version': 1,
                'hub_id': '0199e7d0-0000-7000-8000-000000000099',
                'endpoint': 'https://127.0.0.1:8789',
                'certificate_sha256': List.filled(64, 'a').join(),
                'invitation_id': invitationId,
                'invitation_token': List.filled(43, 'A').join(),
                'expires_at': '2099-10-24T01:00:00Z',
              },
            }),
          );
        }
        if (uri.path.endsWith('/cancel')) active = false;
        if (uri.path == '/v1/admin/pairing') {
          return SyncHTTPResponse(
            statusCode: 200,
            body: jsonEncode({
              'protocol_version': 1,
              'info': {'enabled': true, 'endpoint': 'https://127.0.0.1:8789'},
              'requests': [],
              'active_invitation': active
                  ? {'invitation_id': invitationId}
                  : null,
            }),
          );
        }
        return const SyncHTTPResponse(
          statusCode: 200,
          body: '{"protocol_version":1,"devices":[]}',
        );
      },
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: DevicePairingSection(database: database, client: client),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('pairing-refresh')));
    await _pumpUntil(
      tester,
      () => find
          .byKey(const ValueKey('create-pairing-invitation'))
          .evaluate()
          .isNotEmpty,
    );
    await tester.tap(find.byKey(const ValueKey('create-pairing-invitation')));
    await _pumpUntil(
      tester,
      () => find.text('Teks undangan').evaluate().isNotEmpty,
    );
    expect(active, isTrue);
    final cancel = find.text('Batalkan undangan');
    await tester.ensureVisible(cancel);
    await tester.pumpAndSettle();
    await tester.tap(cancel);
    await _pumpUntil(
      tester,
      () => find.text('Teks undangan').evaluate().isEmpty,
    );
    expect(active, isFalse);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets(
    'daftar perangkat offline tidak menghubungi service sebelum diminta',
    (tester) async {
      var calls = 0;
      final client = PairingAdminClient(
        readCredential: () async {
          calls++;
          throw const SyncUnavailableException();
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DevicePairingSection(database: database, client: client),
          ),
        ),
      );
      await tester.pump();
      expect(calls, 0);
      await tester.tap(find.byKey(const ValueKey('pairing-refresh')));
      await _pumpUntil(
        tester,
        () => find.byKey(const ValueKey('pairing-error')).evaluate().isNotEmpty,
      );
      expect(calls, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );

  for (final size in [const Size(1200, 900), const Size(320, 700)]) {
    testWidgets('mengizinkan dan mencabut perangkat pada $size', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      var status = 'pending';
      var revoked = false;
      var approved = false;
      final client = PairingAdminClient(
        readCredential: () async => List.filled(43, 'A').join(),
        request: (uri, {required method, body, headers = const {}}) async {
          if (uri.path.endsWith('/approve')) {
            status = 'approved';
            approved = true;
          }
          if (uri.path.endsWith('/revoke')) {
            revoked = true;
          }
          if (uri.path == '/v1/admin/pairing') {
            return SyncHTTPResponse(
              statusCode: 200,
              body: jsonEncode({
                'protocol_version': 1,
                'info': {'enabled': true, 'endpoint': 'https://127.0.0.1:8789'},
                'requests': [
                  {
                    'request_id': requestId,
                    'device_id': deviceId,
                    'name': 'iPhone Vendra',
                    'status': status,
                    'expires_at': '2099-10-24T01:00:00Z',
                  },
                ],
              }),
            );
          }
          if (uri.path == '/v1/admin/devices') {
            return SyncHTTPResponse(
              statusCode: 200,
              body: jsonEncode({
                'protocol_version': 1,
                'devices': approved
                    ? [
                        {
                          'device_id': deviceId,
                          'name': 'iPhone Vendra',
                          'revoked_at': revoked ? '2026-10-24T00:00:00Z' : null,
                        },
                      ]
                    : [],
              }),
            );
          }
          return const SyncHTTPResponse(
            statusCode: 200,
            body: '{"protocol_version":1}',
          );
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: DevicePairingSection(database: database, client: client),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('pairing-refresh')));
      await _pumpUntil(
        tester,
        () => find
            .byKey(const ValueKey('approve-pairing-$requestId'))
            .evaluate()
            .isNotEmpty,
      );
      final approve = find.byKey(const ValueKey('approve-pairing-$requestId'));
      await tester.ensureVisible(approve);
      await tester.pumpAndSettle();
      await tester.tap(approve);
      await tester.pumpAndSettle();
      expect(approved, isFalse);
      await tester.tap(find.byKey(const ValueKey('confirm-device-action')));
      await _pumpUntil(
        tester,
        () => find.text('Diizinkan').evaluate().isNotEmpty,
      );
      expect(approved, isTrue);
      final revoke = find.byKey(const ValueKey('revoke-device-$deviceId'));
      await tester.ensureVisible(revoke);
      await tester.pumpAndSettle();
      await tester.tap(revoke);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('confirm-device-action')));
      await _pumpUntil(
        tester,
        () => find.text('Akses dicabut').evaluate().isNotEmpty,
      );
      expect(revoked, isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  }
}

Future<void> _pumpUntil(WidgetTester tester, bool Function() condition) async {
  for (var count = 0; count < 100; count++) {
    await tester.pump(const Duration(milliseconds: 20));
    if (condition()) return;
  }
  fail('Kondisi pairing tidak tercapai setelah 100 pump.');
}
