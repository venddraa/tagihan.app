import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tagihan_vendra/data/local/app_database.dart';
import 'package:tagihan_vendra/domain/bill.dart';
import 'package:tagihan_vendra/domain/calendar_date.dart';
import 'package:tagihan_vendra/domain/entity_id.dart';
import 'package:tagihan_vendra/domain/money.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  test('membuat schema version 1 beserta index', () async {
    final indexes = await database
        .customSelect("PRAGMA index_list('bills')")
        .get();
    final indexNames = indexes.map((row) => row.read<String>('name')).toSet();
    final foreignKeys = await database
        .customSelect('PRAGMA foreign_keys')
        .getSingle();

    expect(database.schemaVersion, 1);
    expect(indexNames, contains('bills_status_next_due_date'));
    expect(indexNames, contains('bills_deleted_at_ms'));
    expect(foreignKeys.read<int>('foreign_keys'), 1);
  });

  test('menyimpan dan membaca Bill tanpa kehilangan nilai', () async {
    final source = _bill(
      id: '01890f47-3d7a-7c53-bb3c-9d6ec2f1a6b0',
      name: 'ChatGPT Plus',
      category: 'Software',
      billingCycle: BillingCycle.monthly,
      notes: 'Tagihan utama',
      version: 3,
    );

    await database.insertBill(source);
    final stored = await database.findBillById(source.id);

    expect(stored, isNotNull);
    expect(stored!.id, source.id);
    expect(stored.name, source.name);
    expect(stored.category, source.category);
    expect(stored.amount, source.amount);
    expect(stored.billingCycle, source.billingCycle);
    expect(stored.nextDueDate, source.nextDueDate);
    expect(stored.startDate, source.startDate);
    expect(stored.status, source.status);
    expect(stored.notes, source.notes);
    expect(stored.createdAt, source.createdAt);
    expect(stored.updatedAt, source.updatedAt);
    expect(stored.deletedAt, source.deletedAt);
    expect(stored.version, source.version);
  });

  test('menolak UUID tagihan yang sama', () async {
    final bill = _bill(
      id: '01890f47-3d7a-7c53-bb3c-9d6ec2f1a6b0',
      name: 'Spotify',
    );

    await database.insertBill(bill);

    await expectLater(database.insertBill(bill), throwsA(isA<Exception>()));
  });

  test('constraint database menolak nominal negatif', () async {
    await expectLater(
      database
          .into(database.bills)
          .insert(
            _rawBill(
              id: '01890f47-3d7a-7c53-bb3c-9d6ec2f1a6b0',
              amountMinorUnits: -1,
            ),
          ),
      throwsA(isA<Exception>()),
    );
  });

  test('constraint database menolak version kurang dari satu', () async {
    await expectLater(
      database
          .into(database.bills)
          .insert(
            _rawBill(id: '01890f47-3d7a-7c53-bb3c-9d6ec2f1a6b0', version: 0),
          ),
      throwsA(isA<Exception>()),
    );
  });

  test('query aktif mengabaikan paused, archived, dan tombstone', () async {
    final activeLater = _bill(
      id: '01890f47-3d7a-7c53-bb3c-9d6ec2f1a6b0',
      name: 'Spotify',
      nextDueDate: CalendarDate(2026, 10, 25),
    );
    final activeEarlier = _bill(
      id: '01890f47-3d7a-7c54-8b3c-9d6ec2f1a6b1',
      name: 'ChatGPT Plus',
      nextDueDate: CalendarDate(2026, 10, 18),
    );
    final paused = _bill(
      id: '01890f47-3d7a-7c55-9b3c-9d6ec2f1a6b2',
      name: 'Paused',
      status: BillStatus.paused,
    );
    final archived = _bill(
      id: '01890f47-3d7a-7c56-ab3c-9d6ec2f1a6b3',
      name: 'Archived',
      status: BillStatus.archived,
    );
    final deletedAt = DateTime.utc(2026, 10, 12, 12);
    final deleted = _bill(
      id: '01890f47-3d7a-7c57-bb3c-9d6ec2f1a6b4',
      name: 'Deleted',
      updatedAt: deletedAt,
      deletedAt: deletedAt,
    );

    for (final bill in [
      activeLater,
      paused,
      deleted,
      activeEarlier,
      archived,
    ]) {
      await database.insertBill(bill);
    }

    final result = await database.getActiveBills();

    expect(result.map((bill) => bill.name), ['ChatGPT Plus', 'Spotify']);
  });

  test('tombstone tetap tersimpan dan dapat dibaca berdasarkan ID', () async {
    final deletedAt = DateTime.utc(2026, 10, 12, 12);
    final source = _bill(
      id: '01890f47-3d7a-7c53-bb3c-9d6ec2f1a6b0',
      name: 'Domain example.com',
      updatedAt: deletedAt,
      deletedAt: deletedAt,
    );

    await database.insertBill(source);
    final stored = await database.findBillById(source.id);

    expect(stored, isNotNull);
    expect(stored!.isDeleted, isTrue);
    expect(stored.deletedAt, deletedAt);
  });
}

Bill _bill({
  required String id,
  required String name,
  String? category,
  BillingCycle billingCycle = BillingCycle.monthly,
  CalendarDate? nextDueDate,
  BillStatus status = BillStatus.active,
  String? notes,
  DateTime? updatedAt,
  DateTime? deletedAt,
  int version = 1,
}) {
  return Bill(
    id: EntityId.fromString(id),
    name: name,
    category: category,
    amount: Money(minorUnits: 59990, currency: Currency.idr),
    billingCycle: billingCycle,
    nextDueDate: nextDueDate ?? CalendarDate(2026, 10, 25),
    startDate: CalendarDate(2026, 1, 25),
    status: status,
    notes: notes,
    createdAt: DateTime.utc(2026, 10, 1),
    updatedAt: updatedAt ?? DateTime.utc(2026, 10, 1),
    deletedAt: deletedAt,
    version: version,
  );
}

BillsCompanion _rawBill({
  required String id,
  int amountMinorUnits = 59990,
  int version = 1,
}) {
  return BillsCompanion.insert(
    id: id,
    name: 'Raw Bill',
    amountMinorUnits: amountMinorUnits,
    currency: 'IDR',
    billingCycle: 'monthly',
    nextDueDate: '2026-10-25',
    startDate: '2026-01-25',
    status: 'active',
    createdAtMs: DateTime.utc(2026, 10, 1).millisecondsSinceEpoch,
    updatedAtMs: DateTime.utc(2026, 10, 1).millisecondsSinceEpoch,
    version: version,
  );
}
