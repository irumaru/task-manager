import 'package:drift/drift.dart';
import 'priorities_table.dart';
import 'statuses_table.dart';

@DataClassName('TaskData')
class Tasks extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text()();
  DateTimeColumn get dueDate => dateTime().nullable()();
  IntColumn get priorityId =>
      integer().nullable().references(Priorities, #id)();
  IntColumn get statusId => integer().nullable().references(Statuses, #id)();
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime)();
}
