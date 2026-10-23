import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tagihan_vendra/data/sync/sync_http.dart';

void main() {
  test('transport tidak mengikuti redirect atau memakai proxy untuk credential lokal', () async {
    final request = _Request();
    final client = _Client(request);
    final response = await HttpOverrides.runZoned(
      () => requestSyncJSONWithDartIO(
        Uri.parse('http://127.0.0.1:8787/v1/sync/pull?after=0'),
        method: 'GET',
        headers: {'authorization': 'Bearer fixture'},
      ),
      createHttpClient: (_) => client,
    );
    expect(request.followRedirects, isFalse);
    expect(client.findProxy!(Uri.parse('http://127.0.0.1:8787')), 'DIRECT');
    expect(request.headers.values['authorization'], 'Bearer fixture');
    expect(response.statusCode, 302);
    expect(client.closed, isTrue);
  });
}

final class _Client implements HttpClient {
  _Client(this.request);
  final _Request request;
  bool closed = false;
  @override
  Duration? connectionTimeout;
  @override
  String Function(Uri)? findProxy;
  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async => request;
  @override
  void close({bool force = false}) => closed = true;
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
  int get statusCode => HttpStatus.found;
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
