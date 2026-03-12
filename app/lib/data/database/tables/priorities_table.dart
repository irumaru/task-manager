import 'package:drift/drift.dart';

@DataClassName('PriorityData')
class Priorities extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  IntColumn get sortOrder => integer()();
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();
}
