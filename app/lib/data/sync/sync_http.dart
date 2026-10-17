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

Future<SyncHTTPResponse> getSyncJSONWithDartIO(Uri uri) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
  try {
    final request = await client
        .getUrl(uri)
        .timeout(const Duration(seconds: 5));
    request.headers.set(HttpHeaders.acceptHeader, ContentType.json.mimeType);
    final response = await request.close().timeout(const Duration(seconds: 15));
    final responseBody = await utf8.decoder.bind(response).join();
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

Future<SyncHTTPResponse> postSyncJSONWithDartIO(Uri uri, String body) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
  try {
    final request = await client
        .postUrl(uri)
        .timeout(const Duration(seconds: 5));
    request.headers.contentType = ContentType.json;
    request.headers.set(HttpHeaders.acceptHeader, ContentType.json.mimeType);
    request.write(body);
    final response = await request.close().timeout(const Duration(seconds: 15));
    final responseBody = await utf8.decoder.bind(response).join();
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
