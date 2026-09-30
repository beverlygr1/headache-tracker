import 'package:flutter/material.dart';

import '../features/attacks/data/attacks_api.dart';
import '../features/auth/presentation/auth_page.dart';
import '../features/auth/state/auth_controller.dart';
import '../features/tracker/data/attack_repository.dart';
import '../features/tracker/presentation/app_shell.dart';
import '../features/tracker/state/tracker_controller.dart';

/// Показывает вход, пока нет сессии, и дневник после авторизации.
class AuthGate extends StatefulWidget {
  const AuthGate({
    required this.authController,
    required this.attacksApi,
    super.key,
  });

  final AuthController authController;
  final AttacksApi attacksApi;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  TrackerController? _tracker;

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
    }
  }

  @override
  Widget build(BuildContext context) {
    final tracker = _tracker;
    return switch (widget.authController.status) {
      AuthStatus.unknown => const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      AuthStatus.unauthenticated => AuthPage(controller: widget.authController),
      AuthStatus.authenticated => AppShell(
          key: ObjectKey(tracker),
          controller: tracker!,
          userName: widget.authController.profile?.name,
          userEmail: widget.authController.profile?.email,
          onLogout: widget.authController.logout,
        ),
    };
  }
}
