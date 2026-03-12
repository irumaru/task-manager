import '../models/priority.dart';

abstract class PriorityRepository {
  Future<List<Priority>> getPriorities();
  Future<int> addPriority({required String name});
  Future<void> updatePriority({required int id, required String name, int? sortOrder});
  Future<void> deletePriority(int id);
  Future<void> reorderPriorities(List<int> orderedIds);
}
