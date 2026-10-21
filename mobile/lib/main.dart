import 'package:flutter/material.dart';

import 'app/app.dart';
import 'app/auth_gate.dart';
import 'core/api/api_client.dart';
import 'core/config/app_config.dart';
import 'core/config/server_settings.dart';
import 'features/attacks/data/attacks_api.dart';
import 'features/auth/data/auth_api.dart';
import 'features/auth/state/auth_controller.dart';
import 'features/diary/data/diary_api.dart';
import 'features/onboarding/presentation/onboarding_demo.dart';
import 'features/profile/data/profile_api.dart';
import 'features/reminders/data/reminder_scheduler.dart';
import 'features/reminders/data/reminder_settings.dart';
import 'features/reminders/state/reminder_controller.dart';
import 'features/tracker/presentation/app_shell.dart';
import 'features/tracker/state/tracker_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(HeadacheTrackerApp(home: await _buildHome()));
}

Future<Widget> _buildHome() async {
  if (AppConfig.onboardingDemo) return const OnboardingDemo();

  final scheduler = LocalNotificationReminderScheduler();
  final reminders = ReminderController(
    scheduler: scheduler.isSupported
        ? scheduler
        : const UnsupportedReminderScheduler(),
    store: SecureReminderSettingsStore(),
  );
  await reminders.load();

  if (AppConfig.demoMode) {
    return AppShell(
      controller: TrackerController.demo(),
      reminderController: reminders,
    );
  }

  final client = ApiClient();
  final serverSettings = ServerSettings(client: client);
  await serverSettings.load();
  final authController = AuthController(
    client: client,
    authApi: AuthApi(client),
    profileApi: ProfileApi(client),
  )..restoreSession();

  return AuthGate(
    authController: authController,
    apiClient: client,
    serverSettings: serverSettings,
    reminderController: reminders,
    attacksApi: AttacksApi(client),
    diaryApi: DiaryApi(client),
  );
}
