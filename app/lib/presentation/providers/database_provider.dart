import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/database/app_database.dart';
import '../../data/repositories/task_repository_impl.dart';
import '../../data/repositories/priority_repository_impl.dart';
import '../../data/repositories/status_repository_impl.dart';
import '../../data/repositories/tag_repository_impl.dart';
import '../../domain/repositories/task_repository.dart';
import '../../domain/repositories/priority_repository.dart';
import '../../domain/repositories/status_repository.dart';
import '../../domain/repositories/tag_repository.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final taskRepositoryProvider = Provider<TaskRepository>((ref) {
  return TaskRepositoryImpl(ref.watch(databaseProvider));
});

final priorityRepositoryProvider = Provider<PriorityRepository>((ref) {
  return PriorityRepositoryImpl(ref.watch(databaseProvider));
});

final statusRepositoryProvider = Provider<StatusRepository>((ref) {
  return StatusRepositoryImpl(ref.watch(databaseProvider));
});

final tagRepositoryProvider = Provider<TagRepository>((ref) {
  return TagRepositoryImpl(ref.watch(databaseProvider));
});
