import 'package:dio/dio.dart';

class ApiException implements Exception {
  final int statusCode;
  final String message;

  ApiException({required this.statusCode, required this.message});

  factory ApiException.fromDioException(DioException e) {
    final data = e.response?.data;
    return ApiException(
      statusCode: e.response?.statusCode ?? 0,
      message: data is Map ? data['message'] ?? e.message ?? '' : e.message ?? '',
    );
  }

  bool get isUnauthorized => statusCode == 401;
  bool get isNotFound => statusCode == 404;

  @override
  String toString() => 'ApiException($statusCode): $message';
}
