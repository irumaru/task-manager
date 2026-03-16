import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'api_exception.dart';

class ApiClient {
  final Dio _dio;
  final FlutterSecureStorage _storage;

  ApiClient({required String baseUrl, required FlutterSecureStorage storage})
      : _storage = storage,
        _dio = Dio(BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
          contentType: 'application/json',
        )) {
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.read(key: 'access_token');
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) {
        handler.next(error);
      },
    ));
  }

  Future<T> _handle<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  // ─── Auth ───

  /// POST /auth/google
  Future<Map<String, dynamic>> googleLogin(String idToken) {
    return _handle(() async {
      final response = await _dio.post('/auth/google', data: {'idToken': idToken});
      return response.data as Map<String, dynamic>;
    });
  }

  /// GET /auth/me
  Future<Map<String, dynamic>> getMe() {
    return _handle(() async {
      final response = await _dio.get('/auth/me');
      return response.data as Map<String, dynamic>;
    });
  }

  // ─── Tasks ───

  /// GET /tasks
  Future<List<dynamic>> getTasks() {
    return _handle(() async {
      final response = await _dio.get('/tasks');
      return response.data['items'] as List<dynamic>;
    });
  }

  /// GET /tasks/:id
  Future<Map<String, dynamic>> getTask(String id) {
    return _handle(() async {
      final response = await _dio.get('/tasks/$id');
      return response.data as Map<String, dynamic>;
    });
  }

  /// POST /tasks
  Future<Map<String, dynamic>> createTask(Map<String, dynamic> body) {
    return _handle(() async {
      final response = await _dio.post('/tasks', data: body);
      return response.data as Map<String, dynamic>;
    });
  }

  /// PATCH /tasks/:id
  Future<Map<String, dynamic>> updateTask(String id, Map<String, dynamic> body) {
    return _handle(() async {
      final response = await _dio.patch('/tasks/$id', data: body);
      return response.data as Map<String, dynamic>;
    });
  }

  /// DELETE /tasks/:id
  Future<void> deleteTask(String id) {
    return _handle(() async {
      await _dio.delete('/tasks/$id');
    });
  }

  // ─── Priorities ───

  /// GET /priorities
  Future<List<dynamic>> getPriorities() {
    return _handle(() async {
      final response = await _dio.get('/priorities');
      return response.data['items'] as List<dynamic>;
    });
  }

  /// POST /priorities
  Future<Map<String, dynamic>> createPriority(Map<String, dynamic> body) {
    return _handle(() async {
      final response = await _dio.post('/priorities', data: body);
      return response.data as Map<String, dynamic>;
    });
  }

  /// PATCH /priorities/:id
  Future<Map<String, dynamic>> updatePriority(String id, Map<String, dynamic> body) {
    return _handle(() async {
      final response = await _dio.patch('/priorities/$id', data: body);
      return response.data as Map<String, dynamic>;
    });
  }

  /// DELETE /priorities/:id
  Future<void> deletePriority(String id) {
    return _handle(() async {
      await _dio.delete('/priorities/$id');
    });
  }

  // ─── Statuses ───

  /// GET /statuses
  Future<List<dynamic>> getStatuses() {
    return _handle(() async {
      final response = await _dio.get('/statuses');
      return response.data['items'] as List<dynamic>;
    });
  }

  /// POST /statuses
  Future<Map<String, dynamic>> createStatus(Map<String, dynamic> body) {
    return _handle(() async {
      final response = await _dio.post('/statuses', data: body);
      return response.data as Map<String, dynamic>;
    });
  }

  /// PATCH /statuses/:id
  Future<Map<String, dynamic>> updateStatus(String id, Map<String, dynamic> body) {
    return _handle(() async {
      final response = await _dio.patch('/statuses/$id', data: body);
      return response.data as Map<String, dynamic>;
    });
  }

  /// DELETE /statuses/:id
  Future<void> deleteStatus(String id) {
    return _handle(() async {
      await _dio.delete('/statuses/$id');
    });
  }

  // ─── Tags ───

  /// GET /tags
  Future<List<dynamic>> getTags() {
    return _handle(() async {
      final response = await _dio.get('/tags');
      return response.data['items'] as List<dynamic>;
    });
  }

  /// POST /tags
  Future<Map<String, dynamic>> createTag(Map<String, dynamic> body) {
    return _handle(() async {
      final response = await _dio.post('/tags', data: body);
      return response.data as Map<String, dynamic>;
    });
  }

  /// PATCH /tags/:id
  Future<Map<String, dynamic>> updateTag(String id, Map<String, dynamic> body) {
    return _handle(() async {
      final response = await _dio.patch('/tags/$id', data: body);
      return response.data as Map<String, dynamic>;
    });
  }

  /// DELETE /tags/:id
  Future<void> deleteTag(String id) {
    return _handle(() async {
      await _dio.delete('/tags/$id');
    });
  }
}
