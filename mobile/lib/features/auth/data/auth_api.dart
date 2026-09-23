import '../../../core/api/api_client.dart';


class AuthApi {
  AuthApi(this._client);

  final ApiClient _client;

  Future<void> register({
    required String email,
    required String password,
    required String name,
  }) async {
    await _client.post<Map<String, dynamic>>(
      '/auth/register',
      data: {
        'email': email,
        'password': password,
        'name': name,
      },
    );
  }

  Future<void> login({
    required String email,
    required String password,
  }) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/auth/login',
      data: {
        'email': email,
        'password': password,
      },
    );

    final data = response.data;
    if (data == null) {
      throw StateError('Пустой ответ от /auth/login');
    }

    await _client.tokenStorage.saveTokens(
      accessToken: data['access_token'] as String,
      refreshToken: data['refresh_token'] as String,
    );
  }

  Future<void> refresh() async {
    final refreshToken = await _client.tokenStorage.getRefreshToken();

    if (refreshToken == null || refreshToken.isEmpty) {
      throw StateError('Refresh token отсутствует');
    }

    final response = await _client.post<Map<String, dynamic>>(
      '/auth/refresh',
      data: {
        'refresh_token': refreshToken,
      },
    );

    final data = response.data;
    if (data == null) {
      throw StateError('Пустой ответ от /auth/refresh');
    }

    await _client.tokenStorage.saveTokens(
      accessToken: data['access_token'] as String,
      refreshToken: data['refresh_token'] as String,
    );
  }

  Future<void> logout() {
    return _client.tokenStorage.clear();
  }
}
