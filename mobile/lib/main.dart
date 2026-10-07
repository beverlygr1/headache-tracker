import 'package:flutter/material.dart';

import 'app/app.dart';
import 'app/auth_gate.dart';
import 'core/api/api_client.dart';
import 'core/config/app_config.dart';
import 'features/attacks/data/attacks_api.dart';
import 'features/auth/data/auth_api.dart';
import 'features/auth/state/auth_controller.dart';
import 'features/diary/data/diary_api.dart';
import 'features/onboarding/presentation/onboarding_demo.dart';
import 'features/profile/data/profile_api.dart';
import 'features/tracker/presentation/app_shell.dart';
import 'features/tracker/state/tracker_controller.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(HeadacheTrackerApp(home: _buildHome()));
}

Widget _buildHome() {
  if (AppConfig.onboardingDemo) return const OnboardingDemo();
  if (AppConfig.demoMode) {
    return AppShell(controller: TrackerController.demo());
  }

  final client = ApiClient();
  final authController = AuthController(
    client: client,
    authApi: AuthApi(client),
    profileApi: ProfileApi(client),
  )..restoreSession();

  return AuthGate(
    authController: authController,
    attacksApi: AttacksApi(client),
    diaryApi: DiaryApi(client),
  );
}
