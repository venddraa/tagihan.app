import 'dart:io';

import 'package:tagihan_vendra/data/sync/pairing_receiver.dart';
import 'package:tagihan_vendra/data/sync/pinned_sync_transport.dart';
import 'package:tagihan_vendra/data/sync/sync_http.dart';

final class PairedSyncAccess {
  PairedSyncAccess({
    required this.receiver,
    required this.sourceBaseUri,
    PairingTransport? transport,
  }) : _transport =
           transport ??
           ((endpoint, pin) => createPinnedSyncRequest(endpoint, pin));
  final PairingReceiver receiver;
  final Uri sourceBaseUri;
  final PairingTransport _transport;
  PairingProfile? _verified;

  Future<void> prepare() async {
    _verified = null;
    _verified = await receiver.requirePaired();
  }

  Future<SyncHTTPResponse> get(Uri uri) => _send(uri, method: 'GET');
  Future<SyncHTTPResponse> post(Uri uri, String body) =>
      _send(uri, method: 'POST', body: body);

  Future<SyncHTTPResponse> _send(
    Uri uri, {
    required String method,
    String? body,
  }) async {
    final profile = _verified;
    if (profile == null ||
        uri.origin != sourceBaseUri.origin ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment ||
        !(method == 'POST' && uri.path == '/v1/sync/push' && !uri.hasQuery ||
            method == 'GET' && uri.path == '/v1/sync/pull')) {
      throw const SyncAuthorizationException(
        'Tujuan sync belum diverifikasi atau rute tidak diizinkan untuk client.',
      );
    }
    final endpoint = profile.endpoint.replace(
      path: uri.path,
      query: uri.hasQuery ? uri.query : null,
    );
    final response = await _transport(profile.endpoint, profile.fingerprint)(
      endpoint,
      method: method,
      body: body,
      headers: {
        HttpHeaders.authorizationHeader: 'Bearer ${profile.credential}',
      },
    );
    checkSyncAuthorization(response);
    return response;
  }
}
