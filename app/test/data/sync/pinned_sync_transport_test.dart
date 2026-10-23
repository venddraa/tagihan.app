import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tagihan_vendra/data/sync/pinned_sync_transport.dart';
import 'package:tagihan_vendra/data/sync/sync_http.dart';

void main() {
  test('pin certificate memeriksa digest dan masa berlaku', () {
    final certificate = _Certificate();
    final pin = sha256.convert(certificate.der).toString();
    expect(
      matchesPinnedCertificate(
        certificate,
        pin,
        now: DateTime.utc(2026, 10, 24),
      ),
      isTrue,
    );
    expect(
      matchesPinnedCertificate(certificate, pin, now: DateTime.utc(2019)),
      isFalse,
    );
    expect(
      matchesPinnedCertificate(certificate, pin, now: DateTime.utc(2100)),
      isFalse,
    );
    expect(
      matchesPinnedCertificate(
        certificate,
        List.filled(64, 'a').join(),
        now: DateTime.utc(2026, 10, 24),
      ),
      isFalse,
    );
  });
  for (final correct in [true, false]) {
    test(
      'certificate ${correct ? 'benar' : 'berbeda'} diverifikasi sebelum header credential',
      () async {
        final certificate = _Certificate();
        final socket = _Socket(certificate);
        final client = _Client();
        final request = createPinnedSyncRequest(
          Uri.parse('https://127.0.0.1:8789'),
          correct
              ? sha256.convert(certificate.der).toString()
              : List.filled(64, 'a').join(),
          connect: (uri, validate) async =>
              ConnectionTask.fromSocket(Future.value(socket), () {}),
        );
        Future<void> send() async {
          await HttpOverrides.runZoned(
            () => request(
              Uri.parse('https://127.0.0.1:8789/v1/sync/pull?after=0'),
              method: 'GET',
              headers: {'authorization': 'Bearer fixture'},
            ),
            createHttpClient: (_) => client,
          );
        }

        if (correct) {
          await send();
          expect(
            client.request.headers.values['authorization'],
            'Bearer fixture',
          );
        } else {
          await expectLater(send(), throwsA(isA<SyncAuthorizationException>()));
          expect(client.request.headers.values, isEmpty);
          expect(socket.destroyed, isTrue);
        }
      },
    );
  }
}

final class _Certificate implements X509Certificate {
  @override
  Uint8List get der => Uint8List.fromList([1, 2, 3]);
  @override
  DateTime get startValidity => DateTime.utc(2020);
  @override
  DateTime get endValidity => DateTime.utc(2100);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _Socket implements SecureSocket {
  _Socket(this.certificate);
  final X509Certificate certificate;
  bool destroyed = false;
  @override
  X509Certificate get peerCertificate => certificate;
  @override
  void destroy() {
    destroyed = true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _Client implements HttpClient {
  final _Request request = _Request();
  @override
  Duration? connectionTimeout;
  @override
  String Function(Uri)? findProxy;
  @override
  Future<ConnectionTask<Socket>> Function(Uri, String?, int?)?
  connectionFactory;
  @override
  Future<HttpClientRequest> openUrl(String method, Uri uri) async {
    final task = await connectionFactory!(uri, null, null);
    await task.socket;
    return request;
  }

  @override
  void close({bool force = false}) {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _Request implements HttpClientRequest {
  @override
  bool followRedirects = true;
  @override
  final _Headers headers = _Headers();
  @override
  Future<HttpClientResponse> close() async => _Response();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _Headers implements HttpHeaders {
  final Map<String, Object> values = {};
  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {
    values[name] = value;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _Response extends Stream<List<int>> implements HttpClientResponse {
  @override
  int get statusCode => 200;
  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => Stream.value(utf8.encode('{}')).listen(
    onData,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
