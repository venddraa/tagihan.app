import 'dart:io';

import 'package:tagihan_vendra/data/local/app_database.dart';
import 'package:tagihan_vendra/data/sync/local_sync_access.dart';
import 'package:tagihan_vendra/data/sync/sync_credential_store.dart';
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
  const adminUrl = String.fromEnvironment(
    'TAGIHAN_SYNC_ADMIN_URL',
    defaultValue: 'http://127.0.0.1:8788',
  );
  final access = LocalSyncAccess(
    database: database,
    serviceBaseUri: serviceBaseUri,
    adminBaseUri: Uri.parse(adminUrl),
    credentials: LinuxKeyringCredentialStore(),
  );
  final initializeLocalHub =
      Platform.isLinux && isLocalSyncBaseUri(serviceBaseUri);
  return SyncCoordinator(
    database: database,
    prepareSync: () async {
      if (!Platform.isLinux) {
        throw const SyncAuthorizationException(
          'Hubungkan perangkat melalui pairing setelah fitur tersebut tersedia.',
        );
      }
      await access.prepare();
    },
    bootstrapPolicy: initializeLocalHub
        ? SyncBootstrapPolicy.initializeHub
        : SyncBootstrapPolicy.skip,
    bootstrapClient: initializeLocalHub
        ? SyncBootstrapClient(
            database: database,
            serviceBaseUri: serviceBaseUri,
            postJSON: access.post,
          )
        : null,
    pushClient: SyncPushClient(
      database: database,
      serviceBaseUri: serviceBaseUri,
      postJSON: access.post,
    ),
    pullClient: SyncPullClient(
      database: database,
      serviceBaseUri: serviceBaseUri,
      getJSON: access.get,
    ),
  );
}
