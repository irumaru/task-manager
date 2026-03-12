import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import 'tables/tasks_table.dart';
import 'tables/priorities_table.dart';
import 'tables/statuses_table.dart';
import 'tables/tags_table.dart';
import 'tables/task_tags_table.dart';
import '../../core/constants/app_constants.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [Tasks, Priorities, Statuses, Tags, TaskTags],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await _insertDefaultData();
        },
      );

  Future<void> _insertDefaultData() async {
    for (final p in AppConstants.defaultPriorities) {
      await into(priorities).insert(
        PrioritiesCompanion.insert(
          name: p['name'] as String,
          sortOrder: p['sortOrder'] as int,
          isDefault: const Value(true),
        ),
      );
    }
    for (final s in AppConstants.defaultStatuses) {
      await into(statuses).insert(
        StatusesCompanion.insert(
          name: s['name'] as String,
          sortOrder: s['sortOrder'] as int,
          isDefault: const Value(true),
        ),
      );
    }
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'task_manager.db'));
    return NativeDatabase.createInBackground(file);
  });
}
