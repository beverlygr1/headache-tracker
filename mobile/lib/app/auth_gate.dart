import 'package:flutter/material.dart';

import '../features/attacks/data/attacks_api.dart';
import '../features/auth/presentation/auth_page.dart';
import '../features/auth/state/auth_controller.dart';
import '../features/diary/data/diary_api.dart';
import '../features/diary/data/diary_repository.dart';
import '../features/onboarding/presentation/onboarding_page.dart';
import '../features/tracker/data/attack_repository.dart';
import '../features/tracker/presentation/app_shell.dart';
import '../features/tracker/state/tracker_controller.dart';
import '../features/tracker/presentation/widgets/common.dart';

/// Показывает вход, пока нет сессии, и дневник после авторизации.
class AuthGate extends StatefulWidget {
  const AuthGate({
    required this.authController,
    required this.attacksApi,
    required this.diaryApi,
    super.key,
  });

  final AuthController authController;
  final AttacksApi attacksApi;
  final DiaryApi diaryApi;

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

  @override
  Widget build(BuildContext context) {
    final tracker = _tracker;
    final profile = widget.authController.profile;
    return switch (widget.authController.status) {
      AuthStatus.unknown => const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      AuthStatus.unauthenticated => AuthPage(controller: widget.authController),
      AuthStatus.authenticated when profile == null => Scaffold(
          body: ErrorRetryView(
            message:
                'Не удалось получить профиль. Проверьте соединение с сервером.',
            onRetry: widget.authController.restoreSession,
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
          diaryRepository: ApiDiaryRepository(widget.diaryApi),
          initialAction: _initialAction,
          userName: widget.authController.profile?.name,
          userEmail: widget.authController.profile?.email,
          onLogout: widget.authController.logout,
        ),
    };
  }
}
