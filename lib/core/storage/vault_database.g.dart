// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'vault_database.dart';

// ignore_for_file: type=lint
class $VaultMetaTable extends VaultMeta
    with TableInfo<$VaultMetaTable, VaultMetaRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $VaultMetaTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL CHECK (id = 1)',
  );
  static const VerificationMeta _headerMeta = const VerificationMeta('header');
  @override
  late final GeneratedColumn<String> header = GeneratedColumn<String>(
    'header',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, header];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'vault_meta';
  @override
  VerificationContext validateIntegrity(
    Insertable<VaultMetaRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('header')) {
      context.handle(
        _headerMeta,
        header.isAcceptableOrUnknown(data['header']!, _headerMeta),
      );
    } else if (isInserting) {
      context.missing(_headerMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  VaultMetaRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return VaultMetaRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      header: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}header'],
      )!,
    );
  }

  @override
  $VaultMetaTable createAlias(String alias) {
    return $VaultMetaTable(attachedDatabase, alias);
  }
}

class VaultMetaRow extends DataClass implements Insertable<VaultMetaRow> {
  final int id;
  final String header;
  const VaultMetaRow({required this.id, required this.header});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['header'] = Variable<String>(header);
    return map;
  }

  VaultMetaCompanion toCompanion(bool nullToAbsent) {
    return VaultMetaCompanion(id: Value(id), header: Value(header));
  }

  factory VaultMetaRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return VaultMetaRow(
      id: serializer.fromJson<int>(json['id']),
      header: serializer.fromJson<String>(json['header']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'header': serializer.toJson<String>(header),
    };
  }

  VaultMetaRow copyWith({int? id, String? header}) =>
      VaultMetaRow(id: id ?? this.id, header: header ?? this.header);
  VaultMetaRow copyWithCompanion(VaultMetaCompanion data) {
    return VaultMetaRow(
      id: data.id.present ? data.id.value : this.id,
      header: data.header.present ? data.header.value : this.header,
    );
  }

  @override
  String toString() {
    return (StringBuffer('VaultMetaRow(')
          ..write('id: $id, ')
          ..write('header: $header')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, header);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is VaultMetaRow &&
          other.id == this.id &&
          other.header == this.header);
}

class VaultMetaCompanion extends UpdateCompanion<VaultMetaRow> {
  final Value<int> id;
  final Value<String> header;
  const VaultMetaCompanion({
    this.id = const Value.absent(),
    this.header = const Value.absent(),
  });
  VaultMetaCompanion.insert({
    this.id = const Value.absent(),
    required String header,
  }) : header = Value(header);
  static Insertable<VaultMetaRow> custom({
    Expression<int>? id,
    Expression<String>? header,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (header != null) 'header': header,
    });
  }

  VaultMetaCompanion copyWith({Value<int>? id, Value<String>? header}) {
    return VaultMetaCompanion(id: id ?? this.id, header: header ?? this.header);
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (header.present) {
      map['header'] = Variable<String>(header.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('VaultMetaCompanion(')
          ..write('id: $id, ')
          ..write('header: $header')
          ..write(')'))
        .toString();
  }
}

class $RecordsTable extends Records with TableInfo<$RecordsTable, RecordRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RecordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<Uint8List> id = GeneratedColumn<Uint8List>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.blob,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (length(id) = 16)',
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<Uint8List> payload = GeneratedColumn<Uint8List>(
    'blob',
    aliasedName,
    false,
    type: DriftSqlType.blob,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    type,
    payload,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'records';
  @override
  VerificationContext validateIntegrity(
    Insertable<RecordRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('blob')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['blob']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RecordRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RecordRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}id'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}blob'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $RecordsTable createAlias(String alias) {
    return $RecordsTable(attachedDatabase, alias);
  }

  @override
  bool get withoutRowId => true;
}

