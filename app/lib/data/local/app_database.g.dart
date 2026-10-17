// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $BillsTable extends Bills with TableInfo<$BillsTable, BillRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BillsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _categoryMeta = const VerificationMeta(
    'category',
  );
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
    'category',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _amountMinorUnitsMeta = const VerificationMeta(
    'amountMinorUnits',
  );
  @override
  late final GeneratedColumn<int> amountMinorUnits = GeneratedColumn<int>(
    'amount_minor_units',
    aliasedName,
    false,
    check: () => ComparableExpr(amountMinorUnits).isBiggerOrEqualValue(0),
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _currencyMeta = const VerificationMeta(
    'currency',
  );
  @override
  late final GeneratedColumn<String> currency = GeneratedColumn<String>(
    'currency',
    aliasedName,
    false,
    check: () => currency.isIn(const ['IDR', 'USD', 'EUR']),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _billingCycleMeta = const VerificationMeta(
    'billingCycle',
  );
  @override
  late final GeneratedColumn<String> billingCycle = GeneratedColumn<String>(
    'billing_cycle',
    aliasedName,
    false,
    check: () =>
        billingCycle.isIn(const ['one_time', 'weekly', 'monthly', 'yearly']),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nextDueDateMeta = const VerificationMeta(
    'nextDueDate',
  );
  @override
  late final GeneratedColumn<String> nextDueDate = GeneratedColumn<String>(
    'next_due_date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startDateMeta = const VerificationMeta(
    'startDate',
  );
  @override
  late final GeneratedColumn<String> startDate = GeneratedColumn<String>(
    'start_date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    check: () => status.isIn(const ['active', 'paused', 'archived']),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMsMeta = const VerificationMeta(
    'createdAtMs',
  );
  @override
  late final GeneratedColumn<int> createdAtMs = GeneratedColumn<int>(
    'created_at_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMsMeta = const VerificationMeta(
    'updatedAtMs',
  );
  @override
  late final GeneratedColumn<int> updatedAtMs = GeneratedColumn<int>(
    'updated_at_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMsMeta = const VerificationMeta(
    'deletedAtMs',
  );
  @override
  late final GeneratedColumn<int> deletedAtMs = GeneratedColumn<int>(
    'deleted_at_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    check: () => ComparableExpr(version).isBiggerOrEqualValue(1),
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    category,
    amountMinorUnits,
    currency,
    billingCycle,
    nextDueDate,
    startDate,
    status,
    notes,
    createdAtMs,
    updatedAtMs,
    deletedAtMs,
    version,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'bills';
  @override
  VerificationContext validateIntegrity(
    Insertable<BillRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('category')) {
      context.handle(
        _categoryMeta,
        category.isAcceptableOrUnknown(data['category']!, _categoryMeta),
      );
    }
    if (data.containsKey('amount_minor_units')) {
      context.handle(
        _amountMinorUnitsMeta,
        amountMinorUnits.isAcceptableOrUnknown(
          data['amount_minor_units']!,
          _amountMinorUnitsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_amountMinorUnitsMeta);
    }
    if (data.containsKey('currency')) {
      context.handle(
        _currencyMeta,
        currency.isAcceptableOrUnknown(data['currency']!, _currencyMeta),
      );
    } else if (isInserting) {
      context.missing(_currencyMeta);
    }
    if (data.containsKey('billing_cycle')) {
      context.handle(
        _billingCycleMeta,
        billingCycle.isAcceptableOrUnknown(
          data['billing_cycle']!,
          _billingCycleMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_billingCycleMeta);
    }
    if (data.containsKey('next_due_date')) {
      context.handle(
        _nextDueDateMeta,
        nextDueDate.isAcceptableOrUnknown(
          data['next_due_date']!,
          _nextDueDateMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_nextDueDateMeta);
    }
    if (data.containsKey('start_date')) {
      context.handle(
        _startDateMeta,
        startDate.isAcceptableOrUnknown(data['start_date']!, _startDateMeta),
      );
    } else if (isInserting) {
      context.missing(_startDateMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('created_at_ms')) {
      context.handle(
        _createdAtMsMeta,
        createdAtMs.isAcceptableOrUnknown(
          data['created_at_ms']!,
          _createdAtMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdAtMsMeta);
    }
    if (data.containsKey('updated_at_ms')) {
      context.handle(
        _updatedAtMsMeta,
        updatedAtMs.isAcceptableOrUnknown(
          data['updated_at_ms']!,
          _updatedAtMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMsMeta);
    }
    if (data.containsKey('deleted_at_ms')) {
      context.handle(
        _deletedAtMsMeta,
        deletedAtMs.isAcceptableOrUnknown(
          data['deleted_at_ms']!,
          _deletedAtMsMeta,
        ),
      );
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    } else if (isInserting) {
      context.missing(_versionMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  BillRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BillRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      category: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category'],
      ),
      amountMinorUnits: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}amount_minor_units'],
      )!,
      currency: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}currency'],
      )!,
      billingCycle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}billing_cycle'],
      )!,
      nextDueDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}next_due_date'],
      )!,
      startDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}start_date'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      createdAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at_ms'],
      )!,
      updatedAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at_ms'],
      )!,
      deletedAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at_ms'],
      ),
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
    );
  }

  @override
  $BillsTable createAlias(String alias) {
    return $BillsTable(attachedDatabase, alias);
  }
}

class BillRow extends DataClass implements Insertable<BillRow> {
  final String id;
  final String name;
  final String? category;
  final int amountMinorUnits;
  final String currency;
  final String billingCycle;
  final String nextDueDate;
  final String startDate;
  final String status;
  final String? notes;
  final int createdAtMs;
  final int updatedAtMs;
  final int? deletedAtMs;
  final int version;
  const BillRow({
    required this.id,
    required this.name,
    this.category,
    required this.amountMinorUnits,
    required this.currency,
    required this.billingCycle,
    required this.nextDueDate,
    required this.startDate,
    required this.status,
    this.notes,
    required this.createdAtMs,
    required this.updatedAtMs,
    this.deletedAtMs,
    required this.version,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || category != null) {
      map['category'] = Variable<String>(category);
    }
    map['amount_minor_units'] = Variable<int>(amountMinorUnits);
    map['currency'] = Variable<String>(currency);
    map['billing_cycle'] = Variable<String>(billingCycle);
    map['next_due_date'] = Variable<String>(nextDueDate);
    map['start_date'] = Variable<String>(startDate);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    map['created_at_ms'] = Variable<int>(createdAtMs);
    map['updated_at_ms'] = Variable<int>(updatedAtMs);
    if (!nullToAbsent || deletedAtMs != null) {
      map['deleted_at_ms'] = Variable<int>(deletedAtMs);
    }
    map['version'] = Variable<int>(version);
    return map;
  }

  BillsCompanion toCompanion(bool nullToAbsent) {
    return BillsCompanion(
      id: Value(id),
      name: Value(name),
      category: category == null && nullToAbsent
          ? const Value.absent()
          : Value(category),
      amountMinorUnits: Value(amountMinorUnits),
      currency: Value(currency),
      billingCycle: Value(billingCycle),
      nextDueDate: Value(nextDueDate),
      startDate: Value(startDate),
      status: Value(status),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      createdAtMs: Value(createdAtMs),
      updatedAtMs: Value(updatedAtMs),
      deletedAtMs: deletedAtMs == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAtMs),
      version: Value(version),
    );
  }

  factory BillRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BillRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      category: serializer.fromJson<String?>(json['category']),
      amountMinorUnits: serializer.fromJson<int>(json['amountMinorUnits']),
      currency: serializer.fromJson<String>(json['currency']),
      billingCycle: serializer.fromJson<String>(json['billingCycle']),
      nextDueDate: serializer.fromJson<String>(json['nextDueDate']),
      startDate: serializer.fromJson<String>(json['startDate']),
      status: serializer.fromJson<String>(json['status']),
      notes: serializer.fromJson<String?>(json['notes']),
      createdAtMs: serializer.fromJson<int>(json['createdAtMs']),
      updatedAtMs: serializer.fromJson<int>(json['updatedAtMs']),
      deletedAtMs: serializer.fromJson<int?>(json['deletedAtMs']),
      version: serializer.fromJson<int>(json['version']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'category': serializer.toJson<String?>(category),
      'amountMinorUnits': serializer.toJson<int>(amountMinorUnits),
      'currency': serializer.toJson<String>(currency),
      'billingCycle': serializer.toJson<String>(billingCycle),
      'nextDueDate': serializer.toJson<String>(nextDueDate),
      'startDate': serializer.toJson<String>(startDate),
      'status': serializer.toJson<String>(status),
      'notes': serializer.toJson<String?>(notes),
      'createdAtMs': serializer.toJson<int>(createdAtMs),
      'updatedAtMs': serializer.toJson<int>(updatedAtMs),
      'deletedAtMs': serializer.toJson<int?>(deletedAtMs),
      'version': serializer.toJson<int>(version),
    };
  }

  BillRow copyWith({
    String? id,
    String? name,
    Value<String?> category = const Value.absent(),
    int? amountMinorUnits,
    String? currency,
    String? billingCycle,
    String? nextDueDate,
    String? startDate,
    String? status,
    Value<String?> notes = const Value.absent(),
    int? createdAtMs,
    int? updatedAtMs,
    Value<int?> deletedAtMs = const Value.absent(),
    int? version,
  }) => BillRow(
    id: id ?? this.id,
    name: name ?? this.name,
    category: category.present ? category.value : this.category,
    amountMinorUnits: amountMinorUnits ?? this.amountMinorUnits,
    currency: currency ?? this.currency,
    billingCycle: billingCycle ?? this.billingCycle,
    nextDueDate: nextDueDate ?? this.nextDueDate,
    startDate: startDate ?? this.startDate,
    status: status ?? this.status,
    notes: notes.present ? notes.value : this.notes,
    createdAtMs: createdAtMs ?? this.createdAtMs,
    updatedAtMs: updatedAtMs ?? this.updatedAtMs,
    deletedAtMs: deletedAtMs.present ? deletedAtMs.value : this.deletedAtMs,
    version: version ?? this.version,
  );
  BillRow copyWithCompanion(BillsCompanion data) {
    return BillRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      category: data.category.present ? data.category.value : this.category,
      amountMinorUnits: data.amountMinorUnits.present
          ? data.amountMinorUnits.value
          : this.amountMinorUnits,
      currency: data.currency.present ? data.currency.value : this.currency,
      billingCycle: data.billingCycle.present
          ? data.billingCycle.value
          : this.billingCycle,
      nextDueDate: data.nextDueDate.present
          ? data.nextDueDate.value
          : this.nextDueDate,
      startDate: data.startDate.present ? data.startDate.value : this.startDate,
      status: data.status.present ? data.status.value : this.status,
      notes: data.notes.present ? data.notes.value : this.notes,
      createdAtMs: data.createdAtMs.present
          ? data.createdAtMs.value
          : this.createdAtMs,
      updatedAtMs: data.updatedAtMs.present
          ? data.updatedAtMs.value
          : this.updatedAtMs,
      deletedAtMs: data.deletedAtMs.present
          ? data.deletedAtMs.value
          : this.deletedAtMs,
      version: data.version.present ? data.version.value : this.version,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BillRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('category: $category, ')
          ..write('amountMinorUnits: $amountMinorUnits, ')
          ..write('currency: $currency, ')
          ..write('billingCycle: $billingCycle, ')
          ..write('nextDueDate: $nextDueDate, ')
          ..write('startDate: $startDate, ')
          ..write('status: $status, ')
          ..write('notes: $notes, ')
          ..write('createdAtMs: $createdAtMs, ')
          ..write('updatedAtMs: $updatedAtMs, ')
          ..write('deletedAtMs: $deletedAtMs, ')
          ..write('version: $version')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    category,
    amountMinorUnits,
    currency,
    billingCycle,
    nextDueDate,
    startDate,
    status,
    notes,
    createdAtMs,
    updatedAtMs,
    deletedAtMs,
    version,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BillRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.category == this.category &&
          other.amountMinorUnits == this.amountMinorUnits &&
          other.currency == this.currency &&
          other.billingCycle == this.billingCycle &&
          other.nextDueDate == this.nextDueDate &&
          other.startDate == this.startDate &&
          other.status == this.status &&
          other.notes == this.notes &&
          other.createdAtMs == this.createdAtMs &&
          other.updatedAtMs == this.updatedAtMs &&
          other.deletedAtMs == this.deletedAtMs &&
          other.version == this.version);
}

