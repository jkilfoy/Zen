/// §11.5.1, §11.4.6. The Drift-backed [ReplicaRepository].
library;

import 'package:drift/drift.dart';
import 'package:zen_domain/zen_domain.dart';

import '../database.dart';

/// §11.5.1. The one-row table identifying this installation.
///
/// "`replica` holds exactly one row: this device's `replica_id` (UUIDv7,
/// generated on first launch) and `device_name`." The row is created on first
/// read rather than by a migration, because the device name comes from the
/// platform and only `zen_app` knows it (M4).
final class DriftReplicaRepository implements ReplicaRepository {
  /// Creates a repository over [db].
  ///
  /// [ids] mints the replica id on first launch; [defaultDeviceName] is what
  /// the row is seeded with if it does not exist yet.
  DriftReplicaRepository(
    this._db, {
    required IdGenerator ids,
    required String defaultDeviceName,
    // See the note in `DriftTaskRepository`: a named parameter may not begin
    // with an underscore, so `this._ids` is not available here.
    // ignore: prefer_initializing_formals
  }) : _ids = ids,
       // ignore: prefer_initializing_formals
       _defaultDeviceName = defaultDeviceName;

  final AppDatabase _db;
  final IdGenerator _ids;
  final String _defaultDeviceName;

  @override
  Future<String> replicaId() async => (await _row()).replicaId;

  @override
  Future<String> deviceName() async => (await _row()).deviceName;

  /// Renames this device, for the pairing screen (§11.6.4).
  Future<void> setDeviceName(String name) async {
    await _row();
    await (_db.update(_db.replica)..where((Replica r) => r.id.equals(1))).write(
      ReplicaCompanion(deviceName: Value<String>(name)),
    );
  }

  Future<ReplicaRow> _row() => _db.transaction(() async {
    final ReplicaRow? existing = await (_db.select(
      _db.replica,
    )..where((Replica r) => r.id.equals(1))).getSingleOrNull();
    if (existing != null) {
      return existing;
    }

    final ReplicaCompanion seed = ReplicaCompanion(
      id: const Value<int>(1),
      replicaId: Value<String>(_ids.newId()),
      deviceName: Value<String>(_defaultDeviceName),
    );
    await _db.into(_db.replica).insert(seed);
    return (_db.select(
      _db.replica,
    )..where((Replica r) => r.id.equals(1))).getSingle();
  });
}
