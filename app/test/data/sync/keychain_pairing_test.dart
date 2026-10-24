import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tagihan_vendra/data/local/app_database.dart';
import 'package:tagihan_vendra/data/sync/paired_sync_access.dart';
import 'package:tagihan_vendra/data/sync/pairing_admin_client.dart';
import 'package:tagihan_vendra/data/sync/pairing_receiver.dart';
import 'package:tagihan_vendra/data/sync/platform_credential_store.dart';
import 'package:tagihan_vendra/data/sync/sync_coordinator.dart';
import 'package:tagihan_vendra/data/sync/sync_pull_client.dart';
import 'package:tagihan_vendra/data/sync/sync_push_client.dart';
import 'package:tagihan_vendra/domain/bill.dart';
import 'package:tagihan_vendra/domain/calendar_date.dart';
import 'package:tagihan_vendra/domain/entity_id.dart';
import 'package:tagihan_vendra/domain/money.dart';

import 'pairing_admin_client_test.dart' show invitationFixture;
import 'platform_credential_store_test.dart' show keychainChannel;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Fixture fixture;
  setUp(() async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    fixture = _Fixture();
    await fixture.database.insertBill(_bill());
  });
  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(keychainChannel, null);
    debugDefaultTargetPlatformOverride = null;
    await fixture.database.close();
  });

  for (final mode in ['error', 'false_ack']) {
    test(
      'Keychain $mode menghentikan pairing sebelum jaringan tanpa mengubah outbox',
      () async {
        fixture.failure = mode;
        final before = await fixture.database.getLocalSyncState();
        await expectLater(
          fixture.receiver.begin(fixture.invitation.code, 'iPhone'),
          throwsA(isA<SyncAuthorizationException>()),
        );
        expect(fixture.network, isEmpty);
        expect(fixture.values, isEmpty);
        final after = await fixture.database.getLocalSyncState();
        expect(after.deviceId, before.deviceId);
        expect(after.lastPulledSequence, 0);
        expect(after.hubBinding, isNull);
        expect(await fixture.database.countPendingSyncOperations(), 1);
        expect(
          (await fixture.database.findBillById(_bill().id))!.amount.minorUnits,
          59990,
        );
      },
    );
  }

  test('commit Keychain dengan response gagal dipulihkan memakai request/token yang sama', () async {
    fixture.failure = 'after_commit';
    await expectLater(
      fixture.receiver.begin(fixture.invitation.code, 'iPhone'),
      throwsA(isA<SyncAuthorizationException>()),
    );
    expect(fixture.network, isEmpty);
    final saved = (await fixture.receiver.readProfile())!;
    fixture.failure = null;
    final pending = await fixture.receiver.resume();
    expect(pending.requestId, saved.requestId);
    expect(pending.credential, saved.credential);
    expect(fixture.submitted!['request_id'], saved.requestId);
    expect(fixture.submitted!['credential'], saved.credential);
    expect(pending.status, 'pending');
    expect(
      fixture.network.where((uri) => uri.path == '/v1/pairing/requests'),
      hasLength(1),
    );
    expect(await fixture.database.countPendingSyncOperations(), 1);
    expect((await fixture.database.getLocalSyncState()).lastPulledSequence, 0);
  });

  test('Keychain terkunci menolak sync tanpa jaringan dan menjaga profil, tagihan, serta cursor', () async {
    await fixture.receiver.begin(fixture.invitation.code, 'iPhone');
    fixture.approved = true;
    final paired = await fixture.receiver.resume();
    final storedProfile = fixture.values.values.single;
    final before = await fixture.database.getLocalSyncState();
    fixture.network.clear();
    fixture.locked = true;
    final base = Uri.parse('http://127.0.0.1:8787');
    final access = PairedSyncAccess(
      receiver: fixture.receiver,
      sourceBaseUri: base,
      transport: fixture.transport,
    );
    final coordinator = SyncCoordinator(
      database: fixture.database,
      prepareSync: access.prepare,
      pushClient: SyncPushClient(
        database: fixture.database,
        serviceBaseUri: base,
        postJSON: access.post,
      ),
      pullClient: SyncPullClient(
        database: fixture.database,
        serviceBaseUri: base,
        getJSON: access.get,
      ),
    );
    addTearDown(coordinator.close);
    final result = await coordinator.synchronize();
    expect(result.phase, SyncRuntimePhase.failed);
    expect(result.message, contains('Keychain'));
    expect(result.message, isNot(contains('native-secret-detail')));
    expect(fixture.network, isEmpty);
    expect(fixture.values.values.single, storedProfile);
    expect(await fixture.database.countPendingSyncOperations(), 1);
    final after = await fixture.database.getLocalSyncState();
    expect(after.deviceId, before.deviceId);
    expect(after.hubBinding, paired.binding);
    expect(after.lastPulledSequence, before.lastPulledSequence);
    // CRUD lokal tetap berfungsi ketika credential tidak dapat diakses.
    await fixture.database.archiveBill(_bill().id, DateTime.utc(2026, 10, 25));
    expect(
      (await fixture.database.findBillById(_bill().id))!.status,
      BillStatus.archived,
    );
    expect(await fixture.database.countPendingSyncOperations(), 2);
  });
}

