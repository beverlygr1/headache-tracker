import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'theme.dart';

class HeadacheTrackerApp extends StatelessWidget {
  const HeadacheTrackerApp({
    required this.home,
    super.key,
  });

  final Widget home;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Дневник головной боли',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      locale: const Locale('ru'),
      supportedLocales: const [Locale('ru'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
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
                  child: MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                      size: Size(width, constraints.maxHeight),
                      alwaysUse24HourFormat: true,
                    ),
                    child: child ?? const SizedBox.shrink(),
                  ),
                ),
              ),
            );
          },
        );
      },
      home: home,
    );
  }
}
