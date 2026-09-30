import 'package:dio/dio.dart';

class ApiException implements Exception {
  ApiException({
    required this.message,
    this.statusCode,
    this.data,
    this.isNetworkError = false,
  });

  final String message;
  final int? statusCode;
  final dynamic data;

  /// Сервер недоступен: нет сети, таймаут, backend не запущен.
  final bool isNetworkError;

  bool get isUnauthorized => statusCode == 401;

  factory ApiException.fromDio(DioException error) {
    final response = error.response;

    if (response == null) {
      return switch (error.type) {
        DioExceptionType.connectionTimeout ||
        DioExceptionType.sendTimeout ||
        DioExceptionType.receiveTimeout =>
          ApiException(
            message: 'Сервер не отвечает. Попробуйте ещё раз',
            isNetworkError: true,
          ),
        DioExceptionType.connectionError => ApiException(
            message: 'Нет соединения с сервером',
            isNetworkError: true,
          ),
        DioExceptionType.cancel => ApiException(message: 'Запрос отменён'),
        // Ошибка внутри приложения до/после запроса (например, хранилище
        // токенов) — не выдаём её за проблему сети.
        _ => ApiException(
            message:
                'Не удалось выполнить запрос: ${error.error ?? error.message}',
          ),
      };
    }

    final data = response.data;
    return ApiException(
      message: _detailMessage(data) ?? _statusMessage(response.statusCode),
      statusCode: response.statusCode,
      data: data,
    );
  }

  /// FastAPI отдаёт `detail` строкой (HTTPException) или списком ошибок
  /// валидации Pydantic (422).
  static String? _detailMessage(dynamic data) {
    if (data is! Map) return null;
    final detail = data['detail'];
    if (detail is String && detail.isNotEmpty) return detail;
    if (detail is List && detail.isNotEmpty) {
      final messages = detail
          .whereType<Map>()
          .map((item) => item['msg'])
          .whereType<String>()
          .toList();
      if (messages.isNotEmpty) return messages.join('\n');
    }
    return null;
  }

  static String _statusMessage(int? statusCode) {
    return switch (statusCode) {
      401 => 'Требуется повторный вход',
      403 => 'Недостаточно прав',
      404 => 'Не найдено',
      422 => 'Проверьте введённые данные',
      501 => 'Функция пока не реализована на сервере',
      final code? when code >= 500 => 'Ошибка сервера ($code)',
      _ => 'Ошибка запроса',
    };
  }

  @override
  String toString() => 'ApiException($statusCode): $message';
}
