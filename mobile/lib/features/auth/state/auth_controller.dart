import 'package:flutter/foundation.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';
import '../../profile/data/profile_api.dart';
import '../../profile/data/user_profile.dart';
import '../data/auth_api.dart';

enum AuthStatus { unknown, unauthenticated, authenticated }

class AuthController extends ChangeNotifier {
  AuthController({
    required ApiClient client,
    required AuthApi authApi,
    required ProfileApi profileApi,
  })  : _client = client,
        _authApi = authApi,
        _profileApi = profileApi {
    _client.onSessionExpired = _onSessionExpired;
  }

  final ApiClient _client;
  final AuthApi _authApi;
  final ProfileApi _profileApi;

  AuthStatus _status = AuthStatus.unknown;
  UserProfile? _profile;
  bool _isBusy = false;

  AuthStatus get status => _status;
  UserProfile? get profile => _profile;

  /// Идёт вход или регистрация.
  bool get isBusy => _isBusy;

  /// Проверяет сохранённые токены при запуске приложения.
  Future<void> restoreSession() async {
    try {
      final token = await _client.tokenStorage.getAccessToken();
      if (token == null || token.isEmpty) {
        _setStatus(AuthStatus.unauthenticated);
        return;
      }

      _profile = await _profileApi.getProfile();
      _setStatus(AuthStatus.authenticated);
    } on ApiException catch (error) {
      // Сервер недоступен или вернул 5xx — пускаем в приложение с сохранённым
      // токеном: экран данных сам покажет ошибку и кнопку повтора.
      _setStatus(
        error.isUnauthorized
            ? AuthStatus.unauthenticated
            : AuthStatus.authenticated,
      );
    } catch (_) {
      // Хранилище токенов не читается (например, повреждено) — входим заново.
      try {
        await _client.tokenStorage.clear();
      } catch (_) {}
      _setStatus(AuthStatus.unauthenticated);
    }
  }

  Future<void> login({required String email, required String password}) {
    return _run(() => _authApi.login(email: email, password: password));
  }

  Future<void> register({
    required String name,
    required String email,
    required String password,
  }) {
    return _run(() async {
      await _authApi.register(email: email, password: password, name: name);
      await _authApi.login(email: email, password: password);
    });
  }

  Future<void> logout() async {
    await _authApi.logout();
    _profile = null;
    _setStatus(AuthStatus.unauthenticated);
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_isBusy) return;
    _isBusy = true;
    notifyListeners();
    try {
      await action();
      _profile = await _profileApi.getProfile();
      _status = AuthStatus.authenticated;
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  void _onSessionExpired() {
    if (_status != AuthStatus.authenticated) return;
    _profile = null;
    _setStatus(AuthStatus.unauthenticated);
  }

  void _setStatus(AuthStatus status) {
    _status = status;
    notifyListeners();
  }

  @override
  void dispose() {
    if (_client.onSessionExpired == _onSessionExpired) {
      _client.onSessionExpired = null;
    }
    super.dispose();
  }
}
