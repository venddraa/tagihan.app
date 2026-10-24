import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tagihan_vendra/data/local/app_database.dart';
import 'package:tagihan_vendra/data/sync/paired_sync_access.dart';
import 'package:tagihan_vendra/data/sync/pairing_admin_client.dart';
import 'package:tagihan_vendra/data/sync/pairing_receiver.dart';
import 'package:tagihan_vendra/data/sync/sync_credential_store.dart';
import 'package:tagihan_vendra/data/sync/sync_http.dart';

import 'pairing_admin_client_test.dart' show invitationFixture;

// Semua response di fixture ini memakai transport palsu; test pin/socket berada
// pada pinned_sync_transport_test.dart. Tidak ada listener/network sungguhan.
final class MemoryPairingCredentials implements SyncCredentialStore {
  final values = <String, String>{};
  bool failWrite = false;
  int reads = 0;
  @override
  Future<String?> read(String service, String deviceId) async {
    reads++;
    return values['$service|$deviceId'];
  }

  @override
  Future<void> write(String service, String deviceId, String credential) async {
    if (failWrite) throw const SyncAuthorizationException('Keyring terkunci.');
    values['$service|$deviceId'] = credential;
  }

  @override
  Future<void> delete(String service, String deviceId) async =>
      values.remove('$service|$deviceId');
}

final class ReceiverFixture {
  final database = AppDatabase(NativeDatabase.memory());
  final credentials = MemoryPairingCredentials();
  final invitation = PairingInvitation.fromJson(invitationFixture());
  final calls = <Uri>[];
  Map<String, dynamic>? submitted;
  bool approved = false,
      restart = false,
      offline = false,
      wrongHub = false,
      wrongDevice = false,
      loseSubmit = false;
  String status = 'pending';
  late final receiver = PairingReceiver(
    database: database,
    credentials: credentials,
    transport: transport,
  );

  SyncHTTPRequest transport(Uri endpoint, String pin) {
    expect(endpoint, invitation.endpoint);
    expect(pin, invitation.fingerprint);
    return (uri, {required method, body, headers = const {}}) async {
      calls.add(uri);
      if (offline) throw const SyncUnavailableException();
      if (uri.path == '/v1/pairing/requests' && method == 'POST') {
        final input = (jsonDecode(body!) as Map).cast<String, dynamic>();
        // Token/request_id wajib sudah tersimpan sebelum request jaringan.
        final saved = await receiver.readProfile();
        expect(saved!.credential, input['credential']);
        expect(saved.requestId, input['request_id']);
        expect(headers['authorization'], 'Bearer ${invitation.token}');
        if (submitted != null) expect(input, submitted);
        submitted = input;
        if (loseSubmit) {
          loseSubmit = false;
          throw const SyncUnavailableException();
        }
        return response({'request': entry()});
      }
      final saved = (await receiver.readProfile())!;
      expect(headers['authorization'], 'Bearer ${saved.credential}');
      if (uri.path == '/v1/pairing/identity') {
        if (!approved) {
          return const SyncHTTPResponse(statusCode: 401, body: '{}');
        }
        return response({
          'hub_id': wrongHub
              ? '0199e7d0-0000-7000-8000-000000000098'
              : invitation.hubId,
          'device_id': wrongDevice ? invitation.id : saved.deviceId,
        });
      }
      if (restart) return const SyncHTTPResponse(statusCode: 410, body: '{}');
      if (uri.path.endsWith('/cancel')) {
        if (approved || status == 'approving') {
          return const SyncHTTPResponse(statusCode: 409, body: '{}');
        }
        status = 'cancelled';
      }
      return response({'request': entry()});
    };
  }

  Map<String, dynamic> entry() => {
    'request_id': submitted!['request_id'],
    'device_id': submitted!['device_id'],
    'name': submitted!['name'],
    'status': approved ? 'approved' : status,
    'expires_at': '2026-10-24T01:05:00Z',
  };
  SyncHTTPResponse response(Map<String, dynamic> values) => SyncHTTPResponse(
    statusCode: 200,
    body: jsonEncode({'protocol_version': 1, ...values}),
  );
  Future<PairingProfile> begin() =>
      receiver.begin(invitation.code, 'iPhone Vendra');
}

