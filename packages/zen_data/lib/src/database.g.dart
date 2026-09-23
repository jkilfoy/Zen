// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class Settings extends Table with TableInfo<Settings, SettingRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  Settings(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _settingKeyMeta = const VerificationMeta(
    'settingKey',
  );
  late final GeneratedColumn<String> settingKey = GeneratedColumn<String>(
    'setting_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL PRIMARY KEY',
  );
  static const VerificationMeta _settingValueMeta = const VerificationMeta(
    'settingValue',
  );
  late final GeneratedColumn<String> settingValue = GeneratedColumn<String>(
    'setting_value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  @override
  List<GeneratedColumn> get $columns => [settingKey, settingValue];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<SettingRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('setting_key')) {
      context.handle(
        _settingKeyMeta,
        settingKey.isAcceptableOrUnknown(data['setting_key']!, _settingKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_settingKeyMeta);
    }
    if (data.containsKey('setting_value')) {
      context.handle(
        _settingValueMeta,
        settingValue.isAcceptableOrUnknown(
          data['setting_value']!,
          _settingValueMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_settingValueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {settingKey};
  @override
  SettingRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SettingRow(
      settingKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}setting_key'],
      )!,
      settingValue: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}setting_value'],
      )!,
    );
  }

  @override
  Settings createAlias(String alias) {
    return Settings(attachedDatabase, alias);
  }

  @override
  bool get isStrict => true;
  @override
  bool get dontWriteConstraints => true;
}

