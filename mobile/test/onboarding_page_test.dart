import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:headache_tracker_app/app/app.dart';
import 'package:headache_tracker_app/core/api/api_exception.dart';
import 'package:headache_tracker_app/features/onboarding/presentation/onboarding_demo.dart';
import 'package:headache_tracker_app/features/onboarding/presentation/onboarding_page.dart';

void main() {
  void viewport(WidgetTester tester, Size size) {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('welcome leads to attack choice without creating records',
      (tester) async {
    viewport(tester, const Size(412, 892));
    final steps = <int>[];
    final actions = <OnboardingAction>[];
    await tester.pumpWidget(HeadacheTrackerApp(
        home: OnboardingPage(
      onStepChanged: (step) async => steps.add(step),
      onFinished: (action) async => actions.add(action),
    )));
    expect(find.text('Начнём с вашего\nсамочувствия'), findsOneWidget);
    await tester.tap(find.text('Начать'));
    await tester.pumpAndSettle();
    expect(steps, [1]);
    expect(find.text('С чего начнём?'), findsOneWidget);
    await tester.tap(find.text('Сейчас есть боль'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Записать приступ'));
    await tester.pumpAndSettle();
    expect(actions, [OnboardingAction.attack]);
  });

  testWidgets('skip and restored progress have distinct outcomes',
      (tester) async {
    viewport(tester, const Size(412, 892));
    OnboardingAction? result;
    await tester.pumpWidget(HeadacheTrackerApp(
        home: OnboardingPage(
      onStepChanged: (_) async {},
      onFinished: (action) async => result = action,
    )));
    await tester.tap(find.text('Позже'));
    await tester.pumpAndSettle();
    expect(result, OnboardingAction.today);
    await tester.pumpWidget(HeadacheTrackerApp(
        home: OnboardingPage(
      key: const ValueKey('restored'),
      initialStep: 1,
      onStepChanged: (_) async {},
      onFinished: (action) async => result = action,
    )));
    expect(find.text('С чего начнём?'), findsOneWidget);
    await tester
        .tap(find.widgetWithText(FilledButton, 'Отметить самочувствие'));
    await tester.pumpAndSettle();
    expect(result, OnboardingAction.diary);
  });

  testWidgets('failed progress remains on screen and can be retried',
      (tester) async {
    viewport(tester, const Size(412, 892));
    final pending = Completer<void>();
    var requests = 0;
    await tester.pumpWidget(HeadacheTrackerApp(
        home: OnboardingPage(
      onStepChanged: (_) {
        requests++;
        return requests == 1 ? pending.future : Future.value();
      },
      onFinished: (_) async {},
    )));
    await tester.tap(find.text('Начать'));
    await tester.pump();
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull);
    expect(requests, 1);
    pending.completeError(ApiException(message: 'Нет соединения с сервером'));
    await tester.pumpAndSettle();
    expect(find.text('Нет соединения с сервером'), findsOneWidget);
    expect(find.text('Начнём с вашего\nсамочувствия'), findsOneWidget);
    await tester.tap(find.text('Начать'));
    await tester.pumpAndSettle();
    expect(requests, 2);
    expect(find.text('С чего начнём?'), findsOneWidget);
  });

  testWidgets('both steps fit a small screen with enlarged text',
      (tester) async {
    viewport(tester, const Size(320, 568));
    await tester.pumpWidget(MaterialApp(
        home: MediaQuery(
      data: const MediaQueryData(
          size: Size(320, 568), textScaler: TextScaler.linear(1.6)),
      child:
          OnboardingPage(onStepChanged: (_) async {}, onFinished: (_) async {}),
    )));
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Начать'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Перейти на главную'), findsOneWidget);
  });

  testWidgets('demo completes onboarding into a real daily form and history',
      (tester) async {
    viewport(tester, const Size(412, 892));
    await tester.pumpWidget(const HeadacheTrackerApp(home: OnboardingDemo()));
    await tester.tap(find.text('Начать'));
    await tester.pumpAndSettle();
    await tester
        .tap(find.widgetWithText(FilledButton, 'Отметить самочувствие'));
    await tester.pumpAndSettle();
    expect(find.text('Самочувствие'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).first, '7,5');
    await tester.tap(find.text('Сохранить самочувствие'));
    await tester.pumpAndSettle();
    expect(find.text('Самочувствие сегодня'), findsOneWidget);
    expect(find.text('Сон 7,5 ч'), findsOneWidget);
    expect(find.text('7 дней наблюдений'), findsNothing);
    await tester.tap(find.text('Дневник'));
    await tester.pumpAndSettle();
    expect(find.text('Сон 7,5 ч'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
