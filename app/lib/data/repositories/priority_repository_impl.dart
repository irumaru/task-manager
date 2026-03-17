import '../../data/api/api_client.dart';
import '../../domain/models/priority.dart';
import '../../domain/repositories/priority_repository.dart';

class PriorityRepositoryImpl implements PriorityRepository {
  final ApiClient _api;

  PriorityRepositoryImpl(this._api);

  Priority _toDomain(Map<String, dynamic> json) => Priority(
        id: json['id'] as String,
        name: json['name'] as String,
        sortOrder: json['displayOrder'] as int,
        isDefault: false,
      );

  @override
  Future<List<Priority>> getPriorities() async {
    final items = await _api.getPriorities();
    final list = items.map((json) => _toDomain(json as Map<String, dynamic>)).toList();
    list.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return list;
  }

  @override
  Future<void> addPriority({required String name, required int displayOrder}) async {
    await _api.createPriority({'name': name, 'displayOrder': displayOrder});
  }

  @override
  Future<void> updatePriority({required String id, required String name, int? sortOrder}) async {
    await _api.updatePriority(id, {
      'name': name,
      if (sortOrder != null) 'displayOrder': sortOrder,
    });
  }

  @override
  Future<void> deletePriority(String id) async {
    await _api.deletePriority(id);
  }

  @override
  Future<void> reorderPriorities(List<String> orderedIds) async {
    for (var i = 0; i < orderedIds.length; i++) {
      await _api.updatePriority(orderedIds[i], {'displayOrder': i});
    }
  }
}
