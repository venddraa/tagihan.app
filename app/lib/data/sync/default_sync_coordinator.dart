import 'dart:io';

import 'package:tagihan_vendra/data/local/app_database.dart';
import 'package:tagihan_vendra/data/sync/sync_bootstrap_client.dart';
import 'package:tagihan_vendra/data/sync/sync_coordinator.dart';
import 'package:tagihan_vendra/data/sync/sync_pull_client.dart';
import 'package:tagihan_vendra/data/sync/sync_push_client.dart';

const _configuredServiceUrl = String.fromEnvironment(
  'TAGIHAN_SYNC_URL',
  defaultValue: 'http://127.0.0.1:8787',
);

SyncCoordinator createDefaultSyncCoordinator(AppDatabase database) {
  final serviceBaseUri = Uri.parse(_configuredServiceUrl);
  if (!_isValidHTTPBaseUri(serviceBaseUri)) {
    throw StateError('TAGIHAN_SYNC_URL harus berupa URL HTTP yang valid.');
  }

  final initializeLocalHub = Platform.isLinux && _isLoopback(serviceBaseUri);
  return SyncCoordinator(
    database: database,
    bootstrapPolicy: initializeLocalHub
        ? SyncBootstrapPolicy.initializeHub
        : SyncBootstrapPolicy.skip,
    bootstrapClient: initializeLocalHub
        ? SyncBootstrapClient(
            database: database,
            serviceBaseUri: serviceBaseUri,
          )
        : null,
    pushClient: SyncPushClient(
      database: database,
      serviceBaseUri: serviceBaseUri,
    ),
    pullClient: SyncPullClient(
      database: database,
      serviceBaseUri: serviceBaseUri,
    ),
  );
}

bool _isValidHTTPBaseUri(Uri uri) {
  return (uri.scheme == 'http' || uri.scheme == 'https') &&
      uri.host.isNotEmpty &&
      !uri.hasQuery &&
      !uri.hasFragment;
}

bool _isLoopback(Uri uri) {
  return uri.host == '127.0.0.1' ||
      uri.host == 'localhost' ||
      uri.host == '::1';
}