class SettingRow extends DataClass implements Insertable<SettingRow> {
  /// Named `setting_key` rather than `key`, which is a SQL keyword.
  final String settingKey;
  final String settingValue;
  const SettingRow({required this.settingKey, required this.settingValue});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['setting_key'] = Variable<String>(settingKey);
    map['setting_value'] = Variable<String>(settingValue);
    return map;
  }

  SettingsCompanion toCompanion(bool nullToAbsent) {
    return SettingsCompanion(
      settingKey: Value(settingKey),
      settingValue: Value(settingValue),
    );
  }

  factory SettingRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SettingRow(
      settingKey: serializer.fromJson<String>(json['setting_key']),
      settingValue: serializer.fromJson<String>(json['setting_value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'setting_key': serializer.toJson<String>(settingKey),
      'setting_value': serializer.toJson<String>(settingValue),
    };
  }

  SettingRow copyWith({String? settingKey, String? settingValue}) => SettingRow(
    settingKey: settingKey ?? this.settingKey,
    settingValue: settingValue ?? this.settingValue,
  );
  SettingRow copyWithCompanion(SettingsCompanion data) {
    return SettingRow(
      settingKey: data.settingKey.present
          ? data.settingKey.value
          : this.settingKey,
      settingValue: data.settingValue.present
          ? data.settingValue.value
          : this.settingValue,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SettingRow(')
          ..write('settingKey: $settingKey, ')
          ..write('settingValue: $settingValue')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(settingKey, settingValue);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SettingRow &&
          other.settingKey == this.settingKey &&
          other.settingValue == this.settingValue);
}

class SettingsCompanion extends UpdateCompanion<SettingRow> {
  final Value<String> settingKey;
  final Value<String> settingValue;
  final Value<int> rowid;
  const SettingsCompanion({
    this.settingKey = const Value.absent(),
    this.settingValue = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SettingsCompanion.insert({
    required String settingKey,
    required String settingValue,
    this.rowid = const Value.absent(),
  }) : settingKey = Value(settingKey),
       settingValue = Value(settingValue);
  static Insertable<SettingRow> custom({
    Expression<String>? settingKey,
    Expression<String>? settingValue,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (settingKey != null) 'setting_key': settingKey,
      if (settingValue != null) 'setting_value': settingValue,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SettingsCompanion copyWith({
    Value<String>? settingKey,
    Value<String>? settingValue,
    Value<int>? rowid,
  }) {
    return SettingsCompanion(
      settingKey: settingKey ?? this.settingKey,
      settingValue: settingValue ?? this.settingValue,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (settingKey.present) {
      map['setting_key'] = Variable<String>(settingKey.value);
    }
    if (settingValue.present) {
      map['setting_value'] = Variable<String>(settingValue.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SettingsCompanion(')
          ..write('settingKey: $settingKey, ')
          ..write('settingValue: $settingValue, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class Replica extends Table with TableInfo<Replica, ReplicaRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  Replica(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL PRIMARY KEY',
  );
  static const VerificationMeta _replicaIdMeta = const VerificationMeta(
    'replicaId',
  );
  late final GeneratedColumn<String> replicaId = GeneratedColumn<String>(
    'replica_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _deviceNameMeta = const VerificationMeta(
    'deviceName',
  );
  late final GeneratedColumn<String> deviceName = GeneratedColumn<String>(
    'device_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  @override
  List<GeneratedColumn> get $columns => [id, replicaId, deviceName];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'replica';
  @override
  VerificationContext validateIntegrity(
    Insertable<ReplicaRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('replica_id')) {
      context.handle(
        _replicaIdMeta,
        replicaId.isAcceptableOrUnknown(data['replica_id']!, _replicaIdMeta),
      );
    } else if (isInserting) {
      context.missing(_replicaIdMeta);
    }
    if (data.containsKey('device_name')) {
      context.handle(
        _deviceNameMeta,
        deviceName.isAcceptableOrUnknown(data['device_name']!, _deviceNameMeta),
      );
    } else if (isInserting) {
      context.missing(_deviceNameMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ReplicaRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ReplicaRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      replicaId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}replica_id'],
      )!,
      deviceName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_name'],
      )!,
    );
  }

  @override
  Replica createAlias(String alias) {
    return Replica(attachedDatabase, alias);
  }

  @override
  bool get isStrict => true;
  @override
  List<String> get customConstraints => const [
    'CONSTRAINT single_row_replica CHECK(id = 1)',
    'CONSTRAINT replica_id_present CHECK(replica_id <> \'\')',
  ];
  @override
  bool get dontWriteConstraints => true;
}

class ReplicaRow extends DataClass implements Insertable<ReplicaRow> {
  final int id;
  final String replicaId;
  final String deviceName;
  const ReplicaRow({
    required this.id,
    required this.replicaId,
    required this.deviceName,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['replica_id'] = Variable<String>(replicaId);
    map['device_name'] = Variable<String>(deviceName);
    return map;
  }

  ReplicaCompanion toCompanion(bool nullToAbsent) {
    return ReplicaCompanion(
      id: Value(id),
      replicaId: Value(replicaId),
      deviceName: Value(deviceName),
    );
  }

  factory ReplicaRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ReplicaRow(
      id: serializer.fromJson<int>(json['id']),
      replicaId: serializer.fromJson<String>(json['replica_id']),
      deviceName: serializer.fromJson<String>(json['device_name']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'replica_id': serializer.toJson<String>(replicaId),
      'device_name': serializer.toJson<String>(deviceName),
    };
  }

  ReplicaRow copyWith({int? id, String? replicaId, String? deviceName}) =>
      ReplicaRow(
        id: id ?? this.id,
        replicaId: replicaId ?? this.replicaId,
        deviceName: deviceName ?? this.deviceName,
      );
  ReplicaRow copyWithCompanion(ReplicaCompanion data) {
    return ReplicaRow(
      id: data.id.present ? data.id.value : this.id,
      replicaId: data.replicaId.present ? data.replicaId.value : this.replicaId,
      deviceName: data.deviceName.present
          ? data.deviceName.value
          : this.deviceName,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ReplicaRow(')
          ..write('id: $id, ')
          ..write('replicaId: $replicaId, ')
          ..write('deviceName: $deviceName')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, replicaId, deviceName);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReplicaRow &&
          other.id == this.id &&
          other.replicaId == this.replicaId &&
          other.deviceName == this.deviceName);
}

class ReplicaCompanion extends UpdateCompanion<ReplicaRow> {
  final Value<int> id;
  final Value<String> replicaId;
  final Value<String> deviceName;
  const ReplicaCompanion({
    this.id = const Value.absent(),
    this.replicaId = const Value.absent(),
    this.deviceName = const Value.absent(),
  });
  ReplicaCompanion.insert({
    this.id = const Value.absent(),
    required String replicaId,
    required String deviceName,
  }) : replicaId = Value(replicaId),
       deviceName = Value(deviceName);
  static Insertable<ReplicaRow> custom({
    Expression<int>? id,
    Expression<String>? replicaId,
    Expression<String>? deviceName,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (replicaId != null) 'replica_id': replicaId,
      if (deviceName != null) 'device_name': deviceName,
    });
  }

  ReplicaCompanion copyWith({
    Value<int>? id,
    Value<String>? replicaId,
    Value<String>? deviceName,
  }) {
    return ReplicaCompanion(
      id: id ?? this.id,
      replicaId: replicaId ?? this.replicaId,
      deviceName: deviceName ?? this.deviceName,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (replicaId.present) {
      map['replica_id'] = Variable<String>(replicaId.value);
    }
    if (deviceName.present) {
      map['device_name'] = Variable<String>(deviceName.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ReplicaCompanion(')
          ..write('id: $id, ')
          ..write('replicaId: $replicaId, ')
          ..write('deviceName: $deviceName')
          ..write(')'))
        .toString();
  }
}

class Events extends Table with TableInfo<Events, EventRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  Events(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _eventIdMeta = const VerificationMeta(
    'eventId',
  );
  late final GeneratedColumn<String> eventId = GeneratedColumn<String>(
    'event_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL PRIMARY KEY',
  );
  static const VerificationMeta _itemIdMeta = const VerificationMeta('itemId');
  late final GeneratedColumn<String> itemId = GeneratedColumn<String>(
    'item_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _itemKindMeta = const VerificationMeta(
    'itemKind',
  );
  late final GeneratedColumn<String> itemKind = GeneratedColumn<String>(
    'item_kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _timestampMeta = const VerificationMeta(
    'timestamp',
  );
  late final GeneratedColumn<String> timestamp = GeneratedColumn<String>(
    'timestamp',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT \'{}\'',
    defaultValue: const CustomExpression('\'{}\''),
  );
  @override
  List<GeneratedColumn> get $columns => [
    eventId,
    itemId,
    itemKind,
    type,
    timestamp,
    payload,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'events';
  @override
  VerificationContext validateIntegrity(
    Insertable<EventRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('event_id')) {
      context.handle(
        _eventIdMeta,
        eventId.isAcceptableOrUnknown(data['event_id']!, _eventIdMeta),
      );
    } else if (isInserting) {
      context.missing(_eventIdMeta);
    }
    if (data.containsKey('item_id')) {
      context.handle(
        _itemIdMeta,
        itemId.isAcceptableOrUnknown(data['item_id']!, _itemIdMeta),
      );
    } else if (isInserting) {
      context.missing(_itemIdMeta);
    }
    if (data.containsKey('item_kind')) {
      context.handle(
        _itemKindMeta,
        itemKind.isAcceptableOrUnknown(data['item_kind']!, _itemKindMeta),
      );
    } else if (isInserting) {
      context.missing(_itemKindMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('timestamp')) {
      context.handle(
        _timestampMeta,
        timestamp.isAcceptableOrUnknown(data['timestamp']!, _timestampMeta),
      );
    } else if (isInserting) {
      context.missing(_timestampMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {eventId};
  @override
  EventRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EventRow(
      eventId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}event_id'],
      )!,
      itemId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}item_id'],
      )!,
      itemKind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}item_kind'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      timestamp: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}timestamp'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
    );
  }

  @override
  Events createAlias(String alias) {
    return Events(attachedDatabase, alias);
  }

  @override
  bool get isStrict => true;
  @override
  List<String> get customConstraints => const [
    'CONSTRAINT inv9_events_timestamp CHECK(length(timestamp) = 24 AND timestamp LIKE \'%Z\')',
    'CONSTRAINT item_kind_events CHECK(item_kind IN (\'idea\', \'task\'))',
  ];
  @override
  bool get dontWriteConstraints => true;
}

class EventRow extends DataClass implements Insertable<EventRow> {
  final String eventId;
  final String itemId;

  /// ItemKind.name: 'idea' | 'task'.
  final String itemKind;

  /// ItemEventType.name.
  final String type;
  final String timestamp;

  /// HIST-2 specifies a payload without specifying its shape, and the MVP never
  /// reads it back, so it is stored as JSON.
  final String payload;
  const EventRow({
    required this.eventId,
    required this.itemId,
    required this.itemKind,
    required this.type,
    required this.timestamp,
    required this.payload,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['event_id'] = Variable<String>(eventId);
    map['item_id'] = Variable<String>(itemId);
    map['item_kind'] = Variable<String>(itemKind);
    map['type'] = Variable<String>(type);
    map['timestamp'] = Variable<String>(timestamp);
    map['payload'] = Variable<String>(payload);
    return map;
  }

  EventsCompanion toCompanion(bool nullToAbsent) {
    return EventsCompanion(
      eventId: Value(eventId),
      itemId: Value(itemId),
      itemKind: Value(itemKind),
      type: Value(type),
      timestamp: Value(timestamp),
      payload: Value(payload),
    );
  }

  factory EventRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EventRow(
      eventId: serializer.fromJson<String>(json['event_id']),
      itemId: serializer.fromJson<String>(json['item_id']),
      itemKind: serializer.fromJson<String>(json['item_kind']),
      type: serializer.fromJson<String>(json['type']),
      timestamp: serializer.fromJson<String>(json['timestamp']),
      payload: serializer.fromJson<String>(json['payload']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'event_id': serializer.toJson<String>(eventId),
      'item_id': serializer.toJson<String>(itemId),
      'item_kind': serializer.toJson<String>(itemKind),
      'type': serializer.toJson<String>(type),
      'timestamp': serializer.toJson<String>(timestamp),
      'payload': serializer.toJson<String>(payload),
    };
  }

  EventRow copyWith({
    String? eventId,
    String? itemId,
    String? itemKind,
    String? type,
    String? timestamp,
    String? payload,
  }) => EventRow(
    eventId: eventId ?? this.eventId,
    itemId: itemId ?? this.itemId,
    itemKind: itemKind ?? this.itemKind,
    type: type ?? this.type,
    timestamp: timestamp ?? this.timestamp,
    payload: payload ?? this.payload,
  );
  EventRow copyWithCompanion(EventsCompanion data) {
    return EventRow(
      eventId: data.eventId.present ? data.eventId.value : this.eventId,
      itemId: data.itemId.present ? data.itemId.value : this.itemId,
      itemKind: data.itemKind.present ? data.itemKind.value : this.itemKind,
      type: data.type.present ? data.type.value : this.type,
      timestamp: data.timestamp.present ? data.timestamp.value : this.timestamp,
      payload: data.payload.present ? data.payload.value : this.payload,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EventRow(')
          ..write('eventId: $eventId, ')
          ..write('itemId: $itemId, ')
          ..write('itemKind: $itemKind, ')
          ..write('type: $type, ')
          ..write('timestamp: $timestamp, ')
          ..write('payload: $payload')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(eventId, itemId, itemKind, type, timestamp, payload);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventRow &&
          other.eventId == this.eventId &&
          other.itemId == this.itemId &&
          other.itemKind == this.itemKind &&
          other.type == this.type &&
          other.timestamp == this.timestamp &&
          other.payload == this.payload);
}

class EventsCompanion extends UpdateCompanion<EventRow> {
  final Value<String> eventId;
  final Value<String> itemId;
  final Value<String> itemKind;
  final Value<String> type;
  final Value<String> timestamp;
  final Value<String> payload;
  final Value<int> rowid;
  const EventsCompanion({
    this.eventId = const Value.absent(),
    this.itemId = const Value.absent(),
    this.itemKind = const Value.absent(),
    this.type = const Value.absent(),
    this.timestamp = const Value.absent(),
    this.payload = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  EventsCompanion.insert({
    required String eventId,
    required String itemId,
    required String itemKind,
    required String type,
    required String timestamp,
    this.payload = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : eventId = Value(eventId),
       itemId = Value(itemId),
       itemKind = Value(itemKind),
       type = Value(type),
       timestamp = Value(timestamp);
  static Insertable<EventRow> custom({
    Expression<String>? eventId,
    Expression<String>? itemId,
    Expression<String>? itemKind,
    Expression<String>? type,
    Expression<String>? timestamp,
    Expression<String>? payload,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (eventId != null) 'event_id': eventId,
      if (itemId != null) 'item_id': itemId,
      if (itemKind != null) 'item_kind': itemKind,
      if (type != null) 'type': type,
      if (timestamp != null) 'timestamp': timestamp,
      if (payload != null) 'payload': payload,
      if (rowid != null) 'rowid': rowid,
    });
  }

  EventsCompanion copyWith({
    Value<String>? eventId,
    Value<String>? itemId,
    Value<String>? itemKind,
    Value<String>? type,
    Value<String>? timestamp,
    Value<String>? payload,
    Value<int>? rowid,
  }) {
    return EventsCompanion(
      eventId: eventId ?? this.eventId,
      itemId: itemId ?? this.itemId,
      itemKind: itemKind ?? this.itemKind,
      type: type ?? this.type,
      timestamp: timestamp ?? this.timestamp,
      payload: payload ?? this.payload,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (eventId.present) {
      map['event_id'] = Variable<String>(eventId.value);
    }
    if (itemId.present) {
      map['item_id'] = Variable<String>(itemId.value);
    }
    if (itemKind.present) {
      map['item_kind'] = Variable<String>(itemKind.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (timestamp.present) {
      map['timestamp'] = Variable<String>(timestamp.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EventsCompanion(')
          ..write('eventId: $eventId, ')
          ..write('itemId: $itemId, ')
          ..write('itemKind: $itemKind, ')
          ..write('type: $type, ')
          ..write('timestamp: $timestamp, ')
          ..write('payload: $payload, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class IdeaTombstones extends Table
    with TableInfo<IdeaTombstones, IdeaTombstoneRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  IdeaTombstones(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL PRIMARY KEY',
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  late final GeneratedColumn<String> deletedAt = GeneratedColumn<String>(
    'deleted_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _reasonMeta = const VerificationMeta('reason');
  late final GeneratedColumn<String> reason = GeneratedColumn<String>(
    'reason',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  @override
  List<GeneratedColumn> get $columns => [id, deletedAt, reason];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'idea_tombstones';
  @override
  VerificationContext validateIntegrity(
    Insertable<IdeaTombstoneRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_deletedAtMeta);
    }
    if (data.containsKey('reason')) {
      context.handle(
        _reasonMeta,
        reason.isAcceptableOrUnknown(data['reason']!, _reasonMeta),
      );
    } else if (isInserting) {
      context.missing(_reasonMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  IdeaTombstoneRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return IdeaTombstoneRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}deleted_at'],
      )!,
      reason: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reason'],
      )!,
    );
  }

  @override
  IdeaTombstones createAlias(String alias) {
    return IdeaTombstones(attachedDatabase, alias);
  }

  @override
  bool get isStrict => true;
  @override
  List<String> get customConstraints => const [
    'CONSTRAINT inv9_idea_tombstones_deleted_at CHECK(length(deleted_at) = 24 AND deleted_at LIKE \'%Z\')',
    'CONSTRAINT reason_idea_tombstones CHECK(reason IN (\'deleted\', \'converted\'))',
  ];
  @override
  bool get dontWriteConstraints => true;
}

class IdeaTombstoneRow extends DataClass
    implements Insertable<IdeaTombstoneRow> {
  final String id;
  final String deletedAt;

  /// TombstoneReason.name: 'deleted' (DEL-3) or 'converted' (CONVERT-4).
  final String reason;
  const IdeaTombstoneRow({
    required this.id,
    required this.deletedAt,
    required this.reason,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['deleted_at'] = Variable<String>(deletedAt);
    map['reason'] = Variable<String>(reason);
    return map;
  }

  IdeaTombstonesCompanion toCompanion(bool nullToAbsent) {
    return IdeaTombstonesCompanion(
      id: Value(id),
      deletedAt: Value(deletedAt),
      reason: Value(reason),
    );
  }

  factory IdeaTombstoneRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return IdeaTombstoneRow(
      id: serializer.fromJson<String>(json['id']),
      deletedAt: serializer.fromJson<String>(json['deleted_at']),
      reason: serializer.fromJson<String>(json['reason']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'deleted_at': serializer.toJson<String>(deletedAt),
      'reason': serializer.toJson<String>(reason),
    };
  }

  IdeaTombstoneRow copyWith({String? id, String? deletedAt, String? reason}) =>
      IdeaTombstoneRow(
        id: id ?? this.id,
        deletedAt: deletedAt ?? this.deletedAt,
        reason: reason ?? this.reason,
      );
  IdeaTombstoneRow copyWithCompanion(IdeaTombstonesCompanion data) {
    return IdeaTombstoneRow(
      id: data.id.present ? data.id.value : this.id,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      reason: data.reason.present ? data.reason.value : this.reason,
    );
  }

  @override
  String toString() {
    return (StringBuffer('IdeaTombstoneRow(')
          ..write('id: $id, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('reason: $reason')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, deletedAt, reason);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is IdeaTombstoneRow &&
          other.id == this.id &&
          other.deletedAt == this.deletedAt &&
          other.reason == this.reason);
}

class IdeaTombstonesCompanion extends UpdateCompanion<IdeaTombstoneRow> {
  final Value<String> id;
  final Value<String> deletedAt;
  final Value<String> reason;
  final Value<int> rowid;
  const IdeaTombstonesCompanion({
    this.id = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.reason = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  IdeaTombstonesCompanion.insert({
    required String id,
    required String deletedAt,
    required String reason,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       deletedAt = Value(deletedAt),
       reason = Value(reason);
  static Insertable<IdeaTombstoneRow> custom({
    Expression<String>? id,
    Expression<String>? deletedAt,
    Expression<String>? reason,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (reason != null) 'reason': reason,
      if (rowid != null) 'rowid': rowid,
    });
  }

  IdeaTombstonesCompanion copyWith({
    Value<String>? id,
    Value<String>? deletedAt,
    Value<String>? reason,
    Value<int>? rowid,
  }) {
    return IdeaTombstonesCompanion(
      id: id ?? this.id,
      deletedAt: deletedAt ?? this.deletedAt,
      reason: reason ?? this.reason,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<String>(deletedAt.value);
    }
    if (reason.present) {
      map['reason'] = Variable<String>(reason.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('IdeaTombstonesCompanion(')
          ..write('id: $id, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('reason: $reason, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class Ideas extends Table with TableInfo<Ideas, IdeaRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  Ideas(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL PRIMARY KEY',
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _nameNormalizedMeta = const VerificationMeta(
    'nameNormalized',
  );
  late final GeneratedColumn<String> nameNormalized = GeneratedColumn<String>(
    'name_normalized',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _contextMeta = const VerificationMeta(
    'context',
  );
  late final GeneratedColumn<String> context = GeneratedColumn<String>(
    'context',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT \'\'',
    defaultValue: const CustomExpression('\'\''),
  );
  static const VerificationMeta _timeframeMeta = const VerificationMeta(
    'timeframe',
  );
  late final GeneratedColumn<String> timeframe = GeneratedColumn<String>(
    'timeframe',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    nameNormalized,
    context,
    timeframe,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'ideas';
  @override
  VerificationContext validateIntegrity(
    Insertable<IdeaRow> instance, {
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
    if (data.containsKey('name_normalized')) {
      context.handle(
        _nameNormalizedMeta,
        nameNormalized.isAcceptableOrUnknown(
          data['name_normalized']!,
          _nameNormalizedMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_nameNormalizedMeta);
    }
    if (data.containsKey('context')) {
      context.handle(
        _contextMeta,
        this.context.isAcceptableOrUnknown(data['context']!, _contextMeta),
      );
    }
    if (data.containsKey('timeframe')) {
      context.handle(
        _timeframeMeta,
        timeframe.isAcceptableOrUnknown(data['timeframe']!, _timeframeMeta),
      );
    } else if (isInserting) {
      context.missing(_timeframeMeta);
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
  IdeaRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return IdeaRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      nameNormalized: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name_normalized'],
      )!,
      context: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}context'],
      )!,
      timeframe: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}timeframe'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  Ideas createAlias(String alias) {
    return Ideas(attachedDatabase, alias);
  }

  @override
  bool get isStrict => true;
  @override
  List<String> get customConstraints => const [
    'CONSTRAINT inv5_ideas CHECK(created_at <= updated_at)',
    'CONSTRAINT inv9_ideas_created_at CHECK(length(created_at) = 24 AND created_at LIKE \'%Z\')',
    'CONSTRAINT inv9_ideas_updated_at CHECK(length(updated_at) = 24 AND updated_at LIKE \'%Z\')',
    'CONSTRAINT inv6_ideas_name CHECK(name <> \'\' AND name = trim(name) AND instr(name, char(10)) = 0 AND instr(name, char(13)) = 0 AND length(name) <= 16000)',
    'CONSTRAINT inv6_ideas_name_normalized CHECK(name_normalized <> \'\')',
    'CONSTRAINT inv6_ideas_context CHECK(length(context) <= 160000)',
    'CONSTRAINT timeframe_ideas CHECK(timeframe IN (\'now\', \'soon\', \'later\', \'distant\'))',
  ];
  @override
  bool get dontWriteConstraints => true;
}

class IdeaRow extends DataClass implements Insertable<IdeaRow> {
  final String id;
  final String name;

  /// §2, §11.5.2. `normalizeName(name)`, written on every insert and update by
  /// the one mapper that writes this table. SQL cannot assert that it agrees
  /// with `name`; `mapping/` is the single writer and a test re-derives it for
  /// every row (§11.5.2).
  final String nameNormalized;
  final String context;

  /// Timeframe.name: 'now' | 'soon' | 'later' | 'distant'.
  final String timeframe;
  final String createdAt;
  final String updatedAt;
  const IdeaRow({
    required this.id,
    required this.name,
    required this.nameNormalized,
    required this.context,
    required this.timeframe,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['name_normalized'] = Variable<String>(nameNormalized);
    map['context'] = Variable<String>(context);
    map['timeframe'] = Variable<String>(timeframe);
    map['created_at'] = Variable<String>(createdAt);
    map['updated_at'] = Variable<String>(updatedAt);
    return map;
  }

  IdeasCompanion toCompanion(bool nullToAbsent) {
    return IdeasCompanion(
      id: Value(id),
      name: Value(name),
      nameNormalized: Value(nameNormalized),
      context: Value(context),
      timeframe: Value(timeframe),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory IdeaRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return IdeaRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      nameNormalized: serializer.fromJson<String>(json['name_normalized']),
      context: serializer.fromJson<String>(json['context']),
      timeframe: serializer.fromJson<String>(json['timeframe']),
      createdAt: serializer.fromJson<String>(json['created_at']),
      updatedAt: serializer.fromJson<String>(json['updated_at']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'name_normalized': serializer.toJson<String>(nameNormalized),
      'context': serializer.toJson<String>(context),
      'timeframe': serializer.toJson<String>(timeframe),
      'created_at': serializer.toJson<String>(createdAt),
      'updated_at': serializer.toJson<String>(updatedAt),
    };
  }

  IdeaRow copyWith({
    String? id,
    String? name,
    String? nameNormalized,
    String? context,
    String? timeframe,
    String? createdAt,
    String? updatedAt,
  }) => IdeaRow(
    id: id ?? this.id,
    name: name ?? this.name,
    nameNormalized: nameNormalized ?? this.nameNormalized,
    context: context ?? this.context,
    timeframe: timeframe ?? this.timeframe,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  IdeaRow copyWithCompanion(IdeasCompanion data) {
    return IdeaRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      nameNormalized: data.nameNormalized.present
          ? data.nameNormalized.value
          : this.nameNormalized,
      context: data.context.present ? data.context.value : this.context,
      timeframe: data.timeframe.present ? data.timeframe.value : this.timeframe,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('IdeaRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('nameNormalized: $nameNormalized, ')
          ..write('context: $context, ')
          ..write('timeframe: $timeframe, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    nameNormalized,
    context,
    timeframe,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is IdeaRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.nameNormalized == this.nameNormalized &&
          other.context == this.context &&
          other.timeframe == this.timeframe &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class IdeasCompanion extends UpdateCompanion<IdeaRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> nameNormalized;
  final Value<String> context;
  final Value<String> timeframe;
  final Value<String> createdAt;
  final Value<String> updatedAt;
  final Value<int> rowid;
  const IdeasCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.nameNormalized = const Value.absent(),
    this.context = const Value.absent(),
    this.timeframe = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  IdeasCompanion.insert({
    required String id,
    required String name,
    required String nameNormalized,
    this.context = const Value.absent(),
    required String timeframe,
    required String createdAt,
    required String updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       nameNormalized = Value(nameNormalized),
       timeframe = Value(timeframe),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<IdeaRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? nameNormalized,
    Expression<String>? context,
    Expression<String>? timeframe,
    Expression<String>? createdAt,
    Expression<String>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (nameNormalized != null) 'name_normalized': nameNormalized,
      if (context != null) 'context': context,
      if (timeframe != null) 'timeframe': timeframe,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  IdeasCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? nameNormalized,
    Value<String>? context,
    Value<String>? timeframe,
    Value<String>? createdAt,
    Value<String>? updatedAt,
    Value<int>? rowid,
  }) {
    return IdeasCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      nameNormalized: nameNormalized ?? this.nameNormalized,
      context: context ?? this.context,
      timeframe: timeframe ?? this.timeframe,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
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
    if (nameNormalized.present) {
      map['name_normalized'] = Variable<String>(nameNormalized.value);
    }
    if (context.present) {
      map['context'] = Variable<String>(context.value);
    }
    if (timeframe.present) {
      map['timeframe'] = Variable<String>(timeframe.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('IdeasCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('nameNormalized: $nameNormalized, ')
          ..write('context: $context, ')
          ..write('timeframe: $timeframe, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class IdeaTags extends Table with TableInfo<IdeaTags, IdeaTagRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  IdeaTags(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _ownerIdMeta = const VerificationMeta(
    'ownerId',
  );
  late final GeneratedColumn<String> ownerId = GeneratedColumn<String>(
    'owner_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL REFERENCES ideas(id)ON DELETE CASCADE',
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _valueNormalizedMeta = const VerificationMeta(
    'valueNormalized',
  );
  late final GeneratedColumn<String> valueNormalized = GeneratedColumn<String>(
    'value_normalized',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _sortIndexMeta = const VerificationMeta(
    'sortIndex',
  );
  late final GeneratedColumn<int> sortIndex = GeneratedColumn<int>(
    'sort_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  @override
  List<GeneratedColumn> get $columns => [
    ownerId,
    value,
    valueNormalized,
    sortIndex,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'idea_tags';
  @override
  VerificationContext validateIntegrity(
    Insertable<IdeaTagRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('owner_id')) {
      context.handle(
        _ownerIdMeta,
        ownerId.isAcceptableOrUnknown(data['owner_id']!, _ownerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_ownerIdMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    if (data.containsKey('value_normalized')) {
      context.handle(
        _valueNormalizedMeta,
        valueNormalized.isAcceptableOrUnknown(
          data['value_normalized']!,
          _valueNormalizedMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_valueNormalizedMeta);
    }
    if (data.containsKey('sort_index')) {
      context.handle(
        _sortIndexMeta,
        sortIndex.isAcceptableOrUnknown(data['sort_index']!, _sortIndexMeta),
      );
    } else if (isInserting) {
      context.missing(_sortIndexMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {ownerId, valueNormalized};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {ownerId, sortIndex},
  ];
  @override
  IdeaTagRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return IdeaTagRow(
      ownerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_id'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
      valueNormalized: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value_normalized'],
      )!,
      sortIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_index'],
      )!,
    );
  }

  @override
  IdeaTags createAlias(String alias) {
    return IdeaTags(attachedDatabase, alias);
  }

  @override
  bool get isStrict => true;
  @override
  List<String> get customConstraints => const [
    'PRIMARY KEY(owner_id, value_normalized)',
    'CONSTRAINT inv6_idea_tags_value CHECK(value <> \'\' AND instr(value, \' \') = 0 AND instr(value, char(9)) = 0 AND instr(value, char(10)) = 0 AND instr(value, char(13)) = 0 AND value NOT LIKE \'@%\' AND length(value) <= 512)',
    'CONSTRAINT inv6_idea_tags_value_normalized CHECK(value_normalized <> \'\')',
    'CONSTRAINT sort_index_idea_tags CHECK(sort_index >= 0)',
    'CONSTRAINT unique_idea_tags_order UNIQUE(owner_id, sort_index)',
  ];
  @override
  bool get dontWriteConstraints => true;
}

class IdeaTagRow extends DataClass implements Insertable<IdeaTagRow> {
  final String ownerId;
  final String value;

  /// `normalizeTag(value)`: NFC then case-folded (TAG-4, D-M1-15).
  final String valueNormalized;
  final int sortIndex;
  const IdeaTagRow({
    required this.ownerId,
    required this.value,
    required this.valueNormalized,
    required this.sortIndex,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['owner_id'] = Variable<String>(ownerId);
    map['value'] = Variable<String>(value);
    map['value_normalized'] = Variable<String>(valueNormalized);
    map['sort_index'] = Variable<int>(sortIndex);
    return map;
  }

  IdeaTagsCompanion toCompanion(bool nullToAbsent) {
    return IdeaTagsCompanion(
      ownerId: Value(ownerId),
      value: Value(value),
      valueNormalized: Value(valueNormalized),
      sortIndex: Value(sortIndex),
    );
  }

  factory IdeaTagRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return IdeaTagRow(
      ownerId: serializer.fromJson<String>(json['owner_id']),
      value: serializer.fromJson<String>(json['value']),
      valueNormalized: serializer.fromJson<String>(json['value_normalized']),
      sortIndex: serializer.fromJson<int>(json['sort_index']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'owner_id': serializer.toJson<String>(ownerId),
      'value': serializer.toJson<String>(value),
      'value_normalized': serializer.toJson<String>(valueNormalized),
      'sort_index': serializer.toJson<int>(sortIndex),
    };
  }

  IdeaTagRow copyWith({
    String? ownerId,
    String? value,
    String? valueNormalized,
    int? sortIndex,
  }) => IdeaTagRow(
    ownerId: ownerId ?? this.ownerId,
    value: value ?? this.value,
    valueNormalized: valueNormalized ?? this.valueNormalized,
    sortIndex: sortIndex ?? this.sortIndex,
  );
  IdeaTagRow copyWithCompanion(IdeaTagsCompanion data) {
    return IdeaTagRow(
      ownerId: data.ownerId.present ? data.ownerId.value : this.ownerId,
      value: data.value.present ? data.value.value : this.value,
      valueNormalized: data.valueNormalized.present
          ? data.valueNormalized.value
          : this.valueNormalized,
      sortIndex: data.sortIndex.present ? data.sortIndex.value : this.sortIndex,
    );
  }

  @override
  String toString() {
    return (StringBuffer('IdeaTagRow(')
          ..write('ownerId: $ownerId, ')
          ..write('value: $value, ')
          ..write('valueNormalized: $valueNormalized, ')
          ..write('sortIndex: $sortIndex')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(ownerId, value, valueNormalized, sortIndex);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is IdeaTagRow &&
          other.ownerId == this.ownerId &&
          other.value == this.value &&
          other.valueNormalized == this.valueNormalized &&
          other.sortIndex == this.sortIndex);
}

class IdeaTagsCompanion extends UpdateCompanion<IdeaTagRow> {
  final Value<String> ownerId;
  final Value<String> value;
  final Value<String> valueNormalized;
  final Value<int> sortIndex;
  final Value<int> rowid;
  const IdeaTagsCompanion({
    this.ownerId = const Value.absent(),
    this.value = const Value.absent(),
    this.valueNormalized = const Value.absent(),
    this.sortIndex = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  IdeaTagsCompanion.insert({
    required String ownerId,
    required String value,
    required String valueNormalized,
    required int sortIndex,
    this.rowid = const Value.absent(),
  }) : ownerId = Value(ownerId),
       value = Value(value),
       valueNormalized = Value(valueNormalized),
       sortIndex = Value(sortIndex);
  static Insertable<IdeaTagRow> custom({
    Expression<String>? ownerId,
    Expression<String>? value,
    Expression<String>? valueNormalized,
    Expression<int>? sortIndex,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (ownerId != null) 'owner_id': ownerId,
      if (value != null) 'value': value,
      if (valueNormalized != null) 'value_normalized': valueNormalized,
      if (sortIndex != null) 'sort_index': sortIndex,
      if (rowid != null) 'rowid': rowid,
    });
  }

  IdeaTagsCompanion copyWith({
    Value<String>? ownerId,
    Value<String>? value,
    Value<String>? valueNormalized,
    Value<int>? sortIndex,
    Value<int>? rowid,
  }) {
    return IdeaTagsCompanion(
      ownerId: ownerId ?? this.ownerId,
      value: value ?? this.value,
      valueNormalized: valueNormalized ?? this.valueNormalized,
      sortIndex: sortIndex ?? this.sortIndex,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (ownerId.present) {
      map['owner_id'] = Variable<String>(ownerId.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (valueNormalized.present) {
      map['value_normalized'] = Variable<String>(valueNormalized.value);
    }
    if (sortIndex.present) {
      map['sort_index'] = Variable<int>(sortIndex.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('IdeaTagsCompanion(')
          ..write('ownerId: $ownerId, ')
          ..write('value: $value, ')
          ..write('valueNormalized: $valueNormalized, ')
          ..write('sortIndex: $sortIndex, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class Tasks extends Table with TableInfo<Tasks, TaskRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  Tasks(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL PRIMARY KEY',
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _nameNormalizedMeta = const VerificationMeta(
    'nameNormalized',
  );
  late final GeneratedColumn<String> nameNormalized = GeneratedColumn<String>(
    'name_normalized',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT \'\'',
    defaultValue: const CustomExpression('\'\''),
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _completedAtMeta = const VerificationMeta(
    'completedAt',
  );
  late final GeneratedColumn<String> completedAt = GeneratedColumn<String>(
    'completed_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'NULL',
  );
  static const VerificationMeta _isArchivedMeta = const VerificationMeta(
    'isArchived',
  );
  late final GeneratedColumn<int> isArchived = GeneratedColumn<int>(
    'is_archived',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 0',
    defaultValue: const CustomExpression('0'),
  );
  static const VerificationMeta _archivedAtMeta = const VerificationMeta(
    'archivedAt',
  );
  late final GeneratedColumn<String> archivedAt = GeneratedColumn<String>(
    'archived_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'NULL',
  );
  static const VerificationMeta _isDeletedMeta = const VerificationMeta(
    'isDeleted',
  );
  late final GeneratedColumn<int> isDeleted = GeneratedColumn<int>(
    'is_deleted',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 0',
    defaultValue: const CustomExpression('0'),
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  late final GeneratedColumn<String> deletedAt = GeneratedColumn<String>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'NULL',
  );
  static const VerificationMeta _sourceIdeaIdMeta = const VerificationMeta(
    'sourceIdeaId',
  );
  late final GeneratedColumn<String> sourceIdeaId = GeneratedColumn<String>(
    'source_idea_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'NULL',
  );
  static const VerificationMeta _sourceIdeaCreatedAtMeta =
      const VerificationMeta('sourceIdeaCreatedAt');
  late final GeneratedColumn<String> sourceIdeaCreatedAt =
      GeneratedColumn<String>(
        'source_idea_created_at',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        $customConstraints: 'NULL',
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    nameNormalized,
    description,
    status,
    createdAt,
    updatedAt,
    completedAt,
    isArchived,
    archivedAt,
    isDeleted,
    deletedAt,
    sourceIdeaId,
    sourceIdeaCreatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tasks';
  @override
  VerificationContext validateIntegrity(
    Insertable<TaskRow> instance, {
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
    if (data.containsKey('name_normalized')) {
      context.handle(
        _nameNormalizedMeta,
        nameNormalized.isAcceptableOrUnknown(
          data['name_normalized']!,
          _nameNormalizedMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_nameNormalizedMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
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
    if (data.containsKey('completed_at')) {
      context.handle(
        _completedAtMeta,
        completedAt.isAcceptableOrUnknown(
          data['completed_at']!,
          _completedAtMeta,
        ),
      );
    }
    if (data.containsKey('is_archived')) {
      context.handle(
        _isArchivedMeta,
        isArchived.isAcceptableOrUnknown(data['is_archived']!, _isArchivedMeta),
      );
    }
    if (data.containsKey('archived_at')) {
      context.handle(
        _archivedAtMeta,
        archivedAt.isAcceptableOrUnknown(data['archived_at']!, _archivedAtMeta),
      );
    }
    if (data.containsKey('is_deleted')) {
      context.handle(
        _isDeletedMeta,
        isDeleted.isAcceptableOrUnknown(data['is_deleted']!, _isDeletedMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('source_idea_id')) {
      context.handle(
        _sourceIdeaIdMeta,
        sourceIdeaId.isAcceptableOrUnknown(
          data['source_idea_id']!,
          _sourceIdeaIdMeta,
        ),
      );
    }
    if (data.containsKey('source_idea_created_at')) {
      context.handle(
        _sourceIdeaCreatedAtMeta,
        sourceIdeaCreatedAt.isAcceptableOrUnknown(
          data['source_idea_created_at']!,
          _sourceIdeaCreatedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TaskRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TaskRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      nameNormalized: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name_normalized'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_at'],
      )!,
      completedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}completed_at'],
      ),
      isArchived: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}is_archived'],
      )!,
      archivedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}archived_at'],
      ),
      isDeleted: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}is_deleted'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}deleted_at'],
      ),
      sourceIdeaId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_idea_id'],
      ),
      sourceIdeaCreatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_idea_created_at'],
      ),
    );
  }

  @override
  Tasks createAlias(String alias) {
    return Tasks(attachedDatabase, alias);
  }

  @override
  bool get isStrict => true;
  @override
  List<String> get customConstraints => const [
    'CONSTRAINT inv1_tasks CHECK((status = \'done\')=(completed_at IS NOT NULL))',
    'CONSTRAINT inv3_tasks CHECK(is_archived = 0 OR status = \'done\')',
    'CONSTRAINT inv4_tasks_archived CHECK((is_archived = 1)=(archived_at IS NOT NULL))',
    'CONSTRAINT inv4_tasks_deleted CHECK((is_deleted = 1)=(deleted_at IS NOT NULL))',
    'CONSTRAINT inv5_tasks CHECK(created_at <= updated_at)',
    'CONSTRAINT inv8_tasks CHECK((source_idea_id IS NULL)=(source_idea_created_at IS NULL))',
    'CONSTRAINT inv9_tasks_created_at CHECK(length(created_at) = 24 AND created_at LIKE \'%Z\')',
    'CONSTRAINT inv9_tasks_updated_at CHECK(length(updated_at) = 24 AND updated_at LIKE \'%Z\')',
    'CONSTRAINT inv9_tasks_completed_at CHECK(completed_at IS NULL OR(length(completed_at) = 24 AND completed_at LIKE \'%Z\'))',
    'CONSTRAINT inv9_tasks_archived_at CHECK(archived_at IS NULL OR(length(archived_at) = 24 AND archived_at LIKE \'%Z\'))',
    'CONSTRAINT inv9_tasks_deleted_at CHECK(deleted_at IS NULL OR(length(deleted_at) = 24 AND deleted_at LIKE \'%Z\'))',
    'CONSTRAINT inv9_tasks_source_idea_created_at CHECK(source_idea_created_at IS NULL OR(length(source_idea_created_at) = 24 AND source_idea_created_at LIKE \'%Z\'))',
    'CONSTRAINT inv6_tasks_name CHECK(name <> \'\' AND name = trim(name) AND instr(name, char(10)) = 0 AND instr(name, char(13)) = 0 AND length(name) <= 16000)',
    'CONSTRAINT inv6_tasks_name_normalized CHECK(name_normalized <> \'\')',
    'CONSTRAINT inv6_tasks_description CHECK(length(description) <= 160000)',
    'CONSTRAINT status_tasks CHECK(status IN (\'todo\', \'blocked\', \'done\'))',
    'CONSTRAINT bool_tasks_is_archived CHECK(is_archived IN (0, 1))',
    'CONSTRAINT bool_tasks_is_deleted CHECK(is_deleted IN (0, 1))',
  ];
  @override
  bool get dontWriteConstraints => true;
}

class TaskRow extends DataClass implements Insertable<TaskRow> {
  final String id;
  final String name;

  /// §2, §11.5.2. See the note on `ideas.name_normalized`.
  final String nameNormalized;
  final String description;

  /// TaskStatus.name: 'todo' | 'blocked' | 'done'. Stored by name rather than
  /// by index, because `TaskStatus` is declared in merge-precedence order
  /// (§9.3 step 4) and a later reordering must not silently rewrite the data.
  final String status;
  final String createdAt;
  final String updatedAt;
  final String? completedAt;
  final int isArchived;
  final String? archivedAt;
  final int isDeleted;
  final String? deletedAt;
  final String? sourceIdeaId;
  final String? sourceIdeaCreatedAt;
  const TaskRow({
    required this.id,
    required this.name,
    required this.nameNormalized,
    required this.description,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.completedAt,
    required this.isArchived,
    this.archivedAt,
    required this.isDeleted,
    this.deletedAt,
    this.sourceIdeaId,
    this.sourceIdeaCreatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['name_normalized'] = Variable<String>(nameNormalized);
    map['description'] = Variable<String>(description);
    map['status'] = Variable<String>(status);
    map['created_at'] = Variable<String>(createdAt);
    map['updated_at'] = Variable<String>(updatedAt);
    if (!nullToAbsent || completedAt != null) {
      map['completed_at'] = Variable<String>(completedAt);
    }
    map['is_archived'] = Variable<int>(isArchived);
    if (!nullToAbsent || archivedAt != null) {
      map['archived_at'] = Variable<String>(archivedAt);
    }
    map['is_deleted'] = Variable<int>(isDeleted);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<String>(deletedAt);
    }
    if (!nullToAbsent || sourceIdeaId != null) {
      map['source_idea_id'] = Variable<String>(sourceIdeaId);
    }
    if (!nullToAbsent || sourceIdeaCreatedAt != null) {
      map['source_idea_created_at'] = Variable<String>(sourceIdeaCreatedAt);
    }
    return map;
  }

  TasksCompanion toCompanion(bool nullToAbsent) {
    return TasksCompanion(
      id: Value(id),
      name: Value(name),
      nameNormalized: Value(nameNormalized),
      description: Value(description),
      status: Value(status),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      completedAt: completedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(completedAt),
      isArchived: Value(isArchived),
      archivedAt: archivedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(archivedAt),
      isDeleted: Value(isDeleted),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      sourceIdeaId: sourceIdeaId == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceIdeaId),
      sourceIdeaCreatedAt: sourceIdeaCreatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceIdeaCreatedAt),
    );
  }

  factory TaskRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TaskRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      nameNormalized: serializer.fromJson<String>(json['name_normalized']),
      description: serializer.fromJson<String>(json['description']),
      status: serializer.fromJson<String>(json['status']),
      createdAt: serializer.fromJson<String>(json['created_at']),
      updatedAt: serializer.fromJson<String>(json['updated_at']),
      completedAt: serializer.fromJson<String?>(json['completed_at']),
      isArchived: serializer.fromJson<int>(json['is_archived']),
      archivedAt: serializer.fromJson<String?>(json['archived_at']),
      isDeleted: serializer.fromJson<int>(json['is_deleted']),
      deletedAt: serializer.fromJson<String?>(json['deleted_at']),
      sourceIdeaId: serializer.fromJson<String?>(json['source_idea_id']),
      sourceIdeaCreatedAt: serializer.fromJson<String?>(
        json['source_idea_created_at'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'name_normalized': serializer.toJson<String>(nameNormalized),
      'description': serializer.toJson<String>(description),
      'status': serializer.toJson<String>(status),
      'created_at': serializer.toJson<String>(createdAt),
      'updated_at': serializer.toJson<String>(updatedAt),
      'completed_at': serializer.toJson<String?>(completedAt),
      'is_archived': serializer.toJson<int>(isArchived),
      'archived_at': serializer.toJson<String?>(archivedAt),
      'is_deleted': serializer.toJson<int>(isDeleted),
      'deleted_at': serializer.toJson<String?>(deletedAt),
      'source_idea_id': serializer.toJson<String?>(sourceIdeaId),
      'source_idea_created_at': serializer.toJson<String?>(sourceIdeaCreatedAt),
    };
  }

  TaskRow copyWith({
    String? id,
    String? name,
    String? nameNormalized,
    String? description,
    String? status,
    String? createdAt,
    String? updatedAt,
    Value<String?> completedAt = const Value.absent(),
    int? isArchived,
    Value<String?> archivedAt = const Value.absent(),
    int? isDeleted,
    Value<String?> deletedAt = const Value.absent(),
    Value<String?> sourceIdeaId = const Value.absent(),
    Value<String?> sourceIdeaCreatedAt = const Value.absent(),
  }) => TaskRow(
    id: id ?? this.id,
    name: name ?? this.name,
    nameNormalized: nameNormalized ?? this.nameNormalized,
    description: description ?? this.description,
    status: status ?? this.status,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    completedAt: completedAt.present ? completedAt.value : this.completedAt,
    isArchived: isArchived ?? this.isArchived,
    archivedAt: archivedAt.present ? archivedAt.value : this.archivedAt,
    isDeleted: isDeleted ?? this.isDeleted,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    sourceIdeaId: sourceIdeaId.present ? sourceIdeaId.value : this.sourceIdeaId,
    sourceIdeaCreatedAt: sourceIdeaCreatedAt.present
        ? sourceIdeaCreatedAt.value
        : this.sourceIdeaCreatedAt,
  );
  TaskRow copyWithCompanion(TasksCompanion data) {
    return TaskRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      nameNormalized: data.nameNormalized.present
          ? data.nameNormalized.value
          : this.nameNormalized,
      description: data.description.present
          ? data.description.value
          : this.description,
      status: data.status.present ? data.status.value : this.status,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      completedAt: data.completedAt.present
          ? data.completedAt.value
          : this.completedAt,
      isArchived: data.isArchived.present
          ? data.isArchived.value
          : this.isArchived,
      archivedAt: data.archivedAt.present
          ? data.archivedAt.value
          : this.archivedAt,
      isDeleted: data.isDeleted.present ? data.isDeleted.value : this.isDeleted,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      sourceIdeaId: data.sourceIdeaId.present
          ? data.sourceIdeaId.value
          : this.sourceIdeaId,
      sourceIdeaCreatedAt: data.sourceIdeaCreatedAt.present
          ? data.sourceIdeaCreatedAt.value
          : this.sourceIdeaCreatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TaskRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('nameNormalized: $nameNormalized, ')
          ..write('description: $description, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('completedAt: $completedAt, ')
          ..write('isArchived: $isArchived, ')
          ..write('archivedAt: $archivedAt, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('sourceIdeaId: $sourceIdeaId, ')
          ..write('sourceIdeaCreatedAt: $sourceIdeaCreatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    nameNormalized,
    description,
    status,
    createdAt,
    updatedAt,
    completedAt,
    isArchived,
    archivedAt,
    isDeleted,
    deletedAt,
    sourceIdeaId,
    sourceIdeaCreatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TaskRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.nameNormalized == this.nameNormalized &&
          other.description == this.description &&
          other.status == this.status &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.completedAt == this.completedAt &&
          other.isArchived == this.isArchived &&
          other.archivedAt == this.archivedAt &&
          other.isDeleted == this.isDeleted &&
          other.deletedAt == this.deletedAt &&
          other.sourceIdeaId == this.sourceIdeaId &&
          other.sourceIdeaCreatedAt == this.sourceIdeaCreatedAt);
}

class TasksCompanion extends UpdateCompanion<TaskRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> nameNormalized;
  final Value<String> description;
  final Value<String> status;
  final Value<String> createdAt;
  final Value<String> updatedAt;
  final Value<String?> completedAt;
  final Value<int> isArchived;
  final Value<String?> archivedAt;
  final Value<int> isDeleted;
  final Value<String?> deletedAt;
  final Value<String?> sourceIdeaId;
  final Value<String?> sourceIdeaCreatedAt;
  final Value<int> rowid;
  const TasksCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.nameNormalized = const Value.absent(),
    this.description = const Value.absent(),
    this.status = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.isArchived = const Value.absent(),
    this.archivedAt = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.sourceIdeaId = const Value.absent(),
    this.sourceIdeaCreatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TasksCompanion.insert({
    required String id,
    required String name,
    required String nameNormalized,
    this.description = const Value.absent(),
    required String status,
    required String createdAt,
    required String updatedAt,
    this.completedAt = const Value.absent(),
    this.isArchived = const Value.absent(),
    this.archivedAt = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.sourceIdeaId = const Value.absent(),
    this.sourceIdeaCreatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       nameNormalized = Value(nameNormalized),
       status = Value(status),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<TaskRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? nameNormalized,
    Expression<String>? description,
    Expression<String>? status,
    Expression<String>? createdAt,
    Expression<String>? updatedAt,
    Expression<String>? completedAt,
    Expression<int>? isArchived,
    Expression<String>? archivedAt,
    Expression<int>? isDeleted,
    Expression<String>? deletedAt,
    Expression<String>? sourceIdeaId,
    Expression<String>? sourceIdeaCreatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (nameNormalized != null) 'name_normalized': nameNormalized,
      if (description != null) 'description': description,
      if (status != null) 'status': status,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (completedAt != null) 'completed_at': completedAt,
      if (isArchived != null) 'is_archived': isArchived,
      if (archivedAt != null) 'archived_at': archivedAt,
      if (isDeleted != null) 'is_deleted': isDeleted,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (sourceIdeaId != null) 'source_idea_id': sourceIdeaId,
      if (sourceIdeaCreatedAt != null)
        'source_idea_created_at': sourceIdeaCreatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TasksCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? nameNormalized,
    Value<String>? description,
    Value<String>? status,
    Value<String>? createdAt,
    Value<String>? updatedAt,
    Value<String?>? completedAt,
    Value<int>? isArchived,
    Value<String?>? archivedAt,
    Value<int>? isDeleted,
    Value<String?>? deletedAt,
    Value<String?>? sourceIdeaId,
    Value<String?>? sourceIdeaCreatedAt,
    Value<int>? rowid,
  }) {
    return TasksCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      nameNormalized: nameNormalized ?? this.nameNormalized,
      description: description ?? this.description,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      completedAt: completedAt ?? this.completedAt,
      isArchived: isArchived ?? this.isArchived,
      archivedAt: archivedAt ?? this.archivedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: deletedAt ?? this.deletedAt,
      sourceIdeaId: sourceIdeaId ?? this.sourceIdeaId,
      sourceIdeaCreatedAt: sourceIdeaCreatedAt ?? this.sourceIdeaCreatedAt,
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
    if (nameNormalized.present) {
      map['name_normalized'] = Variable<String>(nameNormalized.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<String>(completedAt.value);
    }
    if (isArchived.present) {
      map['is_archived'] = Variable<int>(isArchived.value);
    }
    if (archivedAt.present) {
      map['archived_at'] = Variable<String>(archivedAt.value);
    }
    if (isDeleted.present) {
      map['is_deleted'] = Variable<int>(isDeleted.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<String>(deletedAt.value);
    }
    if (sourceIdeaId.present) {
      map['source_idea_id'] = Variable<String>(sourceIdeaId.value);
    }
    if (sourceIdeaCreatedAt.present) {
      map['source_idea_created_at'] = Variable<String>(
        sourceIdeaCreatedAt.value,
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TasksCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('nameNormalized: $nameNormalized, ')
          ..write('description: $description, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('completedAt: $completedAt, ')
          ..write('isArchived: $isArchived, ')
          ..write('archivedAt: $archivedAt, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('sourceIdeaId: $sourceIdeaId, ')
          ..write('sourceIdeaCreatedAt: $sourceIdeaCreatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class TaskTags extends Table with TableInfo<TaskTags, TaskTagRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  TaskTags(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _ownerIdMeta = const VerificationMeta(
    'ownerId',
  );
  late final GeneratedColumn<String> ownerId = GeneratedColumn<String>(
    'owner_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL REFERENCES tasks(id)ON DELETE CASCADE',
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _valueNormalizedMeta = const VerificationMeta(
    'valueNormalized',
  );
  late final GeneratedColumn<String> valueNormalized = GeneratedColumn<String>(
    'value_normalized',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _sortIndexMeta = const VerificationMeta(
    'sortIndex',
  );
  late final GeneratedColumn<int> sortIndex = GeneratedColumn<int>(
    'sort_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  @override
  List<GeneratedColumn> get $columns => [
    ownerId,
    value,
    valueNormalized,
    sortIndex,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'task_tags';
  @override
  VerificationContext validateIntegrity(
    Insertable<TaskTagRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('owner_id')) {
      context.handle(
        _ownerIdMeta,
        ownerId.isAcceptableOrUnknown(data['owner_id']!, _ownerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_ownerIdMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    if (data.containsKey('value_normalized')) {
      context.handle(
        _valueNormalizedMeta,
        valueNormalized.isAcceptableOrUnknown(
          data['value_normalized']!,
          _valueNormalizedMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_valueNormalizedMeta);
    }
    if (data.containsKey('sort_index')) {
      context.handle(
        _sortIndexMeta,
        sortIndex.isAcceptableOrUnknown(data['sort_index']!, _sortIndexMeta),
      );
    } else if (isInserting) {
      context.missing(_sortIndexMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {ownerId, valueNormalized};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {ownerId, sortIndex},
  ];
  @override
  TaskTagRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TaskTagRow(
      ownerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_id'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
      valueNormalized: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value_normalized'],
      )!,
      sortIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_index'],
      )!,
    );
  }

  @override
  TaskTags createAlias(String alias) {
    return TaskTags(attachedDatabase, alias);
  }

  @override
  bool get isStrict => true;
  @override
  List<String> get customConstraints => const [
    'PRIMARY KEY(owner_id, value_normalized)',
    'CONSTRAINT inv6_task_tags_value CHECK(value <> \'\' AND instr(value, \' \') = 0 AND instr(value, char(9)) = 0 AND instr(value, char(10)) = 0 AND instr(value, char(13)) = 0 AND value NOT LIKE \'@%\' AND length(value) <= 512)',
    'CONSTRAINT inv6_task_tags_value_normalized CHECK(value_normalized <> \'\')',
    'CONSTRAINT sort_index_task_tags CHECK(sort_index >= 0)',
    'CONSTRAINT unique_task_tags_order UNIQUE(owner_id, sort_index)',
  ];
  @override
  bool get dontWriteConstraints => true;
}

class TaskTagRow extends DataClass implements Insertable<TaskTagRow> {
  final String ownerId;
  final String value;
  final String valueNormalized;
  final int sortIndex;
  const TaskTagRow({
    required this.ownerId,
    required this.value,
    required this.valueNormalized,
    required this.sortIndex,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['owner_id'] = Variable<String>(ownerId);
    map['value'] = Variable<String>(value);
    map['value_normalized'] = Variable<String>(valueNormalized);
    map['sort_index'] = Variable<int>(sortIndex);
    return map;
  }

  TaskTagsCompanion toCompanion(bool nullToAbsent) {
    return TaskTagsCompanion(
      ownerId: Value(ownerId),
      value: Value(value),
      valueNormalized: Value(valueNormalized),
      sortIndex: Value(sortIndex),
    );
  }

  factory TaskTagRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TaskTagRow(
      ownerId: serializer.fromJson<String>(json['owner_id']),
      value: serializer.fromJson<String>(json['value']),
      valueNormalized: serializer.fromJson<String>(json['value_normalized']),
      sortIndex: serializer.fromJson<int>(json['sort_index']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'owner_id': serializer.toJson<String>(ownerId),
      'value': serializer.toJson<String>(value),
      'value_normalized': serializer.toJson<String>(valueNormalized),
      'sort_index': serializer.toJson<int>(sortIndex),
    };
  }

  TaskTagRow copyWith({
    String? ownerId,
    String? value,
    String? valueNormalized,
    int? sortIndex,
  }) => TaskTagRow(
    ownerId: ownerId ?? this.ownerId,
    value: value ?? this.value,
    valueNormalized: valueNormalized ?? this.valueNormalized,
    sortIndex: sortIndex ?? this.sortIndex,
  );
  TaskTagRow copyWithCompanion(TaskTagsCompanion data) {
    return TaskTagRow(
      ownerId: data.ownerId.present ? data.ownerId.value : this.ownerId,
      value: data.value.present ? data.value.value : this.value,
      valueNormalized: data.valueNormalized.present
          ? data.valueNormalized.value
          : this.valueNormalized,
      sortIndex: data.sortIndex.present ? data.sortIndex.value : this.sortIndex,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TaskTagRow(')
          ..write('ownerId: $ownerId, ')
          ..write('value: $value, ')
          ..write('valueNormalized: $valueNormalized, ')
          ..write('sortIndex: $sortIndex')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(ownerId, value, valueNormalized, sortIndex);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TaskTagRow &&
          other.ownerId == this.ownerId &&
          other.value == this.value &&
          other.valueNormalized == this.valueNormalized &&
          other.sortIndex == this.sortIndex);
}

class TaskTagsCompanion extends UpdateCompanion<TaskTagRow> {
  final Value<String> ownerId;
  final Value<String> value;
  final Value<String> valueNormalized;
  final Value<int> sortIndex;
  final Value<int> rowid;
  const TaskTagsCompanion({
    this.ownerId = const Value.absent(),
    this.value = const Value.absent(),
    this.valueNormalized = const Value.absent(),
    this.sortIndex = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TaskTagsCompanion.insert({
    required String ownerId,
    required String value,
    required String valueNormalized,
    required int sortIndex,
    this.rowid = const Value.absent(),
  }) : ownerId = Value(ownerId),
       value = Value(value),
       valueNormalized = Value(valueNormalized),
       sortIndex = Value(sortIndex);
  static Insertable<TaskTagRow> custom({
    Expression<String>? ownerId,
    Expression<String>? value,
    Expression<String>? valueNormalized,
    Expression<int>? sortIndex,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (ownerId != null) 'owner_id': ownerId,
      if (value != null) 'value': value,
      if (valueNormalized != null) 'value_normalized': valueNormalized,
      if (sortIndex != null) 'sort_index': sortIndex,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TaskTagsCompanion copyWith({
    Value<String>? ownerId,
    Value<String>? value,
    Value<String>? valueNormalized,
    Value<int>? sortIndex,
    Value<int>? rowid,
  }) {
    return TaskTagsCompanion(
      ownerId: ownerId ?? this.ownerId,
      value: value ?? this.value,
      valueNormalized: valueNormalized ?? this.valueNormalized,
      sortIndex: sortIndex ?? this.sortIndex,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (ownerId.present) {
      map['owner_id'] = Variable<String>(ownerId.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (valueNormalized.present) {
      map['value_normalized'] = Variable<String>(valueNormalized.value);
    }
    if (sortIndex.present) {
      map['sort_index'] = Variable<int>(sortIndex.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TaskTagsCompanion(')
          ..write('ownerId: $ownerId, ')
          ..write('value: $value, ')
          ..write('valueNormalized: $valueNormalized, ')
          ..write('sortIndex: $sortIndex, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class Subtasks extends Table with TableInfo<Subtasks, SubtaskRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  Subtasks(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL PRIMARY KEY',
  );
  static const VerificationMeta _taskIdMeta = const VerificationMeta('taskId');
  late final GeneratedColumn<String> taskId = GeneratedColumn<String>(
    'task_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL REFERENCES tasks(id)ON DELETE CASCADE',
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _sortIndexMeta = const VerificationMeta(
    'sortIndex',
  );
  late final GeneratedColumn<int> sortIndex = GeneratedColumn<int>(
    'sort_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _completedAtMeta = const VerificationMeta(
    'completedAt',
  );
  late final GeneratedColumn<String> completedAt = GeneratedColumn<String>(
    'completed_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'NULL',
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    taskId,
    name,
    status,
    sortIndex,
    createdAt,
    updatedAt,
    completedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'subtasks';
  @override
  VerificationContext validateIntegrity(
    Insertable<SubtaskRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('task_id')) {
      context.handle(
        _taskIdMeta,
        taskId.isAcceptableOrUnknown(data['task_id']!, _taskIdMeta),
      );
    } else if (isInserting) {
      context.missing(_taskIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('sort_index')) {
      context.handle(
        _sortIndexMeta,
        sortIndex.isAcceptableOrUnknown(data['sort_index']!, _sortIndexMeta),
      );
    } else if (isInserting) {
      context.missing(_sortIndexMeta);
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
    if (data.containsKey('completed_at')) {
      context.handle(
        _completedAtMeta,
        completedAt.isAcceptableOrUnknown(
          data['completed_at']!,
          _completedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {taskId, sortIndex},
  ];
  @override
  SubtaskRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SubtaskRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      taskId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}task_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      sortIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_index'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_at'],
      )!,
      completedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}completed_at'],
      ),
    );
  }

  @override
  Subtasks createAlias(String alias) {
    return Subtasks(attachedDatabase, alias);
  }

  @override
  bool get isStrict => true;
  @override
  List<String> get customConstraints => const [
    'CONSTRAINT inv1_subtasks CHECK((status = \'done\')=(completed_at IS NOT NULL))',
    'CONSTRAINT inv5_subtasks CHECK(created_at <= updated_at)',
    'CONSTRAINT inv9_subtasks_created_at CHECK(length(created_at) = 24 AND created_at LIKE \'%Z\')',
    'CONSTRAINT inv9_subtasks_updated_at CHECK(length(updated_at) = 24 AND updated_at LIKE \'%Z\')',
    'CONSTRAINT inv9_subtasks_completed_at CHECK(completed_at IS NULL OR(length(completed_at) = 24 AND completed_at LIKE \'%Z\'))',
    'CONSTRAINT inv6_subtasks_name CHECK(name <> \'\' AND name = trim(name) AND instr(name, char(10)) = 0 AND instr(name, char(13)) = 0 AND length(name) <= 16000)',
    'CONSTRAINT status_subtasks CHECK(status IN (\'todo\', \'blocked\', \'done\'))',
    'CONSTRAINT sort_index_subtasks CHECK(sort_index >= 0)',
    'CONSTRAINT unique_subtasks_order UNIQUE(task_id, sort_index)',
  ];
  @override
  bool get dontWriteConstraints => true;
}

class SubtaskRow extends DataClass implements Insertable<SubtaskRow> {
  final String id;
  final String taskId;
  final String name;
  final String status;
  final int sortIndex;
  final String createdAt;
  final String updatedAt;
  final String? completedAt;
  const SubtaskRow({
    required this.id,
    required this.taskId,
    required this.name,
    required this.status,
    required this.sortIndex,
    required this.createdAt,
    required this.updatedAt,
    this.completedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['task_id'] = Variable<String>(taskId);
    map['name'] = Variable<String>(name);
    map['status'] = Variable<String>(status);
    map['sort_index'] = Variable<int>(sortIndex);
    map['created_at'] = Variable<String>(createdAt);
    map['updated_at'] = Variable<String>(updatedAt);
    if (!nullToAbsent || completedAt != null) {
      map['completed_at'] = Variable<String>(completedAt);
    }
    return map;
  }

  SubtasksCompanion toCompanion(bool nullToAbsent) {
    return SubtasksCompanion(
      id: Value(id),
      taskId: Value(taskId),
      name: Value(name),
      status: Value(status),
      sortIndex: Value(sortIndex),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      completedAt: completedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(completedAt),
    );
  }

  factory SubtaskRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SubtaskRow(
      id: serializer.fromJson<String>(json['id']),
      taskId: serializer.fromJson<String>(json['task_id']),
      name: serializer.fromJson<String>(json['name']),
      status: serializer.fromJson<String>(json['status']),
      sortIndex: serializer.fromJson<int>(json['sort_index']),
      createdAt: serializer.fromJson<String>(json['created_at']),
      updatedAt: serializer.fromJson<String>(json['updated_at']),
      completedAt: serializer.fromJson<String?>(json['completed_at']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'task_id': serializer.toJson<String>(taskId),
      'name': serializer.toJson<String>(name),
      'status': serializer.toJson<String>(status),
      'sort_index': serializer.toJson<int>(sortIndex),
      'created_at': serializer.toJson<String>(createdAt),
      'updated_at': serializer.toJson<String>(updatedAt),
      'completed_at': serializer.toJson<String?>(completedAt),
    };
  }

  SubtaskRow copyWith({
    String? id,
    String? taskId,
    String? name,
    String? status,
    int? sortIndex,
    String? createdAt,
    String? updatedAt,
    Value<String?> completedAt = const Value.absent(),
  }) => SubtaskRow(
    id: id ?? this.id,
    taskId: taskId ?? this.taskId,
    name: name ?? this.name,
    status: status ?? this.status,
    sortIndex: sortIndex ?? this.sortIndex,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    completedAt: completedAt.present ? completedAt.value : this.completedAt,
  );
  SubtaskRow copyWithCompanion(SubtasksCompanion data) {
    return SubtaskRow(
      id: data.id.present ? data.id.value : this.id,
      taskId: data.taskId.present ? data.taskId.value : this.taskId,
      name: data.name.present ? data.name.value : this.name,
      status: data.status.present ? data.status.value : this.status,
      sortIndex: data.sortIndex.present ? data.sortIndex.value : this.sortIndex,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      completedAt: data.completedAt.present
          ? data.completedAt.value
          : this.completedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SubtaskRow(')
          ..write('id: $id, ')
          ..write('taskId: $taskId, ')
          ..write('name: $name, ')
          ..write('status: $status, ')
          ..write('sortIndex: $sortIndex, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('completedAt: $completedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    taskId,
    name,
    status,
    sortIndex,
    createdAt,
    updatedAt,
    completedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SubtaskRow &&
          other.id == this.id &&
          other.taskId == this.taskId &&
          other.name == this.name &&
          other.status == this.status &&
          other.sortIndex == this.sortIndex &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.completedAt == this.completedAt);
}

class SubtasksCompanion extends UpdateCompanion<SubtaskRow> {
  final Value<String> id;
  final Value<String> taskId;
  final Value<String> name;
  final Value<String> status;
  final Value<int> sortIndex;
  final Value<String> createdAt;
  final Value<String> updatedAt;
  final Value<String?> completedAt;
  final Value<int> rowid;
  const SubtasksCompanion({
    this.id = const Value.absent(),
    this.taskId = const Value.absent(),
    this.name = const Value.absent(),
    this.status = const Value.absent(),
    this.sortIndex = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SubtasksCompanion.insert({
    required String id,
    required String taskId,
    required String name,
    required String status,
    required int sortIndex,
    required String createdAt,
    required String updatedAt,
    this.completedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       taskId = Value(taskId),
       name = Value(name),
       status = Value(status),
       sortIndex = Value(sortIndex),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<SubtaskRow> custom({
    Expression<String>? id,
    Expression<String>? taskId,
    Expression<String>? name,
    Expression<String>? status,
    Expression<int>? sortIndex,
    Expression<String>? createdAt,
    Expression<String>? updatedAt,
    Expression<String>? completedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (taskId != null) 'task_id': taskId,
      if (name != null) 'name': name,
      if (status != null) 'status': status,
      if (sortIndex != null) 'sort_index': sortIndex,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (completedAt != null) 'completed_at': completedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SubtasksCompanion copyWith({
    Value<String>? id,
    Value<String>? taskId,
    Value<String>? name,
    Value<String>? status,
    Value<int>? sortIndex,
    Value<String>? createdAt,
    Value<String>? updatedAt,
    Value<String?>? completedAt,
    Value<int>? rowid,
  }) {
    return SubtasksCompanion(
      id: id ?? this.id,
      taskId: taskId ?? this.taskId,
      name: name ?? this.name,
      status: status ?? this.status,
      sortIndex: sortIndex ?? this.sortIndex,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      completedAt: completedAt ?? this.completedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (taskId.present) {
      map['task_id'] = Variable<String>(taskId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (sortIndex.present) {
      map['sort_index'] = Variable<int>(sortIndex.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<String>(completedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SubtasksCompanion(')
          ..write('id: $id, ')
          ..write('taskId: $taskId, ')
          ..write('name: $name, ')
          ..write('status: $status, ')
          ..write('sortIndex: $sortIndex, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('completedAt: $completedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final Settings settings = Settings(this);
  late final Replica replica = Replica(this);
  late final Events events = Events(this);
  late final Index idxEventsItem = Index(
    'idx_events_item',
    'CREATE INDEX idx_events_item ON events (item_id, timestamp)',
  );
  late final Index idxEventsTimestamp = Index(
    'idx_events_timestamp',
    'CREATE INDEX idx_events_timestamp ON events (timestamp)',
  );
  late final IdeaTombstones ideaTombstones = IdeaTombstones(this);
  late final Ideas ideas = Ideas(this);
  late final IdeaTags ideaTags = IdeaTags(this);
  late final Tasks tasks = Tasks(this);
  late final TaskTags taskTags = TaskTags(this);
  late final Index idxIdeaTagsNormalized = Index(
    'idx_idea_tags_normalized',
    'CREATE INDEX idx_idea_tags_normalized ON idea_tags (value_normalized)',
  );
  late final Index idxTaskTagsNormalized = Index(
    'idx_task_tags_normalized',
    'CREATE INDEX idx_task_tags_normalized ON task_tags (value_normalized)',
  );
  late final Index idxTasksActiveName = Index(
    'idx_tasks_active_name',
    'CREATE UNIQUE INDEX idx_tasks_active_name ON tasks (name_normalized) WHERE is_deleted = 0 AND is_archived = 0',
  );
  late final Index idxTasksActive = Index(
    'idx_tasks_active',
    'CREATE INDEX idx_tasks_active ON tasks (is_deleted, is_archived, created_at)',
  );
  late final Index idxTasksCompletedAt = Index(
    'idx_tasks_completed_at',
    'CREATE INDEX idx_tasks_completed_at ON tasks (completed_at)',
  );
  late final Subtasks subtasks = Subtasks(this);
  late final Index idxSubtasksTask = Index(
    'idx_subtasks_task',
    'CREATE INDEX idx_subtasks_task ON subtasks (task_id, sort_index)',
  );
  late final Trigger inv2SubtaskInsert = Trigger(
    'CREATE TRIGGER inv2_subtask_insert BEFORE INSERT ON subtasks WHEN NEW.status <> \'done\' AND (SELECT status FROM tasks WHERE id = NEW.task_id) = \'done\' BEGIN SELECT RAISE (ABORT, \'INV-2: a Done task cannot gain an open subtask\');END',
    'inv2_subtask_insert',
  );
  late final Trigger inv2SubtaskUpdate = Trigger(
    'CREATE TRIGGER inv2_subtask_update BEFORE UPDATE ON subtasks WHEN NEW.status <> \'done\' AND (SELECT status FROM tasks WHERE id = NEW.task_id) = \'done\' BEGIN SELECT RAISE (ABORT, \'INV-2: a Done task cannot hold an open subtask\');END',
    'inv2_subtask_update',
  );
  late final Trigger inv2TaskInsert = Trigger(
    'CREATE TRIGGER inv2_task_insert BEFORE INSERT ON tasks WHEN NEW.status = \'done\' AND EXISTS (SELECT 1 FROM subtasks WHERE task_id = NEW.id AND status <> \'done\') BEGIN SELECT RAISE (ABORT, \'INV-2: this task has subtasks that are not Done\');END',
    'inv2_task_insert',
  );
  late final Trigger inv2TaskUpdate = Trigger(
    'CREATE TRIGGER inv2_task_update BEFORE UPDATE ON tasks WHEN NEW.status = \'done\' AND EXISTS (SELECT 1 FROM subtasks WHERE task_id = NEW.id AND status <> \'done\') BEGIN SELECT RAISE (ABORT, \'INV-2: this task has subtasks that are not Done\');END',
    'inv2_task_update',
  );
  late final Index idxIdeasActiveName = Index(
    'idx_ideas_active_name',
    'CREATE UNIQUE INDEX idx_ideas_active_name ON ideas (name_normalized)',
  );
  late final Index idxIdeasCreatedAt = Index(
    'idx_ideas_created_at',
    'CREATE INDEX idx_ideas_created_at ON ideas (created_at)',
  );
  late final Trigger inv7IdeaInsert = Trigger(
    'CREATE TRIGGER inv7_idea_insert BEFORE INSERT ON ideas WHEN EXISTS (SELECT 1 FROM idea_tombstones WHERE id = NEW.id) BEGIN SELECT RAISE (ABORT, \'INV-7: this Idea id is tombstoned\');END',
    'inv7_idea_insert',
  );
  late final Trigger inv7IdeaUpdate = Trigger(
    'CREATE TRIGGER inv7_idea_update BEFORE UPDATE ON ideas WHEN EXISTS (SELECT 1 FROM idea_tombstones WHERE id = NEW.id) BEGIN SELECT RAISE (ABORT, \'INV-7: this Idea id is tombstoned\');END',
    'inv7_idea_update',
  );
  late final Trigger inv7TombstoneInsert = Trigger(
    'CREATE TRIGGER inv7_tombstone_insert BEFORE INSERT ON idea_tombstones WHEN EXISTS (SELECT 1 FROM ideas WHERE id = NEW.id) BEGIN SELECT RAISE (ABORT, \'INV-7: this Idea is still present; delete it first\');END',
    'inv7_tombstone_insert',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    settings,
    replica,
    events,
    idxEventsItem,
    idxEventsTimestamp,
    ideaTombstones,
    ideas,
    ideaTags,
    tasks,
    taskTags,
    idxIdeaTagsNormalized,
    idxTaskTagsNormalized,
    idxTasksActiveName,
    idxTasksActive,
    idxTasksCompletedAt,
    subtasks,
    idxSubtasksTask,
    inv2SubtaskInsert,
    inv2SubtaskUpdate,
    inv2TaskInsert,
    inv2TaskUpdate,
    idxIdeasActiveName,
    idxIdeasCreatedAt,
    inv7IdeaInsert,
    inv7IdeaUpdate,
    inv7TombstoneInsert,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'ideas',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('idea_tags', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'tasks',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('task_tags', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'tasks',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('subtasks', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'subtasks',
        limitUpdateKind: UpdateKind.insert,
      ),
      result: [],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'subtasks',
        limitUpdateKind: UpdateKind.update,
      ),
      result: [],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'tasks',
        limitUpdateKind: UpdateKind.insert,
      ),
      result: [],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'tasks',
        limitUpdateKind: UpdateKind.update,
      ),
      result: [],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'ideas',
        limitUpdateKind: UpdateKind.insert,
      ),
      result: [],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'ideas',
        limitUpdateKind: UpdateKind.update,
      ),
      result: [],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'idea_tombstones',
        limitUpdateKind: UpdateKind.insert,
      ),
      result: [],
    ),
  ]);
  @override
  DriftDatabaseOptions get options =>
      const DriftDatabaseOptions(storeDateTimeAsText: true);
}

typedef $SettingsCreateCompanionBuilder = SettingsCompanion Function({
  required String settingKey,
  required String settingValue,
  Value<int> rowid,
});
typedef $SettingsUpdateCompanionBuilder = SettingsCompanion Function({
  Value<String> settingKey,
  Value<String> settingValue,
  Value<int> rowid,
});

class $SettingsFilterComposer extends Composer<_$AppDatabase, Settings> {
  $SettingsFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get settingKey => $composableBuilder(
    column: $table.settingKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get settingValue => $composableBuilder(
    column: $table.settingValue,
    builder: (column) => ColumnFilters(column),
  );
}

class $SettingsOrderingComposer extends Composer<_$AppDatabase, Settings> {
  $SettingsOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get settingKey => $composableBuilder(
    column: $table.settingKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get settingValue => $composableBuilder(
    column: $table.settingValue,
    builder: (column) => ColumnOrderings(column),
  );
}

class $SettingsAnnotationComposer extends Composer<_$AppDatabase, Settings> {
  $SettingsAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get settingKey => $composableBuilder(
    column: $table.settingKey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get settingValue => $composableBuilder(
    column: $table.settingValue,
    builder: (column) => column,
  );
}

class $SettingsTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          Settings,
          SettingRow,
          $SettingsFilterComposer,
          $SettingsOrderingComposer,
          $SettingsAnnotationComposer,
          $SettingsCreateCompanionBuilder,
          $SettingsUpdateCompanionBuilder,
          (SettingRow, BaseReferences<_$AppDatabase, Settings, SettingRow>),
          SettingRow,
          PrefetchHooks Function()
        > {
  $SettingsTableManager(_$AppDatabase db, Settings table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $SettingsFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $SettingsOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $SettingsAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> settingKey = const Value.absent(),
                Value<String> settingValue = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SettingsCompanion(
                settingKey: settingKey,
                settingValue: settingValue,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String settingKey,
                required String settingValue,
                Value<int> rowid = const Value.absent(),
              }) => SettingsCompanion.insert(
                settingKey: settingKey,
                settingValue: settingValue,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<Settings, SettingRow>(table),
                  BaseReferences<_$AppDatabase, Settings, SettingRow>(
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

typedef $SettingsProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      Settings,
      SettingRow,
      $SettingsFilterComposer,
      $SettingsOrderingComposer,
      $SettingsAnnotationComposer,
      $SettingsCreateCompanionBuilder,
      $SettingsUpdateCompanionBuilder,
      (SettingRow, BaseReferences<_$AppDatabase, Settings, SettingRow>),
      SettingRow,
      PrefetchHooks Function()
    >;
typedef $ReplicaCreateCompanionBuilder = ReplicaCompanion Function({
  Value<int> id,
  required String replicaId,
  required String deviceName,
});
typedef $ReplicaUpdateCompanionBuilder = ReplicaCompanion Function({
  Value<int> id,
  Value<String> replicaId,
  Value<String> deviceName,
});

class $ReplicaFilterComposer extends Composer<_$AppDatabase, Replica> {
  $ReplicaFilterComposer({
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

  ColumnFilters<String> get replicaId => $composableBuilder(
    column: $table.replicaId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deviceName => $composableBuilder(
    column: $table.deviceName,
    builder: (column) => ColumnFilters(column),
  );
}

class $ReplicaOrderingComposer extends Composer<_$AppDatabase, Replica> {
  $ReplicaOrderingComposer({
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

  ColumnOrderings<String> get replicaId => $composableBuilder(
    column: $table.replicaId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deviceName => $composableBuilder(
    column: $table.deviceName,
    builder: (column) => ColumnOrderings(column),
  );
}

class $ReplicaAnnotationComposer extends Composer<_$AppDatabase, Replica> {
  $ReplicaAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get replicaId =>
      $composableBuilder(column: $table.replicaId, builder: (column) => column);

  GeneratedColumn<String> get deviceName => $composableBuilder(
    column: $table.deviceName,
    builder: (column) => column,
  );
}

class $ReplicaTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          Replica,
          ReplicaRow,
          $ReplicaFilterComposer,
          $ReplicaOrderingComposer,
          $ReplicaAnnotationComposer,
          $ReplicaCreateCompanionBuilder,
          $ReplicaUpdateCompanionBuilder,
          (ReplicaRow, BaseReferences<_$AppDatabase, Replica, ReplicaRow>),
          ReplicaRow,
          PrefetchHooks Function()
        > {
  $ReplicaTableManager(_$AppDatabase db, Replica table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $ReplicaFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $ReplicaOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $ReplicaAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> replicaId = const Value.absent(),
                Value<String> deviceName = const Value.absent(),
              }) => ReplicaCompanion(
                id: id,
                replicaId: replicaId,
                deviceName: deviceName,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String replicaId,
                required String deviceName,
              }) => ReplicaCompanion.insert(
                id: id,
                replicaId: replicaId,
                deviceName: deviceName,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<Replica, ReplicaRow>(table),
                  BaseReferences<_$AppDatabase, Replica, ReplicaRow>(
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

typedef $ReplicaProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      Replica,
      ReplicaRow,
      $ReplicaFilterComposer,
      $ReplicaOrderingComposer,
      $ReplicaAnnotationComposer,
      $ReplicaCreateCompanionBuilder,
      $ReplicaUpdateCompanionBuilder,
      (ReplicaRow, BaseReferences<_$AppDatabase, Replica, ReplicaRow>),
      ReplicaRow,
      PrefetchHooks Function()
    >;
typedef $EventsCreateCompanionBuilder = EventsCompanion Function({
  required String eventId,
  required String itemId,
  required String itemKind,
  required String type,
  required String timestamp,
  Value<String> payload,
  Value<int> rowid,
});
typedef $EventsUpdateCompanionBuilder = EventsCompanion Function({
  Value<String> eventId,
  Value<String> itemId,
  Value<String> itemKind,
  Value<String> type,
  Value<String> timestamp,
  Value<String> payload,
  Value<int> rowid,
});

class $EventsFilterComposer extends Composer<_$AppDatabase, Events> {
  $EventsFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get eventId => $composableBuilder(
    column: $table.eventId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get itemId => $composableBuilder(
    column: $table.itemId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get itemKind => $composableBuilder(
    column: $table.itemKind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get timestamp => $composableBuilder(
    column: $table.timestamp,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );
}

class $EventsOrderingComposer extends Composer<_$AppDatabase, Events> {
  $EventsOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get eventId => $composableBuilder(
    column: $table.eventId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get itemId => $composableBuilder(
    column: $table.itemId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get itemKind => $composableBuilder(
    column: $table.itemKind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get timestamp => $composableBuilder(
    column: $table.timestamp,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );
}

class $EventsAnnotationComposer extends Composer<_$AppDatabase, Events> {
  $EventsAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get eventId =>
      $composableBuilder(column: $table.eventId, builder: (column) => column);

  GeneratedColumn<String> get itemId =>
      $composableBuilder(column: $table.itemId, builder: (column) => column);

  GeneratedColumn<String> get itemKind =>
      $composableBuilder(column: $table.itemKind, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get timestamp =>
      $composableBuilder(column: $table.timestamp, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);
}

class $EventsTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          Events,
          EventRow,
          $EventsFilterComposer,
          $EventsOrderingComposer,
          $EventsAnnotationComposer,
          $EventsCreateCompanionBuilder,
          $EventsUpdateCompanionBuilder,
          (EventRow, BaseReferences<_$AppDatabase, Events, EventRow>),
          EventRow,
          PrefetchHooks Function()
        > {
  $EventsTableManager(_$AppDatabase db, Events table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $EventsFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $EventsOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $EventsAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> eventId = const Value.absent(),
                Value<String> itemId = const Value.absent(),
                Value<String> itemKind = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String> timestamp = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EventsCompanion(
                eventId: eventId,
                itemId: itemId,
                itemKind: itemKind,
                type: type,
                timestamp: timestamp,
                payload: payload,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String eventId,
                required String itemId,
                required String itemKind,
                required String type,
                required String timestamp,
                Value<String> payload = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EventsCompanion.insert(
                eventId: eventId,
                itemId: itemId,
                itemKind: itemKind,
                type: type,
                timestamp: timestamp,
                payload: payload,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<Events, EventRow>(table),
                  BaseReferences<_$AppDatabase, Events, EventRow>(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $EventsProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      Events,
      EventRow,
      $EventsFilterComposer,
      $EventsOrderingComposer,
      $EventsAnnotationComposer,
      $EventsCreateCompanionBuilder,
      $EventsUpdateCompanionBuilder,
      (EventRow, BaseReferences<_$AppDatabase, Events, EventRow>),
      EventRow,
      PrefetchHooks Function()
    >;
typedef $IdeaTombstonesCreateCompanionBuilder =
    IdeaTombstonesCompanion Function({
      required String id,
      required String deletedAt,
      required String reason,
      Value<int> rowid,
    });
typedef $IdeaTombstonesUpdateCompanionBuilder =
    IdeaTombstonesCompanion Function({
      Value<String> id,
      Value<String> deletedAt,
      Value<String> reason,
      Value<int> rowid,
    });

class $IdeaTombstonesFilterComposer
    extends Composer<_$AppDatabase, IdeaTombstones> {
  $IdeaTombstonesFilterComposer({
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

  ColumnFilters<String> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reason => $composableBuilder(
    column: $table.reason,
    builder: (column) => ColumnFilters(column),
  );
}

class $IdeaTombstonesOrderingComposer
    extends Composer<_$AppDatabase, IdeaTombstones> {
  $IdeaTombstonesOrderingComposer({
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

  ColumnOrderings<String> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reason => $composableBuilder(
    column: $table.reason,
    builder: (column) => ColumnOrderings(column),
  );
}

class $IdeaTombstonesAnnotationComposer
    extends Composer<_$AppDatabase, IdeaTombstones> {
  $IdeaTombstonesAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<String> get reason =>
      $composableBuilder(column: $table.reason, builder: (column) => column);
}

class $IdeaTombstonesTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          IdeaTombstones,
          IdeaTombstoneRow,
          $IdeaTombstonesFilterComposer,
          $IdeaTombstonesOrderingComposer,
          $IdeaTombstonesAnnotationComposer,
          $IdeaTombstonesCreateCompanionBuilder,
          $IdeaTombstonesUpdateCompanionBuilder,
          (
            IdeaTombstoneRow,
            BaseReferences<_$AppDatabase, IdeaTombstones, IdeaTombstoneRow>,
          ),
          IdeaTombstoneRow,
          PrefetchHooks Function()
        > {
  $IdeaTombstonesTableManager(_$AppDatabase db, IdeaTombstones table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $IdeaTombstonesFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $IdeaTombstonesOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $IdeaTombstonesAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> deletedAt = const Value.absent(),
                Value<String> reason = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => IdeaTombstonesCompanion(
                id: id,
                deletedAt: deletedAt,
                reason: reason,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String deletedAt,
                required String reason,
                Value<int> rowid = const Value.absent(),
              }) => IdeaTombstonesCompanion.insert(
                id: id,
                deletedAt: deletedAt,
                reason: reason,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<IdeaTombstones, IdeaTombstoneRow>(table),
                  BaseReferences<
                    _$AppDatabase,
                    IdeaTombstones,
                    IdeaTombstoneRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $IdeaTombstonesProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      IdeaTombstones,
      IdeaTombstoneRow,
      $IdeaTombstonesFilterComposer,
      $IdeaTombstonesOrderingComposer,
      $IdeaTombstonesAnnotationComposer,
      $IdeaTombstonesCreateCompanionBuilder,
      $IdeaTombstonesUpdateCompanionBuilder,
      (
        IdeaTombstoneRow,
        BaseReferences<_$AppDatabase, IdeaTombstones, IdeaTombstoneRow>,
      ),
      IdeaTombstoneRow,
      PrefetchHooks Function()
    >;
typedef $IdeasCreateCompanionBuilder = IdeasCompanion Function({
  required String id,
  required String name,
  required String nameNormalized,
  Value<String> context,
  required String timeframe,
  required String createdAt,
  required String updatedAt,
  Value<int> rowid,
});
typedef $IdeasUpdateCompanionBuilder = IdeasCompanion Function({
  Value<String> id,
  Value<String> name,
  Value<String> nameNormalized,
  Value<String> context,
  Value<String> timeframe,
  Value<String> createdAt,
  Value<String> updatedAt,
  Value<int> rowid,
});

final class $IdeasReferences
    extends BaseReferences<_$AppDatabase, Ideas, IdeaRow> {
  $IdeasReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<IdeaTags, List<IdeaTagRow>> _ideaTagsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.ideaTags,
    aliasName: 'ideas__id__idea_tags__owner_id',
  );

  $IdeaTagsProcessedTableManager get ideaTagsRefs {
    final manager = $IdeaTagsTableManager(
      $_db,
      $_db.ideaTags,
    ).filter((f) => f.ownerId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_ideaTagsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $IdeasFilterComposer extends Composer<_$AppDatabase, Ideas> {
  $IdeasFilterComposer({
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

  ColumnFilters<String> get nameNormalized => $composableBuilder(
    column: $table.nameNormalized,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get context => $composableBuilder(
    column: $table.context,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get timeframe => $composableBuilder(
    column: $table.timeframe,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> ideaTagsRefs(
    Expression<bool> Function($IdeaTagsFilterComposer f) f,
  ) {
    final $IdeaTagsFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.ideaTags,
      getReferencedColumn: (t) => t.ownerId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $IdeaTagsFilterComposer(
            $db: $db,
            $table: $db.ideaTags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $IdeasOrderingComposer extends Composer<_$AppDatabase, Ideas> {
  $IdeasOrderingComposer({
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

  ColumnOrderings<String> get nameNormalized => $composableBuilder(
    column: $table.nameNormalized,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get context => $composableBuilder(
    column: $table.context,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get timeframe => $composableBuilder(
    column: $table.timeframe,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $IdeasAnnotationComposer extends Composer<_$AppDatabase, Ideas> {
  $IdeasAnnotationComposer({
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

  GeneratedColumn<String> get nameNormalized => $composableBuilder(
    column: $table.nameNormalized,
    builder: (column) => column,
  );

  GeneratedColumn<String> get context =>
      $composableBuilder(column: $table.context, builder: (column) => column);

  GeneratedColumn<String> get timeframe =>
      $composableBuilder(column: $table.timeframe, builder: (column) => column);

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> ideaTagsRefs<T extends Object>(
    Expression<T> Function($IdeaTagsAnnotationComposer a) f,
  ) {
    final $IdeaTagsAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.ideaTags,
      getReferencedColumn: (t) => t.ownerId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $IdeaTagsAnnotationComposer(
            $db: $db,
            $table: $db.ideaTags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $IdeasTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          Ideas,
          IdeaRow,
          $IdeasFilterComposer,
          $IdeasOrderingComposer,
          $IdeasAnnotationComposer,
          $IdeasCreateCompanionBuilder,
          $IdeasUpdateCompanionBuilder,
          (IdeaRow, $IdeasReferences),
          IdeaRow,
          PrefetchHooks Function({bool ideaTagsRefs})
        > {
  $IdeasTableManager(_$AppDatabase db, Ideas table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $IdeasFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $IdeasOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $IdeasAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> nameNormalized = const Value.absent(),
                Value<String> context = const Value.absent(),
                Value<String> timeframe = const Value.absent(),
                Value<String> createdAt = const Value.absent(),
                Value<String> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => IdeasCompanion(
                id: id,
                name: name,
                nameNormalized: nameNormalized,
                context: context,
                timeframe: timeframe,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required String nameNormalized,
                Value<String> context = const Value.absent(),
                required String timeframe,
                required String createdAt,
                required String updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => IdeasCompanion.insert(
                id: id,
                name: name,
                nameNormalized: nameNormalized,
                context: context,
                timeframe: timeframe,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<Ideas, IdeaRow>(table),
                  $IdeasReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({ideaTagsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (ideaTagsRefs) db.ideaTags],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (ideaTagsRefs)
                    await $_getPrefetchedData<IdeaRow, Ideas, IdeaTagRow>(
                      currentTable: table,
                      referencedTable: $IdeasReferences._ideaTagsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $IdeasReferences(db, table, p0).ideaTagsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.ownerId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $IdeasProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      Ideas,
      IdeaRow,
      $IdeasFilterComposer,
      $IdeasOrderingComposer,
      $IdeasAnnotationComposer,
      $IdeasCreateCompanionBuilder,
      $IdeasUpdateCompanionBuilder,
      (IdeaRow, $IdeasReferences),
      IdeaRow,
      PrefetchHooks Function({bool ideaTagsRefs})
    >;
typedef $IdeaTagsCreateCompanionBuilder = IdeaTagsCompanion Function({
  required String ownerId,
  required String value,
  required String valueNormalized,
  required int sortIndex,
  Value<int> rowid,
});
typedef $IdeaTagsUpdateCompanionBuilder = IdeaTagsCompanion Function({
  Value<String> ownerId,
  Value<String> value,
  Value<String> valueNormalized,
  Value<int> sortIndex,
  Value<int> rowid,
});

final class $IdeaTagsReferences
    extends BaseReferences<_$AppDatabase, IdeaTags, IdeaTagRow> {
  $IdeaTagsReferences(super.$_db, super.$_table, super.$_typedResult);

  static Ideas _ownerIdTable(_$AppDatabase db) =>
      db.ideas.createAlias('idea_tags__owner_id__ideas__id');

  $IdeasProcessedTableManager get ownerId {
    final $_column = $_itemColumn<String>('owner_id')!;

    final manager = $IdeasTableManager(
      $_db,
      $_db.ideas,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_ownerIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $IdeaTagsFilterComposer extends Composer<_$AppDatabase, IdeaTags> {
  $IdeaTagsFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get valueNormalized => $composableBuilder(
    column: $table.valueNormalized,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortIndex => $composableBuilder(
    column: $table.sortIndex,
    builder: (column) => ColumnFilters(column),
  );

  $IdeasFilterComposer get ownerId {
    final $IdeasFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.ownerId,
      referencedTable: $db.ideas,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $IdeasFilterComposer(
            $db: $db,
            $table: $db.ideas,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $IdeaTagsOrderingComposer extends Composer<_$AppDatabase, IdeaTags> {
  $IdeaTagsOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get valueNormalized => $composableBuilder(
    column: $table.valueNormalized,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortIndex => $composableBuilder(
    column: $table.sortIndex,
    builder: (column) => ColumnOrderings(column),
  );

  $IdeasOrderingComposer get ownerId {
    final $IdeasOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.ownerId,
      referencedTable: $db.ideas,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $IdeasOrderingComposer(
            $db: $db,
            $table: $db.ideas,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $IdeaTagsAnnotationComposer extends Composer<_$AppDatabase, IdeaTags> {
  $IdeaTagsAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);

  GeneratedColumn<String> get valueNormalized => $composableBuilder(
    column: $table.valueNormalized,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sortIndex =>
      $composableBuilder(column: $table.sortIndex, builder: (column) => column);

  $IdeasAnnotationComposer get ownerId {
    final $IdeasAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.ownerId,
      referencedTable: $db.ideas,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $IdeasAnnotationComposer(
            $db: $db,
            $table: $db.ideas,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $IdeaTagsTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          IdeaTags,
          IdeaTagRow,
          $IdeaTagsFilterComposer,
          $IdeaTagsOrderingComposer,
          $IdeaTagsAnnotationComposer,
          $IdeaTagsCreateCompanionBuilder,
          $IdeaTagsUpdateCompanionBuilder,
          (IdeaTagRow, $IdeaTagsReferences),
          IdeaTagRow,
          PrefetchHooks Function({bool ownerId})
        > {
  $IdeaTagsTableManager(_$AppDatabase db, IdeaTags table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $IdeaTagsFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $IdeaTagsOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $IdeaTagsAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> ownerId = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<String> valueNormalized = const Value.absent(),
                Value<int> sortIndex = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => IdeaTagsCompanion(
                ownerId: ownerId,
                value: value,
                valueNormalized: valueNormalized,
                sortIndex: sortIndex,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String ownerId,
                required String value,
                required String valueNormalized,
                required int sortIndex,
                Value<int> rowid = const Value.absent(),
              }) => IdeaTagsCompanion.insert(
                ownerId: ownerId,
                value: value,
                valueNormalized: valueNormalized,
                sortIndex: sortIndex,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<IdeaTags, IdeaTagRow>(table),
                  $IdeaTagsReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({ownerId = false}) {
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
                    if (ownerId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.ownerId,
                        referencedTable: $IdeaTagsReferences._ownerIdTable(db),
                        referencedColumn: $IdeaTagsReferences
                            ._ownerIdTable(db)
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

typedef $IdeaTagsProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      IdeaTags,
      IdeaTagRow,
      $IdeaTagsFilterComposer,
      $IdeaTagsOrderingComposer,
      $IdeaTagsAnnotationComposer,
      $IdeaTagsCreateCompanionBuilder,
      $IdeaTagsUpdateCompanionBuilder,
      (IdeaTagRow, $IdeaTagsReferences),
      IdeaTagRow,
      PrefetchHooks Function({bool ownerId})
    >;
typedef $TasksCreateCompanionBuilder = TasksCompanion Function({
  required String id,
  required String name,
  required String nameNormalized,
  Value<String> description,
  required String status,
  required String createdAt,
  required String updatedAt,
  Value<String?> completedAt,
  Value<int> isArchived,
  Value<String?> archivedAt,
  Value<int> isDeleted,
  Value<String?> deletedAt,
  Value<String?> sourceIdeaId,
  Value<String?> sourceIdeaCreatedAt,
  Value<int> rowid,
});
typedef $TasksUpdateCompanionBuilder = TasksCompanion Function({
  Value<String> id,
  Value<String> name,
  Value<String> nameNormalized,
  Value<String> description,
  Value<String> status,
  Value<String> createdAt,
  Value<String> updatedAt,
  Value<String?> completedAt,
  Value<int> isArchived,
  Value<String?> archivedAt,
  Value<int> isDeleted,
  Value<String?> deletedAt,
  Value<String?> sourceIdeaId,
  Value<String?> sourceIdeaCreatedAt,
  Value<int> rowid,
});

final class $TasksReferences
    extends BaseReferences<_$AppDatabase, Tasks, TaskRow> {
  $TasksReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<TaskTags, List<TaskTagRow>> _taskTagsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.taskTags,
    aliasName: 'tasks__id__task_tags__owner_id',
  );

  $TaskTagsProcessedTableManager get taskTagsRefs {
    final manager = $TaskTagsTableManager(
      $_db,
      $_db.taskTags,
    ).filter((f) => f.ownerId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_taskTagsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<Subtasks, List<SubtaskRow>> _subtasksRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.subtasks,
    aliasName: 'tasks__id__subtasks__task_id',
  );

  $SubtasksProcessedTableManager get subtasksRefs {
    final manager = $SubtasksTableManager(
      $_db,
      $_db.subtasks,
    ).filter((f) => f.taskId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_subtasksRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $TasksFilterComposer extends Composer<_$AppDatabase, Tasks> {
  $TasksFilterComposer({
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

  ColumnFilters<String> get nameNormalized => $composableBuilder(
    column: $table.nameNormalized,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get isArchived => $composableBuilder(
    column: $table.isArchived,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceIdeaId => $composableBuilder(
    column: $table.sourceIdeaId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceIdeaCreatedAt => $composableBuilder(
    column: $table.sourceIdeaCreatedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> taskTagsRefs(
    Expression<bool> Function($TaskTagsFilterComposer f) f,
  ) {
    final $TaskTagsFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.taskTags,
      getReferencedColumn: (t) => t.ownerId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $TaskTagsFilterComposer(
            $db: $db,
            $table: $db.taskTags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> subtasksRefs(
    Expression<bool> Function($SubtasksFilterComposer f) f,
  ) {
    final $SubtasksFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.subtasks,
      getReferencedColumn: (t) => t.taskId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $SubtasksFilterComposer(
            $db: $db,
            $table: $db.subtasks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $TasksOrderingComposer extends Composer<_$AppDatabase, Tasks> {
  $TasksOrderingComposer({
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

  ColumnOrderings<String> get nameNormalized => $composableBuilder(
    column: $table.nameNormalized,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get isArchived => $composableBuilder(
    column: $table.isArchived,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceIdeaId => $composableBuilder(
    column: $table.sourceIdeaId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceIdeaCreatedAt => $composableBuilder(
    column: $table.sourceIdeaCreatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $TasksAnnotationComposer extends Composer<_$AppDatabase, Tasks> {
  $TasksAnnotationComposer({
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

  GeneratedColumn<String> get nameNormalized => $composableBuilder(
    column: $table.nameNormalized,
    builder: (column) => column,
  );

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get isArchived => $composableBuilder(
    column: $table.isArchived,
    builder: (column) => column,
  );

  GeneratedColumn<String> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get isDeleted =>
      $composableBuilder(column: $table.isDeleted, builder: (column) => column);

  GeneratedColumn<String> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<String> get sourceIdeaId => $composableBuilder(
    column: $table.sourceIdeaId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sourceIdeaCreatedAt => $composableBuilder(
    column: $table.sourceIdeaCreatedAt,
    builder: (column) => column,
  );

  Expression<T> taskTagsRefs<T extends Object>(
    Expression<T> Function($TaskTagsAnnotationComposer a) f,
  ) {
    final $TaskTagsAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.taskTags,
      getReferencedColumn: (t) => t.ownerId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $TaskTagsAnnotationComposer(
            $db: $db,
            $table: $db.taskTags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> subtasksRefs<T extends Object>(
    Expression<T> Function($SubtasksAnnotationComposer a) f,
  ) {
    final $SubtasksAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.subtasks,
      getReferencedColumn: (t) => t.taskId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $SubtasksAnnotationComposer(
            $db: $db,
            $table: $db.subtasks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $TasksTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          Tasks,
          TaskRow,
          $TasksFilterComposer,
          $TasksOrderingComposer,
          $TasksAnnotationComposer,
          $TasksCreateCompanionBuilder,
          $TasksUpdateCompanionBuilder,
          (TaskRow, $TasksReferences),
          TaskRow,
          PrefetchHooks Function({bool taskTagsRefs, bool subtasksRefs})
        > {
  $TasksTableManager(_$AppDatabase db, Tasks table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $TasksFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $TasksOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $TasksAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> nameNormalized = const Value.absent(),
                Value<String> description = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String> createdAt = const Value.absent(),
                Value<String> updatedAt = const Value.absent(),
                Value<String?> completedAt = const Value.absent(),
                Value<int> isArchived = const Value.absent(),
                Value<String?> archivedAt = const Value.absent(),
                Value<int> isDeleted = const Value.absent(),
                Value<String?> deletedAt = const Value.absent(),
                Value<String?> sourceIdeaId = const Value.absent(),
                Value<String?> sourceIdeaCreatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TasksCompanion(
                id: id,
                name: name,
                nameNormalized: nameNormalized,
                description: description,
                status: status,
                createdAt: createdAt,
                updatedAt: updatedAt,
                completedAt: completedAt,
                isArchived: isArchived,
                archivedAt: archivedAt,
                isDeleted: isDeleted,
                deletedAt: deletedAt,
                sourceIdeaId: sourceIdeaId,
                sourceIdeaCreatedAt: sourceIdeaCreatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required String nameNormalized,
                Value<String> description = const Value.absent(),
                required String status,
                required String createdAt,
                required String updatedAt,
                Value<String?> completedAt = const Value.absent(),
                Value<int> isArchived = const Value.absent(),
                Value<String?> archivedAt = const Value.absent(),
                Value<int> isDeleted = const Value.absent(),
                Value<String?> deletedAt = const Value.absent(),
                Value<String?> sourceIdeaId = const Value.absent(),
                Value<String?> sourceIdeaCreatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TasksCompanion.insert(
                id: id,
                name: name,
                nameNormalized: nameNormalized,
                description: description,
                status: status,
                createdAt: createdAt,
                updatedAt: updatedAt,
                completedAt: completedAt,
                isArchived: isArchived,
                archivedAt: archivedAt,
                isDeleted: isDeleted,
                deletedAt: deletedAt,
                sourceIdeaId: sourceIdeaId,
                sourceIdeaCreatedAt: sourceIdeaCreatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<Tasks, TaskRow>(table),
                  $TasksReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({taskTagsRefs = false, subtasksRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (taskTagsRefs) db.taskTags,
                    if (subtasksRefs) db.subtasks,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (taskTagsRefs)
                        await $_getPrefetchedData<TaskRow, Tasks, TaskTagRow>(
                          currentTable: table,
                          referencedTable: $TasksReferences._taskTagsRefsTable(
                            db,
                          ),
                          managerFromTypedResult: (p0) =>
                              $TasksReferences(db, table, p0).taskTagsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.ownerId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (subtasksRefs)
                        await $_getPrefetchedData<TaskRow, Tasks, SubtaskRow>(
                          currentTable: table,
                          referencedTable: $TasksReferences._subtasksRefsTable(
                            db,
                          ),
                          managerFromTypedResult: (p0) =>
                              $TasksReferences(db, table, p0).subtasksRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.taskId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $TasksProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      Tasks,
      TaskRow,
      $TasksFilterComposer,
      $TasksOrderingComposer,
      $TasksAnnotationComposer,
      $TasksCreateCompanionBuilder,
      $TasksUpdateCompanionBuilder,
      (TaskRow, $TasksReferences),
      TaskRow,
      PrefetchHooks Function({bool taskTagsRefs, bool subtasksRefs})
    >;
typedef $TaskTagsCreateCompanionBuilder = TaskTagsCompanion Function({
  required String ownerId,
  required String value,
  required String valueNormalized,
  required int sortIndex,
  Value<int> rowid,
});
typedef $TaskTagsUpdateCompanionBuilder = TaskTagsCompanion Function({
  Value<String> ownerId,
  Value<String> value,
  Value<String> valueNormalized,
  Value<int> sortIndex,
  Value<int> rowid,
});

final class $TaskTagsReferences
    extends BaseReferences<_$AppDatabase, TaskTags, TaskTagRow> {
  $TaskTagsReferences(super.$_db, super.$_table, super.$_typedResult);

  static Tasks _ownerIdTable(_$AppDatabase db) =>
      db.tasks.createAlias('task_tags__owner_id__tasks__id');

  $TasksProcessedTableManager get ownerId {
    final $_column = $_itemColumn<String>('owner_id')!;

    final manager = $TasksTableManager(
      $_db,
      $_db.tasks,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_ownerIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $TaskTagsFilterComposer extends Composer<_$AppDatabase, TaskTags> {
  $TaskTagsFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get valueNormalized => $composableBuilder(
    column: $table.valueNormalized,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortIndex => $composableBuilder(
    column: $table.sortIndex,
    builder: (column) => ColumnFilters(column),
  );

  $TasksFilterComposer get ownerId {
    final $TasksFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.ownerId,
      referencedTable: $db.tasks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $TasksFilterComposer(
            $db: $db,
            $table: $db.tasks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $TaskTagsOrderingComposer extends Composer<_$AppDatabase, TaskTags> {
  $TaskTagsOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get valueNormalized => $composableBuilder(
    column: $table.valueNormalized,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortIndex => $composableBuilder(
    column: $table.sortIndex,
    builder: (column) => ColumnOrderings(column),
  );

  $TasksOrderingComposer get ownerId {
    final $TasksOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.ownerId,
      referencedTable: $db.tasks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $TasksOrderingComposer(
            $db: $db,
            $table: $db.tasks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $TaskTagsAnnotationComposer extends Composer<_$AppDatabase, TaskTags> {
  $TaskTagsAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);

  GeneratedColumn<String> get valueNormalized => $composableBuilder(
    column: $table.valueNormalized,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sortIndex =>
      $composableBuilder(column: $table.sortIndex, builder: (column) => column);

  $TasksAnnotationComposer get ownerId {
    final $TasksAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.ownerId,
      referencedTable: $db.tasks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $TasksAnnotationComposer(
            $db: $db,
            $table: $db.tasks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $TaskTagsTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          TaskTags,
          TaskTagRow,
          $TaskTagsFilterComposer,
          $TaskTagsOrderingComposer,
          $TaskTagsAnnotationComposer,
          $TaskTagsCreateCompanionBuilder,
          $TaskTagsUpdateCompanionBuilder,
          (TaskTagRow, $TaskTagsReferences),
          TaskTagRow,
          PrefetchHooks Function({bool ownerId})
        > {
  $TaskTagsTableManager(_$AppDatabase db, TaskTags table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $TaskTagsFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $TaskTagsOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $TaskTagsAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> ownerId = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<String> valueNormalized = const Value.absent(),
                Value<int> sortIndex = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TaskTagsCompanion(
                ownerId: ownerId,
                value: value,
                valueNormalized: valueNormalized,
                sortIndex: sortIndex,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String ownerId,
                required String value,
                required String valueNormalized,
                required int sortIndex,
                Value<int> rowid = const Value.absent(),
              }) => TaskTagsCompanion.insert(
                ownerId: ownerId,
                value: value,
                valueNormalized: valueNormalized,
                sortIndex: sortIndex,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<TaskTags, TaskTagRow>(table),
                  $TaskTagsReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({ownerId = false}) {
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
                    if (ownerId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.ownerId,
                        referencedTable: $TaskTagsReferences._ownerIdTable(db),
                        referencedColumn: $TaskTagsReferences
                            ._ownerIdTable(db)
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

typedef $TaskTagsProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      TaskTags,
      TaskTagRow,
      $TaskTagsFilterComposer,
      $TaskTagsOrderingComposer,
      $TaskTagsAnnotationComposer,
      $TaskTagsCreateCompanionBuilder,
      $TaskTagsUpdateCompanionBuilder,
      (TaskTagRow, $TaskTagsReferences),
      TaskTagRow,
      PrefetchHooks Function({bool ownerId})
    >;
typedef $SubtasksCreateCompanionBuilder = SubtasksCompanion Function({
  required String id,
  required String taskId,
  required String name,
  required String status,
  required int sortIndex,
  required String createdAt,
  required String updatedAt,
  Value<String?> completedAt,
  Value<int> rowid,
});
typedef $SubtasksUpdateCompanionBuilder = SubtasksCompanion Function({
  Value<String> id,
  Value<String> taskId,
  Value<String> name,
  Value<String> status,
  Value<int> sortIndex,
  Value<String> createdAt,
  Value<String> updatedAt,
  Value<String?> completedAt,
  Value<int> rowid,
});

final class $SubtasksReferences
    extends BaseReferences<_$AppDatabase, Subtasks, SubtaskRow> {
  $SubtasksReferences(super.$_db, super.$_table, super.$_typedResult);

  static Tasks _taskIdTable(_$AppDatabase db) =>
      db.tasks.createAlias('subtasks__task_id__tasks__id');

  $TasksProcessedTableManager get taskId {
    final $_column = $_itemColumn<String>('task_id')!;

    final manager = $TasksTableManager(
      $_db,
      $_db.tasks,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_taskIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $SubtasksFilterComposer extends Composer<_$AppDatabase, Subtasks> {
  $SubtasksFilterComposer({
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

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortIndex => $composableBuilder(
    column: $table.sortIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnFilters(column),
  );

  $TasksFilterComposer get taskId {
    final $TasksFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.taskId,
      referencedTable: $db.tasks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $TasksFilterComposer(
            $db: $db,
            $table: $db.tasks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $SubtasksOrderingComposer extends Composer<_$AppDatabase, Subtasks> {
  $SubtasksOrderingComposer({
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

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortIndex => $composableBuilder(
    column: $table.sortIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $TasksOrderingComposer get taskId {
    final $TasksOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.taskId,
      referencedTable: $db.tasks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $TasksOrderingComposer(
            $db: $db,
            $table: $db.tasks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $SubtasksAnnotationComposer extends Composer<_$AppDatabase, Subtasks> {
  $SubtasksAnnotationComposer({
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

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get sortIndex =>
      $composableBuilder(column: $table.sortIndex, builder: (column) => column);

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => column,
  );

  $TasksAnnotationComposer get taskId {
    final $TasksAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.taskId,
      referencedTable: $db.tasks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $TasksAnnotationComposer(
            $db: $db,
            $table: $db.tasks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $SubtasksTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          Subtasks,
          SubtaskRow,
          $SubtasksFilterComposer,
          $SubtasksOrderingComposer,
          $SubtasksAnnotationComposer,
          $SubtasksCreateCompanionBuilder,
          $SubtasksUpdateCompanionBuilder,
          (SubtaskRow, $SubtasksReferences),
          SubtaskRow,
          PrefetchHooks Function({bool taskId})
        > {
  $SubtasksTableManager(_$AppDatabase db, Subtasks table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $SubtasksFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $SubtasksOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $SubtasksAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> taskId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> sortIndex = const Value.absent(),
                Value<String> createdAt = const Value.absent(),
                Value<String> updatedAt = const Value.absent(),
                Value<String?> completedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SubtasksCompanion(
                id: id,
                taskId: taskId,
                name: name,
                status: status,
                sortIndex: sortIndex,
                createdAt: createdAt,
                updatedAt: updatedAt,
                completedAt: completedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String taskId,
                required String name,
                required String status,
                required int sortIndex,
                required String createdAt,
                required String updatedAt,
                Value<String?> completedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SubtasksCompanion.insert(
                id: id,
                taskId: taskId,
                name: name,
                status: status,
                sortIndex: sortIndex,
                createdAt: createdAt,
                updatedAt: updatedAt,
                completedAt: completedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<Subtasks, SubtaskRow>(table),
                  $SubtasksReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({taskId = false}) {
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
                    if (taskId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.taskId,
                        referencedTable: $SubtasksReferences._taskIdTable(db),
                        referencedColumn: $SubtasksReferences
                            ._taskIdTable(db)
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

typedef $SubtasksProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      Subtasks,
      SubtaskRow,
      $SubtasksFilterComposer,
      $SubtasksOrderingComposer,
      $SubtasksAnnotationComposer,
      $SubtasksCreateCompanionBuilder,
      $SubtasksUpdateCompanionBuilder,
      (SubtaskRow, $SubtasksReferences),
      SubtaskRow,
      PrefetchHooks Function({bool taskId})
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $SettingsTableManager get settings =>
      $SettingsTableManager(_db, _db.settings);
  $ReplicaTableManager get replica => $ReplicaTableManager(_db, _db.replica);
  $EventsTableManager get events => $EventsTableManager(_db, _db.events);
  $IdeaTombstonesTableManager get ideaTombstones =>
      $IdeaTombstonesTableManager(_db, _db.ideaTombstones);
  $IdeasTableManager get ideas => $IdeasTableManager(_db, _db.ideas);
  $IdeaTagsTableManager get ideaTags =>
      $IdeaTagsTableManager(_db, _db.ideaTags);
  $TasksTableManager get tasks => $TasksTableManager(_db, _db.tasks);
  $TaskTagsTableManager get taskTags =>
      $TaskTagsTableManager(_db, _db.taskTags);
  $SubtasksTableManager get subtasks =>
      $SubtasksTableManager(_db, _db.subtasks);
}
