import '../models/status.dart';

abstract class StatusRepository {
  Future<List<Status>> getStatuses();
  Future<void> addStatus({required String name, required int displayOrder});
  Future<void> updateStatus({required String id, required String name, int? sortOrder});
  Future<void> deleteStatus(String id);
  Future<void> reorderStatuses(List<String> orderedIds);
}
