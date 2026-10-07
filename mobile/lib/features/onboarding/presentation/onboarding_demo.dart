import 'package:flutter/material.dart';

import '../../diary/data/diary_repository.dart';
import '../../tracker/data/attack_repository.dart';
import '../../tracker/presentation/app_shell.dart';
import '../../tracker/state/tracker_controller.dart';
import 'onboarding_page.dart';

/// Preview without credentials or a backend; all entries are kept in memory.
class OnboardingDemo extends StatefulWidget {
  const OnboardingDemo({super.key});

  @override
  State<OnboardingDemo> createState() => _OnboardingDemoState();
}

class _OnboardingDemoState extends State<OnboardingDemo> {
  final _tracker = TrackerController(repository: InMemoryAttackRepository([]));
  final _diary = InMemoryDiaryRepository();
  OnboardingAction? _action;
  int _step = 0;

  @override
  void dispose() {
    _tracker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _action == null
      ? OnboardingPage(
          initialStep: _step,
          onStepChanged: (step) async => setState(() => _step = step),
          onFinished: (action) async => setState(() => _action = action),
        )
      : AppShell(
          controller: _tracker,
          diaryRepository: _diary,
          initialAction: _action!);
}
