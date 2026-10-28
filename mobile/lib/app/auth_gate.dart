import 'package:flutter/material.dart';

import '../core/api/api_client.dart';
import '../core/config/server_settings.dart';
import '../features/attacks/data/attacks_api.dart';
import '../features/auth/presentation/auth_page.dart';
import '../features/auth/state/auth_controller.dart';
import '../features/diary/data/diary_api.dart';
import '../features/diary/data/diary_repository.dart';
import '../features/onboarding/presentation/onboarding_page.dart';
import '../features/reminders/state/reminder_controller.dart';
import '../features/settings/presentation/server_address_dialog.dart';
import '../features/tracker/data/attack_repository.dart';
import '../features/tracker/presentation/app_shell.dart';
import '../features/tracker/presentation/widgets/common.dart';
import '../features/tracker/state/tracker_controller.dart';

/// Показывает вход, пока нет сессии, и дневник после авторизации.
class AuthGate extends StatefulWidget {
  const AuthGate({
    required this.authController,
    required this.attacksApi,
    required this.diaryApi,
    this.apiClient,
    this.serverSettings,
    this.reminderController,
    super.key,
  });

  final AuthController authController;
  final AttacksApi attacksApi;
  final DiaryApi diaryApi;
  final ApiClient? apiClient;

  /// Адрес сервера, который можно поменять в приложении. `null` в тестах.
  final ServerSettings? serverSettings;

  /// Ежедневное напоминание о дневнике. `null` в тестах.
  final ReminderController? reminderController;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  TrackerController? _tracker;
  OnboardingAction _initialAction = OnboardingAction.today;

  Future<void> _finishOnboarding(OnboardingAction action) async {
    _initialAction = action;
    try {
      await widget.authController
          .saveOnboardingProgress(step: 1, completed: true);
    } catch (_) {
      _initialAction = OnboardingAction.today;
      rethrow;
    }
  }

  @override
  void initState() {
    super.initState();
    widget.authController.addListener(_onAuthChanged);
    _syncTracker();
  }

  @override
  void dispose() {
    widget.authController.removeListener(_onAuthChanged);
    _tracker?.dispose();
    super.dispose();
  }

  void _onAuthChanged() {
    if (widget.authController.status != AuthStatus.authenticated &&
        _tracker != null) {
      // Закрыть открытые поверх дневника экраны и диалоги, чтобы экран входа
      // не оказался под ними.
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
    setState(_syncTracker);
  }

  void _syncTracker() {
    final authenticated =
        widget.authController.status == AuthStatus.authenticated;

    // Данные предыдущего пользователя не переживают выход из аккаунта.
    if (authenticated && _tracker == null) {
      _tracker = TrackerController(
        repository: ApiAttackRepository(widget.attacksApi),
      );
    } else if (!authenticated && _tracker != null) {
      // Закрываемые экраны ещё держат контроллер до конца кадра.
      final tracker = _tracker!;
      WidgetsBinding.instance.addPostFrameCallback((_) => tracker.dispose());
      _tracker = null;
      _initialAction = OnboardingAction.today;
    }
  }

  Future<void> _changeServer() async {
    final settings = widget.serverSettings;
    if (settings == null) return;
    if (await showServerAddressDialog(context, settings)) {
      await widget.authController.restoreSession();
    }
  }

  @override
  Widget build(BuildContext context) {
    final tracker = _tracker;
    final profile = widget.authController.profile;
    return switch (widget.authController.status) {
      AuthStatus.unknown => const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      AuthStatus.unauthenticated => AuthPage(
          controller: widget.authController,
          serverSettings: widget.serverSettings,
        ),
      AuthStatus.authenticated when profile == null => Scaffold(
          body: ErrorRetryView(
            message:
                'Не удалось получить профиль. Проверьте соединение с сервером.',
            onRetry: widget.authController.restoreSession,
            secondaryLabel:
                widget.serverSettings == null ? null : 'Адрес сервера',
            onSecondary: _changeServer,
          ),
        ),
      AuthStatus.authenticated when !profile!.onboardingCompleted =>
        OnboardingPage(
          key: ValueKey(profile.id),
          initialStep: profile.onboardingStep,
          onStepChanged: (step) =>
              widget.authController.saveOnboardingProgress(step: step),
          onFinished: _finishOnboarding,
        ),
      AuthStatus.authenticated => AppShell(
          key: ObjectKey(tracker),
          controller: tracker!,
          apiClient: widget.apiClient,
          serverSettings: widget.serverSettings,
          reminderController: widget.reminderController,
          diaryRepository: ApiDiaryRepository(widget.diaryApi),
          initialAction: _initialAction,
          userName: widget.authController.profile?.name,
          timeZone: widget.authController.profile?.timeZone ?? 'UTC',
          userEmail: widget.authController.profile?.email,
          onLogout: widget.authController.logout,
        ),
    };
  }
}
