import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tagihan_vendra/app/app_shell.dart';
import 'package:tagihan_vendra/app/app_theme.dart';
import 'package:tagihan_vendra/data/local/app_database.dart';
import 'package:tagihan_vendra/data/sync/default_sync_coordinator.dart';
import 'package:tagihan_vendra/data/sync/sync_coordinator.dart';

class TagihanVendraApp extends StatefulWidget {
  const TagihanVendraApp({
    super.key,
    required this.database,
    this.syncCoordinator,
  });

  final AppDatabase database;
  final SyncCoordinator? syncCoordinator;

  @override
  State<TagihanVendraApp> createState() => _TagihanVendraAppState();
}

class _TagihanVendraAppState extends State<TagihanVendraApp> {
  late SyncCoordinator _syncCoordinator;
  late bool _ownsSyncCoordinator;

  @override
  void initState() {
    super.initState();
    _configureSyncCoordinator();
  }

  void _configureSyncCoordinator() {
    _ownsSyncCoordinator = widget.syncCoordinator == null;
    _syncCoordinator =
        widget.syncCoordinator ?? createDefaultSyncCoordinator(widget.database);
  }

  @override
  void didUpdateWidget(covariant TagihanVendraApp oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.database == widget.database &&
        oldWidget.syncCoordinator == widget.syncCoordinator) {
      return;
    }
    if (_ownsSyncCoordinator) unawaited(_syncCoordinator.close());
    _configureSyncCoordinator();
  }

  @override
  void dispose() {
    if (_ownsSyncCoordinator) unawaited(_syncCoordinator.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Tagihan Vendra',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      home: AppShell(
        database: widget.database,
        syncCoordinator: _syncCoordinator,
      ),
    );
  }
}
