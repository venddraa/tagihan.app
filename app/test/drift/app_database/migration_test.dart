// dart format width=80
// ignore_for_file: unused_local_variable, unused_import
import 'package:drift/drift.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:tagihan_vendra/data/local/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

import 'generated/schema.dart';

import 'generated/schema_v1.dart' as v1;
import 'generated/schema_v2.dart' as v2;
import 'generated/schema_v3.dart' as v3;
import 'generated/schema_v4.dart' as v4;
import 'generated/schema_v5.dart' as v5;

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SchemaVerifier verifier;

  setUpAll(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  group('simple database migrations', () {
    // These simple tests verify all possible schema updates with a simple (no
    // data) migration. This is a quick way to ensure that written database
    // migrations properly alter the schema.
    const versions = GeneratedHelper.versions;
    for (final (i, fromVersion) in versions.indexed) {
      group('from $fromVersion', () {
        for (final toVersion in versions.skip(i + 1)) {
          test('to $toVersion', () async {
            final schema = await verifier.schemaAt(fromVersion);
            final db = AppDatabase(schema.newConnection());
            await verifier.migrateAndValidate(db, toVersion);
            await db.close();
          });
        }
      });
    }
  });

  test('migration from v1 to v2 does not corrupt data', () async {
    const oldBillsData = [
      v1.BillsData(
        id: '01890f47-3d7a-7c53-bb3c-9d6ec2f1a6b0',
        name: 'Spotify',
        category: 'Hiburan',
        amountMinorUnits: 59990,
        currency: 'IDR',
        billingCycle: 'monthly',
        nextDueDate: '2026-10-25',
        startDate: '2026-01-25',
        status: 'active',
        notes: 'Paket pribadi',
        createdAtMs: 1790812800000,
        updatedAtMs: 1790812800000,
        version: 1,
      ),
    ];
    const expectedNewBillsData = [
      v2.BillsData(
        id: '01890f47-3d7a-7c53-bb3c-9d6ec2f1a6b0',
        name: 'Spotify',
        category: 'Hiburan',
        amountMinorUnits: 59990,
        currency: 'IDR',
        billingCycle: 'monthly',
        nextDueDate: '2026-10-25',
        startDate: '2026-01-25',
        status: 'active',
        notes: 'Paket pribadi',
        createdAtMs: 1790812800000,
        updatedAtMs: 1790812800000,
        version: 1,
      ),
    ];

    await verifier.testWithDataIntegrity(
      oldVersion: 1,
      newVersion: 2,
      createOld: v1.DatabaseAtV1.new,
      createNew: v2.DatabaseAtV2.new,
      openTestedDatabase: AppDatabase.new,
      createItems: (batch, oldDb) {
        batch.insertAll(oldDb.bills, oldBillsData);
      },
      validateItems: (newDb) async {
        expect(expectedNewBillsData, await newDb.select(newDb.bills).get());
        expect(await newDb.select(newDb.payments).get(), isEmpty);
      },
    );
  });

  test(
    'migration from v2 to v3 preserves bills and creates sync state',
    () async {
      const oldBillsData = [
        v2.BillsData(
          id: '01890f47-3d7a-7c53-bb3c-9d6ec2f1a6b0',
          name: 'Spotify',
          category: 'Hiburan',
          amountMinorUnits: 59990,
          currency: 'IDR',
          billingCycle: 'monthly',
          nextDueDate: '2026-10-25',
          startDate: '2026-01-25',
          status: 'active',
          notes: 'Paket pribadi',
          createdAtMs: 1790812800000,
          updatedAtMs: 1790812800000,
          version: 1,
        ),
      ];
      const expectedNewBillsData = [
        v3.BillsData(
          id: '01890f47-3d7a-7c53-bb3c-9d6ec2f1a6b0',
          name: 'Spotify',
          category: 'Hiburan',
          amountMinorUnits: 59990,
          currency: 'IDR',
          billingCycle: 'monthly',
          nextDueDate: '2026-10-25',
          startDate: '2026-01-25',
          status: 'active',
          notes: 'Paket pribadi',
          createdAtMs: 1790812800000,
          updatedAtMs: 1790812800000,
          version: 1,
        ),
      ];

      await verifier.testWithDataIntegrity(
        oldVersion: 2,
        newVersion: 3,
        createOld: v2.DatabaseAtV2.new,
        createNew: v3.DatabaseAtV3.new,
        openTestedDatabase: AppDatabase.new,
        createItems: (batch, oldDb) {
          batch.insertAll(oldDb.bills, oldBillsData);
        },
        validateItems: (newDb) async {
          expect(expectedNewBillsData, await newDb.select(newDb.bills).get());
          expect(await newDb.select(newDb.syncOutbox).get(), isEmpty);
          expect(await newDb.select(newDb.appliedOperations).get(), isEmpty);
          final states = await newDb.select(newDb.syncState).get();
          expect(states, hasLength(1));
          expect(states.single.lastPulledSequence, 0);
        },
      );
    },
  );

  test('migration from v3 to v4 preserves sync state', () async {
    const oldSyncState = v3.SyncStateData(
      id: 1,
      deviceId: '0199e7d0-0000-7000-8000-000000000001',
      lastPulledSequence: 7,
      createdAtMs: 1792195200000,
    );

    await verifier.testWithDataIntegrity(
      oldVersion: 3,
      newVersion: 4,
      createOld: v3.DatabaseAtV3.new,
      createNew: v4.DatabaseAtV4.new,
      openTestedDatabase: AppDatabase.new,
      createItems: (batch, oldDb) {
        batch.insert(oldDb.syncState, oldSyncState);
      },
      validateItems: (newDb) async {
        final states = await newDb.select(newDb.syncState).get();
        expect(states, hasLength(1));
        expect(states.single.deviceId, oldSyncState.deviceId);
        expect(states.single.lastPulledSequence, 7);
        expect(states.single.bootstrapId, equals(null));
        expect(states.single.bootstrapPayloadJson, equals(null));
        expect(states.single.bootstrapCompletedAtMs, equals(null));
      },
    );
  });

  test(
    'migration from v4 to v5 preserves local data and sync cursor',
    () async {
      const oldBill = v4.BillsData(
        id: '01890f47-3d7a-7c53-bb3c-9d6ec2f1a6b0',
        name: 'Spotify',
        category: 'Hiburan',
        amountMinorUnits: 59990,
        currency: 'IDR',
        billingCycle: 'monthly',
        nextDueDate: '2026-10-25',
        startDate: '2026-01-25',
        status: 'active',
        notes: null,
        createdAtMs: 1790812800000,
        updatedAtMs: 1790812800000,
        version: 1,
      );
      const oldState = v4.SyncStateData(
        id: 1,
        deviceId: '0199e7d0-0000-7000-8000-000000000001',
        lastPulledSequence: 12,
        createdAtMs: 1792195200000,
        bootstrapId: '0199e7d0-0000-7000-8000-000000000030',
        bootstrapCreatedAtMs: 1792195200000,
        bootstrapCompletedAtMs: 1792195260000,
      );

      await verifier.testWithDataIntegrity(
        oldVersion: 4,
        newVersion: 5,
        createOld: v4.DatabaseAtV4.new,
        createNew: v5.DatabaseAtV5.new,
        openTestedDatabase: AppDatabase.new,
        createItems: (batch, oldDb) {
          batch.insert(oldDb.bills, oldBill);
          batch.insert(oldDb.syncState, oldState);
        },
        validateItems: (newDb) async {
          final bills = await newDb.select(newDb.bills).get();
          final states = await newDb.select(newDb.syncState).get();
          expect(bills.single.name, 'Spotify');
          expect(states.single.lastPulledSequence, 12);
          expect(await newDb.select(newDb.appliedOperations).get(), isEmpty);
          expect(await newDb.select(newDb.syncConflicts).get(), isEmpty);
        },
      );
    },
  );
}
