import 'package:flutter/material.dart';

import '../features/tracker/presentation/app_shell.dart';
import '../features/tracker/state/tracker_controller.dart';
import 'theme.dart';

class HeadacheTrackerApp extends StatelessWidget {
  const HeadacheTrackerApp({
    required this.controller,
    super.key,
  });

  final TrackerController controller;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Дневник головной боли',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      builder: (context, child) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final width =
                constraints.maxWidth > 430 ? 430.0 : constraints.maxWidth;

            return ColoredBox(
              color: AppColors.desktopCanvas,
              child: Align(
                alignment: Alignment.topCenter,
                child: SizedBox(
                  width: width,
                  height: constraints.maxHeight,
                  child: child ?? const SizedBox.shrink(),
                ),
              ),
            );
          },
        );
      },
      home: AppShell(controller: controller),
    );
  }
}
