import 'dart:async';
import 'dart:convert';
import 'dart:io';

typedef SyncJSONGet = Future<SyncHTTPResponse> Function(Uri uri);
typedef SyncJSONPost = Future<SyncHTTPResponse> Function(Uri uri, String body);

final class SyncHTTPResponse {
  const SyncHTTPResponse({required this.statusCode, required this.body});

  final int statusCode;
  final String body;
}

final class SyncUnavailableException implements Exception {
  const SyncUnavailableException([
    this.message = 'Sync service tidak tersedia.',
  ]);

  final String message;

  @override
  String toString() => message;
}

final class SyncProtocolException implements Exception {
  const SyncProtocolException(this.message);

  final String message;

  @override
  String toString() => message;
}

final class SyncAuthorizationException implements Exception {
  const SyncAuthorizationException([
    this.message = 'Credential sync tidak valid atau akses perangkat dicabut.',
  ]);

  final String message;

  @override
  String toString() => message;
}

void checkSyncAuthorization(SyncHTTPResponse response) {
  if (response.statusCode == HttpStatus.unauthorized ||
      response.statusCode == HttpStatus.forbidden) {
    throw const SyncAuthorizationException();
  }
}

Future<SyncHTTPResponse> getSyncJSONWithDartIO(Uri uri) =>
    requestSyncJSONWithDartIO(uri, method: 'GET');

Future<SyncHTTPResponse> postSyncJSONWithDartIO(Uri uri, String body) =>
    requestSyncJSONWithDartIO(uri, method: 'POST', body: body);

typedef SyncHTTPRequest = Future<SyncHTTPResponse> Function(
  Uri uri, {
  required String method,
  String? body,
  Map<String, String> headers,
});

Future<SyncHTTPResponse> requestSyncJSONWithDartIO(
  Uri uri, {
  required String method,
  String? body,
  Map<String, String> headers = const {},
  HttpClient Function()? createClient,
}) async {
  final client = (createClient?.call() ?? HttpClient())
    ..connectionTimeout = const Duration(seconds: 5)
    ..findProxy = (_) => 'DIRECT';
  try {
    final request = await client
        .openUrl(method, uri)
        .timeout(const Duration(seconds: 5));
    request.followRedirects = false;
    request.headers.set(HttpHeaders.acceptHeader, ContentType.json.mimeType);
    headers.forEach(request.headers.set);
    if (body != null) {
      request.headers.contentType = ContentType.json;
      request.write(body);
    }
    final response = await request.close().timeout(const Duration(seconds: 15));
    // join juga dibatasi, agar server yang tidak menutup body tidak menggantung sync.
    final responseBody = await utf8.decoder
        .bind(response)
        .join()
        .timeout(const Duration(seconds: 15));
    return SyncHTTPResponse(
      statusCode: response.statusCode,
      body: responseBody,
    );
  } on SocketException catch (_) {
    throw const SyncUnavailableException();
  } on TimeoutException catch (_) {
    throw const SyncUnavailableException('Sync service tidak merespons.');
  } finally {
    client.close(force: true);
  }
}
