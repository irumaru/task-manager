import 'package:drift/drift.dart';

import '../database/app_database.dart';
import '../../domain/models/priority.dart';
import '../../domain/repositories/priority_repository.dart';

class PriorityRepositoryImpl implements PriorityRepository {
  final AppDatabase _db;

  PriorityRepositoryImpl(this._db);

  Priority _toDomain(PriorityData d) => Priority(
        id: d.id,
        name: d.name,
        sortOrder: d.sortOrder,
        isDefault: d.isDefault,
      );

  @override
  Future<List<Priority>> getPriorities() async {
    final rows = await (_db.select(_db.priorities)
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .get();
    return rows.map(_toDomain).toList();
  }

  @override
  Future<int> addPriority({required String name}) async {
    final rows = await _db.select(_db.priorities).get();
    final nextOrder = rows.isEmpty
        ? 0
        : rows.map((r) => r.sortOrder).reduce((a, b) => a > b ? a : b) + 1;
    return _db.into(_db.priorities).insert(
          PrioritiesCompanion.insert(name: name, sortOrder: nextOrder),
        );
  }

  @override
  Future<void> updatePriority(
      {required int id, required String name, int? sortOrder}) async {
    await (_db.update(_db.priorities)..where((t) => t.id.equals(id))).write(
      PrioritiesCompanion(
        name: Value(name),
        sortOrder: sortOrder != null ? Value(sortOrder) : const Value.absent(),
      ),
    );
  }

  @override
  Future<void> deletePriority(int id) async {
    await (_db.update(_db.tasks)..where((t) => t.priorityId.equals(id)))
        .write(const TasksCompanion(priorityId: Value(null)));
    await (_db.delete(_db.priorities)..where((t) => t.id.equals(id))).go();
  }

  @override
  Future<void> reorderPriorities(List<int> orderedIds) async {
    await _db.transaction(() async {
      for (var i = 0; i < orderedIds.length; i++) {
        await (_db.update(_db.priorities)
              ..where((t) => t.id.equals(orderedIds[i])))
            .write(PrioritiesCompanion(sortOrder: Value(i)));
      }
    });
  }
}
