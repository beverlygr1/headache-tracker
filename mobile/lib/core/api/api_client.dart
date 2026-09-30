import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../storage/token_storage.dart';
import 'api_exception.dart';

class ApiClient {
  ApiClient({
    Dio? dio,
    TokenStorage? tokenStorage,
  })  : tokenStorage = tokenStorage ?? TokenStorage(),
        dio = dio ?? Dio(_baseOptions()) {
    _refreshDio = Dio(this.dio.options.copyWith());
    this.dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) async {
              final token = await this.tokenStorage.getAccessToken();

              if (token != null && token.isNotEmpty) {
                options.headers['Authorization'] = 'Bearer $token';
              }

              handler.next(options);
            },
            onError: (error, handler) async {
              try {
                final retried = await _retryWithFreshToken(error);
                if (retried != null) return handler.resolve(retried);
              } on DioException catch (retryError) {
                return handler.next(retryError);
              }
              handler.next(error);
            },
          ),
        );
  }

  static const _retriedKey = 'auth_retried';

  final Dio dio;
  final TokenStorage tokenStorage;

  /// Вызывается, когда access token истёк и обновить его не удалось:
  /// пользователя нужно вернуть на экран входа.
  void Function()? onSessionExpired;

  late final Dio _refreshDio;
  Future<bool>? _refreshing;

  static BaseOptions _baseOptions() {
    return BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      headers: const {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
    );
  }

  Future<Response<dynamic>?> _retryWithFreshToken(DioException error) async {
    final options = error.requestOptions;
    if (error.response?.statusCode != 401 ||
        options.path.startsWith('/auth/') ||
        options.extra[_retriedKey] == true) {
      return null;
    }

    // Несколько запросов могут получить 401 одновременно — обновляем токен
    // один раз и ждём общий результат.
    final refreshed = await (_refreshing ??=
        _refreshTokens().whenComplete(() => _refreshing = null));

    if (!refreshed) {
      await tokenStorage.clear();
      onSessionExpired?.call();
      return null;
    }

    options.extra[_retriedKey] = true;
    return dio.fetch<dynamic>(options);
  }

  Future<bool> _refreshTokens() async {
    final refreshToken = await tokenStorage.getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) return false;

    try {
      final response = await _refreshDio.post<Map<String, dynamic>>(
        '/auth/refresh',
        data: {'refresh_token': refreshToken},
      );
      final data = response.data;
      if (data == null) return false;

      await tokenStorage.saveTokens(
        accessToken: data['access_token'] as String,
        refreshToken: data['refresh_token'] as String,
      );
      return true;
    } on DioException {
      return false;
    }
  }

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await dio.get<T>(
        path,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<Response<T>> post<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await dio.post<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<Response<T>> put<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await dio.put<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<Response<T>> delete<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await dio.delete<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }
}
