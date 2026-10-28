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
    Future<String?> Function()? deviceTimeZone,
  })  : _client = client,
        _authApi = authApi,
        _profileApi = profileApi,
        _deviceTimeZone = deviceTimeZone {
    _client.onSessionExpired = _onSessionExpired;
  }

  final ApiClient _client;
  final AuthApi _authApi;
  final ProfileApi _profileApi;

  /// IANA-пояс телефона. Нужен аналитике и прогнозу: без пояса в профиле
  /// сервер считает дни по UTC, и ночные приступы уходят на соседний день.
  final Future<String?> Function()? _deviceTimeZone;

  AuthStatus _status = AuthStatus.unknown;
  UserProfile? _profile;
  Uint8List? _avatar;
  bool _isBusy = false;

  AuthStatus get status => _status;
  UserProfile? get profile => _profile;

  /// Фото профиля; `null` — фото нет или ещё загружается.
  Uint8List? get avatar => _avatar;

  /// Идёт вход или регистрация.
  bool get isBusy => _isBusy;

  Future<void> saveOnboardingProgress({
    required int step,
    bool completed = false,
  }) async {
    final userId = _profile?.id;
    if (_status != AuthStatus.authenticated || userId == null) {
      throw StateError('Нет активного аккаунта');
    }
    final profile = await _profileApi.updateOnboarding(
      step: step,
      completed: completed,
    );
    // An expired session must not be resurrected by a late response.
    if (_status != AuthStatus.authenticated || _profile?.id != userId) return;
    _profile = profile;
    notifyListeners();
  }

  /// Проверяет сохранённые токены при запуске приложения.
  Future<void> restoreSession() async {
    try {
      final token = await _client.tokenStorage.getAccessToken();
      if (token == null || token.isEmpty) {
        _setStatus(AuthStatus.unauthenticated);
        return;
      }

      _profile = await _fillTimeZone(await _profileApi.getProfile());
      _setStatus(AuthStatus.authenticated);
      _loadAvatar();
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

  Future<void> updateName(String name) async {
    final userId = _profile?.id;
    if (_status != AuthStatus.authenticated || userId == null) {
      throw StateError('Нет активного аккаунта');
    }
    final profile = await _profileApi.updateProfile(name: name.trim());
    if (_status != AuthStatus.authenticated || _profile?.id != userId) return;
    _profile = profile;
    notifyListeners();
  }

  /// Дата рождения, пол и часовой пояс. `null` очищает значение.
  Future<void> updatePersonal({
    required DateTime? birthDate,
    required String? gender,
    required String? timeZone,
  }) async {
    final userId = _requireUser();
    final profile = await _profileApi.updatePersonal(
      birthDate: birthDate,
      gender: gender,
      timeZone: timeZone,
    );
    if (!_isCurrent(userId)) return;
    _profile = profile;
    notifyListeners();
  }

  Future<void> uploadAvatar(Uint8List bytes) async {
    final userId = _requireUser();
    final profile = await _profileApi.uploadAvatar(bytes);
    if (!_isCurrent(userId)) return;
    _profile = profile;
    _avatar = bytes;
    notifyListeners();
  }

  Future<void> deleteAvatar() async {
    final userId = _requireUser();
    final profile = await _profileApi.deleteAvatar();
    if (!_isCurrent(userId)) return;
    _profile = profile;
    _avatar = null;
    notifyListeners();
  }

  /// Один раз записывает пояс телефона, если в профиле его нет. Заданный
  /// пользователем пояс не меняется; любая ошибка не мешает входу.
  Future<UserProfile> _fillTimeZone(UserProfile profile) async {
    final detect = _deviceTimeZone;
    if (detect == null || (profile.timeZone?.isNotEmpty ?? false)) {
      return profile;
    }
    try {
      final zone = await detect().timeout(const Duration(seconds: 3));
      if (zone == null || zone.isEmpty) return profile;
      return await _profileApi
          .updateProfile(timeZone: zone)
          .timeout(const Duration(seconds: 5));
    } catch (_) {
      return profile;
    }
  }

  /// Подгружает фото, не задерживая вход: без него приложение работает.
  Future<void> _loadAvatar() async {
    final profile = _profile;
    if (profile == null || !profile.hasAvatar) {
      _avatar = null;
      return;
    }
    try {
      final bytes = await _profileApi.fetchAvatar();
      if (!_isCurrent(profile.id)) return;
      _avatar = bytes;
      notifyListeners();
    } catch (_) {}
  }

  int _requireUser() {
    final userId = _profile?.id;
    if (_status != AuthStatus.authenticated || userId == null) {
      throw StateError('Нет активного аккаунта');
    }
    return userId;
  }

  // Поздний ответ не должен оживить вышедший или сменившийся аккаунт.
  bool _isCurrent(int userId) =>
      _status == AuthStatus.authenticated && _profile?.id == userId;

  Future<void> changePassword(
      {required String currentPassword, required String newPassword}) async {
    final userId = _profile?.id;
    if (_status != AuthStatus.authenticated || userId == null) {
      throw StateError('Нет активного аккаунта');
    }
    final tokens = await _authApi.changePassword(
        currentPassword: currentPassword, newPassword: newPassword);
    if (_status != AuthStatus.authenticated || _profile?.id != userId) return;
    await _client.tokenStorage.saveTokens(
        accessToken: tokens['access_token'] as String,
        refreshToken: tokens['refresh_token'] as String);
  }

  Future<void> logout() async {
    await _authApi.logout();
    _profile = null;
    _avatar = null;
    _setStatus(AuthStatus.unauthenticated);
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_isBusy) return;
    _isBusy = true;
    notifyListeners();
    try {
      await action();
      _profile = await _fillTimeZone(await _profileApi.getProfile());
      _avatar = null;
      _status = AuthStatus.authenticated;
    } finally {
      _isBusy = false;
      notifyListeners();
    }
    _loadAvatar();
  }

  void _onSessionExpired() {
    if (_status != AuthStatus.authenticated) return;
    _profile = null;
    _avatar = null;
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
