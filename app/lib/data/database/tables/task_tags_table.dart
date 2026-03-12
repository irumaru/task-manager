import 'package:drift/drift.dart';
import 'tasks_table.dart';
import 'tags_table.dart';

class TaskTags extends Table {
  IntColumn get taskId => integer().references(Tasks, #id)();
  IntColumn get tagId => integer().references(Tags, #id)();

  @override
  Set<Column> get primaryKey => {taskId, tagId};
}
