import 'dart:async';

import 'package:tagihan_vendra/data/local/app_database.dart';
import 'package:tagihan_vendra/data/sync/sync_bootstrap_client.dart';
import 'package:tagihan_vendra/data/sync/sync_pull_client.dart';
import 'package:tagihan_vendra/data/sync/sync_push_client.dart';

enum SyncBootstrapPolicy { skip, initializeHub }

enum SyncRuntimePhase { idle, syncing, synced, offline, conflict, failed }

final class SyncRuntimeStatus {
  const SyncRuntimeStatus({
    required this.phase,
    required this.pendingChanges,
    required this.conflicts,
    required this.message,
    this.lastSyncAt,
  });

  const SyncRuntimeStatus.idle()
    : phase = SyncRuntimePhase.idle,
      pendingChanges = 0,
      conflicts = 0,
      message = 'Belum disinkronkan.',
      lastSyncAt = null;

  final SyncRuntimePhase phase;
  final int pendingChanges;
  final int conflicts;
  final String message;
  final DateTime? lastSyncAt;
}

final class SyncCoordinator {
  factory SyncCoordinator({
    required AppDatabase database,
    required SyncPushClient pushClient,
    required SyncPullClient pullClient,
    SyncBootstrapPolicy bootstrapPolicy = SyncBootstrapPolicy.skip,
    SyncBootstrapClient? bootstrapClient,
    Future<void> Function()? prepareSync,
  }) {
    if (bootstrapPolicy == SyncBootstrapPolicy.initializeHub &&
        bootstrapClient == null) {
      throw ArgumentError(
        'Bootstrap client wajib tersedia untuk initializeHub.',
      );
    }
    return SyncCoordinator._(
      database,
      bootstrapClient,
      pushClient,
      pullClient,
      bootstrapPolicy,
      prepareSync,
    );
  }

  SyncCoordinator._(
    this._database,
    this._bootstrapClient,
    this._pushClient,
    this._pullClient,
    this.bootstrapPolicy,
    this._prepareSync,
  );

  final AppDatabase _database;
  final SyncBootstrapClient? _bootstrapClient;
  final SyncPushClient _pushClient;
  final SyncPullClient _pullClient;
  final SyncBootstrapPolicy bootstrapPolicy;
  final Future<void> Function()? _prepareSync;
  final StreamController<SyncRuntimeStatus> _statusController =
      StreamController<SyncRuntimeStatus>.broadcast(sync: true);

  SyncRuntimeStatus _status = const SyncRuntimeStatus.idle();
  Future<SyncRuntimeStatus>? _activeSync;
  DateTime? _lastSyncAt;

  SyncRuntimeStatus get status => _status;

  Stream<SyncRuntimeStatus> get statusChanges => _statusController.stream;

  Future<SyncRuntimeStatus> refreshLocalStatus() async {
    if (_activeSync != null) return _status;

    try {
      final counts = await _readCounts();
      if (counts.conflicts > 0) {
        return _publish(
          SyncRuntimeStatus(
            phase: SyncRuntimePhase.conflict,
            pendingChanges: counts.pending,
            conflicts: counts.conflicts,
            message: 'Ada perubahan yang perlu dipilih secara manual.',
            lastSyncAt: _lastSyncAt,
          ),
        );
      }

      if (_status.phase == SyncRuntimePhase.offline ||
          _status.phase == SyncRuntimePhase.failed) {
        return _publish(
          SyncRuntimeStatus(
            phase: _status.phase,
            pendingChanges: counts.pending,
            conflicts: 0,
            message: _status.message,
            lastSyncAt: _lastSyncAt,
          ),
        );
      }

      final hasSynced = _lastSyncAt != null;
      final hasPendingChanges = counts.pending > 0;
      return _publish(
        SyncRuntimeStatus(
          phase: hasSynced && !hasPendingChanges
              ? SyncRuntimePhase.synced
              : SyncRuntimePhase.idle,
          pendingChanges: counts.pending,
          conflicts: 0,
          message: hasPendingChanges
              ? '${counts.pending} perubahan menunggu sinkronisasi.'
              : hasSynced
              ? 'Semua perubahan sudah tersinkron.'
              : 'Belum disinkronkan pada sesi ini.',
          lastSyncAt: _lastSyncAt,
        ),
      );
    } on Object {
      return _publish(
        SyncRuntimeStatus(
          phase: SyncRuntimePhase.failed,
          pendingChanges: _status.pendingChanges,
          conflicts: _status.conflicts,
          message: 'Status sinkronisasi lokal tidak dapat dibaca.',
          lastSyncAt: _lastSyncAt,
        ),
      );
    }
  }

