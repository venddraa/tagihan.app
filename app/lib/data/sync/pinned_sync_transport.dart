import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:tagihan_vendra/data/sync/pairing_admin_client.dart';
import 'package:tagihan_vendra/data/sync/sync_http.dart';

typedef PinnedSocketConnector = Future<ConnectionTask<SecureSocket>> Function(
  Uri uri,
  bool Function(X509Certificate) validate,
);

bool matchesPinnedCertificate(
  X509Certificate certificate,
  String expected, {
  DateTime? now,
}) {
  final time = (now ?? DateTime.now()).toUtc();
  return !time.isBefore(certificate.startValidity.toUtc()) &&
      time.isBefore(certificate.endValidity.toUtc()) &&
      sha256.convert(certificate.der).toString() == expected;
}

// Koneksi baru diverifikasi sebelum HttpClient memperoleh socket dan mengirim
// header/body. Validasi ulang setelah handshake berlaku juga untuk sertifikat CA.
SyncHTTPRequest createPinnedSyncRequest(
  Uri endpoint,
  String fingerprint, {
  PinnedSocketConnector? connect,
}) {
  if (!isPrivateHTTPSUri(endpoint) ||
      !RegExp(r'^[0-9a-f]{64}$').hasMatch(fingerprint)) {
    throw const SyncAuthorizationException(
      'Alamat atau identitas HTTPS hub tidak valid.',
    );
  }
  return (uri, {required method, body, headers = const {}}) async {
    if (uri.origin != endpoint.origin ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment) {
      throw const SyncAuthorizationException(
        'Tujuan HTTPS berbeda dari hub yang dipasangkan.',
      );
    }
    try {
      return await requestSyncJSONWithDartIO(
        uri,
        method: method,
        body: body,
        headers: headers,
        createClient: () {
          final client = HttpClient();
          client.connectionFactory = (target, proxyHost, proxyPort) async {
            if (proxyHost != null ||
                proxyPort != null ||
                target.origin != endpoint.origin) {
              throw const SyncAuthorizationException();
            }
            bool validate(X509Certificate certificate) =>
                matchesPinnedCertificate(certificate, fingerprint);
            final task =
                await (connect?.call(target, validate) ??
                    SecureSocket.startConnect(
                      target.host,
                      target.port,
                      context: SecurityContext(withTrustedRoots: false),
                      onBadCertificate: validate,
                      supportedProtocols: ['http/1.1'],
                    ));
            final verified = task.socket.then((socket) {
              final certificate = socket.peerCertificate;
              if (certificate == null || !validate(certificate)) {
                socket.destroy();
                throw const SyncAuthorizationException(
                  'Sertifikat hub berbeda atau kedaluwarsa. Verifikasi dan pairing ulang diperlukan.',
                );
              }
              return socket;
            });
            return ConnectionTask.fromSocket<Socket>(verified, task.cancel);
          };
          return client;
        },
      );
    } on HandshakeException {
      throw const SyncAuthorizationException(
        'Identitas HTTPS hub tidak dapat diverifikasi.',
      );
    }
  };
}
