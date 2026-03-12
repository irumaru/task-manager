import '../models/status.dart';

abstract class StatusRepository {
  Future<List<Status>> getStatuses();
  Future<int> addStatus({required String name});
  Future<void> updateStatus({required int id, required String name, int? sortOrder});
  Future<void> deleteStatus(int id);
  Future<void> reorderStatuses(List<int> orderedIds);
}