  Future<SyncRuntimeStatus> synchronize() {
    final active = _activeSync;
    if (active != null) return active;

    final run = _synchronize();
    _activeSync = run;
    run.whenComplete(() {
      if (identical(_activeSync, run)) _activeSync = null;
    });
    return run;
  }

  Future<SyncRuntimeStatus> _synchronize() async {
    try {
      final initialCounts = await _readCounts();
      _publish(
        SyncRuntimeStatus(
          phase: SyncRuntimePhase.syncing,
          pendingChanges: initialCounts.pending,
          conflicts: initialCounts.conflicts,
          message: 'Menyinkronkan perubahan…',
          lastSyncAt: _lastSyncAt,
        ),
      );

      await _prepareSync?.call();
      if (bootstrapPolicy == SyncBootstrapPolicy.initializeHub) {
        await _bootstrapClient!.bootstrapIfNeeded();
      }

      var pushConflicts = 0;
      var rejected = 0;
      while (true) {
        final push = await _pushClient.pushPending();
        pushConflicts += push.conflicts;
        rejected += push.rejected;
        if (!push.hadWork ||
            push.completed < push.sent ||
            push.conflicts > 0 ||
            push.rejected > 0) {
          break;
        }
      }

      if (rejected > 0) {
        return await _publishCurrent(
          phase: SyncRuntimePhase.failed,
          message: 'Ada perubahan lokal yang ditolak sync hub.',
        );
      }

      await _pullClient.pullAndApplyAvailable();
      final pending = await _database.countPendingSyncOperations();
      final storedConflicts = await _database.countUnresolvedSyncConflicts();
      final conflicts = storedConflicts > 0 ? storedConflicts : pushConflicts;
      _lastSyncAt = DateTime.now().toUtc();
      if (conflicts > 0) {
        return _publish(
          SyncRuntimeStatus(
            phase: SyncRuntimePhase.conflict,
            pendingChanges: pending,
            conflicts: conflicts,
            message: 'Ada perubahan yang perlu dipilih secara manual.',
            lastSyncAt: _lastSyncAt,
          ),
        );
      }
      return _publish(
        SyncRuntimeStatus(
          phase: SyncRuntimePhase.synced,
          pendingChanges: pending,
          conflicts: 0,
          message: 'Semua perubahan sudah tersinkron.',
          lastSyncAt: _lastSyncAt,
        ),
      );
    } on SyncAuthorizationException catch (error) {
      return _publishCurrent(
        phase: SyncRuntimePhase.failed,
        message: error.message,
      );
    } on SyncUnavailableException {
      return _publishCurrent(
        phase: SyncRuntimePhase.offline,
        message: 'Sync hub tidak tersedia. Data lokal tetap aman.',
      );
    } on SyncBootstrapRejectedException {
      return _publishCurrent(
        phase: SyncRuntimePhase.failed,
        message: 'Sync hub sudah berisi data dan menolak bootstrap.',
      );
    } on SyncProtocolException {
      return _publishCurrent(
        phase: SyncRuntimePhase.failed,
        message: 'Versi atau response sync hub tidak sesuai.',
      );
    } on Object {
      return _publishCurrent(
        phase: SyncRuntimePhase.failed,
        message: 'Sinkronisasi belum dapat diselesaikan.',
      );
    }
  }

  Future<SyncRuntimeStatus> _publishCurrent({
    required SyncRuntimePhase phase,
    required String message,
  }) async {
    final counts = await _readCountsSafely();
    return _publish(
      SyncRuntimeStatus(
        phase: phase,
        pendingChanges: counts.pending,
        conflicts: counts.conflicts,
        message: message,
        lastSyncAt: _lastSyncAt,
      ),
    );
  }

  Future<({int pending, int conflicts})> _readCounts() async {
    return (
      pending: await _database.countPendingSyncOperations(),
      conflicts: await _database.countUnresolvedSyncConflicts(),
    );
  }

  Future<({int pending, int conflicts})> _readCountsSafely() async {
    try {
      return await _readCounts();
    } on Object {
      return (pending: _status.pendingChanges, conflicts: _status.conflicts);
    }
  }

  SyncRuntimeStatus _publish(SyncRuntimeStatus next) {
    _status = next;
    if (!_statusController.isClosed) _statusController.add(next);
    return next;
  }

  Future<void> close() => _statusController.close();
}
