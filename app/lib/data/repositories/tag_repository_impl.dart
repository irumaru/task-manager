import 'package:drift/drift.dart';

import '../database/app_database.dart';
import '../../domain/models/tag.dart';
import '../../domain/repositories/tag_repository.dart';

class TagRepositoryImpl implements TagRepository {
  final AppDatabase _db;

  TagRepositoryImpl(this._db);

  Tag _toDomain(TagData d) => Tag(id: d.id, name: d.name);

  @override
  Future<List<Tag>> getTags() async {
    final rows = await (_db.select(_db.tags)
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .get();
    return rows.map(_toDomain).toList();
  }

  @override
  Future<Tag?> getTagByName(String name) async {
    final row = await (_db.select(_db.tags)
          ..where((t) => t.name.equals(name)))
        .getSingleOrNull();
    return row == null ? null : _toDomain(row);
  }

  @override
  Future<int> addTag({required String name}) async {
    return _db.into(_db.tags).insert(TagsCompanion.insert(name: name));
  }

  @override
  Future<void> updateTag({required int id, required String name}) async {
    await (_db.update(_db.tags)..where((t) => t.id.equals(id)))
        .write(TagsCompanion(name: Value(name)));
  }

  @override
  Future<void> deleteTag(int id) async {
    await (_db.delete(_db.taskTags)..where((t) => t.tagId.equals(id))).go();
    await (_db.delete(_db.tags)..where((t) => t.id.equals(id))).go();
  }
}
