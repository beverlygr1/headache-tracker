class AppConfig {
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000/api/v1',
  );

  /// `--dart-define=DEMO_MODE=true` запускает UI на локальных демо-данных
  /// без backend и авторизации.
  static const bool demoMode = bool.fromEnvironment('DEMO_MODE');
  static const bool onboardingDemo = bool.fromEnvironment('ONBOARDING_DEMO');
}
