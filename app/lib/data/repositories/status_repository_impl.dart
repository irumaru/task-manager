import 'package:drift/drift.dart';

import '../database/app_database.dart';
import '../../domain/models/status.dart';
import '../../domain/repositories/status_repository.dart';

class StatusRepositoryImpl implements StatusRepository {
  final AppDatabase _db;

  StatusRepositoryImpl(this._db);

  Status _toDomain(StatusData d) => Status(
        id: d.id,
        name: d.name,
        sortOrder: d.sortOrder,
        isDefault: d.isDefault,
      );

  @override
  Future<List<Status>> getStatuses() async {
    final rows = await (_db.select(_db.statuses)
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .get();
    return rows.map(_toDomain).toList();
  }

  @override
  Future<int> addStatus({required String name}) async {
    final rows = await _db.select(_db.statuses).get();
    final nextOrder = rows.isEmpty
        ? 0
        : rows.map((r) => r.sortOrder).reduce((a, b) => a > b ? a : b) + 1;
    return _db.into(_db.statuses).insert(
          StatusesCompanion.insert(name: name, sortOrder: nextOrder),
        );
  }

  @override
  Future<void> updateStatus(
      {required int id, required String name, int? sortOrder}) async {
    await (_db.update(_db.statuses)..where((t) => t.id.equals(id))).write(
      StatusesCompanion(
        name: Value(name),
        sortOrder: sortOrder != null ? Value(sortOrder) : const Value.absent(),
      ),
    );
  }

  @override
  Future<void> deleteStatus(int id) async {
    await (_db.update(_db.tasks)..where((t) => t.statusId.equals(id)))
        .write(const TasksCompanion(statusId: Value(null)));
    await (_db.delete(_db.statuses)..where((t) => t.id.equals(id))).go();
  }

  @override
  Future<void> reorderStatuses(List<int> orderedIds) async {
    await _db.transaction(() async {
      for (var i = 0; i < orderedIds.length; i++) {
        await (_db.update(_db.statuses)
              ..where((t) => t.id.equals(orderedIds[i])))
            .write(StatusesCompanion(sortOrder: Value(i)));
      }
    });
  }
}