class BillsCompanion extends UpdateCompanion<BillRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<String?> category;
  final Value<int> amountMinorUnits;
  final Value<String> currency;
  final Value<String> billingCycle;
  final Value<String> nextDueDate;
  final Value<String> startDate;
  final Value<String> status;
  final Value<String?> notes;
  final Value<int> createdAtMs;
  final Value<int> updatedAtMs;
  final Value<int?> deletedAtMs;
  final Value<int> version;
  final Value<int> rowid;
  const BillsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.category = const Value.absent(),
    this.amountMinorUnits = const Value.absent(),
    this.currency = const Value.absent(),
    this.billingCycle = const Value.absent(),
    this.nextDueDate = const Value.absent(),
    this.startDate = const Value.absent(),
    this.status = const Value.absent(),
    this.notes = const Value.absent(),
    this.createdAtMs = const Value.absent(),
    this.updatedAtMs = const Value.absent(),
    this.deletedAtMs = const Value.absent(),
    this.version = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BillsCompanion.insert({
    required String id,
    required String name,
    this.category = const Value.absent(),
    required int amountMinorUnits,
    required String currency,
    required String billingCycle,
    required String nextDueDate,
    required String startDate,
    required String status,
    this.notes = const Value.absent(),
    required int createdAtMs,
    required int updatedAtMs,
    this.deletedAtMs = const Value.absent(),
    required int version,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       amountMinorUnits = Value(amountMinorUnits),
       currency = Value(currency),
       billingCycle = Value(billingCycle),
       nextDueDate = Value(nextDueDate),
       startDate = Value(startDate),
       status = Value(status),
       createdAtMs = Value(createdAtMs),
       updatedAtMs = Value(updatedAtMs),
       version = Value(version);
  static Insertable<BillRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? category,
    Expression<int>? amountMinorUnits,
    Expression<String>? currency,
    Expression<String>? billingCycle,
    Expression<String>? nextDueDate,
    Expression<String>? startDate,
    Expression<String>? status,
    Expression<String>? notes,
    Expression<int>? createdAtMs,
    Expression<int>? updatedAtMs,
    Expression<int>? deletedAtMs,
    Expression<int>? version,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (category != null) 'category': category,
      if (amountMinorUnits != null) 'amount_minor_units': amountMinorUnits,
      if (currency != null) 'currency': currency,
      if (billingCycle != null) 'billing_cycle': billingCycle,
      if (nextDueDate != null) 'next_due_date': nextDueDate,
      if (startDate != null) 'start_date': startDate,
      if (status != null) 'status': status,
      if (notes != null) 'notes': notes,
      if (createdAtMs != null) 'created_at_ms': createdAtMs,
      if (updatedAtMs != null) 'updated_at_ms': updatedAtMs,
      if (deletedAtMs != null) 'deleted_at_ms': deletedAtMs,
      if (version != null) 'version': version,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BillsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String?>? category,
    Value<int>? amountMinorUnits,
    Value<String>? currency,
    Value<String>? billingCycle,
    Value<String>? nextDueDate,
    Value<String>? startDate,
    Value<String>? status,
    Value<String?>? notes,
    Value<int>? createdAtMs,
    Value<int>? updatedAtMs,
    Value<int?>? deletedAtMs,
    Value<int>? version,
    Value<int>? rowid,
  }) {
    return BillsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      amountMinorUnits: amountMinorUnits ?? this.amountMinorUnits,
      currency: currency ?? this.currency,
      billingCycle: billingCycle ?? this.billingCycle,
      nextDueDate: nextDueDate ?? this.nextDueDate,
      startDate: startDate ?? this.startDate,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      createdAtMs: createdAtMs ?? this.createdAtMs,
      updatedAtMs: updatedAtMs ?? this.updatedAtMs,
      deletedAtMs: deletedAtMs ?? this.deletedAtMs,
      version: version ?? this.version,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (amountMinorUnits.present) {
      map['amount_minor_units'] = Variable<int>(amountMinorUnits.value);
    }
    if (currency.present) {
      map['currency'] = Variable<String>(currency.value);
    }
    if (billingCycle.present) {
      map['billing_cycle'] = Variable<String>(billingCycle.value);
    }
    if (nextDueDate.present) {
      map['next_due_date'] = Variable<String>(nextDueDate.value);
    }
    if (startDate.present) {
      map['start_date'] = Variable<String>(startDate.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (createdAtMs.present) {
      map['created_at_ms'] = Variable<int>(createdAtMs.value);
    }
    if (updatedAtMs.present) {
      map['updated_at_ms'] = Variable<int>(updatedAtMs.value);
    }
    if (deletedAtMs.present) {
      map['deleted_at_ms'] = Variable<int>(deletedAtMs.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BillsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('category: $category, ')
          ..write('amountMinorUnits: $amountMinorUnits, ')
          ..write('currency: $currency, ')
          ..write('billingCycle: $billingCycle, ')
          ..write('nextDueDate: $nextDueDate, ')
          ..write('startDate: $startDate, ')
          ..write('status: $status, ')
          ..write('notes: $notes, ')
          ..write('createdAtMs: $createdAtMs, ')
          ..write('updatedAtMs: $updatedAtMs, ')
          ..write('deletedAtMs: $deletedAtMs, ')
          ..write('version: $version, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PaymentsTable extends Payments
    with TableInfo<$PaymentsTable, PaymentRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PaymentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _billIdMeta = const VerificationMeta('billId');
  @override
  late final GeneratedColumn<String> billId = GeneratedColumn<String>(
    'bill_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES bills (id)',
    ),
  );
  static const VerificationMeta _amountMinorUnitsMeta = const VerificationMeta(
    'amountMinorUnits',
  );
  @override
  late final GeneratedColumn<int> amountMinorUnits = GeneratedColumn<int>(
    'amount_minor_units',
    aliasedName,
    false,
    check: () => ComparableExpr(amountMinorUnits).isBiggerOrEqualValue(0),
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _currencyMeta = const VerificationMeta(
    'currency',
  );
  @override
  late final GeneratedColumn<String> currency = GeneratedColumn<String>(
    'currency',
    aliasedName,
    false,
    check: () => currency.isIn(const ['IDR', 'USD', 'EUR']),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dueDateMeta = const VerificationMeta(
    'dueDate',
  );
  @override
  late final GeneratedColumn<String> dueDate = GeneratedColumn<String>(
    'due_date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _paidAtMsMeta = const VerificationMeta(
    'paidAtMs',
  );
  @override
  late final GeneratedColumn<int> paidAtMs = GeneratedColumn<int>(
    'paid_at_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMsMeta = const VerificationMeta(
    'createdAtMs',
  );
  @override
  late final GeneratedColumn<int> createdAtMs = GeneratedColumn<int>(
    'created_at_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMsMeta = const VerificationMeta(
    'updatedAtMs',
  );
  @override
  late final GeneratedColumn<int> updatedAtMs = GeneratedColumn<int>(
    'updated_at_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMsMeta = const VerificationMeta(
    'deletedAtMs',
  );
  @override
  late final GeneratedColumn<int> deletedAtMs = GeneratedColumn<int>(
    'deleted_at_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    check: () => ComparableExpr(version).isBiggerOrEqualValue(1),
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    billId,
    amountMinorUnits,
    currency,
    dueDate,
    paidAtMs,
    notes,
    createdAtMs,
    updatedAtMs,
    deletedAtMs,
    version,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'payments';
  @override
  VerificationContext validateIntegrity(
    Insertable<PaymentRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('bill_id')) {
      context.handle(
        _billIdMeta,
        billId.isAcceptableOrUnknown(data['bill_id']!, _billIdMeta),
      );
    } else if (isInserting) {
      context.missing(_billIdMeta);
    }
    if (data.containsKey('amount_minor_units')) {
      context.handle(
        _amountMinorUnitsMeta,
        amountMinorUnits.isAcceptableOrUnknown(
          data['amount_minor_units']!,
          _amountMinorUnitsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_amountMinorUnitsMeta);
    }
    if (data.containsKey('currency')) {
      context.handle(
        _currencyMeta,
        currency.isAcceptableOrUnknown(data['currency']!, _currencyMeta),
      );
    } else if (isInserting) {
      context.missing(_currencyMeta);
    }
    if (data.containsKey('due_date')) {
      context.handle(
        _dueDateMeta,
        dueDate.isAcceptableOrUnknown(data['due_date']!, _dueDateMeta),
      );
    } else if (isInserting) {
      context.missing(_dueDateMeta);
    }
    if (data.containsKey('paid_at_ms')) {
      context.handle(
        _paidAtMsMeta,
        paidAtMs.isAcceptableOrUnknown(data['paid_at_ms']!, _paidAtMsMeta),
      );
    } else if (isInserting) {
      context.missing(_paidAtMsMeta);
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('created_at_ms')) {
      context.handle(
        _createdAtMsMeta,
        createdAtMs.isAcceptableOrUnknown(
          data['created_at_ms']!,
          _createdAtMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdAtMsMeta);
    }
    if (data.containsKey('updated_at_ms')) {
      context.handle(
        _updatedAtMsMeta,
        updatedAtMs.isAcceptableOrUnknown(
          data['updated_at_ms']!,
          _updatedAtMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMsMeta);
    }
    if (data.containsKey('deleted_at_ms')) {
      context.handle(
        _deletedAtMsMeta,
        deletedAtMs.isAcceptableOrUnknown(
          data['deleted_at_ms']!,
          _deletedAtMsMeta,
        ),
      );
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    } else if (isInserting) {
      context.missing(_versionMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PaymentRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PaymentRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      billId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}bill_id'],
      )!,
      amountMinorUnits: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}amount_minor_units'],
      )!,
      currency: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}currency'],
      )!,
      dueDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}due_date'],
      )!,
      paidAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}paid_at_ms'],
      )!,
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      createdAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at_ms'],
      )!,
      updatedAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at_ms'],
      )!,
      deletedAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at_ms'],
      ),
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
    );
  }

  @override
  $PaymentsTable createAlias(String alias) {
    return $PaymentsTable(attachedDatabase, alias);
  }
}

class PaymentRow extends DataClass implements Insertable<PaymentRow> {
  final String id;
  final String billId;
  final int amountMinorUnits;
  final String currency;
  final String dueDate;
  final int paidAtMs;
  final String? notes;
  final int createdAtMs;
  final int updatedAtMs;
  final int? deletedAtMs;
  final int version;
  const PaymentRow({
    required this.id,
    required this.billId,
    required this.amountMinorUnits,
    required this.currency,
    required this.dueDate,
    required this.paidAtMs,
    this.notes,
    required this.createdAtMs,
    required this.updatedAtMs,
    this.deletedAtMs,
    required this.version,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['bill_id'] = Variable<String>(billId);
    map['amount_minor_units'] = Variable<int>(amountMinorUnits);
    map['currency'] = Variable<String>(currency);
    map['due_date'] = Variable<String>(dueDate);
    map['paid_at_ms'] = Variable<int>(paidAtMs);
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    map['created_at_ms'] = Variable<int>(createdAtMs);
    map['updated_at_ms'] = Variable<int>(updatedAtMs);
    if (!nullToAbsent || deletedAtMs != null) {
      map['deleted_at_ms'] = Variable<int>(deletedAtMs);
    }
    map['version'] = Variable<int>(version);
    return map;
  }

  PaymentsCompanion toCompanion(bool nullToAbsent) {
    return PaymentsCompanion(
      id: Value(id),
      billId: Value(billId),
      amountMinorUnits: Value(amountMinorUnits),
      currency: Value(currency),
      dueDate: Value(dueDate),
      paidAtMs: Value(paidAtMs),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      createdAtMs: Value(createdAtMs),
      updatedAtMs: Value(updatedAtMs),
      deletedAtMs: deletedAtMs == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAtMs),
      version: Value(version),
    );
  }

  factory PaymentRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PaymentRow(
      id: serializer.fromJson<String>(json['id']),
      billId: serializer.fromJson<String>(json['billId']),
      amountMinorUnits: serializer.fromJson<int>(json['amountMinorUnits']),
      currency: serializer.fromJson<String>(json['currency']),
      dueDate: serializer.fromJson<String>(json['dueDate']),
      paidAtMs: serializer.fromJson<int>(json['paidAtMs']),
      notes: serializer.fromJson<String?>(json['notes']),
      createdAtMs: serializer.fromJson<int>(json['createdAtMs']),
      updatedAtMs: serializer.fromJson<int>(json['updatedAtMs']),
      deletedAtMs: serializer.fromJson<int?>(json['deletedAtMs']),
      version: serializer.fromJson<int>(json['version']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'billId': serializer.toJson<String>(billId),
      'amountMinorUnits': serializer.toJson<int>(amountMinorUnits),
      'currency': serializer.toJson<String>(currency),
      'dueDate': serializer.toJson<String>(dueDate),
      'paidAtMs': serializer.toJson<int>(paidAtMs),
      'notes': serializer.toJson<String?>(notes),
      'createdAtMs': serializer.toJson<int>(createdAtMs),
      'updatedAtMs': serializer.toJson<int>(updatedAtMs),
      'deletedAtMs': serializer.toJson<int?>(deletedAtMs),
      'version': serializer.toJson<int>(version),
    };
  }