void main() {
  late ReceiverFixture fixture;
  setUp(() => fixture = ReceiverFixture());
  tearDown(() => fixture.database.close());

  test('request disimpan sebelum dikirim dan retry timeout memakai token serta ID sama', () async {
    fixture.loseSubmit = true;
    await expectLater(
      fixture.begin(),
      throwsA(isA<SyncUnavailableException>()),
    );
    final pending = (await fixture.receiver.readProfile())!;
    final again = await fixture.receiver.resume();
    expect(again.requestId, pending.requestId);
    expect(again.credential, pending.credential);
    expect(again.status, 'pending');
    expect((await fixture.database.getLocalSyncState()).hubBinding, isNull);
  });

  test(
    'keyring gagal atau database mempunyai riwayat tidak mengirim request',
    () async {
      fixture.credentials.failWrite = true;
      await expectLater(
        fixture.begin(),
        throwsA(isA<SyncAuthorizationException>()),
      );
      expect(fixture.calls, isEmpty);
      fixture.credentials.failWrite = false;
      await fixture.database.bindSyncHub(
        'local|http://127.0.0.1:8787',
        paired: false,
      );
      await expectLater(fixture.begin(), throwsStateError);
      expect(fixture.calls, isEmpty);
    },
  );

  test(
    'approval durable pulih sesudah restart tanpa mengirim ulang undangan',
    () async {
      final pending = await fixture.begin();
      fixture.approved = true;
      fixture.restart = true;
      fixture.calls.clear();
      final paired = await fixture.receiver.resume();
      expect(paired.paired, isTrue);
      expect(paired.credential, pending.credential);
      expect(paired.invitationCode, isNull);
      expect(paired.encode(), isNot(contains(fixture.invitation.token)));
      expect(fixture.calls.map((uri) => uri.path), ['/v1/pairing/identity']);
      expect(
        (await fixture.database.getLocalSyncState()).hubBinding,
        paired.binding,
      );
    },
  );

  test('gagal menyimpan approved mempertahankan sesi lama dan binding untuk recovery', () async {
    await fixture.begin();
    fixture.approved = true;
    fixture.credentials.failWrite = true;
    await expectLater(
      fixture.receiver.resume(),
      throwsA(isA<SyncAuthorizationException>()),
    );
    expect((await fixture.receiver.readProfile())!.status, 'pending');
    expect(
      (await fixture.database.getLocalSyncState()).hubBinding,
      startsWith('paired|'),
    );
    fixture.credentials.failWrite = false;
    expect((await fixture.receiver.resume()).paired, isTrue);
  });

  test('identitas hub/device yang berbeda tidak mengikat database', () async {
    await fixture.begin();
    fixture.approved = true;
    fixture.wrongHub = true;
    await expectLater(
      fixture.receiver.resume(),
      throwsA(isA<SyncAuthorizationException>()),
    );
    fixture.wrongHub = false;
    fixture.wrongDevice = true;
    await expectLater(
      fixture.receiver.resume(),
      throwsA(isA<SyncAuthorizationException>()),
    );
    expect((await fixture.database.getLocalSyncState()).hubBinding, isNull);
  });

  test('pending, profil hilang, dan revoked menghentikan sync tanpa data finansial', () async {
    final access = PairedSyncAccess(
      receiver: fixture.receiver,
      sourceBaseUri: Uri.parse('http://127.0.0.1:8787'),
    );
    await expectLater(
      access.prepare(),
      throwsA(isA<SyncAuthorizationException>()),
    );
    await fixture.begin();
    await expectLater(
      access.prepare(),
      throwsA(isA<SyncAuthorizationException>()),
    );
    fixture.approved = true;
    await fixture.receiver.resume();
    fixture.approved = false;
    await expectLater(
      access.prepare(),
      throwsA(isA<SyncAuthorizationException>()),
    );
    expect(
      fixture.calls.where((uri) => uri.path.startsWith('/v1/sync/')),
      isEmpty,
    );
    final paired = (await fixture.receiver.readProfile())!;
    await fixture.credentials.delete(
      PairingReceiver.profileService,
      paired.deviceId,
    );
    await expectLater(
      access.prepare(),
      throwsA(isA<SyncAuthorizationException>()),
    );
    expect(
      (await fixture.database.getLocalSyncState()).hubBinding,
      paired.binding,
    );
  });

  test('client hanya meneruskan push/pull ke HTTPS berpinned tanpa bootstrap/admin', () async {
    await fixture.begin();
    fixture.approved = true;
    final paired = await fixture.receiver.resume();
    final dataCalls = <Uri>[];
    final base = Uri.parse('http://127.0.0.1:8787');
    final access = PairedSyncAccess(
      receiver: fixture.receiver,
      sourceBaseUri: base,
      transport: (endpoint, pin) {
        expect(endpoint, paired.endpoint);
        expect(pin, paired.fingerprint);
        return (uri, {required method, body, headers = const {}}) async {
          expect(headers['authorization'], 'Bearer ${paired.credential}');
          dataCalls.add(uri);
          return fixture.response({});
        };
      },
    );
    await access.prepare();
    await access.post(base.resolve('/v1/sync/push'), '{}');
    await access.get(base.resolve('/v1/sync/pull?after=7&limit=50'));
    expect(
      dataCalls.map((uri) => uri.origin),
      everyElement(paired.endpoint.origin),
    );
    expect(dataCalls.last.query, 'after=7&limit=50');
    for (final path in ['/v1/sync/bootstrap', '/v1/admin/devices']) {
      await expectLater(
        access.post(base.resolve(path), '{}'),
        throwsA(isA<SyncAuthorizationException>()),
      );
    }
    await expectLater(
      access.get(Uri.parse('http://other/v1/sync/pull')),
      throwsA(isA<SyncAuthorizationException>()),
    );
    expect(dataCalls, hasLength(2));
  });

  test('cancel membutuhkan konfirmasi hub; offline dan approved tidak membuang credential', () async {
    final pending = await fixture.begin();
    fixture.offline = true;
    await expectLater(
      fixture.receiver.cancel(),
      throwsA(isA<SyncUnavailableException>()),
    );
    expect(
      (await fixture.receiver.readProfile())!.credential,
      pending.credential,
    );
    fixture.offline = false;
    fixture.approved = true;
    await expectLater(
      fixture.receiver.cancel(),
      throwsA(isA<SyncAuthorizationException>()),
    );
    expect(await fixture.receiver.readProfile(), isNotNull);
    fixture.approved = false;
    await fixture.receiver.cancel();
    expect(await fixture.receiver.readProfile(), isNull);
    expect((await fixture.database.getLocalSyncState()).hubBinding, isNull);
  });

  test(
    'cancel setelah restart memulihkan approval dan tidak membuang credential',
    () async {
      await fixture.begin();
      fixture.restart = true;
      fixture.approved = true;
      await expectLater(
        fixture.receiver.cancel(),
        throwsA(isA<SyncAuthorizationException>()),
      );
      expect((await fixture.receiver.readProfile())!.paired, isTrue);
    },
  );

  test('profil rusak tidak membocorkan token melalui pesan error', () async {
    final pending = await fixture.begin();
    final json = jsonDecode(pending.encode()) as Map<String, dynamic>;
    json['hub_id'] = 'invalid';
    expect(
      () => PairingProfile.decode(jsonEncode(json)),
      throwsA(
        isA<SyncAuthorizationException>().having(
          (error) => error.toString(),
          'redacted',
          isNot(contains(pending.credential)),
        ),
      ),
    );
  });
}
