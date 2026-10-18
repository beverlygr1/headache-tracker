import 'package:flutter/foundation.dart';

class AppConfig {
  /// `--dart-define=API_BASE_URL=...` — явный адрес backend, например
  /// `http://192.168.1.50:8000/api/v1` для APK на настоящем телефоне.
  static const String _apiBaseUrlOverride = String.fromEnvironment(
    'API_BASE_URL',
  );

  /// Адрес backend по умолчанию зависит от платформы: внутри Android-эмулятора
  /// `localhost` — это сам эмулятор, а компьютер доступен как `10.0.2.2`.
  static String get apiBaseUrl {
    if (_apiBaseUrlOverride.isNotEmpty) return _apiBaseUrlOverride;
    return defaultApiBaseUrl(
      isWeb: kIsWeb,
      platform: defaultTargetPlatform,
    );
  }

  @visibleForTesting
  static String defaultApiBaseUrl({
    required bool isWeb,
    required TargetPlatform platform,
  }) {
    if (!isWeb && platform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000/api/v1';
    }
    return 'http://localhost:8000/api/v1';
  }

  /// `--dart-define=DEMO_MODE=true` запускает UI на локальных демо-данных
  /// без backend и авторизации.
  static const bool demoMode = bool.fromEnvironment('DEMO_MODE');
  static const bool onboardingDemo = bool.fromEnvironment('ONBOARDING_DEMO');
}