  PaymentRow copyWith({
    String? id,
    String? billId,
    int? amountMinorUnits,
    String? currency,
    String? dueDate,
    int? paidAtMs,
    Value<String?> notes = const Value.absent(),
    int? createdAtMs,
    int? updatedAtMs,
    Value<int?> deletedAtMs = const Value.absent(),
    int? version,
  }) => PaymentRow(
    id: id ?? this.id,
    billId: billId ?? this.billId,
    amountMinorUnits: amountMinorUnits ?? this.amountMinorUnits,
    currency: currency ?? this.currency,
    dueDate: dueDate ?? this.dueDate,
    paidAtMs: paidAtMs ?? this.paidAtMs,
    notes: notes.present ? notes.value : this.notes,
    createdAtMs: createdAtMs ?? this.createdAtMs,
    updatedAtMs: updatedAtMs ?? this.updatedAtMs,
    deletedAtMs: deletedAtMs.present ? deletedAtMs.value : this.deletedAtMs,
    version: version ?? this.version,
  );
  PaymentRow copyWithCompanion(PaymentsCompanion data) {
    return PaymentRow(
      id: data.id.present ? data.id.value : this.id,
      billId: data.billId.present ? data.billId.value : this.billId,
      amountMinorUnits: data.amountMinorUnits.present
          ? data.amountMinorUnits.value
          : this.amountMinorUnits,
      currency: data.currency.present ? data.currency.value : this.currency,
      dueDate: data.dueDate.present ? data.dueDate.value : this.dueDate,
      paidAtMs: data.paidAtMs.present ? data.paidAtMs.value : this.paidAtMs,
      notes: data.notes.present ? data.notes.value : this.notes,
      createdAtMs: data.createdAtMs.present
          ? data.createdAtMs.value
          : this.createdAtMs,
      updatedAtMs: data.updatedAtMs.present
          ? data.updatedAtMs.value
          : this.updatedAtMs,
      deletedAtMs: data.deletedAtMs.present
          ? data.deletedAtMs.value
          : this.deletedAtMs,
      version: data.version.present ? data.version.value : this.version,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PaymentRow(')
          ..write('id: $id, ')
          ..write('billId: $billId, ')
          ..write('amountMinorUnits: $amountMinorUnits, ')
          ..write('currency: $currency, ')
          ..write('dueDate: $dueDate, ')
          ..write('paidAtMs: $paidAtMs, ')
          ..write('notes: $notes, ')
          ..write('createdAtMs: $createdAtMs, ')
          ..write('updatedAtMs: $updatedAtMs, ')
          ..write('deletedAtMs: $deletedAtMs, ')
          ..write('version: $version')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    billId,
    amountMinorUnits,
    currency,
    dueDate,
    paidAtMs,
    notes,
    createdAtMs,
    updatedAtMs,
    deletedAtMs,
    version,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PaymentRow &&
          other.id == this.id &&
          other.billId == this.billId &&
          other.amountMinorUnits == this.amountMinorUnits &&
          other.currency == this.currency &&
          other.dueDate == this.dueDate &&
          other.paidAtMs == this.paidAtMs &&
          other.notes == this.notes &&
          other.createdAtMs == this.createdAtMs &&
          other.updatedAtMs == this.updatedAtMs &&
          other.deletedAtMs == this.deletedAtMs &&
          other.version == this.version);
}

class PaymentsCompanion extends UpdateCompanion<PaymentRow> {
  final Value<String> id;
  final Value<String> billId;
  final Value<int> amountMinorUnits;
  final Value<String> currency;
  final Value<String> dueDate;
  final Value<int> paidAtMs;
  final Value<String?> notes;
  final Value<int> createdAtMs;
  final Value<int> updatedAtMs;
  final Value<int?> deletedAtMs;
  final Value<int> version;
  final Value<int> rowid;
  const PaymentsCompanion({
    this.id = const Value.absent(),
    this.billId = const Value.absent(),
    this.amountMinorUnits = const Value.absent(),
    this.currency = const Value.absent(),
    this.dueDate = const Value.absent(),
    this.paidAtMs = const Value.absent(),
    this.notes = const Value.absent(),
    this.createdAtMs = const Value.absent(),
    this.updatedAtMs = const Value.absent(),
    this.deletedAtMs = const Value.absent(),
    this.version = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PaymentsCompanion.insert({
    required String id,
    required String billId,
    required int amountMinorUnits,
    required String currency,
    required String dueDate,
    required int paidAtMs,
    this.notes = const Value.absent(),
    required int createdAtMs,
    required int updatedAtMs,
    this.deletedAtMs = const Value.absent(),
    required int version,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       billId = Value(billId),
       amountMinorUnits = Value(amountMinorUnits),
       currency = Value(currency),
       dueDate = Value(dueDate),
       paidAtMs = Value(paidAtMs),
       createdAtMs = Value(createdAtMs),
       updatedAtMs = Value(updatedAtMs),
       version = Value(version);
  static Insertable<PaymentRow> custom({
    Expression<String>? id,
    Expression<String>? billId,
    Expression<int>? amountMinorUnits,
    Expression<String>? currency,
    Expression<String>? dueDate,
    Expression<int>? paidAtMs,
    Expression<String>? notes,
    Expression<int>? createdAtMs,
    Expression<int>? updatedAtMs,
    Expression<int>? deletedAtMs,
    Expression<int>? version,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (billId != null) 'bill_id': billId,
      if (amountMinorUnits != null) 'amount_minor_units': amountMinorUnits,
      if (currency != null) 'currency': currency,
      if (dueDate != null) 'due_date': dueDate,
      if (paidAtMs != null) 'paid_at_ms': paidAtMs,
      if (notes != null) 'notes': notes,
      if (createdAtMs != null) 'created_at_ms': createdAtMs,
      if (updatedAtMs != null) 'updated_at_ms': updatedAtMs,
      if (deletedAtMs != null) 'deleted_at_ms': deletedAtMs,
      if (version != null) 'version': version,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PaymentsCompanion copyWith({
    Value<String>? id,
    Value<String>? billId,
    Value<int>? amountMinorUnits,
    Value<String>? currency,
    Value<String>? dueDate,
    Value<int>? paidAtMs,
    Value<String?>? notes,
    Value<int>? createdAtMs,
    Value<int>? updatedAtMs,
    Value<int?>? deletedAtMs,
    Value<int>? version,
    Value<int>? rowid,
  }) {
    return PaymentsCompanion(
      id: id ?? this.id,
      billId: billId ?? this.billId,
      amountMinorUnits: amountMinorUnits ?? this.amountMinorUnits,
      currency: currency ?? this.currency,
      dueDate: dueDate ?? this.dueDate,
      paidAtMs: paidAtMs ?? this.paidAtMs,
      notes: notes ?? this.notes,
      createdAtMs: createdAtMs ?? this.createdAtMs,
      updatedAtMs: updatedAtMs ?? this.updatedAtMs,
      deletedAtMs: deletedAtMs ?? this.deletedAtMs,
      version: version ?? this.version,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (billId.present) {
      map['bill_id'] = Variable<String>(billId.value);
    }
    if (amountMinorUnits.present) {
      map['amount_minor_units'] = Variable<int>(amountMinorUnits.value);
    }
    if (currency.present) {
      map['currency'] = Variable<String>(currency.value);
    }
    if (dueDate.present) {
      map['due_date'] = Variable<String>(dueDate.value);
    }
    if (paidAtMs.present) {
      map['paid_at_ms'] = Variable<int>(paidAtMs.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (createdAtMs.present) {
      map['created_at_ms'] = Variable<int>(createdAtMs.value);
    }
    if (updatedAtMs.present) {
      map['updated_at_ms'] = Variable<int>(updatedAtMs.value);
    }
    if (deletedAtMs.present) {
      map['deleted_at_ms'] = Variable<int>(deletedAtMs.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PaymentsCompanion(')
          ..write('id: $id, ')
          ..write('billId: $billId, ')
          ..write('amountMinorUnits: $amountMinorUnits, ')
          ..write('currency: $currency, ')
          ..write('dueDate: $dueDate, ')
          ..write('paidAtMs: $paidAtMs, ')
          ..write('notes: $notes, ')
          ..write('createdAtMs: $createdAtMs, ')
          ..write('updatedAtMs: $updatedAtMs, ')
          ..write('deletedAtMs: $deletedAtMs, ')
          ..write('version: $version, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncOutboxTable extends SyncOutbox
    with TableInfo<$SyncOutboxTable, SyncOutboxRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncOutboxTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _localSequenceMeta = const VerificationMeta(
    'localSequence',
  );
  @override
  late final GeneratedColumn<int> localSequence = GeneratedColumn<int>(
    'local_sequence',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _operationIdMeta = const VerificationMeta(
    'operationId',
  );
  @override
  late final GeneratedColumn<String> operationId = GeneratedColumn<String>(
    'operation_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _entityTypeMeta = const VerificationMeta(
    'entityType',
  );
  @override
  late final GeneratedColumn<String> entityType = GeneratedColumn<String>(
    'entity_type',
    aliasedName,
    false,
    check: () => entityType.isIn(const ['bill', 'payment']),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entityIdMeta = const VerificationMeta(
    'entityId',
  );
  @override
  late final GeneratedColumn<String> entityId = GeneratedColumn<String>(
    'entity_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _operationTypeMeta = const VerificationMeta(
    'operationType',
  );
  @override
  late final GeneratedColumn<String> operationType = GeneratedColumn<String>(
    'operation_type',
    aliasedName,
    false,
    check: () => operationType.isIn(const [
      'bill.create',
      'bill.update',
      'bill.archive',
      'payment.record',
    ]),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _baseVersionMeta = const VerificationMeta(
    'baseVersion',
  );
  @override
  late final GeneratedColumn<int> baseVersion = GeneratedColumn<int>(
    'base_version',
    aliasedName,
    false,
    check: () => ComparableExpr(baseVersion).isBiggerOrEqualValue(0),
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadJsonMeta = const VerificationMeta(
    'payloadJson',
  );
  @override
  late final GeneratedColumn<String> payloadJson = GeneratedColumn<String>(
    'payload_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMsMeta = const VerificationMeta(
    'createdAtMs',
  );
  @override
  late final GeneratedColumn<int> createdAtMs = GeneratedColumn<int>(
    'created_at_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    localSequence,
    operationId,
    entityType,
    entityId,
    operationType,
    baseVersion,
    payloadJson,
    createdAtMs,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_outbox';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncOutboxRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('local_sequence')) {
      context.handle(
        _localSequenceMeta,
        localSequence.isAcceptableOrUnknown(
          data['local_sequence']!,
          _localSequenceMeta,
        ),
      );
    }
    if (data.containsKey('operation_id')) {
      context.handle(
        _operationIdMeta,
        operationId.isAcceptableOrUnknown(
          data['operation_id']!,
          _operationIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_operationIdMeta);
    }
    if (data.containsKey('entity_type')) {
      context.handle(
        _entityTypeMeta,
        entityType.isAcceptableOrUnknown(data['entity_type']!, _entityTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_entityTypeMeta);
    }
    if (data.containsKey('entity_id')) {
      context.handle(
        _entityIdMeta,
        entityId.isAcceptableOrUnknown(data['entity_id']!, _entityIdMeta),
      );
    } else if (isInserting) {
      context.missing(_entityIdMeta);
    }
    if (data.containsKey('operation_type')) {
      context.handle(
        _operationTypeMeta,
        operationType.isAcceptableOrUnknown(
          data['operation_type']!,
          _operationTypeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_operationTypeMeta);
    }
    if (data.containsKey('base_version')) {
      context.handle(
        _baseVersionMeta,
        baseVersion.isAcceptableOrUnknown(
          data['base_version']!,
          _baseVersionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_baseVersionMeta);
    }
    if (data.containsKey('payload_json')) {
      context.handle(
        _payloadJsonMeta,
        payloadJson.isAcceptableOrUnknown(
          data['payload_json']!,
          _payloadJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_payloadJsonMeta);
    }
    if (data.containsKey('created_at_ms')) {
      context.handle(
        _createdAtMsMeta,
        createdAtMs.isAcceptableOrUnknown(
          data['created_at_ms']!,
          _createdAtMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdAtMsMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {localSequence};
  @override
  SyncOutboxRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncOutboxRow(
      localSequence: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}local_sequence'],
      )!,
      operationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}operation_id'],
      )!,
      entityType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_type'],
      )!,
      entityId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_id'],
      )!,
      operationType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}operation_type'],
      )!,
      baseVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}base_version'],
      )!,
      payloadJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload_json'],
      )!,
      createdAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at_ms'],
      )!,
    );
  }

  @override
  $SyncOutboxTable createAlias(String alias) {
    return $SyncOutboxTable(attachedDatabase, alias);
  }
}

class SyncOutboxRow extends DataClass implements Insertable<SyncOutboxRow> {
  final int localSequence;
  final String operationId;
  final String entityType;
  final String entityId;
  final String operationType;
  final int baseVersion;
  final String payloadJson;
  final int createdAtMs;
  const SyncOutboxRow({
    required this.localSequence,
    required this.operationId,
    required this.entityType,
    required this.entityId,
    required this.operationType,
    required this.baseVersion,
    required this.payloadJson,
    required this.createdAtMs,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['local_sequence'] = Variable<int>(localSequence);
    map['operation_id'] = Variable<String>(operationId);
    map['entity_type'] = Variable<String>(entityType);
    map['entity_id'] = Variable<String>(entityId);
    map['operation_type'] = Variable<String>(operationType);
    map['base_version'] = Variable<int>(baseVersion);
    map['payload_json'] = Variable<String>(payloadJson);
    map['created_at_ms'] = Variable<int>(createdAtMs);
    return map;
  }

  SyncOutboxCompanion toCompanion(bool nullToAbsent) {
    return SyncOutboxCompanion(
      localSequence: Value(localSequence),
      operationId: Value(operationId),
      entityType: Value(entityType),
      entityId: Value(entityId),
      operationType: Value(operationType),
      baseVersion: Value(baseVersion),
      payloadJson: Value(payloadJson),
      createdAtMs: Value(createdAtMs),
    );
  }

  factory SyncOutboxRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncOutboxRow(
      localSequence: serializer.fromJson<int>(json['localSequence']),
      operationId: serializer.fromJson<String>(json['operationId']),
      entityType: serializer.fromJson<String>(json['entityType']),
      entityId: serializer.fromJson<String>(json['entityId']),
      operationType: serializer.fromJson<String>(json['operationType']),
      baseVersion: serializer.fromJson<int>(json['baseVersion']),
      payloadJson: serializer.fromJson<String>(json['payloadJson']),
      createdAtMs: serializer.fromJson<int>(json['createdAtMs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'localSequence': serializer.toJson<int>(localSequence),
      'operationId': serializer.toJson<String>(operationId),
      'entityType': serializer.toJson<String>(entityType),
      'entityId': serializer.toJson<String>(entityId),
      'operationType': serializer.toJson<String>(operationType),
      'baseVersion': serializer.toJson<int>(baseVersion),
      'payloadJson': serializer.toJson<String>(payloadJson),
      'createdAtMs': serializer.toJson<int>(createdAtMs),
    };
  }

  SyncOutboxRow copyWith({
    int? localSequence,
    String? operationId,
    String? entityType,
    String? entityId,
    String? operationType,
    int? baseVersion,
    String? payloadJson,
    int? createdAtMs,
  }) => SyncOutboxRow(
    localSequence: localSequence ?? this.localSequence,
    operationId: operationId ?? this.operationId,
    entityType: entityType ?? this.entityType,
    entityId: entityId ?? this.entityId,
    operationType: operationType ?? this.operationType,
    baseVersion: baseVersion ?? this.baseVersion,
    payloadJson: payloadJson ?? this.payloadJson,
    createdAtMs: createdAtMs ?? this.createdAtMs,
  );
  SyncOutboxRow copyWithCompanion(SyncOutboxCompanion data) {
    return SyncOutboxRow(
      localSequence: data.localSequence.present
          ? data.localSequence.value
          : this.localSequence,
      operationId: data.operationId.present
          ? data.operationId.value
          : this.operationId,
      entityType: data.entityType.present
          ? data.entityType.value
          : this.entityType,
      entityId: data.entityId.present ? data.entityId.value : this.entityId,
      operationType: data.operationType.present
          ? data.operationType.value
          : this.operationType,
      baseVersion: data.baseVersion.present
          ? data.baseVersion.value
          : this.baseVersion,
      payloadJson: data.payloadJson.present
          ? data.payloadJson.value
          : this.payloadJson,
      createdAtMs: data.createdAtMs.present
          ? data.createdAtMs.value
          : this.createdAtMs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncOutboxRow(')
          ..write('localSequence: $localSequence, ')
          ..write('operationId: $operationId, ')
          ..write('entityType: $entityType, ')
          ..write('entityId: $entityId, ')
          ..write('operationType: $operationType, ')
          ..write('baseVersion: $baseVersion, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('createdAtMs: $createdAtMs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    localSequence,
    operationId,
    entityType,
    entityId,
    operationType,
    baseVersion,
    payloadJson,
    createdAtMs,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncOutboxRow &&
          other.localSequence == this.localSequence &&
          other.operationId == this.operationId &&
          other.entityType == this.entityType &&
          other.entityId == this.entityId &&
          other.operationType == this.operationType &&
          other.baseVersion == this.baseVersion &&
          other.payloadJson == this.payloadJson &&
          other.createdAtMs == this.createdAtMs);
}

class SyncOutboxCompanion extends UpdateCompanion<SyncOutboxRow> {
  final Value<int> localSequence;
  final Value<String> operationId;
  final Value<String> entityType;
  final Value<String> entityId;
  final Value<String> operationType;
  final Value<int> baseVersion;
  final Value<String> payloadJson;
  final Value<int> createdAtMs;
  const SyncOutboxCompanion({
    this.localSequence = const Value.absent(),
    this.operationId = const Value.absent(),
    this.entityType = const Value.absent(),
    this.entityId = const Value.absent(),
    this.operationType = const Value.absent(),
    this.baseVersion = const Value.absent(),
    this.payloadJson = const Value.absent(),
    this.createdAtMs = const Value.absent(),
  });
  SyncOutboxCompanion.insert({
    this.localSequence = const Value.absent(),
    required String operationId,
    required String entityType,
    required String entityId,
    required String operationType,
    required int baseVersion,
    required String payloadJson,
    required int createdAtMs,
  }) : operationId = Value(operationId),
       entityType = Value(entityType),
       entityId = Value(entityId),
       operationType = Value(operationType),
       baseVersion = Value(baseVersion),
       payloadJson = Value(payloadJson),
       createdAtMs = Value(createdAtMs);
  static Insertable<SyncOutboxRow> custom({
    Expression<int>? localSequence,
    Expression<String>? operationId,
    Expression<String>? entityType,
    Expression<String>? entityId,
    Expression<String>? operationType,
    Expression<int>? baseVersion,
    Expression<String>? payloadJson,
    Expression<int>? createdAtMs,
  }) {
    return RawValuesInsertable({
      if (localSequence != null) 'local_sequence': localSequence,
      if (operationId != null) 'operation_id': operationId,
      if (entityType != null) 'entity_type': entityType,
      if (entityId != null) 'entity_id': entityId,
      if (operationType != null) 'operation_type': operationType,
      if (baseVersion != null) 'base_version': baseVersion,
      if (payloadJson != null) 'payload_json': payloadJson,
      if (createdAtMs != null) 'created_at_ms': createdAtMs,
    });
  }

  SyncOutboxCompanion copyWith({
    Value<int>? localSequence,
    Value<String>? operationId,
    Value<String>? entityType,
    Value<String>? entityId,
    Value<String>? operationType,
    Value<int>? baseVersion,
    Value<String>? payloadJson,
    Value<int>? createdAtMs,
  }) {
    return SyncOutboxCompanion(
      localSequence: localSequence ?? this.localSequence,
      operationId: operationId ?? this.operationId,
      entityType: entityType ?? this.entityType,
      entityId: entityId ?? this.entityId,
      operationType: operationType ?? this.operationType,
      baseVersion: baseVersion ?? this.baseVersion,
      payloadJson: payloadJson ?? this.payloadJson,
      createdAtMs: createdAtMs ?? this.createdAtMs,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (localSequence.present) {
      map['local_sequence'] = Variable<int>(localSequence.value);
    }
    if (operationId.present) {
      map['operation_id'] = Variable<String>(operationId.value);
    }
    if (entityType.present) {
      map['entity_type'] = Variable<String>(entityType.value);
    }
    if (entityId.present) {
      map['entity_id'] = Variable<String>(entityId.value);
    }
    if (operationType.present) {
      map['operation_type'] = Variable<String>(operationType.value);
    }
    if (baseVersion.present) {
      map['base_version'] = Variable<int>(baseVersion.value);
    }
    if (payloadJson.present) {
      map['payload_json'] = Variable<String>(payloadJson.value);
    }
    if (createdAtMs.present) {
      map['created_at_ms'] = Variable<int>(createdAtMs.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncOutboxCompanion(')
          ..write('localSequence: $localSequence, ')
          ..write('operationId: $operationId, ')
          ..write('entityType: $entityType, ')
          ..write('entityId: $entityId, ')
          ..write('operationType: $operationType, ')
          ..write('baseVersion: $baseVersion, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('createdAtMs: $createdAtMs')
          ..write(')'))
        .toString();
  }
}

class $SyncStatesTable extends SyncStates
    with TableInfo<$SyncStatesTable, SyncStateRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncStatesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    check: () => id.equals(1),
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastPulledSequenceMeta =
      const VerificationMeta('lastPulledSequence');
  @override
  late final GeneratedColumn<int> lastPulledSequence = GeneratedColumn<int>(
    'last_pulled_sequence',
    aliasedName,
    false,
    check: () => ComparableExpr(lastPulledSequence).isBiggerOrEqualValue(0),
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _createdAtMsMeta = const VerificationMeta(
    'createdAtMs',
  );
  @override
  late final GeneratedColumn<int> createdAtMs = GeneratedColumn<int>(
    'created_at_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bootstrapIdMeta = const VerificationMeta(
    'bootstrapId',
  );
  @override
  late final GeneratedColumn<String> bootstrapId = GeneratedColumn<String>(
    'bootstrap_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _bootstrapPayloadJsonMeta =
      const VerificationMeta('bootstrapPayloadJson');
  @override
  late final GeneratedColumn<String> bootstrapPayloadJson =
      GeneratedColumn<String>(
        'bootstrap_payload_json',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _bootstrapOutboxSequenceMeta =
      const VerificationMeta('bootstrapOutboxSequence');
  @override
  late final GeneratedColumn<int> bootstrapOutboxSequence =
      GeneratedColumn<int>(
        'bootstrap_outbox_sequence',
        aliasedName,
        true,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _bootstrapCreatedAtMsMeta =
      const VerificationMeta('bootstrapCreatedAtMs');
  @override
  late final GeneratedColumn<int> bootstrapCreatedAtMs = GeneratedColumn<int>(
    'bootstrap_created_at_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _bootstrapCompletedAtMsMeta =
      const VerificationMeta('bootstrapCompletedAtMs');
  @override
  late final GeneratedColumn<int> bootstrapCompletedAtMs = GeneratedColumn<int>(
    'bootstrap_completed_at_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    deviceId,
    lastPulledSequence,
    createdAtMs,
    bootstrapId,
    bootstrapPayloadJson,
    bootstrapOutboxSequence,
    bootstrapCreatedAtMs,
    bootstrapCompletedAtMs,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_state';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncStateRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    if (data.containsKey('last_pulled_sequence')) {
      context.handle(
        _lastPulledSequenceMeta,
        lastPulledSequence.isAcceptableOrUnknown(
          data['last_pulled_sequence']!,
          _lastPulledSequenceMeta,
        ),
      );
    }
    if (data.containsKey('created_at_ms')) {
      context.handle(
        _createdAtMsMeta,
        createdAtMs.isAcceptableOrUnknown(
          data['created_at_ms']!,
          _createdAtMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdAtMsMeta);
    }
    if (data.containsKey('bootstrap_id')) {
      context.handle(
        _bootstrapIdMeta,
        bootstrapId.isAcceptableOrUnknown(
          data['bootstrap_id']!,
          _bootstrapIdMeta,
        ),
      );
    }
    if (data.containsKey('bootstrap_payload_json')) {
      context.handle(
        _bootstrapPayloadJsonMeta,
        bootstrapPayloadJson.isAcceptableOrUnknown(
          data['bootstrap_payload_json']!,
          _bootstrapPayloadJsonMeta,
        ),
      );
    }
    if (data.containsKey('bootstrap_outbox_sequence')) {
      context.handle(
        _bootstrapOutboxSequenceMeta,
        bootstrapOutboxSequence.isAcceptableOrUnknown(
          data['bootstrap_outbox_sequence']!,
          _bootstrapOutboxSequenceMeta,
        ),
      );
    }
    if (data.containsKey('bootstrap_created_at_ms')) {
      context.handle(
        _bootstrapCreatedAtMsMeta,
        bootstrapCreatedAtMs.isAcceptableOrUnknown(
          data['bootstrap_created_at_ms']!,
          _bootstrapCreatedAtMsMeta,
        ),
      );
    }
    if (data.containsKey('bootstrap_completed_at_ms')) {
      context.handle(
        _bootstrapCompletedAtMsMeta,
        bootstrapCompletedAtMs.isAcceptableOrUnknown(
          data['bootstrap_completed_at_ms']!,
          _bootstrapCompletedAtMsMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SyncStateRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncStateRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      )!,
      lastPulledSequence: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_pulled_sequence'],
      )!,
      createdAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at_ms'],
      )!,
      bootstrapId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}bootstrap_id'],
      ),
      bootstrapPayloadJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}bootstrap_payload_json'],
      ),
      bootstrapOutboxSequence: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}bootstrap_outbox_sequence'],
      ),
      bootstrapCreatedAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}bootstrap_created_at_ms'],
      ),
      bootstrapCompletedAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}bootstrap_completed_at_ms'],
      ),
    );
  }

  @override
  $SyncStatesTable createAlias(String alias) {
    return $SyncStatesTable(attachedDatabase, alias);
  }
}

class SyncStateRow extends DataClass implements Insertable<SyncStateRow> {
  final int id;
  final String deviceId;
  final int lastPulledSequence;
  final int createdAtMs;
  final String? bootstrapId;
  final String? bootstrapPayloadJson;
  final int? bootstrapOutboxSequence;
  final int? bootstrapCreatedAtMs;
  final int? bootstrapCompletedAtMs;
  const SyncStateRow({
    required this.id,
    required this.deviceId,
    required this.lastPulledSequence,
    required this.createdAtMs,
    this.bootstrapId,
    this.bootstrapPayloadJson,
    this.bootstrapOutboxSequence,
    this.bootstrapCreatedAtMs,
    this.bootstrapCompletedAtMs,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['device_id'] = Variable<String>(deviceId);
    map['last_pulled_sequence'] = Variable<int>(lastPulledSequence);
    map['created_at_ms'] = Variable<int>(createdAtMs);
    if (!nullToAbsent || bootstrapId != null) {
      map['bootstrap_id'] = Variable<String>(bootstrapId);
    }
    if (!nullToAbsent || bootstrapPayloadJson != null) {
      map['bootstrap_payload_json'] = Variable<String>(bootstrapPayloadJson);
    }
    if (!nullToAbsent || bootstrapOutboxSequence != null) {
      map['bootstrap_outbox_sequence'] = Variable<int>(bootstrapOutboxSequence);
    }
    if (!nullToAbsent || bootstrapCreatedAtMs != null) {
      map['bootstrap_created_at_ms'] = Variable<int>(bootstrapCreatedAtMs);
    }
    if (!nullToAbsent || bootstrapCompletedAtMs != null) {
      map['bootstrap_completed_at_ms'] = Variable<int>(bootstrapCompletedAtMs);
    }
    return map;
  }

  SyncStatesCompanion toCompanion(bool nullToAbsent) {
    return SyncStatesCompanion(
      id: Value(id),
      deviceId: Value(deviceId),
      lastPulledSequence: Value(lastPulledSequence),
      createdAtMs: Value(createdAtMs),
      bootstrapId: bootstrapId == null && nullToAbsent
          ? const Value.absent()
          : Value(bootstrapId),
      bootstrapPayloadJson: bootstrapPayloadJson == null && nullToAbsent
          ? const Value.absent()
          : Value(bootstrapPayloadJson),
      bootstrapOutboxSequence: bootstrapOutboxSequence == null && nullToAbsent
          ? const Value.absent()
          : Value(bootstrapOutboxSequence),
      bootstrapCreatedAtMs: bootstrapCreatedAtMs == null && nullToAbsent
          ? const Value.absent()
          : Value(bootstrapCreatedAtMs),
      bootstrapCompletedAtMs: bootstrapCompletedAtMs == null && nullToAbsent
          ? const Value.absent()
          : Value(bootstrapCompletedAtMs),
    );
  }

  factory SyncStateRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncStateRow(
      id: serializer.fromJson<int>(json['id']),
      deviceId: serializer.fromJson<String>(json['deviceId']),
      lastPulledSequence: serializer.fromJson<int>(json['lastPulledSequence']),
      createdAtMs: serializer.fromJson<int>(json['createdAtMs']),
      bootstrapId: serializer.fromJson<String?>(json['bootstrapId']),
      bootstrapPayloadJson: serializer.fromJson<String?>(
        json['bootstrapPayloadJson'],
      ),
      bootstrapOutboxSequence: serializer.fromJson<int?>(
        json['bootstrapOutboxSequence'],
      ),
      bootstrapCreatedAtMs: serializer.fromJson<int?>(
        json['bootstrapCreatedAtMs'],
      ),
      bootstrapCompletedAtMs: serializer.fromJson<int?>(
        json['bootstrapCompletedAtMs'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'deviceId': serializer.toJson<String>(deviceId),
      'lastPulledSequence': serializer.toJson<int>(lastPulledSequence),
      'createdAtMs': serializer.toJson<int>(createdAtMs),
      'bootstrapId': serializer.toJson<String?>(bootstrapId),
      'bootstrapPayloadJson': serializer.toJson<String?>(bootstrapPayloadJson),
      'bootstrapOutboxSequence': serializer.toJson<int?>(
        bootstrapOutboxSequence,
      ),
      'bootstrapCreatedAtMs': serializer.toJson<int?>(bootstrapCreatedAtMs),
      'bootstrapCompletedAtMs': serializer.toJson<int?>(bootstrapCompletedAtMs),
    };
  }

  SyncStateRow copyWith({
    int? id,
    String? deviceId,
    int? lastPulledSequence,
    int? createdAtMs,
    Value<String?> bootstrapId = const Value.absent(),
    Value<String?> bootstrapPayloadJson = const Value.absent(),
    Value<int?> bootstrapOutboxSequence = const Value.absent(),
    Value<int?> bootstrapCreatedAtMs = const Value.absent(),
    Value<int?> bootstrapCompletedAtMs = const Value.absent(),
  }) => SyncStateRow(
    id: id ?? this.id,
    deviceId: deviceId ?? this.deviceId,
    lastPulledSequence: lastPulledSequence ?? this.lastPulledSequence,
    createdAtMs: createdAtMs ?? this.createdAtMs,
    bootstrapId: bootstrapId.present ? bootstrapId.value : this.bootstrapId,
    bootstrapPayloadJson: bootstrapPayloadJson.present
        ? bootstrapPayloadJson.value
        : this.bootstrapPayloadJson,
    bootstrapOutboxSequence: bootstrapOutboxSequence.present
        ? bootstrapOutboxSequence.value
        : this.bootstrapOutboxSequence,
    bootstrapCreatedAtMs: bootstrapCreatedAtMs.present
        ? bootstrapCreatedAtMs.value
        : this.bootstrapCreatedAtMs,
    bootstrapCompletedAtMs: bootstrapCompletedAtMs.present
        ? bootstrapCompletedAtMs.value
        : this.bootstrapCompletedAtMs,
  );
  SyncStateRow copyWithCompanion(SyncStatesCompanion data) {
    return SyncStateRow(
      id: data.id.present ? data.id.value : this.id,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      lastPulledSequence: data.lastPulledSequence.present
          ? data.lastPulledSequence.value
          : this.lastPulledSequence,
      createdAtMs: data.createdAtMs.present
          ? data.createdAtMs.value
          : this.createdAtMs,
      bootstrapId: data.bootstrapId.present
          ? data.bootstrapId.value
          : this.bootstrapId,
      bootstrapPayloadJson: data.bootstrapPayloadJson.present
          ? data.bootstrapPayloadJson.value
          : this.bootstrapPayloadJson,
      bootstrapOutboxSequence: data.bootstrapOutboxSequence.present
          ? data.bootstrapOutboxSequence.value
          : this.bootstrapOutboxSequence,
      bootstrapCreatedAtMs: data.bootstrapCreatedAtMs.present
          ? data.bootstrapCreatedAtMs.value
          : this.bootstrapCreatedAtMs,
      bootstrapCompletedAtMs: data.bootstrapCompletedAtMs.present
          ? data.bootstrapCompletedAtMs.value
          : this.bootstrapCompletedAtMs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncStateRow(')
          ..write('id: $id, ')
          ..write('deviceId: $deviceId, ')
          ..write('lastPulledSequence: $lastPulledSequence, ')
          ..write('createdAtMs: $createdAtMs, ')
          ..write('bootstrapId: $bootstrapId, ')
          ..write('bootstrapPayloadJson: $bootstrapPayloadJson, ')
          ..write('bootstrapOutboxSequence: $bootstrapOutboxSequence, ')
          ..write('bootstrapCreatedAtMs: $bootstrapCreatedAtMs, ')
          ..write('bootstrapCompletedAtMs: $bootstrapCompletedAtMs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    deviceId,
    lastPulledSequence,
    createdAtMs,
    bootstrapId,
    bootstrapPayloadJson,
    bootstrapOutboxSequence,
    bootstrapCreatedAtMs,
    bootstrapCompletedAtMs,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncStateRow &&
          other.id == this.id &&
          other.deviceId == this.deviceId &&
          other.lastPulledSequence == this.lastPulledSequence &&
          other.createdAtMs == this.createdAtMs &&
          other.bootstrapId == this.bootstrapId &&
          other.bootstrapPayloadJson == this.bootstrapPayloadJson &&
          other.bootstrapOutboxSequence == this.bootstrapOutboxSequence &&
          other.bootstrapCreatedAtMs == this.bootstrapCreatedAtMs &&
          other.bootstrapCompletedAtMs == this.bootstrapCompletedAtMs);
}

class SyncStatesCompanion extends UpdateCompanion<SyncStateRow> {
  final Value<int> id;
  final Value<String> deviceId;
  final Value<int> lastPulledSequence;
  final Value<int> createdAtMs;
  final Value<String?> bootstrapId;
  final Value<String?> bootstrapPayloadJson;
  final Value<int?> bootstrapOutboxSequence;
  final Value<int?> bootstrapCreatedAtMs;
  final Value<int?> bootstrapCompletedAtMs;
  const SyncStatesCompanion({
    this.id = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.lastPulledSequence = const Value.absent(),
    this.createdAtMs = const Value.absent(),
    this.bootstrapId = const Value.absent(),
    this.bootstrapPayloadJson = const Value.absent(),
    this.bootstrapOutboxSequence = const Value.absent(),
    this.bootstrapCreatedAtMs = const Value.absent(),
    this.bootstrapCompletedAtMs = const Value.absent(),
  });
  SyncStatesCompanion.insert({
    this.id = const Value.absent(),
    required String deviceId,
    this.lastPulledSequence = const Value.absent(),
    required int createdAtMs,
    this.bootstrapId = const Value.absent(),
    this.bootstrapPayloadJson = const Value.absent(),
    this.bootstrapOutboxSequence = const Value.absent(),
    this.bootstrapCreatedAtMs = const Value.absent(),
    this.bootstrapCompletedAtMs = const Value.absent(),
  }) : deviceId = Value(deviceId),
       createdAtMs = Value(createdAtMs);
  static Insertable<SyncStateRow> custom({
    Expression<int>? id,
    Expression<String>? deviceId,
    Expression<int>? lastPulledSequence,
    Expression<int>? createdAtMs,
    Expression<String>? bootstrapId,
    Expression<String>? bootstrapPayloadJson,
    Expression<int>? bootstrapOutboxSequence,
    Expression<int>? bootstrapCreatedAtMs,
    Expression<int>? bootstrapCompletedAtMs,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (deviceId != null) 'device_id': deviceId,
      if (lastPulledSequence != null)
        'last_pulled_sequence': lastPulledSequence,
      if (createdAtMs != null) 'created_at_ms': createdAtMs,
      if (bootstrapId != null) 'bootstrap_id': bootstrapId,
      if (bootstrapPayloadJson != null)
        'bootstrap_payload_json': bootstrapPayloadJson,
      if (bootstrapOutboxSequence != null)
        'bootstrap_outbox_sequence': bootstrapOutboxSequence,
      if (bootstrapCreatedAtMs != null)
        'bootstrap_created_at_ms': bootstrapCreatedAtMs,
      if (bootstrapCompletedAtMs != null)
        'bootstrap_completed_at_ms': bootstrapCompletedAtMs,
    });
  }

  SyncStatesCompanion copyWith({
    Value<int>? id,
    Value<String>? deviceId,
    Value<int>? lastPulledSequence,
    Value<int>? createdAtMs,
    Value<String?>? bootstrapId,
    Value<String?>? bootstrapPayloadJson,
    Value<int?>? bootstrapOutboxSequence,
    Value<int?>? bootstrapCreatedAtMs,
    Value<int?>? bootstrapCompletedAtMs,
  }) {
    return SyncStatesCompanion(
      id: id ?? this.id,
      deviceId: deviceId ?? this.deviceId,
      lastPulledSequence: lastPulledSequence ?? this.lastPulledSequence,
      createdAtMs: createdAtMs ?? this.createdAtMs,
      bootstrapId: bootstrapId ?? this.bootstrapId,
      bootstrapPayloadJson: bootstrapPayloadJson ?? this.bootstrapPayloadJson,
      bootstrapOutboxSequence:
          bootstrapOutboxSequence ?? this.bootstrapOutboxSequence,
      bootstrapCreatedAtMs: bootstrapCreatedAtMs ?? this.bootstrapCreatedAtMs,
      bootstrapCompletedAtMs:
          bootstrapCompletedAtMs ?? this.bootstrapCompletedAtMs,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (lastPulledSequence.present) {
      map['last_pulled_sequence'] = Variable<int>(lastPulledSequence.value);
    }
    if (createdAtMs.present) {
      map['created_at_ms'] = Variable<int>(createdAtMs.value);
    }
    if (bootstrapId.present) {
      map['bootstrap_id'] = Variable<String>(bootstrapId.value);
    }
    if (bootstrapPayloadJson.present) {
      map['bootstrap_payload_json'] = Variable<String>(
        bootstrapPayloadJson.value,
      );
    }
    if (bootstrapOutboxSequence.present) {
      map['bootstrap_outbox_sequence'] = Variable<int>(
        bootstrapOutboxSequence.value,
      );
    }
    if (bootstrapCreatedAtMs.present) {
      map['bootstrap_created_at_ms'] = Variable<int>(
        bootstrapCreatedAtMs.value,
      );
    }
    if (bootstrapCompletedAtMs.present) {
      map['bootstrap_completed_at_ms'] = Variable<int>(
        bootstrapCompletedAtMs.value,
      );
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncStatesCompanion(')
          ..write('id: $id, ')
          ..write('deviceId: $deviceId, ')
          ..write('lastPulledSequence: $lastPulledSequence, ')
          ..write('createdAtMs: $createdAtMs, ')
          ..write('bootstrapId: $bootstrapId, ')
          ..write('bootstrapPayloadJson: $bootstrapPayloadJson, ')
          ..write('bootstrapOutboxSequence: $bootstrapOutboxSequence, ')
          ..write('bootstrapCreatedAtMs: $bootstrapCreatedAtMs, ')
          ..write('bootstrapCompletedAtMs: $bootstrapCompletedAtMs')
          ..write(')'))
        .toString();
  }
}

class $AppliedOperationsTable extends AppliedOperations
    with TableInfo<$AppliedOperationsTable, AppliedOperationRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppliedOperationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _operationIdMeta = const VerificationMeta(
    'operationId',
  );
  @override
  late final GeneratedColumn<String> operationId = GeneratedColumn<String>(
    'operation_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _serverSequenceMeta = const VerificationMeta(
    'serverSequence',
  );
  @override
  late final GeneratedColumn<int> serverSequence = GeneratedColumn<int>(
    'server_sequence',
    aliasedName,
    false,
    check: () => ComparableExpr(serverSequence).isBiggerOrEqualValue(1),
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _entityTypeMeta = const VerificationMeta(
    'entityType',
  );
  @override
  late final GeneratedColumn<String> entityType = GeneratedColumn<String>(
    'entity_type',
    aliasedName,
    false,
    check: () => entityType.isIn(const ['bill', 'payment']),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entityIdMeta = const VerificationMeta(
    'entityId',
  );
  @override
  late final GeneratedColumn<String> entityId = GeneratedColumn<String>(
    'entity_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    check: () => ComparableExpr(version).isBiggerOrEqualValue(1),
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _appliedAtMsMeta = const VerificationMeta(
    'appliedAtMs',
  );
  @override
  late final GeneratedColumn<int> appliedAtMs = GeneratedColumn<int>(
    'applied_at_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    operationId,
    serverSequence,
    entityType,
    entityId,
    version,
    appliedAtMs,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'applied_operations';
  @override
  VerificationContext validateIntegrity(
    Insertable<AppliedOperationRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('operation_id')) {
      context.handle(
        _operationIdMeta,
        operationId.isAcceptableOrUnknown(
          data['operation_id']!,
          _operationIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_operationIdMeta);
    }
    if (data.containsKey('server_sequence')) {
      context.handle(
        _serverSequenceMeta,
        serverSequence.isAcceptableOrUnknown(
          data['server_sequence']!,
          _serverSequenceMeta,
        ),
      );
    }
    if (data.containsKey('entity_type')) {
      context.handle(
        _entityTypeMeta,
        entityType.isAcceptableOrUnknown(data['entity_type']!, _entityTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_entityTypeMeta);
    }
    if (data.containsKey('entity_id')) {
      context.handle(
        _entityIdMeta,
        entityId.isAcceptableOrUnknown(data['entity_id']!, _entityIdMeta),
      );
    } else if (isInserting) {
      context.missing(_entityIdMeta);
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    } else if (isInserting) {
      context.missing(_versionMeta);
    }
    if (data.containsKey('applied_at_ms')) {
      context.handle(
        _appliedAtMsMeta,
        appliedAtMs.isAcceptableOrUnknown(
          data['applied_at_ms']!,
          _appliedAtMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_appliedAtMsMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {serverSequence};
  @override
  AppliedOperationRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppliedOperationRow(
      operationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}operation_id'],
      )!,
      serverSequence: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}server_sequence'],
      )!,
      entityType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_type'],
      )!,
      entityId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_id'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
      appliedAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}applied_at_ms'],
      )!,
    );
  }

  @override
  $AppliedOperationsTable createAlias(String alias) {
    return $AppliedOperationsTable(attachedDatabase, alias);
  }
}

class AppliedOperationRow extends DataClass
    implements Insertable<AppliedOperationRow> {
  final String operationId;
  final int serverSequence;
  final String entityType;
  final String entityId;
  final int version;
  final int appliedAtMs;
  const AppliedOperationRow({
    required this.operationId,
    required this.serverSequence,
    required this.entityType,
    required this.entityId,
    required this.version,
    required this.appliedAtMs,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['operation_id'] = Variable<String>(operationId);
    map['server_sequence'] = Variable<int>(serverSequence);
    map['entity_type'] = Variable<String>(entityType);
    map['entity_id'] = Variable<String>(entityId);
    map['version'] = Variable<int>(version);
    map['applied_at_ms'] = Variable<int>(appliedAtMs);
    return map;
  }

  AppliedOperationsCompanion toCompanion(bool nullToAbsent) {
    return AppliedOperationsCompanion(
      operationId: Value(operationId),
      serverSequence: Value(serverSequence),
      entityType: Value(entityType),
      entityId: Value(entityId),
      version: Value(version),
      appliedAtMs: Value(appliedAtMs),
    );
  }

  factory AppliedOperationRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AppliedOperationRow(
      operationId: serializer.fromJson<String>(json['operationId']),
      serverSequence: serializer.fromJson<int>(json['serverSequence']),
      entityType: serializer.fromJson<String>(json['entityType']),
      entityId: serializer.fromJson<String>(json['entityId']),
      version: serializer.fromJson<int>(json['version']),
      appliedAtMs: serializer.fromJson<int>(json['appliedAtMs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'operationId': serializer.toJson<String>(operationId),
      'serverSequence': serializer.toJson<int>(serverSequence),
      'entityType': serializer.toJson<String>(entityType),
      'entityId': serializer.toJson<String>(entityId),
      'version': serializer.toJson<int>(version),
      'appliedAtMs': serializer.toJson<int>(appliedAtMs),
    };
  }

  AppliedOperationRow copyWith({
    String? operationId,
    int? serverSequence,
    String? entityType,
    String? entityId,
    int? version,
    int? appliedAtMs,
  }) => AppliedOperationRow(
    operationId: operationId ?? this.operationId,
    serverSequence: serverSequence ?? this.serverSequence,
    entityType: entityType ?? this.entityType,
    entityId: entityId ?? this.entityId,
    version: version ?? this.version,
    appliedAtMs: appliedAtMs ?? this.appliedAtMs,
  );
  AppliedOperationRow copyWithCompanion(AppliedOperationsCompanion data) {
    return AppliedOperationRow(
      operationId: data.operationId.present
          ? data.operationId.value
          : this.operationId,
      serverSequence: data.serverSequence.present
          ? data.serverSequence.value
          : this.serverSequence,
      entityType: data.entityType.present
          ? data.entityType.value
          : this.entityType,
      entityId: data.entityId.present ? data.entityId.value : this.entityId,
      version: data.version.present ? data.version.value : this.version,
      appliedAtMs: data.appliedAtMs.present
          ? data.appliedAtMs.value
          : this.appliedAtMs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AppliedOperationRow(')
          ..write('operationId: $operationId, ')
          ..write('serverSequence: $serverSequence, ')
          ..write('entityType: $entityType, ')
          ..write('entityId: $entityId, ')
          ..write('version: $version, ')
          ..write('appliedAtMs: $appliedAtMs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    operationId,
    serverSequence,
    entityType,
    entityId,
    version,
    appliedAtMs,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppliedOperationRow &&
          other.operationId == this.operationId &&
          other.serverSequence == this.serverSequence &&
          other.entityType == this.entityType &&
          other.entityId == this.entityId &&
          other.version == this.version &&
          other.appliedAtMs == this.appliedAtMs);
}

class AppliedOperationsCompanion extends UpdateCompanion<AppliedOperationRow> {
  final Value<String> operationId;
  final Value<int> serverSequence;
  final Value<String> entityType;
  final Value<String> entityId;
  final Value<int> version;
  final Value<int> appliedAtMs;
  const AppliedOperationsCompanion({
    this.operationId = const Value.absent(),
    this.serverSequence = const Value.absent(),
    this.entityType = const Value.absent(),
    this.entityId = const Value.absent(),
    this.version = const Value.absent(),
    this.appliedAtMs = const Value.absent(),
  });
  AppliedOperationsCompanion.insert({
    required String operationId,
    this.serverSequence = const Value.absent(),
    required String entityType,
    required String entityId,
    required int version,
    required int appliedAtMs,
  }) : operationId = Value(operationId),
       entityType = Value(entityType),
       entityId = Value(entityId),
       version = Value(version),
       appliedAtMs = Value(appliedAtMs);
  static Insertable<AppliedOperationRow> custom({
    Expression<String>? operationId,
    Expression<int>? serverSequence,
    Expression<String>? entityType,
    Expression<String>? entityId,
    Expression<int>? version,
    Expression<int>? appliedAtMs,
  }) {
    return RawValuesInsertable({
      if (operationId != null) 'operation_id': operationId,
      if (serverSequence != null) 'server_sequence': serverSequence,
      if (entityType != null) 'entity_type': entityType,
      if (entityId != null) 'entity_id': entityId,
      if (version != null) 'version': version,
      if (appliedAtMs != null) 'applied_at_ms': appliedAtMs,
    });
  }

  AppliedOperationsCompanion copyWith({
    Value<String>? operationId,
    Value<int>? serverSequence,
    Value<String>? entityType,
    Value<String>? entityId,
    Value<int>? version,
    Value<int>? appliedAtMs,
  }) {
    return AppliedOperationsCompanion(
      operationId: operationId ?? this.operationId,
      serverSequence: serverSequence ?? this.serverSequence,
      entityType: entityType ?? this.entityType,
      entityId: entityId ?? this.entityId,
      version: version ?? this.version,
      appliedAtMs: appliedAtMs ?? this.appliedAtMs,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (operationId.present) {
      map['operation_id'] = Variable<String>(operationId.value);
    }
    if (serverSequence.present) {
      map['server_sequence'] = Variable<int>(serverSequence.value);
    }
    if (entityType.present) {
      map['entity_type'] = Variable<String>(entityType.value);
    }
    if (entityId.present) {
      map['entity_id'] = Variable<String>(entityId.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (appliedAtMs.present) {
      map['applied_at_ms'] = Variable<int>(appliedAtMs.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppliedOperationsCompanion(')
          ..write('operationId: $operationId, ')
          ..write('serverSequence: $serverSequence, ')
          ..write('entityType: $entityType, ')
          ..write('entityId: $entityId, ')
          ..write('version: $version, ')
          ..write('appliedAtMs: $appliedAtMs')
          ..write(')'))
        .toString();
  }
}

class $SyncConflictsTable extends SyncConflicts
    with TableInfo<$SyncConflictsTable, SyncConflictRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncConflictsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _serverSequenceMeta = const VerificationMeta(
    'serverSequence',
  );
  @override
  late final GeneratedColumn<int> serverSequence = GeneratedColumn<int>(
    'server_sequence',
    aliasedName,
    false,
    check: () => ComparableExpr(serverSequence).isBiggerOrEqualValue(1),
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _operationIdMeta = const VerificationMeta(
    'operationId',
  );
  @override
  late final GeneratedColumn<String> operationId = GeneratedColumn<String>(
    'operation_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entityTypeMeta = const VerificationMeta(
    'entityType',
  );
  @override
  late final GeneratedColumn<String> entityType = GeneratedColumn<String>(
    'entity_type',
    aliasedName,
    false,
    check: () => entityType.isIn(const ['bill', 'payment']),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entityIdMeta = const VerificationMeta(
    'entityId',
  );
  @override
  late final GeneratedColumn<String> entityId = GeneratedColumn<String>(
    'entity_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _reasonMeta = const VerificationMeta('reason');
  @override
  late final GeneratedColumn<String> reason = GeneratedColumn<String>(
    'reason',
    aliasedName,
    false,
    check: () => reason.isIn(const [
      'pending_local_change',
      'same_version_different_payload',
      'version_gap',
      'operation_conflict',
    ]),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _localVersionMeta = const VerificationMeta(
    'localVersion',
  );
  @override
  late final GeneratedColumn<int> localVersion = GeneratedColumn<int>(
    'local_version',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _remoteVersionMeta = const VerificationMeta(
    'remoteVersion',
  );
  @override
  late final GeneratedColumn<int> remoteVersion = GeneratedColumn<int>(
    'remote_version',
    aliasedName,
    false,
    check: () => ComparableExpr(remoteVersion).isBiggerOrEqualValue(1),
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _localPayloadJsonMeta = const VerificationMeta(
    'localPayloadJson',
  );
  @override
  late final GeneratedColumn<String> localPayloadJson = GeneratedColumn<String>(
    'local_payload_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _remotePayloadJsonMeta = const VerificationMeta(
    'remotePayloadJson',
  );
  @override
  late final GeneratedColumn<String> remotePayloadJson =
      GeneratedColumn<String>(
        'remote_payload_json',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _detectedAtMsMeta = const VerificationMeta(
    'detectedAtMs',
  );
  @override
  late final GeneratedColumn<int> detectedAtMs = GeneratedColumn<int>(
    'detected_at_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _resolvedAtMsMeta = const VerificationMeta(
    'resolvedAtMs',
  );
  @override
  late final GeneratedColumn<int> resolvedAtMs = GeneratedColumn<int>(
    'resolved_at_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    serverSequence,
    operationId,
    entityType,
    entityId,
    reason,
    localVersion,
    remoteVersion,
    localPayloadJson,
    remotePayloadJson,
    detectedAtMs,
    resolvedAtMs,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_conflicts';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncConflictRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('server_sequence')) {
      context.handle(
        _serverSequenceMeta,
        serverSequence.isAcceptableOrUnknown(
          data['server_sequence']!,
          _serverSequenceMeta,
        ),
      );
    }
    if (data.containsKey('operation_id')) {
      context.handle(
        _operationIdMeta,
        operationId.isAcceptableOrUnknown(
          data['operation_id']!,
          _operationIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_operationIdMeta);
    }
    if (data.containsKey('entity_type')) {
      context.handle(
        _entityTypeMeta,
        entityType.isAcceptableOrUnknown(data['entity_type']!, _entityTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_entityTypeMeta);
    }
    if (data.containsKey('entity_id')) {
      context.handle(
        _entityIdMeta,
        entityId.isAcceptableOrUnknown(data['entity_id']!, _entityIdMeta),
      );
    } else if (isInserting) {
      context.missing(_entityIdMeta);
    }
    if (data.containsKey('reason')) {
      context.handle(
        _reasonMeta,
        reason.isAcceptableOrUnknown(data['reason']!, _reasonMeta),
      );
    } else if (isInserting) {
      context.missing(_reasonMeta);
    }
    if (data.containsKey('local_version')) {
      context.handle(
        _localVersionMeta,
        localVersion.isAcceptableOrUnknown(
          data['local_version']!,
          _localVersionMeta,
        ),
      );
    }
    if (data.containsKey('remote_version')) {
      context.handle(
        _remoteVersionMeta,
        remoteVersion.isAcceptableOrUnknown(
          data['remote_version']!,
          _remoteVersionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_remoteVersionMeta);
    }
    if (data.containsKey('local_payload_json')) {
      context.handle(
        _localPayloadJsonMeta,
        localPayloadJson.isAcceptableOrUnknown(
          data['local_payload_json']!,
          _localPayloadJsonMeta,
        ),
      );
    }
    if (data.containsKey('remote_payload_json')) {
      context.handle(
        _remotePayloadJsonMeta,
        remotePayloadJson.isAcceptableOrUnknown(
          data['remote_payload_json']!,
          _remotePayloadJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_remotePayloadJsonMeta);
    }
    if (data.containsKey('detected_at_ms')) {
      context.handle(
        _detectedAtMsMeta,
        detectedAtMs.isAcceptableOrUnknown(
          data['detected_at_ms']!,
          _detectedAtMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_detectedAtMsMeta);
    }
    if (data.containsKey('resolved_at_ms')) {
      context.handle(
        _resolvedAtMsMeta,
        resolvedAtMs.isAcceptableOrUnknown(
          data['resolved_at_ms']!,
          _resolvedAtMsMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {serverSequence};
  @override
  SyncConflictRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncConflictRow(
      serverSequence: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}server_sequence'],
      )!,
      operationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}operation_id'],
      )!,
      entityType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_type'],
      )!,
      entityId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_id'],
      )!,
      reason: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reason'],
      )!,
      localVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}local_version'],
      ),
      remoteVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}remote_version'],
      )!,
      localPayloadJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_payload_json'],
      ),
      remotePayloadJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}remote_payload_json'],
      )!,
      detectedAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}detected_at_ms'],
      )!,
      resolvedAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}resolved_at_ms'],
      ),
    );
  }

  @override
  $SyncConflictsTable createAlias(String alias) {
    return $SyncConflictsTable(attachedDatabase, alias);
  }
}

class SyncConflictRow extends DataClass implements Insertable<SyncConflictRow> {
  final int serverSequence;
  final String operationId;
  final String entityType;
  final String entityId;
  final String reason;
  final int? localVersion;
  final int remoteVersion;
  final String? localPayloadJson;
  final String remotePayloadJson;
  final int detectedAtMs;
  final int? resolvedAtMs;
  const SyncConflictRow({
    required this.serverSequence,
    required this.operationId,
    required this.entityType,
    required this.entityId,
    required this.reason,
    this.localVersion,
    required this.remoteVersion,
    this.localPayloadJson,
    required this.remotePayloadJson,
    required this.detectedAtMs,
    this.resolvedAtMs,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['server_sequence'] = Variable<int>(serverSequence);
    map['operation_id'] = Variable<String>(operationId);
    map['entity_type'] = Variable<String>(entityType);
    map['entity_id'] = Variable<String>(entityId);
    map['reason'] = Variable<String>(reason);
    if (!nullToAbsent || localVersion != null) {
      map['local_version'] = Variable<int>(localVersion);
    }
    map['remote_version'] = Variable<int>(remoteVersion);
    if (!nullToAbsent || localPayloadJson != null) {
      map['local_payload_json'] = Variable<String>(localPayloadJson);
    }
    map['remote_payload_json'] = Variable<String>(remotePayloadJson);
    map['detected_at_ms'] = Variable<int>(detectedAtMs);
    if (!nullToAbsent || resolvedAtMs != null) {
      map['resolved_at_ms'] = Variable<int>(resolvedAtMs);
    }
    return map;
  }

  SyncConflictsCompanion toCompanion(bool nullToAbsent) {
    return SyncConflictsCompanion(
      serverSequence: Value(serverSequence),
      operationId: Value(operationId),
      entityType: Value(entityType),
      entityId: Value(entityId),
      reason: Value(reason),
      localVersion: localVersion == null && nullToAbsent
          ? const Value.absent()
          : Value(localVersion),
      remoteVersion: Value(remoteVersion),
      localPayloadJson: localPayloadJson == null && nullToAbsent
          ? const Value.absent()
          : Value(localPayloadJson),
      remotePayloadJson: Value(remotePayloadJson),
      detectedAtMs: Value(detectedAtMs),
      resolvedAtMs: resolvedAtMs == null && nullToAbsent
          ? const Value.absent()
          : Value(resolvedAtMs),
    );
  }

  factory SyncConflictRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncConflictRow(
      serverSequence: serializer.fromJson<int>(json['serverSequence']),
      operationId: serializer.fromJson<String>(json['operationId']),
      entityType: serializer.fromJson<String>(json['entityType']),
      entityId: serializer.fromJson<String>(json['entityId']),
      reason: serializer.fromJson<String>(json['reason']),
      localVersion: serializer.fromJson<int?>(json['localVersion']),
      remoteVersion: serializer.fromJson<int>(json['remoteVersion']),
      localPayloadJson: serializer.fromJson<String?>(json['localPayloadJson']),
      remotePayloadJson: serializer.fromJson<String>(json['remotePayloadJson']),
      detectedAtMs: serializer.fromJson<int>(json['detectedAtMs']),
      resolvedAtMs: serializer.fromJson<int?>(json['resolvedAtMs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'serverSequence': serializer.toJson<int>(serverSequence),
      'operationId': serializer.toJson<String>(operationId),
      'entityType': serializer.toJson<String>(entityType),
      'entityId': serializer.toJson<String>(entityId),
      'reason': serializer.toJson<String>(reason),
      'localVersion': serializer.toJson<int?>(localVersion),
      'remoteVersion': serializer.toJson<int>(remoteVersion),
      'localPayloadJson': serializer.toJson<String?>(localPayloadJson),
      'remotePayloadJson': serializer.toJson<String>(remotePayloadJson),
      'detectedAtMs': serializer.toJson<int>(detectedAtMs),
      'resolvedAtMs': serializer.toJson<int?>(resolvedAtMs),
    };
  }

  SyncConflictRow copyWith({
    int? serverSequence,
    String? operationId,
    String? entityType,
    String? entityId,
    String? reason,
    Value<int?> localVersion = const Value.absent(),
    int? remoteVersion,
    Value<String?> localPayloadJson = const Value.absent(),
    String? remotePayloadJson,
    int? detectedAtMs,
    Value<int?> resolvedAtMs = const Value.absent(),
  }) => SyncConflictRow(
    serverSequence: serverSequence ?? this.serverSequence,
    operationId: operationId ?? this.operationId,
    entityType: entityType ?? this.entityType,
    entityId: entityId ?? this.entityId,
    reason: reason ?? this.reason,
    localVersion: localVersion.present ? localVersion.value : this.localVersion,
    remoteVersion: remoteVersion ?? this.remoteVersion,
    localPayloadJson: localPayloadJson.present
        ? localPayloadJson.value
        : this.localPayloadJson,
    remotePayloadJson: remotePayloadJson ?? this.remotePayloadJson,
    detectedAtMs: detectedAtMs ?? this.detectedAtMs,
    resolvedAtMs: resolvedAtMs.present ? resolvedAtMs.value : this.resolvedAtMs,
  );
  SyncConflictRow copyWithCompanion(SyncConflictsCompanion data) {
    return SyncConflictRow(
      serverSequence: data.serverSequence.present
          ? data.serverSequence.value
          : this.serverSequence,
      operationId: data.operationId.present
          ? data.operationId.value
          : this.operationId,
      entityType: data.entityType.present
          ? data.entityType.value
          : this.entityType,
      entityId: data.entityId.present ? data.entityId.value : this.entityId,
      reason: data.reason.present ? data.reason.value : this.reason,
      localVersion: data.localVersion.present
          ? data.localVersion.value
          : this.localVersion,
      remoteVersion: data.remoteVersion.present
          ? data.remoteVersion.value
          : this.remoteVersion,
      localPayloadJson: data.localPayloadJson.present
          ? data.localPayloadJson.value
          : this.localPayloadJson,
      remotePayloadJson: data.remotePayloadJson.present
          ? data.remotePayloadJson.value
          : this.remotePayloadJson,
      detectedAtMs: data.detectedAtMs.present
          ? data.detectedAtMs.value
          : this.detectedAtMs,
      resolvedAtMs: data.resolvedAtMs.present
          ? data.resolvedAtMs.value
          : this.resolvedAtMs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncConflictRow(')
          ..write('serverSequence: $serverSequence, ')
          ..write('operationId: $operationId, ')
          ..write('entityType: $entityType, ')
          ..write('entityId: $entityId, ')
          ..write('reason: $reason, ')
          ..write('localVersion: $localVersion, ')
          ..write('remoteVersion: $remoteVersion, ')
          ..write('localPayloadJson: $localPayloadJson, ')
          ..write('remotePayloadJson: $remotePayloadJson, ')
          ..write('detectedAtMs: $detectedAtMs, ')
          ..write('resolvedAtMs: $resolvedAtMs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    serverSequence,
    operationId,
    entityType,
    entityId,
    reason,
    localVersion,
    remoteVersion,
    localPayloadJson,
    remotePayloadJson,
    detectedAtMs,
    resolvedAtMs,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncConflictRow &&
          other.serverSequence == this.serverSequence &&
          other.operationId == this.operationId &&
          other.entityType == this.entityType &&
          other.entityId == this.entityId &&
          other.reason == this.reason &&
          other.localVersion == this.localVersion &&
          other.remoteVersion == this.remoteVersion &&
          other.localPayloadJson == this.localPayloadJson &&
          other.remotePayloadJson == this.remotePayloadJson &&
          other.detectedAtMs == this.detectedAtMs &&
          other.resolvedAtMs == this.resolvedAtMs);
}

class SyncConflictsCompanion extends UpdateCompanion<SyncConflictRow> {
  final Value<int> serverSequence;
  final Value<String> operationId;
  final Value<String> entityType;
  final Value<String> entityId;
  final Value<String> reason;
  final Value<int?> localVersion;
  final Value<int> remoteVersion;
  final Value<String?> localPayloadJson;
  final Value<String> remotePayloadJson;
  final Value<int> detectedAtMs;
  final Value<int?> resolvedAtMs;
  const SyncConflictsCompanion({
    this.serverSequence = const Value.absent(),
    this.operationId = const Value.absent(),
    this.entityType = const Value.absent(),
    this.entityId = const Value.absent(),
    this.reason = const Value.absent(),
    this.localVersion = const Value.absent(),
    this.remoteVersion = const Value.absent(),
    this.localPayloadJson = const Value.absent(),
    this.remotePayloadJson = const Value.absent(),
    this.detectedAtMs = const Value.absent(),
    this.resolvedAtMs = const Value.absent(),
  });
  SyncConflictsCompanion.insert({
    this.serverSequence = const Value.absent(),
    required String operationId,
    required String entityType,
    required String entityId,
    required String reason,
    this.localVersion = const Value.absent(),
    required int remoteVersion,
    this.localPayloadJson = const Value.absent(),
    required String remotePayloadJson,
    required int detectedAtMs,
    this.resolvedAtMs = const Value.absent(),
  }) : operationId = Value(operationId),
       entityType = Value(entityType),
       entityId = Value(entityId),
       reason = Value(reason),
       remoteVersion = Value(remoteVersion),
       remotePayloadJson = Value(remotePayloadJson),
       detectedAtMs = Value(detectedAtMs);
  static Insertable<SyncConflictRow> custom({
    Expression<int>? serverSequence,
    Expression<String>? operationId,
    Expression<String>? entityType,
    Expression<String>? entityId,
    Expression<String>? reason,
    Expression<int>? localVersion,
    Expression<int>? remoteVersion,
    Expression<String>? localPayloadJson,
    Expression<String>? remotePayloadJson,
    Expression<int>? detectedAtMs,
    Expression<int>? resolvedAtMs,
  }) {
    return RawValuesInsertable({
      if (serverSequence != null) 'server_sequence': serverSequence,
      if (operationId != null) 'operation_id': operationId,
      if (entityType != null) 'entity_type': entityType,
      if (entityId != null) 'entity_id': entityId,
      if (reason != null) 'reason': reason,
      if (localVersion != null) 'local_version': localVersion,
      if (remoteVersion != null) 'remote_version': remoteVersion,
      if (localPayloadJson != null) 'local_payload_json': localPayloadJson,
      if (remotePayloadJson != null) 'remote_payload_json': remotePayloadJson,
      if (detectedAtMs != null) 'detected_at_ms': detectedAtMs,
      if (resolvedAtMs != null) 'resolved_at_ms': resolvedAtMs,
    });
  }

  SyncConflictsCompanion copyWith({
    Value<int>? serverSequence,
    Value<String>? operationId,
    Value<String>? entityType,
    Value<String>? entityId,
    Value<String>? reason,
    Value<int?>? localVersion,
    Value<int>? remoteVersion,
    Value<String?>? localPayloadJson,
    Value<String>? remotePayloadJson,
    Value<int>? detectedAtMs,
    Value<int?>? resolvedAtMs,
  }) {
    return SyncConflictsCompanion(
      serverSequence: serverSequence ?? this.serverSequence,
      operationId: operationId ?? this.operationId,
      entityType: entityType ?? this.entityType,
      entityId: entityId ?? this.entityId,
      reason: reason ?? this.reason,
      localVersion: localVersion ?? this.localVersion,
      remoteVersion: remoteVersion ?? this.remoteVersion,
      localPayloadJson: localPayloadJson ?? this.localPayloadJson,
      remotePayloadJson: remotePayloadJson ?? this.remotePayloadJson,
      detectedAtMs: detectedAtMs ?? this.detectedAtMs,
      resolvedAtMs: resolvedAtMs ?? this.resolvedAtMs,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (serverSequence.present) {
      map['server_sequence'] = Variable<int>(serverSequence.value);
    }
    if (operationId.present) {
      map['operation_id'] = Variable<String>(operationId.value);
    }
    if (entityType.present) {
      map['entity_type'] = Variable<String>(entityType.value);
    }
    if (entityId.present) {
      map['entity_id'] = Variable<String>(entityId.value);
    }
    if (reason.present) {
      map['reason'] = Variable<String>(reason.value);
    }
    if (localVersion.present) {
      map['local_version'] = Variable<int>(localVersion.value);
    }
    if (remoteVersion.present) {
      map['remote_version'] = Variable<int>(remoteVersion.value);
    }
    if (localPayloadJson.present) {
      map['local_payload_json'] = Variable<String>(localPayloadJson.value);
    }
    if (remotePayloadJson.present) {
      map['remote_payload_json'] = Variable<String>(remotePayloadJson.value);
    }
    if (detectedAtMs.present) {
      map['detected_at_ms'] = Variable<int>(detectedAtMs.value);
    }
    if (resolvedAtMs.present) {
      map['resolved_at_ms'] = Variable<int>(resolvedAtMs.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncConflictsCompanion(')
          ..write('serverSequence: $serverSequence, ')
          ..write('operationId: $operationId, ')
          ..write('entityType: $entityType, ')
          ..write('entityId: $entityId, ')
          ..write('reason: $reason, ')
          ..write('localVersion: $localVersion, ')
          ..write('remoteVersion: $remoteVersion, ')
          ..write('localPayloadJson: $localPayloadJson, ')
          ..write('remotePayloadJson: $remotePayloadJson, ')
          ..write('detectedAtMs: $detectedAtMs, ')
          ..write('resolvedAtMs: $resolvedAtMs')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $BillsTable bills = $BillsTable(this);
  late final $PaymentsTable payments = $PaymentsTable(this);
  late final $SyncOutboxTable syncOutbox = $SyncOutboxTable(this);
  late final $SyncStatesTable syncStates = $SyncStatesTable(this);
  late final $AppliedOperationsTable appliedOperations =
      $AppliedOperationsTable(this);
  late final $SyncConflictsTable syncConflicts = $SyncConflictsTable(this);
  late final Index billsStatusNextDueDate = Index(
    'bills_status_next_due_date',
    'CREATE INDEX bills_status_next_due_date ON bills (status, next_due_date)',
  );
  late final Index billsDeletedAtMs = Index(
    'bills_deleted_at_ms',
    'CREATE INDEX bills_deleted_at_ms ON bills (deleted_at_ms)',
  );
  late final Index paymentsBillIdDueDate = Index(
    'payments_bill_id_due_date',
    'CREATE INDEX payments_bill_id_due_date ON payments (bill_id, due_date)',
  );
  late final Index paymentsPaidAtMs = Index(
    'payments_paid_at_ms',
    'CREATE INDEX payments_paid_at_ms ON payments (paid_at_ms)',
  );
  late final Index paymentsDeletedAtMs = Index(
    'payments_deleted_at_ms',
    'CREATE INDEX payments_deleted_at_ms ON payments (deleted_at_ms)',
  );
  late final Index syncOutboxEntity = Index(
    'sync_outbox_entity',
    'CREATE INDEX sync_outbox_entity ON sync_outbox (entity_type, entity_id)',
  );
  late final Index appliedOperationsOperation = Index(
    'applied_operations_operation',
    'CREATE INDEX applied_operations_operation ON applied_operations (operation_id)',
  );
  late final Index syncConflictsEntity = Index(
    'sync_conflicts_entity',
    'CREATE INDEX sync_conflicts_entity ON sync_conflicts (entity_type, entity_id, resolved_at_ms)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    bills,
    payments,
    syncOutbox,
    syncStates,
    appliedOperations,
    syncConflicts,
    billsStatusNextDueDate,
    billsDeletedAtMs,
    paymentsBillIdDueDate,
    paymentsPaidAtMs,
    paymentsDeletedAtMs,
    syncOutboxEntity,
    appliedOperationsOperation,
    syncConflictsEntity,
  ];
}

typedef $$BillsTableCreateCompanionBuilder = BillsCompanion Function({
  required String id,
  required String name,
  Value<String?> category,
  required int amountMinorUnits,
  required String currency,
  required String billingCycle,
  required String nextDueDate,
  required String startDate,
  required String status,
  Value<String?> notes,
  required int createdAtMs,
  required int updatedAtMs,
  Value<int?> deletedAtMs,
  required int version,
  Value<int> rowid,
});
typedef $$BillsTableUpdateCompanionBuilder = BillsCompanion Function({
  Value<String> id,
  Value<String> name,
  Value<String?> category,
  Value<int> amountMinorUnits,
  Value<String> currency,
  Value<String> billingCycle,
  Value<String> nextDueDate,
  Value<String> startDate,
  Value<String> status,
  Value<String?> notes,
  Value<int> createdAtMs,
  Value<int> updatedAtMs,
  Value<int?> deletedAtMs,
  Value<int> version,
  Value<int> rowid,
});

final class $$BillsTableReferences
    extends BaseReferences<_$AppDatabase, $BillsTable, BillRow> {
  $$BillsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$PaymentsTable, List<PaymentRow>>
  _paymentsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.payments,
    aliasName: 'bills__id__payments__bill_id',
  );

  $$PaymentsTableProcessedTableManager get paymentsRefs {
    final manager = $$PaymentsTableTableManager(
      $_db,
      $_db.payments,
    ).filter((f) => f.billId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_paymentsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$BillsTableFilterComposer extends Composer<_$AppDatabase, $BillsTable> {
  $$BillsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get amountMinorUnits => $composableBuilder(
    column: $table.amountMinorUnits,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get billingCycle => $composableBuilder(
    column: $table.billingCycle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nextDueDate => $composableBuilder(
    column: $table.nextDueDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get startDate => $composableBuilder(
    column: $table.startDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAtMs => $composableBuilder(
    column: $table.createdAtMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAtMs => $composableBuilder(
    column: $table.updatedAtMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAtMs => $composableBuilder(
    column: $table.deletedAtMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> paymentsRefs(
    Expression<bool> Function($$PaymentsTableFilterComposer f) f,
  ) {
    final $$PaymentsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.payments,
      getReferencedColumn: (t) => t.billId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PaymentsTableFilterComposer(
            $db: $db,
            $table: $db.payments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$BillsTableOrderingComposer
    extends Composer<_$AppDatabase, $BillsTable> {
  $$BillsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get amountMinorUnits => $composableBuilder(
    column: $table.amountMinorUnits,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get billingCycle => $composableBuilder(
    column: $table.billingCycle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nextDueDate => $composableBuilder(
    column: $table.nextDueDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get startDate => $composableBuilder(
    column: $table.startDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAtMs => $composableBuilder(
    column: $table.createdAtMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAtMs => $composableBuilder(
    column: $table.updatedAtMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAtMs => $composableBuilder(
    column: $table.deletedAtMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BillsTableAnnotationComposer
    extends Composer<_$AppDatabase, $BillsTable> {
  $$BillsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<int> get amountMinorUnits => $composableBuilder(
    column: $table.amountMinorUnits,
    builder: (column) => column,
  );

  GeneratedColumn<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => column);

  GeneratedColumn<String> get billingCycle => $composableBuilder(
    column: $table.billingCycle,
    builder: (column) => column,
  );

  GeneratedColumn<String> get nextDueDate => $composableBuilder(
    column: $table.nextDueDate,
    builder: (column) => column,
  );

  GeneratedColumn<String> get startDate =>
      $composableBuilder(column: $table.startDate, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<int> get createdAtMs => $composableBuilder(
    column: $table.createdAtMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get updatedAtMs => $composableBuilder(
    column: $table.updatedAtMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get deletedAtMs => $composableBuilder(
    column: $table.deletedAtMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  Expression<T> paymentsRefs<T extends Object>(
    Expression<T> Function($$PaymentsTableAnnotationComposer a) f,
  ) {
    final $$PaymentsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.payments,
      getReferencedColumn: (t) => t.billId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PaymentsTableAnnotationComposer(
            $db: $db,
            $table: $db.payments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$BillsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BillsTable,
          BillRow,
          $$BillsTableFilterComposer,
          $$BillsTableOrderingComposer,
          $$BillsTableAnnotationComposer,
          $$BillsTableCreateCompanionBuilder,
          $$BillsTableUpdateCompanionBuilder,
          (BillRow, $$BillsTableReferences),
          BillRow,
          PrefetchHooks Function({bool paymentsRefs})
        > {
  $$BillsTableTableManager(_$AppDatabase db, $BillsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BillsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BillsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BillsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> category = const Value.absent(),
                Value<int> amountMinorUnits = const Value.absent(),
                Value<String> currency = const Value.absent(),
                Value<String> billingCycle = const Value.absent(),
                Value<String> nextDueDate = const Value.absent(),
                Value<String> startDate = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<int> createdAtMs = const Value.absent(),
                Value<int> updatedAtMs = const Value.absent(),
                Value<int?> deletedAtMs = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BillsCompanion(
                id: id,
                name: name,
                category: category,
                amountMinorUnits: amountMinorUnits,
                currency: currency,
                billingCycle: billingCycle,
                nextDueDate: nextDueDate,
                startDate: startDate,
                status: status,
                notes: notes,
                createdAtMs: createdAtMs,
                updatedAtMs: updatedAtMs,
                deletedAtMs: deletedAtMs,
                version: version,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<String?> category = const Value.absent(),
                required int amountMinorUnits,
                required String currency,
                required String billingCycle,
                required String nextDueDate,
                required String startDate,
                required String status,
                Value<String?> notes = const Value.absent(),
                required int createdAtMs,
                required int updatedAtMs,
                Value<int?> deletedAtMs = const Value.absent(),
                required int version,
                Value<int> rowid = const Value.absent(),
              }) => BillsCompanion.insert(
                id: id,
                name: name,
                category: category,
                amountMinorUnits: amountMinorUnits,
                currency: currency,
                billingCycle: billingCycle,
                nextDueDate: nextDueDate,
                startDate: startDate,
                status: status,
                notes: notes,
                createdAtMs: createdAtMs,
                updatedAtMs: updatedAtMs,
                deletedAtMs: deletedAtMs,
                version: version,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$BillsTable, BillRow>(table),
                  $$BillsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({paymentsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (paymentsRefs) db.payments],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (paymentsRefs)
                    await $_getPrefetchedData<BillRow, $BillsTable, PaymentRow>(
                      currentTable: table,
                      referencedTable: $$BillsTableReferences
                          ._paymentsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$BillsTableReferences(db, table, p0).paymentsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.billId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$BillsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BillsTable,
      BillRow,
      $$BillsTableFilterComposer,
      $$BillsTableOrderingComposer,
      $$BillsTableAnnotationComposer,
      $$BillsTableCreateCompanionBuilder,
      $$BillsTableUpdateCompanionBuilder,
      (BillRow, $$BillsTableReferences),
      BillRow,
      PrefetchHooks Function({bool paymentsRefs})
    >;
typedef $$PaymentsTableCreateCompanionBuilder = PaymentsCompanion Function({
  required String id,
  required String billId,
  required int amountMinorUnits,
  required String currency,
  required String dueDate,
  required int paidAtMs,
  Value<String?> notes,
  required int createdAtMs,
  required int updatedAtMs,
  Value<int?> deletedAtMs,
  required int version,
  Value<int> rowid,
});
typedef $$PaymentsTableUpdateCompanionBuilder = PaymentsCompanion Function({
  Value<String> id,
  Value<String> billId,
  Value<int> amountMinorUnits,
  Value<String> currency,
  Value<String> dueDate,
  Value<int> paidAtMs,
  Value<String?> notes,
  Value<int> createdAtMs,
  Value<int> updatedAtMs,
  Value<int?> deletedAtMs,
  Value<int> version,
  Value<int> rowid,
});

final class $$PaymentsTableReferences
    extends BaseReferences<_$AppDatabase, $PaymentsTable, PaymentRow> {
  $$PaymentsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $BillsTable _billIdTable(_$AppDatabase db) =>
      db.bills.createAlias('payments__bill_id__bills__id');

  $$BillsTableProcessedTableManager get billId {
    final $_column = $_itemColumn<String>('bill_id')!;

    final manager = $$BillsTableTableManager(
      $_db,
      $_db.bills,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_billIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$PaymentsTableFilterComposer
    extends Composer<_$AppDatabase, $PaymentsTable> {
  $$PaymentsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get amountMinorUnits => $composableBuilder(
    column: $table.amountMinorUnits,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dueDate => $composableBuilder(
    column: $table.dueDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get paidAtMs => $composableBuilder(
    column: $table.paidAtMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAtMs => $composableBuilder(
    column: $table.createdAtMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAtMs => $composableBuilder(
    column: $table.updatedAtMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAtMs => $composableBuilder(
    column: $table.deletedAtMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  $$BillsTableFilterComposer get billId {
    final $$BillsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.billId,
      referencedTable: $db.bills,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BillsTableFilterComposer(
            $db: $db,
            $table: $db.bills,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PaymentsTableOrderingComposer
    extends Composer<_$AppDatabase, $PaymentsTable> {
  $$PaymentsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get amountMinorUnits => $composableBuilder(
    column: $table.amountMinorUnits,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dueDate => $composableBuilder(
    column: $table.dueDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get paidAtMs => $composableBuilder(
    column: $table.paidAtMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAtMs => $composableBuilder(
    column: $table.createdAtMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAtMs => $composableBuilder(
    column: $table.updatedAtMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAtMs => $composableBuilder(
    column: $table.deletedAtMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  $$BillsTableOrderingComposer get billId {
    final $$BillsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.billId,
      referencedTable: $db.bills,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BillsTableOrderingComposer(
            $db: $db,
            $table: $db.bills,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PaymentsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PaymentsTable> {
  $$PaymentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get amountMinorUnits => $composableBuilder(
    column: $table.amountMinorUnits,
    builder: (column) => column,
  );

  GeneratedColumn<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => column);

  GeneratedColumn<String> get dueDate =>
      $composableBuilder(column: $table.dueDate, builder: (column) => column);

  GeneratedColumn<int> get paidAtMs =>
      $composableBuilder(column: $table.paidAtMs, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<int> get createdAtMs => $composableBuilder(
    column: $table.createdAtMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get updatedAtMs => $composableBuilder(
    column: $table.updatedAtMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get deletedAtMs => $composableBuilder(
    column: $table.deletedAtMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  $$BillsTableAnnotationComposer get billId {
    final $$BillsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.billId,
      referencedTable: $db.bills,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BillsTableAnnotationComposer(
            $db: $db,
            $table: $db.bills,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PaymentsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PaymentsTable,
          PaymentRow,
          $$PaymentsTableFilterComposer,
          $$PaymentsTableOrderingComposer,
          $$PaymentsTableAnnotationComposer,
          $$PaymentsTableCreateCompanionBuilder,
          $$PaymentsTableUpdateCompanionBuilder,
          (PaymentRow, $$PaymentsTableReferences),
          PaymentRow,
          PrefetchHooks Function({bool billId})
        > {
  $$PaymentsTableTableManager(_$AppDatabase db, $PaymentsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PaymentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PaymentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PaymentsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> billId = const Value.absent(),
                Value<int> amountMinorUnits = const Value.absent(),
                Value<String> currency = const Value.absent(),
                Value<String> dueDate = const Value.absent(),
                Value<int> paidAtMs = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<int> createdAtMs = const Value.absent(),
                Value<int> updatedAtMs = const Value.absent(),
                Value<int?> deletedAtMs = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PaymentsCompanion(
                id: id,
                billId: billId,
                amountMinorUnits: amountMinorUnits,
                currency: currency,
                dueDate: dueDate,
                paidAtMs: paidAtMs,
                notes: notes,
                createdAtMs: createdAtMs,
                updatedAtMs: updatedAtMs,
                deletedAtMs: deletedAtMs,
                version: version,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String billId,
                required int amountMinorUnits,
                required String currency,
                required String dueDate,
                required int paidAtMs,
                Value<String?> notes = const Value.absent(),
                required int createdAtMs,
                required int updatedAtMs,
                Value<int?> deletedAtMs = const Value.absent(),
                required int version,
                Value<int> rowid = const Value.absent(),
              }) => PaymentsCompanion.insert(
                id: id,
                billId: billId,
                amountMinorUnits: amountMinorUnits,
                currency: currency,
                dueDate: dueDate,
                paidAtMs: paidAtMs,
                notes: notes,
                createdAtMs: createdAtMs,
                updatedAtMs: updatedAtMs,
                deletedAtMs: deletedAtMs,
                version: version,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PaymentsTable, PaymentRow>(table),
                  $$PaymentsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({billId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (billId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.billId,
                        referencedTable: $$PaymentsTableReferences._billIdTable(
                          db,
                        ),
                        referencedColumn: $$PaymentsTableReferences
                            ._billIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$PaymentsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PaymentsTable,
      PaymentRow,
      $$PaymentsTableFilterComposer,
      $$PaymentsTableOrderingComposer,
      $$PaymentsTableAnnotationComposer,
      $$PaymentsTableCreateCompanionBuilder,
      $$PaymentsTableUpdateCompanionBuilder,
      (PaymentRow, $$PaymentsTableReferences),
      PaymentRow,
      PrefetchHooks Function({bool billId})
    >;
typedef $$SyncOutboxTableCreateCompanionBuilder = SyncOutboxCompanion Function({
  Value<int> localSequence,
  required String operationId,
  required String entityType,
  required String entityId,
  required String operationType,
  required int baseVersion,
  required String payloadJson,
  required int createdAtMs,
});
typedef $$SyncOutboxTableUpdateCompanionBuilder = SyncOutboxCompanion Function({
  Value<int> localSequence,
  Value<String> operationId,
  Value<String> entityType,
  Value<String> entityId,
  Value<String> operationType,
  Value<int> baseVersion,
  Value<String> payloadJson,
  Value<int> createdAtMs,
});

class $$SyncOutboxTableFilterComposer
    extends Composer<_$AppDatabase, $SyncOutboxTable> {
  $$SyncOutboxTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get localSequence => $composableBuilder(
    column: $table.localSequence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get operationId => $composableBuilder(
    column: $table.operationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get operationType => $composableBuilder(
    column: $table.operationType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get baseVersion => $composableBuilder(
    column: $table.baseVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAtMs => $composableBuilder(
    column: $table.createdAtMs,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncOutboxTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncOutboxTable> {
  $$SyncOutboxTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get localSequence => $composableBuilder(
    column: $table.localSequence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get operationId => $composableBuilder(
    column: $table.operationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get operationType => $composableBuilder(
    column: $table.operationType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get baseVersion => $composableBuilder(
    column: $table.baseVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAtMs => $composableBuilder(
    column: $table.createdAtMs,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncOutboxTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncOutboxTable> {
  $$SyncOutboxTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get localSequence => $composableBuilder(
    column: $table.localSequence,
    builder: (column) => column,
  );

  GeneratedColumn<String> get operationId => $composableBuilder(
    column: $table.operationId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get entityId =>
      $composableBuilder(column: $table.entityId, builder: (column) => column);

  GeneratedColumn<String> get operationType => $composableBuilder(
    column: $table.operationType,
    builder: (column) => column,
  );

  GeneratedColumn<int> get baseVersion => $composableBuilder(
    column: $table.baseVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAtMs => $composableBuilder(
    column: $table.createdAtMs,
    builder: (column) => column,
  );
}

class $$SyncOutboxTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyncOutboxTable,
          SyncOutboxRow,
          $$SyncOutboxTableFilterComposer,
          $$SyncOutboxTableOrderingComposer,
          $$SyncOutboxTableAnnotationComposer,
          $$SyncOutboxTableCreateCompanionBuilder,
          $$SyncOutboxTableUpdateCompanionBuilder,
          (
            SyncOutboxRow,
            BaseReferences<_$AppDatabase, $SyncOutboxTable, SyncOutboxRow>,
          ),
          SyncOutboxRow,
          PrefetchHooks Function()
        > {
  $$SyncOutboxTableTableManager(_$AppDatabase db, $SyncOutboxTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncOutboxTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncOutboxTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncOutboxTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> localSequence = const Value.absent(),
                Value<String> operationId = const Value.absent(),
                Value<String> entityType = const Value.absent(),
                Value<String> entityId = const Value.absent(),
                Value<String> operationType = const Value.absent(),
                Value<int> baseVersion = const Value.absent(),
                Value<String> payloadJson = const Value.absent(),
                Value<int> createdAtMs = const Value.absent(),
              }) => SyncOutboxCompanion(
                localSequence: localSequence,
                operationId: operationId,
                entityType: entityType,
                entityId: entityId,
                operationType: operationType,
                baseVersion: baseVersion,
                payloadJson: payloadJson,
                createdAtMs: createdAtMs,
              ),
          createCompanionCallback:
              ({
                Value<int> localSequence = const Value.absent(),
                required String operationId,
                required String entityType,
                required String entityId,
                required String operationType,
                required int baseVersion,
                required String payloadJson,
                required int createdAtMs,
              }) => SyncOutboxCompanion.insert(
                localSequence: localSequence,
                operationId: operationId,
                entityType: entityType,
                entityId: entityId,
                operationType: operationType,
                baseVersion: baseVersion,
                payloadJson: payloadJson,
                createdAtMs: createdAtMs,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SyncOutboxTable, SyncOutboxRow>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $SyncOutboxTable,
                    SyncOutboxRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncOutboxTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyncOutboxTable,
      SyncOutboxRow,
      $$SyncOutboxTableFilterComposer,
      $$SyncOutboxTableOrderingComposer,
      $$SyncOutboxTableAnnotationComposer,
      $$SyncOutboxTableCreateCompanionBuilder,
      $$SyncOutboxTableUpdateCompanionBuilder,
      (
        SyncOutboxRow,
        BaseReferences<_$AppDatabase, $SyncOutboxTable, SyncOutboxRow>,
      ),
      SyncOutboxRow,
      PrefetchHooks Function()
    >;
typedef $$SyncStatesTableCreateCompanionBuilder = SyncStatesCompanion Function({
  Value<int> id,
  required String deviceId,
  Value<int> lastPulledSequence,
  required int createdAtMs,
  Value<String?> bootstrapId,
  Value<String?> bootstrapPayloadJson,
  Value<int?> bootstrapOutboxSequence,
  Value<int?> bootstrapCreatedAtMs,
  Value<int?> bootstrapCompletedAtMs,
});
typedef $$SyncStatesTableUpdateCompanionBuilder = SyncStatesCompanion Function({
  Value<int> id,
  Value<String> deviceId,
  Value<int> lastPulledSequence,
  Value<int> createdAtMs,
  Value<String?> bootstrapId,
  Value<String?> bootstrapPayloadJson,
  Value<int?> bootstrapOutboxSequence,
  Value<int?> bootstrapCreatedAtMs,
  Value<int?> bootstrapCompletedAtMs,
});

class $$SyncStatesTableFilterComposer
    extends Composer<_$AppDatabase, $SyncStatesTable> {
  $$SyncStatesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastPulledSequence => $composableBuilder(
    column: $table.lastPulledSequence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAtMs => $composableBuilder(
    column: $table.createdAtMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bootstrapId => $composableBuilder(
    column: $table.bootstrapId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bootstrapPayloadJson => $composableBuilder(
    column: $table.bootstrapPayloadJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get bootstrapOutboxSequence => $composableBuilder(
    column: $table.bootstrapOutboxSequence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get bootstrapCreatedAtMs => $composableBuilder(
    column: $table.bootstrapCreatedAtMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get bootstrapCompletedAtMs => $composableBuilder(
    column: $table.bootstrapCompletedAtMs,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncStatesTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncStatesTable> {
  $$SyncStatesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastPulledSequence => $composableBuilder(
    column: $table.lastPulledSequence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAtMs => $composableBuilder(
    column: $table.createdAtMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bootstrapId => $composableBuilder(
    column: $table.bootstrapId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bootstrapPayloadJson => $composableBuilder(
    column: $table.bootstrapPayloadJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get bootstrapOutboxSequence => $composableBuilder(
    column: $table.bootstrapOutboxSequence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get bootstrapCreatedAtMs => $composableBuilder(
    column: $table.bootstrapCreatedAtMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get bootstrapCompletedAtMs => $composableBuilder(
    column: $table.bootstrapCompletedAtMs,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncStatesTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncStatesTable> {
  $$SyncStatesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);

  GeneratedColumn<int> get lastPulledSequence => $composableBuilder(
    column: $table.lastPulledSequence,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAtMs => $composableBuilder(
    column: $table.createdAtMs,
    builder: (column) => column,
  );

  GeneratedColumn<String> get bootstrapId => $composableBuilder(
    column: $table.bootstrapId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get bootstrapPayloadJson => $composableBuilder(
    column: $table.bootstrapPayloadJson,
    builder: (column) => column,
  );

  GeneratedColumn<int> get bootstrapOutboxSequence => $composableBuilder(
    column: $table.bootstrapOutboxSequence,
    builder: (column) => column,
  );

  GeneratedColumn<int> get bootstrapCreatedAtMs => $composableBuilder(
    column: $table.bootstrapCreatedAtMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get bootstrapCompletedAtMs => $composableBuilder(
    column: $table.bootstrapCompletedAtMs,
    builder: (column) => column,
  );
}

class $$SyncStatesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyncStatesTable,
          SyncStateRow,
          $$SyncStatesTableFilterComposer,
          $$SyncStatesTableOrderingComposer,
          $$SyncStatesTableAnnotationComposer,
          $$SyncStatesTableCreateCompanionBuilder,
          $$SyncStatesTableUpdateCompanionBuilder,
          (
            SyncStateRow,
            BaseReferences<_$AppDatabase, $SyncStatesTable, SyncStateRow>,
          ),
          SyncStateRow,
          PrefetchHooks Function()
        > {
  $$SyncStatesTableTableManager(_$AppDatabase db, $SyncStatesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncStatesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncStatesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncStatesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> deviceId = const Value.absent(),
                Value<int> lastPulledSequence = const Value.absent(),
                Value<int> createdAtMs = const Value.absent(),
                Value<String?> bootstrapId = const Value.absent(),
                Value<String?> bootstrapPayloadJson = const Value.absent(),
                Value<int?> bootstrapOutboxSequence = const Value.absent(),
                Value<int?> bootstrapCreatedAtMs = const Value.absent(),
                Value<int?> bootstrapCompletedAtMs = const Value.absent(),
              }) => SyncStatesCompanion(
                id: id,
                deviceId: deviceId,
                lastPulledSequence: lastPulledSequence,
                createdAtMs: createdAtMs,
                bootstrapId: bootstrapId,
                bootstrapPayloadJson: bootstrapPayloadJson,
                bootstrapOutboxSequence: bootstrapOutboxSequence,
                bootstrapCreatedAtMs: bootstrapCreatedAtMs,
                bootstrapCompletedAtMs: bootstrapCompletedAtMs,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String deviceId,
                Value<int> lastPulledSequence = const Value.absent(),
                required int createdAtMs,
                Value<String?> bootstrapId = const Value.absent(),
                Value<String?> bootstrapPayloadJson = const Value.absent(),
                Value<int?> bootstrapOutboxSequence = const Value.absent(),
                Value<int?> bootstrapCreatedAtMs = const Value.absent(),
                Value<int?> bootstrapCompletedAtMs = const Value.absent(),
              }) => SyncStatesCompanion.insert(
                id: id,
                deviceId: deviceId,
                lastPulledSequence: lastPulledSequence,
                createdAtMs: createdAtMs,
                bootstrapId: bootstrapId,
                bootstrapPayloadJson: bootstrapPayloadJson,
                bootstrapOutboxSequence: bootstrapOutboxSequence,
                bootstrapCreatedAtMs: bootstrapCreatedAtMs,
                bootstrapCompletedAtMs: bootstrapCompletedAtMs,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SyncStatesTable, SyncStateRow>(table),
                  BaseReferences<_$AppDatabase, $SyncStatesTable, SyncStateRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncStatesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyncStatesTable,
      SyncStateRow,
      $$SyncStatesTableFilterComposer,
      $$SyncStatesTableOrderingComposer,
      $$SyncStatesTableAnnotationComposer,
      $$SyncStatesTableCreateCompanionBuilder,
      $$SyncStatesTableUpdateCompanionBuilder,
      (
        SyncStateRow,
        BaseReferences<_$AppDatabase, $SyncStatesTable, SyncStateRow>,
      ),
      SyncStateRow,
      PrefetchHooks Function()
    >;
typedef $$AppliedOperationsTableCreateCompanionBuilder =
    AppliedOperationsCompanion Function({
      required String operationId,
      Value<int> serverSequence,
      required String entityType,
      required String entityId,
      required int version,
      required int appliedAtMs,
    });
typedef $$AppliedOperationsTableUpdateCompanionBuilder =
    AppliedOperationsCompanion Function({
      Value<String> operationId,
      Value<int> serverSequence,
      Value<String> entityType,
      Value<String> entityId,
      Value<int> version,
      Value<int> appliedAtMs,
    });

class $$AppliedOperationsTableFilterComposer
    extends Composer<_$AppDatabase, $AppliedOperationsTable> {
  $$AppliedOperationsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get operationId => $composableBuilder(
    column: $table.operationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get serverSequence => $composableBuilder(
    column: $table.serverSequence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get appliedAtMs => $composableBuilder(
    column: $table.appliedAtMs,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AppliedOperationsTableOrderingComposer
    extends Composer<_$AppDatabase, $AppliedOperationsTable> {
  $$AppliedOperationsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get operationId => $composableBuilder(
    column: $table.operationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get serverSequence => $composableBuilder(
    column: $table.serverSequence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get appliedAtMs => $composableBuilder(
    column: $table.appliedAtMs,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AppliedOperationsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AppliedOperationsTable> {
  $$AppliedOperationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get operationId => $composableBuilder(
    column: $table.operationId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get serverSequence => $composableBuilder(
    column: $table.serverSequence,
    builder: (column) => column,
  );

  GeneratedColumn<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get entityId =>
      $composableBuilder(column: $table.entityId, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<int> get appliedAtMs => $composableBuilder(
    column: $table.appliedAtMs,
    builder: (column) => column,
  );
}

class $$AppliedOperationsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AppliedOperationsTable,
          AppliedOperationRow,
          $$AppliedOperationsTableFilterComposer,
          $$AppliedOperationsTableOrderingComposer,
          $$AppliedOperationsTableAnnotationComposer,
          $$AppliedOperationsTableCreateCompanionBuilder,
          $$AppliedOperationsTableUpdateCompanionBuilder,
          (
            AppliedOperationRow,
            BaseReferences<
              _$AppDatabase,
              $AppliedOperationsTable,
              AppliedOperationRow
            >,
          ),
          AppliedOperationRow,
          PrefetchHooks Function()
        > {
  $$AppliedOperationsTableTableManager(
    _$AppDatabase db,
    $AppliedOperationsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AppliedOperationsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AppliedOperationsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AppliedOperationsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> operationId = const Value.absent(),
                Value<int> serverSequence = const Value.absent(),
                Value<String> entityType = const Value.absent(),
                Value<String> entityId = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<int> appliedAtMs = const Value.absent(),
              }) => AppliedOperationsCompanion(
                operationId: operationId,
                serverSequence: serverSequence,
                entityType: entityType,
                entityId: entityId,
                version: version,
                appliedAtMs: appliedAtMs,
              ),
          createCompanionCallback:
              ({
                required String operationId,
                Value<int> serverSequence = const Value.absent(),
                required String entityType,
                required String entityId,
                required int version,
                required int appliedAtMs,
              }) => AppliedOperationsCompanion.insert(
                operationId: operationId,
                serverSequence: serverSequence,
                entityType: entityType,
                entityId: entityId,
                version: version,
                appliedAtMs: appliedAtMs,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$AppliedOperationsTable, AppliedOperationRow>(
                    table,
                  ),
                  BaseReferences<
                    _$AppDatabase,
                    $AppliedOperationsTable,
                    AppliedOperationRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AppliedOperationsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AppliedOperationsTable,
      AppliedOperationRow,
      $$AppliedOperationsTableFilterComposer,
      $$AppliedOperationsTableOrderingComposer,
      $$AppliedOperationsTableAnnotationComposer,
      $$AppliedOperationsTableCreateCompanionBuilder,
      $$AppliedOperationsTableUpdateCompanionBuilder,
      (
        AppliedOperationRow,
        BaseReferences<
          _$AppDatabase,
          $AppliedOperationsTable,
          AppliedOperationRow
        >,
      ),
      AppliedOperationRow,
      PrefetchHooks Function()
    >;
typedef $$SyncConflictsTableCreateCompanionBuilder =
    SyncConflictsCompanion Function({
      Value<int> serverSequence,
      required String operationId,
      required String entityType,
      required String entityId,
      required String reason,
      Value<int?> localVersion,
      required int remoteVersion,
      Value<String?> localPayloadJson,
      required String remotePayloadJson,
      required int detectedAtMs,
      Value<int?> resolvedAtMs,
    });
typedef $$SyncConflictsTableUpdateCompanionBuilder =
    SyncConflictsCompanion Function({
      Value<int> serverSequence,
      Value<String> operationId,
      Value<String> entityType,
      Value<String> entityId,
      Value<String> reason,
      Value<int?> localVersion,
      Value<int> remoteVersion,
      Value<String?> localPayloadJson,
      Value<String> remotePayloadJson,
      Value<int> detectedAtMs,
      Value<int?> resolvedAtMs,
    });

class $$SyncConflictsTableFilterComposer
    extends Composer<_$AppDatabase, $SyncConflictsTable> {
  $$SyncConflictsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get serverSequence => $composableBuilder(
    column: $table.serverSequence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get operationId => $composableBuilder(
    column: $table.operationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reason => $composableBuilder(
    column: $table.reason,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get localVersion => $composableBuilder(
    column: $table.localVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get remoteVersion => $composableBuilder(
    column: $table.remoteVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get localPayloadJson => $composableBuilder(
    column: $table.localPayloadJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get remotePayloadJson => $composableBuilder(
    column: $table.remotePayloadJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get detectedAtMs => $composableBuilder(
    column: $table.detectedAtMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get resolvedAtMs => $composableBuilder(
    column: $table.resolvedAtMs,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncConflictsTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncConflictsTable> {
  $$SyncConflictsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get serverSequence => $composableBuilder(
    column: $table.serverSequence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get operationId => $composableBuilder(
    column: $table.operationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reason => $composableBuilder(
    column: $table.reason,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get localVersion => $composableBuilder(
    column: $table.localVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get remoteVersion => $composableBuilder(
    column: $table.remoteVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get localPayloadJson => $composableBuilder(
    column: $table.localPayloadJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get remotePayloadJson => $composableBuilder(
    column: $table.remotePayloadJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get detectedAtMs => $composableBuilder(
    column: $table.detectedAtMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get resolvedAtMs => $composableBuilder(
    column: $table.resolvedAtMs,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncConflictsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncConflictsTable> {
  $$SyncConflictsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get serverSequence => $composableBuilder(
    column: $table.serverSequence,
    builder: (column) => column,
  );

  GeneratedColumn<String> get operationId => $composableBuilder(
    column: $table.operationId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get entityId =>
      $composableBuilder(column: $table.entityId, builder: (column) => column);

  GeneratedColumn<String> get reason =>
      $composableBuilder(column: $table.reason, builder: (column) => column);

  GeneratedColumn<int> get localVersion => $composableBuilder(
    column: $table.localVersion,
    builder: (column) => column,
  );

  GeneratedColumn<int> get remoteVersion => $composableBuilder(
    column: $table.remoteVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get localPayloadJson => $composableBuilder(
    column: $table.localPayloadJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get remotePayloadJson => $composableBuilder(
    column: $table.remotePayloadJson,
    builder: (column) => column,
  );

  GeneratedColumn<int> get detectedAtMs => $composableBuilder(
    column: $table.detectedAtMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get resolvedAtMs => $composableBuilder(
    column: $table.resolvedAtMs,
    builder: (column) => column,
  );
}

class $$SyncConflictsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyncConflictsTable,
          SyncConflictRow,
          $$SyncConflictsTableFilterComposer,
          $$SyncConflictsTableOrderingComposer,
          $$SyncConflictsTableAnnotationComposer,
          $$SyncConflictsTableCreateCompanionBuilder,
          $$SyncConflictsTableUpdateCompanionBuilder,
          (
            SyncConflictRow,
            BaseReferences<_$AppDatabase, $SyncConflictsTable, SyncConflictRow>,
          ),
          SyncConflictRow,
          PrefetchHooks Function()
        > {
  $$SyncConflictsTableTableManager(_$AppDatabase db, $SyncConflictsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncConflictsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncConflictsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncConflictsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> serverSequence = const Value.absent(),
                Value<String> operationId = const Value.absent(),
                Value<String> entityType = const Value.absent(),
                Value<String> entityId = const Value.absent(),
                Value<String> reason = const Value.absent(),
                Value<int?> localVersion = const Value.absent(),
                Value<int> remoteVersion = const Value.absent(),
                Value<String?> localPayloadJson = const Value.absent(),
                Value<String> remotePayloadJson = const Value.absent(),
                Value<int> detectedAtMs = const Value.absent(),
                Value<int?> resolvedAtMs = const Value.absent(),
              }) => SyncConflictsCompanion(
                serverSequence: serverSequence,
                operationId: operationId,
                entityType: entityType,
                entityId: entityId,
                reason: reason,
                localVersion: localVersion,
                remoteVersion: remoteVersion,
                localPayloadJson: localPayloadJson,
                remotePayloadJson: remotePayloadJson,
                detectedAtMs: detectedAtMs,
                resolvedAtMs: resolvedAtMs,
              ),
          createCompanionCallback:
              ({
                Value<int> serverSequence = const Value.absent(),
                required String operationId,
                required String entityType,
                required String entityId,
                required String reason,
                Value<int?> localVersion = const Value.absent(),
                required int remoteVersion,
                Value<String?> localPayloadJson = const Value.absent(),
                required String remotePayloadJson,
                required int detectedAtMs,
                Value<int?> resolvedAtMs = const Value.absent(),
              }) => SyncConflictsCompanion.insert(
                serverSequence: serverSequence,
                operationId: operationId,
                entityType: entityType,
                entityId: entityId,
                reason: reason,
                localVersion: localVersion,
                remoteVersion: remoteVersion,
                localPayloadJson: localPayloadJson,
                remotePayloadJson: remotePayloadJson,
                detectedAtMs: detectedAtMs,
                resolvedAtMs: resolvedAtMs,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SyncConflictsTable, SyncConflictRow>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $SyncConflictsTable,
                    SyncConflictRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncConflictsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyncConflictsTable,
      SyncConflictRow,
      $$SyncConflictsTableFilterComposer,
      $$SyncConflictsTableOrderingComposer,
      $$SyncConflictsTableAnnotationComposer,
      $$SyncConflictsTableCreateCompanionBuilder,
      $$SyncConflictsTableUpdateCompanionBuilder,
      (
        SyncConflictRow,
        BaseReferences<_$AppDatabase, $SyncConflictsTable, SyncConflictRow>,
      ),
      SyncConflictRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$BillsTableTableManager get bills =>
      $$BillsTableTableManager(_db, _db.bills);
  $$PaymentsTableTableManager get payments =>
      $$PaymentsTableTableManager(_db, _db.payments);
  $$SyncOutboxTableTableManager get syncOutbox =>
      $$SyncOutboxTableTableManager(_db, _db.syncOutbox);
  $$SyncStatesTableTableManager get syncStates =>
      $$SyncStatesTableTableManager(_db, _db.syncStates);
  $$AppliedOperationsTableTableManager get appliedOperations =>
      $$AppliedOperationsTableTableManager(_db, _db.appliedOperations);
  $$SyncConflictsTableTableManager get syncConflicts =>
      $$SyncConflictsTableTableManager(_db, _db.syncConflicts);
}
