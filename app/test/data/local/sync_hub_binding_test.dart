import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tagihan_vendra/data/local/app_database.dart';

void main() {
  test('binding durable dan tidak mengizinkan pindah hub atau role', () async {
    final directory = await Directory.systemTemp.createTemp('tagihan-binding-');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/replica.sqlite');
    final first = AppDatabase(NativeDatabase(file));
    final id = (await first.getLocalSyncState()).deviceId;
    await first.bindSyncHub('paired|hub-a|pin-a', paired: true);
    await first.close();
    final db = AppDatabase(NativeDatabase(file));
    addTearDown(db.close);
    final state = await db.getLocalSyncState();
    expect(state.deviceId, id);
    expect(state.hubBinding, 'paired|hub-a|pin-a');
    await db.bindSyncHub('paired|hub-a|pin-a', paired: true);
    await expectLater(
      db.bindSyncHub('paired|hub-b|pin-b', paired: true),
      throwsStateError,
    );
    await expectLater(
      db.bindSyncHub('local|http://127.0.0.1:8787', paired: false),
      throwsStateError,
    );
    expect((await db.getLocalSyncState()).lastPulledSequence, 0);
  });

  for (final legacy in ['cursor', 'bootstrap']) {
    test(
      'riwayat legacy $legacy menolak pairing tanpa mereset cursor',
      () async {
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(db.close);
        await db.getLocalSyncState();
        await db
            .update(db.syncStates)
            .write(
              legacy == 'cursor'
                  ? const SyncStatesCompanion(lastPulledSequence: Value(12))
                  : const SyncStatesCompanion(
                      bootstrapId: Value(
                        '0199e7d0-0000-7000-8000-000000000030',
                      ),
                    ),
            );
        await expectLater(db.checkPairingEligibility(), throwsStateError);
        await expectLater(
          db.bindSyncHub('paired|hub|pin', paired: true),
          throwsStateError,
        );
        final state = await db.getLocalSyncState();
        expect(state.hubBinding, isNull);
        expect(state.lastPulledSequence, legacy == 'cursor' ? 12 : 0);
        // Upgrade existing Fedora tetap dapat mengikat hub lokalnya secara eksplisit.
        await db.bindSyncHub('local|http://127.0.0.1:8787', paired: false);
        expect(
          (await db.getLocalSyncState()).lastPulledSequence,
          state.lastPulledSequence,
        );
      },
    );
  }
}
