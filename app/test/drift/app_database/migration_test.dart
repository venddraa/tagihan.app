// dart format width=80
// ignore_for_file: unused_local_variable, unused_import
import 'package:drift/drift.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:tagihan_vendra/data/local/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

import 'generated/schema.dart';

import 'generated/schema_v1.dart' as v1;
import 'generated/schema_v2.dart' as v2;

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
}
