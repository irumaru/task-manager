import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/constants/app_constants.dart';
import '../../data/api/api_client.dart';
import '../../data/auth/browser_auth_service.dart';
import '../../data/repositories/priority_repository_impl.dart';
import '../../data/repositories/status_repository_impl.dart';
import '../../data/repositories/tag_repository_impl.dart';
import '../../data/repositories/task_repository_impl.dart';
import '../../domain/repositories/priority_repository.dart';
import '../../domain/repositories/status_repository.dart';
import '../../domain/repositories/tag_repository.dart';
import '../../domain/repositories/task_repository.dart';

final secureStorageProvider = Provider<FlutterSecureStorage>(
  (_) => const FlutterSecureStorage(),
);

final apiClientProvider = Provider<ApiClient>((ref) {
  final storage = ref.watch(secureStorageProvider);
  return ApiClient(
    baseUrl: AppConstants.apiBaseUrl,
    storage: storage,
  );
});

final taskRepositoryProvider = Provider<TaskRepository>((ref) {
  return TaskRepositoryImpl(ref.watch(apiClientProvider));
});

final priorityRepositoryProvider = Provider<PriorityRepository>((ref) {
  return PriorityRepositoryImpl(ref.watch(apiClientProvider));
});

final statusRepositoryProvider = Provider<StatusRepository>((ref) {
  return StatusRepositoryImpl(ref.watch(apiClientProvider));
});

final tagRepositoryProvider = Provider<TagRepository>((ref) {
  return TagRepositoryImpl(ref.watch(apiClientProvider));
});

final browserAuthServiceProvider = Provider<BrowserAuthService>((ref) {
  return BrowserAuthService(clientId: AppConstants.googleOAuthClientId);
});