// Ini adalah contract test Dart dengan MethodChannel mock di Fedora, bukan
// pengujian Apple Keychain atau TLS native pada perangkat iPhone.
final class _Fixture {
  _Fixture() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(keychainChannel, (call) async {
          final args = call.arguments as Map;
          final key = args['key'] as String;
          if (locked) {
            throw PlatformException(
              code: '-25308',
              message: 'native-secret-detail',
            );
          }
          switch (call.method) {
            case 'read':
              return values[key];
            case 'write':
              if (failure == 'error') {
                throw PlatformException(
                  code: 'write_failed',
                  message: 'native-secret-detail',
                );
              }
              if (failure == 'false_ack') return null;
              values[key] = args['value'] as String;
              if (failure == 'after_commit') {
                throw PlatformException(
                  code: 'response_failed',
                  message: 'native-secret-detail',
                );
              }
              return null;
            default:
              throw StateError('Test tidak mengizinkan ${call.method}.');
          }
        });
  }

  final database = AppDatabase(NativeDatabase.memory());
  final values = <String, String>{};
  final network = <Uri>[];
  final invitation = PairingInvitation.fromJson(invitationFixture());
  String? failure;
  bool locked = false, approved = false;
  Map<String, dynamic>? submitted;
  late final receiver = PairingReceiver(
    database: database,
    credentials: createDefaultSyncCredentialStore(operatingSystem: 'ios'),
    transport: transport,
  );

  SyncHTTPRequest transport(Uri endpoint, String pin) =>
      (uri, {required method, body, headers = const {}}) async {
        network.add(uri);
        expect(endpoint, invitation.endpoint);
        expect(pin, invitation.fingerprint);
        final profile = values.isEmpty
            ? null
            : PairingProfile.decode(values.values.single);
        if (uri.path == '/v1/pairing/identity') {
          if (!approved) {
            return const SyncHTTPResponse(statusCode: 401, body: '{}');
          }
          return _response({
            'hub_id': invitation.hubId,
            'device_id': profile!.deviceId,
          });
        }
        if (uri.path == '/v1/pairing/requests' && method == 'POST') {
          submitted = (jsonDecode(body!) as Map).cast();
          expect(profile!.credential, submitted!['credential']);
          expect(profile.requestId, submitted!['request_id']);
        }
        if (submitted == null) {
          return const SyncHTTPResponse(statusCode: 410, body: '{}');
        }
        return _response({
          'request': {
            'request_id': submitted!['request_id'],
            'device_id': submitted!['device_id'],
            'name': submitted!['name'],
            'status': 'pending',
            'expires_at': '2099-10-24T01:05:00Z',
          },
        });
      };
}

SyncHTTPResponse _response(Map<String, dynamic> fields) => SyncHTTPResponse(
  statusCode: 200,
  body: jsonEncode({'protocol_version': 1, ...fields}),
);

Bill _bill() => Bill(
  id: EntityId.fromString('0199e7d0-0000-7000-8000-000000000003'),
  name: 'Tagihan lokal',
  amount: Money(minorUnits: 59990, currency: Currency.idr),
  billingCycle: BillingCycle.monthly,
  nextDueDate: CalendarDate(2026, 10, 25),
  startDate: CalendarDate(2026, 1, 25),
  status: BillStatus.active,
  createdAt: DateTime.utc(2026, 10, 1),
  updatedAt: DateTime.utc(2026, 10, 1),
  version: 1,
);
