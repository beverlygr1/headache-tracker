import 'package:dio/dio.dart';

class ApiException implements Exception {
  ApiException({
    required this.message,
    this.statusCode,
    this.data,
  });

  final String message;
  final int? statusCode;
  final dynamic data;

  factory ApiException.fromDio(DioException error) {
    final data = error.response?.data;

    String message = 'Ошибка сети';

    if (data is Map<String, dynamic>) {
      final detail = data['detail'];
      if (detail is String && detail.isNotEmpty) {
        message = detail;
      }
    } else if (error.message != null && error.message!.isNotEmpty) {
      message = error.message!;
    }

    return ApiException(
      message: message,
      statusCode: error.response?.statusCode,
      data: data,
    );
  }

  @override
  String toString() => 'ApiException($statusCode): $message';
}
