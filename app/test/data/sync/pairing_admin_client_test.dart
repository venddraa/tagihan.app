import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tagihan_vendra/data/sync/pairing_admin_client.dart';
import 'package:tagihan_vendra/data/sync/sync_http.dart';

Map<String, dynamic> invitationFixture() => {
  'protocol_version': 1,
  'hub_id': '0199e7d0-0000-7000-8000-000000000099',
  'endpoint': 'https://192.168.1.10:8789',
  'certificate_sha256': List.filled(64, 'a').join(),
  'invitation_id': '0199e7d0-0000-7000-8000-000000000077',
  'invitation_token': List.filled(43, 'A').join(),
  'expires_at': '2026-10-24T01:00:00Z',
};

void main() {
  test('undangan teks round-trip mempertahankan hub, pin, dan token', () {
    final invitation = PairingInvitation.fromJson(invitationFixture());
    final decoded = PairingInvitation.fromCode(invitation.code);
    expect(decoded.hubId, invitation.hubId);
    expect(decoded.fingerprint, invitation.fingerprint);
    expect(decoded.token, invitation.token);
    expect(decoded.endpoint, invitation.endpoint);
  });
  test(
    'undangan menolak HTTP, IP publik, userinfo, pin salah, dan protocol asing',
    () {
      for (final change in [
        {'endpoint': 'http://192.168.1.10:8789'},
        {'endpoint': 'https://8.8.8.8:8789'},
        {'endpoint': 'https://user@192.168.1.10:8789'},
        {'certificate_sha256': 'bad'},
        {'protocol_version': 2},
      ]) {
        expect(
          () => PairingInvitation.fromJson({...invitationFixture(), ...change}),
          throwsA(isA<FormatException>()),
        );
      }
      expect(
        () => PairingInvitation.fromCode('bad-code'),
        throwsFormatException,
      );
    },
  );
  test('kontrol pairing mengirim token hanya ke admin loopback', () async {
    final paths = <String>[];
    final token = List.filled(43, 'A').join();
    final client = PairingAdminClient(
      readCredential: () async => token,
      request: (uri, {required method, body, headers = const {}}) async {
        paths.add(uri.path);
        expect(uri.origin, 'http://127.0.0.1:8788');
        expect(headers['authorization'], 'Bearer $token');
        if (uri.path == '/v1/admin/pairing/invitations') {
          return SyncHTTPResponse(
            statusCode: 201,
            body: jsonEncode({
              'protocol_version': 1,
              'invitation': invitationFixture(),
            }),
          );
        }
        return const SyncHTTPResponse(
          statusCode: 200,
          body: '{"protocol_version":1}',
        );
      },
    );
    final invitation = await client.createInvitation();
    await client.cancel(invitation.id);
    await client.decide('0199e7d0-0000-7000-8000-000000000088', approve: true);
    await client.revoke('0199e7d0-0000-7000-8000-000000000002');
    expect(paths.length, 4);
  });
  test(
    'kontrol admin non-loopback tidak membaca atau mengirim credential',
    () async {
      var read = false;
      final client = PairingAdminClient(
        baseUri: Uri.parse('http://192.168.1.10:8788'),
        readCredential: () async {
          read = true;
          return List.filled(43, 'A').join();
        },
      );
      await expectLater(
        client.refresh(),
        throwsA(isA<SyncAuthorizationException>()),
      );
      expect(read, isFalse);
    },
  );
}
