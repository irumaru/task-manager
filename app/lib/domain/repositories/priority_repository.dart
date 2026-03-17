import '../models/priority.dart';

abstract class PriorityRepository {
  Future<List<Priority>> getPriorities();
  Future<void> addPriority({required String name, required int displayOrder});
  Future<void> updatePriority({required String id, required String name, int? sortOrder});
  Future<void> deletePriority(String id);
  Future<void> reorderPriorities(List<String> orderedIds);
}