class RecordRow extends DataClass implements Insertable<RecordRow> {
  final Uint8List id;
  final String type;
  final Uint8List payload;
  final int createdAt;
  final int updatedAt;
  const RecordRow({
    required this.id,
    required this.type,
    required this.payload,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<Uint8List>(id);
    map['type'] = Variable<String>(type);
    map['blob'] = Variable<Uint8List>(payload);
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  RecordsCompanion toCompanion(bool nullToAbsent) {
    return RecordsCompanion(
      id: Value(id),
      type: Value(type),
      payload: Value(payload),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory RecordRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RecordRow(
      id: serializer.fromJson<Uint8List>(json['id']),
      type: serializer.fromJson<String>(json['type']),
      payload: serializer.fromJson<Uint8List>(json['payload']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<Uint8List>(id),
      'type': serializer.toJson<String>(type),
      'payload': serializer.toJson<Uint8List>(payload),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  RecordRow copyWith({
    Uint8List? id,
    String? type,
    Uint8List? payload,
    int? createdAt,
    int? updatedAt,
  }) => RecordRow(
    id: id ?? this.id,
    type: type ?? this.type,
    payload: payload ?? this.payload,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  RecordRow copyWithCompanion(RecordsCompanion data) {
    return RecordRow(
      id: data.id.present ? data.id.value : this.id,
      type: data.type.present ? data.type.value : this.type,
      payload: data.payload.present ? data.payload.value : this.payload,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RecordRow(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('payload: $payload, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    $driftBlobEquality.hash(id),
    type,
    $driftBlobEquality.hash(payload),
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RecordRow &&
          $driftBlobEquality.equals(other.id, this.id) &&
          other.type == this.type &&
          $driftBlobEquality.equals(other.payload, this.payload) &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class RecordsCompanion extends UpdateCompanion<RecordRow> {
  final Value<Uint8List> id;
  final Value<String> type;
  final Value<Uint8List> payload;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  const RecordsCompanion({
    this.id = const Value.absent(),
    this.type = const Value.absent(),
    this.payload = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  RecordsCompanion.insert({
    required Uint8List id,
    required String type,
    required Uint8List payload,
    required int createdAt,
    required int updatedAt,
  }) : id = Value(id),
       type = Value(type),
       payload = Value(payload),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<RecordRow> custom({
    Expression<Uint8List>? id,
    Expression<String>? type,
    Expression<Uint8List>? payload,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (type != null) 'type': type,
      if (payload != null) 'blob': payload,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  RecordsCompanion copyWith({
    Value<Uint8List>? id,
    Value<String>? type,
    Value<Uint8List>? payload,
    Value<int>? createdAt,
    Value<int>? updatedAt,
  }) {
    return RecordsCompanion(
      id: id ?? this.id,
      type: type ?? this.type,
      payload: payload ?? this.payload,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<Uint8List>(id.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (payload.present) {
      map['blob'] = Variable<Uint8List>(payload.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RecordsCompanion(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('payload: $payload, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $BiometricSlotTable extends BiometricSlot
    with TableInfo<$BiometricSlotTable, BiometricSlotRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BiometricSlotTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL CHECK (id = 1)',
  );
  static const VerificationMeta _ivMeta = const VerificationMeta('iv');
  @override
  late final GeneratedColumn<Uint8List> iv = GeneratedColumn<Uint8List>(
    'iv',
    aliasedName,
    false,
    type: DriftSqlType.blob,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (length(iv) = 12)',
  );
  static const VerificationMeta _cipherTextMeta = const VerificationMeta(
    'cipherText',
  );
  @override
  late final GeneratedColumn<Uint8List> cipherText = GeneratedColumn<Uint8List>(
    'cipher_text',
    aliasedName,
    false,
    type: DriftSqlType.blob,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (length(cipher_text) = 48)',
  );
  @override
  List<GeneratedColumn> get $columns => [id, iv, cipherText];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'biometric_slot';
  @override
  VerificationContext validateIntegrity(
    Insertable<BiometricSlotRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('iv')) {
      context.handle(_ivMeta, iv.isAcceptableOrUnknown(data['iv']!, _ivMeta));
    } else if (isInserting) {
      context.missing(_ivMeta);
    }
    if (data.containsKey('cipher_text')) {
      context.handle(
        _cipherTextMeta,
        cipherText.isAcceptableOrUnknown(data['cipher_text']!, _cipherTextMeta),
      );
    } else if (isInserting) {
      context.missing(_cipherTextMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  BiometricSlotRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BiometricSlotRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      iv: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}iv'],
      )!,
      cipherText: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}cipher_text'],
      )!,
    );
  }

  @override
  $BiometricSlotTable createAlias(String alias) {
    return $BiometricSlotTable(attachedDatabase, alias);
  }
}

class BiometricSlotRow extends DataClass
    implements Insertable<BiometricSlotRow> {
  final int id;
  final Uint8List iv;
  final Uint8List cipherText;
  const BiometricSlotRow({
    required this.id,
    required this.iv,
    required this.cipherText,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['iv'] = Variable<Uint8List>(iv);
    map['cipher_text'] = Variable<Uint8List>(cipherText);
    return map;
  }

  BiometricSlotCompanion toCompanion(bool nullToAbsent) {
    return BiometricSlotCompanion(
      id: Value(id),
      iv: Value(iv),
      cipherText: Value(cipherText),
    );
  }

  factory BiometricSlotRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BiometricSlotRow(
      id: serializer.fromJson<int>(json['id']),
      iv: serializer.fromJson<Uint8List>(json['iv']),
      cipherText: serializer.fromJson<Uint8List>(json['cipherText']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'iv': serializer.toJson<Uint8List>(iv),
      'cipherText': serializer.toJson<Uint8List>(cipherText),
    };
  }

  BiometricSlotRow copyWith({int? id, Uint8List? iv, Uint8List? cipherText}) =>
      BiometricSlotRow(
        id: id ?? this.id,
        iv: iv ?? this.iv,
        cipherText: cipherText ?? this.cipherText,
      );
  BiometricSlotRow copyWithCompanion(BiometricSlotCompanion data) {
    return BiometricSlotRow(
      id: data.id.present ? data.id.value : this.id,
      iv: data.iv.present ? data.iv.value : this.iv,
      cipherText: data.cipherText.present
          ? data.cipherText.value
          : this.cipherText,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BiometricSlotRow(')
          ..write('id: $id, ')
          ..write('iv: $iv, ')
          ..write('cipherText: $cipherText')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    $driftBlobEquality.hash(iv),
    $driftBlobEquality.hash(cipherText),
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BiometricSlotRow &&
          other.id == this.id &&
          $driftBlobEquality.equals(other.iv, this.iv) &&
          $driftBlobEquality.equals(other.cipherText, this.cipherText));
}

class BiometricSlotCompanion extends UpdateCompanion<BiometricSlotRow> {
  final Value<int> id;
  final Value<Uint8List> iv;
  final Value<Uint8List> cipherText;
  const BiometricSlotCompanion({
    this.id = const Value.absent(),
    this.iv = const Value.absent(),
    this.cipherText = const Value.absent(),
  });
  BiometricSlotCompanion.insert({
    this.id = const Value.absent(),
    required Uint8List iv,
    required Uint8List cipherText,
  }) : iv = Value(iv),
       cipherText = Value(cipherText);
  static Insertable<BiometricSlotRow> custom({
    Expression<int>? id,
    Expression<Uint8List>? iv,
    Expression<Uint8List>? cipherText,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (iv != null) 'iv': iv,
      if (cipherText != null) 'cipher_text': cipherText,
    });
  }

  BiometricSlotCompanion copyWith({
    Value<int>? id,
    Value<Uint8List>? iv,
    Value<Uint8List>? cipherText,
  }) {
    return BiometricSlotCompanion(
      id: id ?? this.id,
      iv: iv ?? this.iv,
      cipherText: cipherText ?? this.cipherText,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (iv.present) {
      map['iv'] = Variable<Uint8List>(iv.value);
    }
    if (cipherText.present) {
      map['cipher_text'] = Variable<Uint8List>(cipherText.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BiometricSlotCompanion(')
          ..write('id: $id, ')
          ..write('iv: $iv, ')
          ..write('cipherText: $cipherText')
          ..write(')'))
        .toString();
  }
}

class $UnlockStateTable extends UnlockState
    with TableInfo<$UnlockStateTable, UnlockStateRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UnlockStateTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL CHECK (id = 1)',
  );
  static const VerificationMeta _failedAttemptsMeta = const VerificationMeta(
    'failedAttempts',
  );
  @override
  late final GeneratedColumn<int> failedAttempts = GeneratedColumn<int>(
    'failed_attempts',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastFailedAtMeta = const VerificationMeta(
    'lastFailedAt',
  );
  @override
  late final GeneratedColumn<int> lastFailedAt = GeneratedColumn<int>(
    'last_failed_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, failedAttempts, lastFailedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'unlock_state';
  @override
  VerificationContext validateIntegrity(
    Insertable<UnlockStateRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('failed_attempts')) {
      context.handle(
        _failedAttemptsMeta,
        failedAttempts.isAcceptableOrUnknown(
          data['failed_attempts']!,
          _failedAttemptsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_failedAttemptsMeta);
    }
    if (data.containsKey('last_failed_at')) {
      context.handle(
        _lastFailedAtMeta,
        lastFailedAt.isAcceptableOrUnknown(
          data['last_failed_at']!,
          _lastFailedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastFailedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  UnlockStateRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UnlockStateRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      failedAttempts: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}failed_attempts'],
      )!,
      lastFailedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_failed_at'],
      )!,
    );
  }

  @override
  $UnlockStateTable createAlias(String alias) {
    return $UnlockStateTable(attachedDatabase, alias);
  }
}

class UnlockStateRow extends DataClass implements Insertable<UnlockStateRow> {
  final int id;
  final int failedAttempts;
  final int lastFailedAt;
  const UnlockStateRow({
    required this.id,
    required this.failedAttempts,
    required this.lastFailedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['failed_attempts'] = Variable<int>(failedAttempts);
    map['last_failed_at'] = Variable<int>(lastFailedAt);
    return map;
  }

  UnlockStateCompanion toCompanion(bool nullToAbsent) {
    return UnlockStateCompanion(
      id: Value(id),
      failedAttempts: Value(failedAttempts),
      lastFailedAt: Value(lastFailedAt),
    );
  }

  factory UnlockStateRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UnlockStateRow(
      id: serializer.fromJson<int>(json['id']),
      failedAttempts: serializer.fromJson<int>(json['failedAttempts']),
      lastFailedAt: serializer.fromJson<int>(json['lastFailedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'failedAttempts': serializer.toJson<int>(failedAttempts),
      'lastFailedAt': serializer.toJson<int>(lastFailedAt),
    };
  }

  UnlockStateRow copyWith({int? id, int? failedAttempts, int? lastFailedAt}) =>
      UnlockStateRow(
        id: id ?? this.id,
        failedAttempts: failedAttempts ?? this.failedAttempts,
        lastFailedAt: lastFailedAt ?? this.lastFailedAt,
      );
  UnlockStateRow copyWithCompanion(UnlockStateCompanion data) {
    return UnlockStateRow(
      id: data.id.present ? data.id.value : this.id,
      failedAttempts: data.failedAttempts.present
          ? data.failedAttempts.value
          : this.failedAttempts,
      lastFailedAt: data.lastFailedAt.present
          ? data.lastFailedAt.value
          : this.lastFailedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UnlockStateRow(')
          ..write('id: $id, ')
          ..write('failedAttempts: $failedAttempts, ')
          ..write('lastFailedAt: $lastFailedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, failedAttempts, lastFailedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UnlockStateRow &&
          other.id == this.id &&
          other.failedAttempts == this.failedAttempts &&
          other.lastFailedAt == this.lastFailedAt);
}

class UnlockStateCompanion extends UpdateCompanion<UnlockStateRow> {
  final Value<int> id;
  final Value<int> failedAttempts;
  final Value<int> lastFailedAt;
  const UnlockStateCompanion({
    this.id = const Value.absent(),
    this.failedAttempts = const Value.absent(),
    this.lastFailedAt = const Value.absent(),
  });
  UnlockStateCompanion.insert({
    this.id = const Value.absent(),
    required int failedAttempts,
    required int lastFailedAt,
  }) : failedAttempts = Value(failedAttempts),
       lastFailedAt = Value(lastFailedAt);
  static Insertable<UnlockStateRow> custom({
    Expression<int>? id,
    Expression<int>? failedAttempts,
    Expression<int>? lastFailedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (failedAttempts != null) 'failed_attempts': failedAttempts,
      if (lastFailedAt != null) 'last_failed_at': lastFailedAt,
    });
  }

  UnlockStateCompanion copyWith({
    Value<int>? id,
    Value<int>? failedAttempts,
    Value<int>? lastFailedAt,
  }) {
    return UnlockStateCompanion(
      id: id ?? this.id,
      failedAttempts: failedAttempts ?? this.failedAttempts,
      lastFailedAt: lastFailedAt ?? this.lastFailedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (failedAttempts.present) {
      map['failed_attempts'] = Variable<int>(failedAttempts.value);
    }
    if (lastFailedAt.present) {
      map['last_failed_at'] = Variable<int>(lastFailedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UnlockStateCompanion(')
          ..write('id: $id, ')
          ..write('failedAttempts: $failedAttempts, ')
          ..write('lastFailedAt: $lastFailedAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$VaultDatabase extends GeneratedDatabase {
  _$VaultDatabase(QueryExecutor e) : super(e);
  $VaultDatabaseManager get managers => $VaultDatabaseManager(this);
  late final $VaultMetaTable vaultMeta = $VaultMetaTable(this);
  late final $RecordsTable records = $RecordsTable(this);
  late final $BiometricSlotTable biometricSlot = $BiometricSlotTable(this);
  late final $UnlockStateTable unlockState = $UnlockStateTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    vaultMeta,
    records,
    biometricSlot,
    unlockState,
  ];
}

typedef $$VaultMetaTableCreateCompanionBuilder = VaultMetaCompanion Function({
  Value<int> id,
  required String header,
});
typedef $$VaultMetaTableUpdateCompanionBuilder = VaultMetaCompanion Function({
  Value<int> id,
  Value<String> header,
});

class $$VaultMetaTableFilterComposer
    extends Composer<_$VaultDatabase, $VaultMetaTable> {
  $$VaultMetaTableFilterComposer({
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

  ColumnFilters<String> get header => $composableBuilder(
    column: $table.header,
    builder: (column) => ColumnFilters(column),
  );
}

class $$VaultMetaTableOrderingComposer
    extends Composer<_$VaultDatabase, $VaultMetaTable> {
  $$VaultMetaTableOrderingComposer({
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

  ColumnOrderings<String> get header => $composableBuilder(
    column: $table.header,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$VaultMetaTableAnnotationComposer
    extends Composer<_$VaultDatabase, $VaultMetaTable> {
  $$VaultMetaTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get header =>
      $composableBuilder(column: $table.header, builder: (column) => column);
}

class $$VaultMetaTableTableManager
    extends
        RootTableManager<
          _$VaultDatabase,
          $VaultMetaTable,
          VaultMetaRow,
          $$VaultMetaTableFilterComposer,
          $$VaultMetaTableOrderingComposer,
          $$VaultMetaTableAnnotationComposer,
          $$VaultMetaTableCreateCompanionBuilder,
          $$VaultMetaTableUpdateCompanionBuilder,
          (
            VaultMetaRow,
            BaseReferences<_$VaultDatabase, $VaultMetaTable, VaultMetaRow>,
          ),
          VaultMetaRow,
          PrefetchHooks Function()
        > {
  $$VaultMetaTableTableManager(_$VaultDatabase db, $VaultMetaTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$VaultMetaTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$VaultMetaTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$VaultMetaTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> header = const Value.absent(),
          }) => VaultMetaCompanion(id: id, header: header),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String header,
          }) => VaultMetaCompanion.insert(id: id, header: header),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$VaultMetaTable, VaultMetaRow>(table),
                  BaseReferences<
                    _$VaultDatabase,
                    $VaultMetaTable,
                    VaultMetaRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$VaultMetaTableProcessedTableManager =
    ProcessedTableManager<
      _$VaultDatabase,
      $VaultMetaTable,
      VaultMetaRow,
      $$VaultMetaTableFilterComposer,
      $$VaultMetaTableOrderingComposer,
      $$VaultMetaTableAnnotationComposer,
      $$VaultMetaTableCreateCompanionBuilder,
      $$VaultMetaTableUpdateCompanionBuilder,
      (
        VaultMetaRow,
        BaseReferences<_$VaultDatabase, $VaultMetaTable, VaultMetaRow>,
      ),
      VaultMetaRow,
      PrefetchHooks Function()
    >;
typedef $$RecordsTableCreateCompanionBuilder = RecordsCompanion Function({
  required Uint8List id,
  required String type,
  required Uint8List payload,
  required int createdAt,
  required int updatedAt,
});
typedef $$RecordsTableUpdateCompanionBuilder = RecordsCompanion Function({
  Value<Uint8List> id,
  Value<String> type,
  Value<Uint8List> payload,
  Value<int> createdAt,
  Value<int> updatedAt,
});

class $$RecordsTableFilterComposer
    extends Composer<_$VaultDatabase, $RecordsTable> {
  $$RecordsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<Uint8List> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RecordsTableOrderingComposer
    extends Composer<_$VaultDatabase, $RecordsTable> {
  $$RecordsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<Uint8List> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RecordsTableAnnotationComposer
    extends Composer<_$VaultDatabase, $RecordsTable> {
  $$RecordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<Uint8List> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<Uint8List> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$RecordsTableTableManager
    extends
        RootTableManager<
          _$VaultDatabase,
          $RecordsTable,
          RecordRow,
          $$RecordsTableFilterComposer,
          $$RecordsTableOrderingComposer,
          $$RecordsTableAnnotationComposer,
          $$RecordsTableCreateCompanionBuilder,
          $$RecordsTableUpdateCompanionBuilder,
          (
            RecordRow,
            BaseReferences<_$VaultDatabase, $RecordsTable, RecordRow>,
          ),
          RecordRow,
          PrefetchHooks Function()
        > {
  $$RecordsTableTableManager(_$VaultDatabase db, $RecordsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RecordsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RecordsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RecordsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<Uint8List> id = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<Uint8List> payload = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
              }) => RecordsCompanion(
                id: id,
                type: type,
                payload: payload,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                required Uint8List id,
                required String type,
                required Uint8List payload,
                required int createdAt,
                required int updatedAt,
              }) => RecordsCompanion.insert(
                id: id,
                type: type,
                payload: payload,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$RecordsTable, RecordRow>(table),
                  BaseReferences<_$VaultDatabase, $RecordsTable, RecordRow>(
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

typedef $$RecordsTableProcessedTableManager =
    ProcessedTableManager<
      _$VaultDatabase,
      $RecordsTable,
      RecordRow,
      $$RecordsTableFilterComposer,
      $$RecordsTableOrderingComposer,
      $$RecordsTableAnnotationComposer,
      $$RecordsTableCreateCompanionBuilder,
      $$RecordsTableUpdateCompanionBuilder,
      (RecordRow, BaseReferences<_$VaultDatabase, $RecordsTable, RecordRow>),
      RecordRow,
      PrefetchHooks Function()
    >;
typedef $$BiometricSlotTableCreateCompanionBuilder =
    BiometricSlotCompanion Function({
      Value<int> id,
      required Uint8List iv,
      required Uint8List cipherText,
    });
typedef $$BiometricSlotTableUpdateCompanionBuilder =
    BiometricSlotCompanion Function({
      Value<int> id,
      Value<Uint8List> iv,
      Value<Uint8List> cipherText,
    });

class $$BiometricSlotTableFilterComposer
    extends Composer<_$VaultDatabase, $BiometricSlotTable> {
  $$BiometricSlotTableFilterComposer({
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

  ColumnFilters<Uint8List> get iv => $composableBuilder(
    column: $table.iv,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get cipherText => $composableBuilder(
    column: $table.cipherText,
    builder: (column) => ColumnFilters(column),
  );
}

class $$BiometricSlotTableOrderingComposer
    extends Composer<_$VaultDatabase, $BiometricSlotTable> {
  $$BiometricSlotTableOrderingComposer({
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

  ColumnOrderings<Uint8List> get iv => $composableBuilder(
    column: $table.iv,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get cipherText => $composableBuilder(
    column: $table.cipherText,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BiometricSlotTableAnnotationComposer
    extends Composer<_$VaultDatabase, $BiometricSlotTable> {
  $$BiometricSlotTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<Uint8List> get iv =>
      $composableBuilder(column: $table.iv, builder: (column) => column);

  GeneratedColumn<Uint8List> get cipherText => $composableBuilder(
    column: $table.cipherText,
    builder: (column) => column,
  );
}

class $$BiometricSlotTableTableManager
    extends
        RootTableManager<
          _$VaultDatabase,
          $BiometricSlotTable,
          BiometricSlotRow,
          $$BiometricSlotTableFilterComposer,
          $$BiometricSlotTableOrderingComposer,
          $$BiometricSlotTableAnnotationComposer,
          $$BiometricSlotTableCreateCompanionBuilder,
          $$BiometricSlotTableUpdateCompanionBuilder,
          (
            BiometricSlotRow,
            BaseReferences<
              _$VaultDatabase,
              $BiometricSlotTable,
              BiometricSlotRow
            >,
          ),
          BiometricSlotRow,
          PrefetchHooks Function()
        > {
  $$BiometricSlotTableTableManager(
    _$VaultDatabase db,
    $BiometricSlotTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BiometricSlotTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BiometricSlotTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BiometricSlotTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<Uint8List> iv = const Value.absent(),
            Value<Uint8List> cipherText = const Value.absent(),
          }) => BiometricSlotCompanion(id: id, iv: iv, cipherText: cipherText),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required Uint8List iv,
                required Uint8List cipherText,
              }) => BiometricSlotCompanion.insert(
                id: id,
                iv: iv,
                cipherText: cipherText,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$BiometricSlotTable, BiometricSlotRow>(table),
                  BaseReferences<
                    _$VaultDatabase,
                    $BiometricSlotTable,
                    BiometricSlotRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$BiometricSlotTableProcessedTableManager =
    ProcessedTableManager<
      _$VaultDatabase,
      $BiometricSlotTable,
      BiometricSlotRow,
      $$BiometricSlotTableFilterComposer,
      $$BiometricSlotTableOrderingComposer,
      $$BiometricSlotTableAnnotationComposer,
      $$BiometricSlotTableCreateCompanionBuilder,
      $$BiometricSlotTableUpdateCompanionBuilder,
      (
        BiometricSlotRow,
        BaseReferences<_$VaultDatabase, $BiometricSlotTable, BiometricSlotRow>,
      ),
      BiometricSlotRow,
      PrefetchHooks Function()
    >;
typedef $$UnlockStateTableCreateCompanionBuilder =
    UnlockStateCompanion Function({
      Value<int> id,
      required int failedAttempts,
      required int lastFailedAt,
    });
typedef $$UnlockStateTableUpdateCompanionBuilder =
    UnlockStateCompanion Function({
      Value<int> id,
      Value<int> failedAttempts,
      Value<int> lastFailedAt,
    });

class $$UnlockStateTableFilterComposer
    extends Composer<_$VaultDatabase, $UnlockStateTable> {
  $$UnlockStateTableFilterComposer({
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

  ColumnFilters<int> get failedAttempts => $composableBuilder(
    column: $table.failedAttempts,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastFailedAt => $composableBuilder(
    column: $table.lastFailedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$UnlockStateTableOrderingComposer
    extends Composer<_$VaultDatabase, $UnlockStateTable> {
  $$UnlockStateTableOrderingComposer({
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

  ColumnOrderings<int> get failedAttempts => $composableBuilder(
    column: $table.failedAttempts,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastFailedAt => $composableBuilder(
    column: $table.lastFailedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$UnlockStateTableAnnotationComposer
    extends Composer<_$VaultDatabase, $UnlockStateTable> {
  $$UnlockStateTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get failedAttempts => $composableBuilder(
    column: $table.failedAttempts,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lastFailedAt => $composableBuilder(
    column: $table.lastFailedAt,
    builder: (column) => column,
  );
}

class $$UnlockStateTableTableManager
    extends
        RootTableManager<
          _$VaultDatabase,
          $UnlockStateTable,
          UnlockStateRow,
          $$UnlockStateTableFilterComposer,
          $$UnlockStateTableOrderingComposer,
          $$UnlockStateTableAnnotationComposer,
          $$UnlockStateTableCreateCompanionBuilder,
          $$UnlockStateTableUpdateCompanionBuilder,
          (
            UnlockStateRow,
            BaseReferences<_$VaultDatabase, $UnlockStateTable, UnlockStateRow>,
          ),
          UnlockStateRow,
          PrefetchHooks Function()
        > {
  $$UnlockStateTableTableManager(_$VaultDatabase db, $UnlockStateTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UnlockStateTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UnlockStateTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$UnlockStateTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> failedAttempts = const Value.absent(),
                Value<int> lastFailedAt = const Value.absent(),
              }) => UnlockStateCompanion(
                id: id,
                failedAttempts: failedAttempts,
                lastFailedAt: lastFailedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int failedAttempts,
                required int lastFailedAt,
              }) => UnlockStateCompanion.insert(
                id: id,
                failedAttempts: failedAttempts,
                lastFailedAt: lastFailedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$UnlockStateTable, UnlockStateRow>(table),
                  BaseReferences<
                    _$VaultDatabase,
                    $UnlockStateTable,
                    UnlockStateRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$UnlockStateTableProcessedTableManager =
    ProcessedTableManager<
      _$VaultDatabase,
      $UnlockStateTable,
      UnlockStateRow,
      $$UnlockStateTableFilterComposer,
      $$UnlockStateTableOrderingComposer,
      $$UnlockStateTableAnnotationComposer,
      $$UnlockStateTableCreateCompanionBuilder,
      $$UnlockStateTableUpdateCompanionBuilder,
      (
        UnlockStateRow,
        BaseReferences<_$VaultDatabase, $UnlockStateTable, UnlockStateRow>,
      ),
      UnlockStateRow,
      PrefetchHooks Function()
    >;

class $VaultDatabaseManager {
  final _$VaultDatabase _db;
  $VaultDatabaseManager(this._db);
  $$VaultMetaTableTableManager get vaultMeta =>
      $$VaultMetaTableTableManager(_db, _db.vaultMeta);
  $$RecordsTableTableManager get records =>
      $$RecordsTableTableManager(_db, _db.records);
  $$BiometricSlotTableTableManager get biometricSlot =>
      $$BiometricSlotTableTableManager(_db, _db.biometricSlot);
  $$UnlockStateTableTableManager get unlockState =>
      $$UnlockStateTableTableManager(_db, _db.unlockState);
}
