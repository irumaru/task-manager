import '../../data/api/api_client.dart';
import '../../domain/models/status.dart';
import '../../domain/repositories/status_repository.dart';

class StatusRepositoryImpl implements StatusRepository {
  final ApiClient _api;

  StatusRepositoryImpl(this._api);

  Status _toDomain(Map<String, dynamic> json) => Status(
        id: json['id'] as String,
        name: json['name'] as String,
        sortOrder: json['displayOrder'] as int,
        isDefault: false,
      );

  @override
  Future<List<Status>> getStatuses() async {
    final items = await _api.getStatuses();
    final list = items.map((json) => _toDomain(json as Map<String, dynamic>)).toList();
    list.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return list;
  }

  @override
  Future<void> addStatus({required String name, required int displayOrder}) async {
    await _api.createStatus({'name': name, 'displayOrder': displayOrder});
  }

  @override
  Future<void> updateStatus({required String id, required String name, int? sortOrder}) async {
    await _api.updateStatus(id, {
      'name': name,
      if (sortOrder != null) 'displayOrder': sortOrder,
    });
  }

  @override
  Future<void> deleteStatus(String id) async {
    await _api.deleteStatus(id);
  }

  @override
  Future<void> reorderStatuses(List<String> orderedIds) async {
    for (var i = 0; i < orderedIds.length; i++) {
      await _api.updateStatus(orderedIds[i], {'displayOrder': i});
    }
  }
}
