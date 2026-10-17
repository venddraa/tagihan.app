import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tagihan_vendra/data/local/app_database.dart';
import 'package:tagihan_vendra/domain/bill.dart';
import 'package:tagihan_vendra/domain/calendar_date.dart';
import 'package:tagihan_vendra/domain/entity_id.dart';
import 'package:tagihan_vendra/domain/money.dart';
import 'package:tagihan_vendra/domain/payment.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  test('membuat schema version 3 beserta index dan sync state', () async {
    final billIndexes = await database
        .customSelect("PRAGMA index_list('bills')")
        .get();
    final paymentIndexes = await database
        .customSelect("PRAGMA index_list('payments')")
        .get();
    final billIndexNames = billIndexes
        .map((row) => row.read<String>('name'))
        .toSet();
    final paymentIndexNames = paymentIndexes
        .map((row) => row.read<String>('name'))
        .toSet();
    final syncOutboxIndexes = await database
        .customSelect("PRAGMA index_list('sync_outbox')")
        .get();
    final syncOutboxIndexNames = syncOutboxIndexes
        .map((row) => row.read<String>('name'))
        .toSet();
    final foreignKeys = await database
        .customSelect('PRAGMA foreign_keys')
        .getSingle();
    final syncState = await database.getLocalSyncState();

    expect(database.schemaVersion, 3);
    expect(billIndexNames, contains('bills_status_next_due_date'));
    expect(billIndexNames, contains('bills_deleted_at_ms'));
    expect(paymentIndexNames, contains('payments_bill_id_due_date'));
    expect(paymentIndexNames, contains('payments_paid_at_ms'));
    expect(paymentIndexNames, contains('payments_deleted_at_ms'));
    expect(syncOutboxIndexNames, contains('sync_outbox_entity'));
    expect(syncState.lastPulledSequence, 0);
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

  test('memperbarui detail tagihan berdasarkan ID', () async {
    final source = _bill(
      id: '01890f47-3d7a-7c53-bb3c-9d6ec2f1a6b0',
      name: 'Spotify',
    );
    await database.insertBill(source);
    final updatedAt = DateTime.utc(2026, 10, 12);
    final updated = Bill(
      id: source.id,
      name: 'Spotify Premium',
      category: source.category,
      amount: Money(minorUnits: 64990, currency: Currency.idr),
      billingCycle: source.billingCycle,
      nextDueDate: source.nextDueDate,
      startDate: source.startDate,
      status: source.status,
      notes: source.notes,
      createdAt: source.createdAt,
      updatedAt: updatedAt,
      version: 2,
    );

    await database.updateBill(updated);
    final stored = await database.findBillById(source.id);

    expect(stored!.name, 'Spotify Premium');
    expect(stored.amount.minorUnits, 64990);
    expect(stored.updatedAt, updatedAt);
    expect(stored.version, 2);
  });

  test(
    'archive menaikkan version dan menghapus tagihan dari daftar aktif',
    () async {
      final source = _bill(
        id: '01890f47-3d7a-7c53-bb3c-9d6ec2f1a6b0',
        name: 'Spotify',
      );
      await database.insertBill(source);
      final archivedAt = DateTime.utc(2026, 10, 12);

      await database.archiveBill(source.id, archivedAt);
      final stored = await database.findBillById(source.id);

      expect(stored!.status, BillStatus.archived);
      expect(stored.updatedAt, archivedAt);
      expect(stored.version, 2);
      expect(await database.getActiveBills(), isEmpty);
    },
  );

  test('stream daftar aktif mengikuti perubahan database', () async {
    final states = <List<Bill>>[];
    final subscription = database.watchActiveBills().listen(states.add);
    addTearDown(subscription.cancel);
    await Future<void>.delayed(Duration.zero);

    final source = _bill(
      id: '01890f47-3d7a-7c53-bb3c-9d6ec2f1a6b0',
      name: 'Spotify',
    );
    await database.insertBill(source);
    await Future<void>.delayed(Duration.zero);
    await database.archiveBill(source.id, DateTime.utc(2026, 10, 12));
    await Future<void>.delayed(Duration.zero);

    expect(states.map((state) => state.length), containsAllInOrder([0, 1, 0]));
  });

  test('menyimpan dan membaca payment sebagai record terpisah', () async {
    final bill = _bill(
      id: '01890f47-3d7a-7c53-bb3c-9d6ec2f1a6b0',
      name: 'Spotify',
    );
    final payment = _payment(
      id: '01890f47-3d7a-7a41-8585-2ec0a6634f2a',
      billId: bill.id,
      paidAt: DateTime.utc(2026, 10, 15, 9, 30),
      notes: 'Dibayar lebih awal',
    );
    await database.insertBill(bill);

    await _insertPaymentRow(database, payment);
    final stored = await database.findPaymentById(payment.id);

    expect(stored, isNotNull);
    expect(stored!.billId, bill.id);
    expect(stored.amount, payment.amount);
    expect(stored.dueDate, payment.dueDate);
    expect(stored.paidAt, payment.paidAt);
    expect(stored.notes, payment.notes);
    expect(stored.version, 1);
  });

  test('foreign key menolak payment untuk tagihan yang tidak ada', () async {
    final payment = _payment(
      id: '01890f47-3d7a-7a41-8585-2ec0a6634f2a',
      billId: EntityId.fromString('01890f47-3d7a-7c53-bb3c-9d6ec2f1a6b0'),
      paidAt: DateTime.utc(2026, 10, 15),
    );

    await expectLater(
      _insertPaymentRow(database, payment),
      throwsA(isA<Exception>()),
    );
  });

  test('riwayat payment terurut terbaru dan mengabaikan tombstone', () async {
    final bill = _bill(
      id: '01890f47-3d7a-7c53-bb3c-9d6ec2f1a6b0',
      name: 'Spotify',
    );
    await database.insertBill(bill);
    final older = _payment(
      id: '01890f47-3d7a-7a41-8585-2ec0a6634f2a',
      billId: bill.id,
      paidAt: DateTime.utc(2026, 9, 15),
    );
    final newer = _payment(
      id: '01890f47-3d7a-7a42-9585-2ec0a6634f2b',
      billId: bill.id,
      paidAt: DateTime.utc(2026, 10, 15),
    );
    final deletedAt = DateTime.utc(2026, 10, 16);
    final deleted = _payment(
      id: '01890f47-3d7a-7a43-a585-2ec0a6634f2c',
      billId: bill.id,
      paidAt: DateTime.utc(2026, 8, 15),
      updatedAt: deletedAt,
      deletedAt: deletedAt,
    );

    await _insertPaymentRow(database, older);
    await _insertPaymentRow(database, deleted);
    await _insertPaymentRow(database, newer);
    final history = await database.getPaymentHistory();

    expect(history.map((entry) => entry.payment.id), [newer.id, older.id]);
    expect(history.map((entry) => entry.billName), ['Spotify', 'Spotify']);
  });

  test('record payment memajukan tagihan monthly secara atomik', () async {
    final bill = _bill(
      id: '01890f47-3d7a-7c53-bb3c-9d6ec2f1a6b0',
      name: 'Spotify',
      nextDueDate: CalendarDate(2026, 10, 25),
    );
    await database.insertBill(bill);
    final payment = _payment(
      id: '01890f47-3d7a-7a41-8585-2ec0a6634f2a',
      billId: bill.id,
      dueDate: bill.nextDueDate,
      paidAt: DateTime.utc(2026, 10, 15),
    );

    await database.recordPayment(payment);
    final updatedBill = await database.findBillById(bill.id);

    expect(updatedBill!.nextDueDate, CalendarDate(2026, 11, 25));
    expect(updatedBill.version, 2);
    expect((await database.getPaymentHistory()).single.payment, isNotNull);
  });

  test('payment historis tidak mengubah jatuh tempo aktif', () async {
    final bill = _bill(
      id: '01890f47-3d7a-7c53-bb3c-9d6ec2f1a6b0',
      name: 'Spotify',
      nextDueDate: CalendarDate(2026, 10, 25),
    );
    await database.insertBill(bill);
    await database.recordPayment(
      _payment(
        id: '01890f47-3d7a-7a41-8585-2ec0a6634f2a',
        billId: bill.id,
        dueDate: CalendarDate(2026, 9, 25),
        paidAt: DateTime.utc(2026, 9, 15),
      ),
    );

    final unchangedBill = await database.findBillById(bill.id);
    expect(unchangedBill!.nextDueDate, bill.nextDueDate);
    expect(unchangedBill.version, 1);
  });

  test('payment one-time mengarsipkan tagihan', () async {
    final bill = _bill(
      id: '01890f47-3d7a-7c53-bb3c-9d6ec2f1a6b0',
      name: 'Lisensi sekali beli',
      billingCycle: BillingCycle.oneTime,
    );
    await database.insertBill(bill);
    await database.recordPayment(
      _payment(
        id: '01890f47-3d7a-7a41-8585-2ec0a6634f2a',
        billId: bill.id,
        dueDate: bill.nextDueDate,
        paidAt: DateTime.utc(2026, 10, 15),
      ),
    );

    final archived = await database.findBillById(bill.id);
    expect(archived!.status, BillStatus.archived);
    expect(archived.version, 2);
    expect(await database.getActiveBills(), isEmpty);
  });

  test('payment duplicate tidak memajukan jatuh tempo dua kali', () async {
    final bill = _bill(
      id: '01890f47-3d7a-7c53-bb3c-9d6ec2f1a6b0',
      name: 'Spotify',
    );
    final payment = _payment(
      id: '01890f47-3d7a-7a41-8585-2ec0a6634f2a',
      billId: bill.id,
      dueDate: bill.nextDueDate,
      paidAt: DateTime.utc(2026, 10, 15),
    );
    await database.insertBill(bill);
    await database.recordPayment(payment);

    await expectLater(
      database.recordPayment(payment),
      throwsA(isA<Exception>()),
    );
    final stored = await database.findBillById(bill.id);
    expect(stored!.nextDueDate, CalendarDate(2026, 11, 25));
    expect(stored.version, 2);
    expect((await database.getPaymentHistory()).length, 1);
  });

  test(
    'query overdue dan upcoming hanya mengembalikan tagihan aktif',
    () async {
      final overdue = _bill(
        id: '01890f47-3d7a-7c53-bb3c-9d6ec2f1a6b0',
        name: 'Terlambat',
        nextDueDate: CalendarDate(2026, 10, 14),
      );
      final dueToday = _bill(
        id: '01890f47-3d7a-7c54-8b3c-9d6ec2f1a6b1',
        name: 'Hari ini',
        nextDueDate: CalendarDate(2026, 10, 15),
      );
      final outsideWindow = _bill(
        id: '01890f47-3d7a-7c55-9b3c-9d6ec2f1a6b2',
        name: 'Nanti',
        nextDueDate: CalendarDate(2026, 10, 23),
      );
      final paused = _bill(
        id: '01890f47-3d7a-7c56-ab3c-9d6ec2f1a6b3',
        name: 'Paused',
        nextDueDate: CalendarDate(2026, 10, 14),
        status: BillStatus.paused,
      );
      for (final bill in [overdue, dueToday, outsideWindow, paused]) {
        await database.insertBill(bill);
      }
      final today = CalendarDate(2026, 10, 15);

      expect((await database.getOverdueBills(today)).map((bill) => bill.name), [
        'Terlambat',
      ]);
      expect(
        (await database.getUpcomingBills(
          today,
          withinDays: 7,
        )).map((bill) => bill.name),
        ['Hari ini'],
      );
    },
  );
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

Payment _payment({
  required String id,
  required EntityId billId,
  required DateTime paidAt,
  CalendarDate? dueDate,
  String? notes,
  DateTime? updatedAt,
  DateTime? deletedAt,
}) {
  final createdAt = DateTime.utc(2026, 8, 1);
  return Payment(
    id: EntityId.fromString(id),
    billId: billId,
    amount: Money(minorUnits: 59990, currency: Currency.idr),
    dueDate: dueDate ?? CalendarDate(paidAt.year, paidAt.month, 25),
    paidAt: paidAt,
    notes: notes,
    createdAt: createdAt,
    updatedAt: updatedAt ?? createdAt,
    deletedAt: deletedAt,
    version: 1,
  );
}

Future<void> _insertPaymentRow(AppDatabase database, Payment payment) async {
  await database
      .into(database.payments)
      .insert(
        PaymentsCompanion.insert(
          id: payment.id.value,
          billId: payment.billId.value,
          amountMinorUnits: payment.amount.minorUnits,
          currency: payment.amount.currency.code,
          dueDate: payment.dueDate.toString(),
          paidAtMs: payment.paidAt.millisecondsSinceEpoch,
          notes: drift.Value(payment.notes),
          createdAtMs: payment.createdAt.millisecondsSinceEpoch,
          updatedAtMs: payment.updatedAt.millisecondsSinceEpoch,
          deletedAtMs: drift.Value(payment.deletedAt?.millisecondsSinceEpoch),
          version: payment.version,
        ),
      );
}
