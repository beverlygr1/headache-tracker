import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:headache_tracker_app/app/app.dart';
import 'package:headache_tracker_app/core/api/api_client.dart';
import 'package:headache_tracker_app/core/config/server_settings.dart';
import 'package:headache_tracker_app/core/storage/token_storage.dart';
import 'package:headache_tracker_app/features/diary/data/daily_entry.dart';
import 'package:headache_tracker_app/features/diary/data/diary_repository.dart';
import 'package:headache_tracker_app/features/diary/presentation/daily_entry_page.dart';
import 'package:headache_tracker_app/features/tracker/data/attack_repository.dart';
import 'package:headache_tracker_app/features/tracker/domain/attack_record.dart';
import 'package:headache_tracker_app/features/tracker/presentation/pages/attack_details_page.dart';
import 'package:headache_tracker_app/features/tracker/presentation/pages/diary_page.dart';
import 'package:headache_tracker_app/features/tracker/presentation/pages/today_page.dart';
import 'package:headache_tracker_app/features/tracker/state/tracker_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('clearing session preserves server address for a cold app start',
      () async {
    FlutterSecureStorage.setMockInitialValues({'other_setting': 'preserved'});
    final client = ApiClient();
    await ServerSettings(client: client)
        .save('http://192.168.1.50:8000/api/v1');
    await client.tokenStorage
        .saveTokens(accessToken: 'access', refreshToken: 'refresh');
    await client.tokenStorage.clear();

    final restarted = ApiClient();
    await ServerSettings(client: restarted).load();
    expect(restarted.baseUrl, 'http://192.168.1.50:8000/api/v1');
    expect(await TokenStorage().getAccessToken(), isNull);
    expect(await TokenStorage().getRefreshToken(), isNull);
    expect(await const FlutterSecureStorage().read(key: 'other_setting'),
        'preserved');
  });

  testWidgets(
      'calendar filters attacks and observations then restores all dates',
      (tester) async {
    _size(tester);
    final today = DateUtils.dateOnly(DateTime.now());
    final earlier = DateTime(today.year, today.month, today.day - 8);
    final controller =
        await _controller([_record(1, today), _record(2, earlier)]);
    addTearDown(controller.dispose);
    await tester.pumpWidget(HeadacheTrackerApp(
        home: Scaffold(
            body: DiaryPage(
      controller: controller,
      onOpenAttack: (_) {},
      onOpenDailyEntry: (_) {},
      dailyEntries: [
        DailyEntry(date: today, waterMl: 1234),
        DailyEntry(date: earlier, waterMl: 2345)
      ],
    ))));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(
        ValueKey('diary-day-${today.year}-${today.month}-${today.day}')));
    await tester.pumpAndSettle();
    expect(find.text('6 / 10'), findsOneWidget);
    await tester.scrollUntilVisible(find.textContaining('1234'), 200);
    expect(find.textContaining('2345'), findsNothing);
    await tester.scrollUntilVisible(
        find.byKey(const ValueKey('diary-all-dates')), -250);
    await tester.tap(find.byKey(const ValueKey('diary-all-dates')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.textContaining('2345'), 200);
    expect(find.textContaining('2345'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'month picker opens an empty past day and passes its date to diary entry',
      (tester) async {
    _size(tester);
    final controller = await _controller([]);
    addTearDown(controller.dispose);
    DateTime? opened;
    await tester.pumpWidget(HeadacheTrackerApp(
        home: Scaffold(
            body: DiaryPage(
      controller: controller,
      onOpenAttack: (_) {},
      onOpenDailyEntry: (date) => opened = date,
    ))));
    await tester.tap(find.byKey(const ValueKey('diary-calendar-picker')));
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsOneWidget);
    await tester.tap(find.byTooltip('Previous month'));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(
        of: find.byType(DatePickerDialog), matching: find.text('15')));
    await tester.tap(find.text('Открыть'));
    await tester.pumpAndSettle();
    expect(find.text('За этот день приступов нет'), findsOneWidget);
    await tester.tap(find.text('Отметить самочувствие'));
    final now = DateTime.now();
    expect(opened, DateTime(now.year, now.month - 1, 15));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'save stays above numeric keyboard on a phone and Done dismisses input',
      (tester) async {
    _size(tester);
    final repository = InMemoryDiaryRepository();
    final date = DateTime(2026, 10, 7);
    await tester.pumpWidget(HeadacheTrackerApp(
        home: DailyEntryPage(repository: repository, date: date)));
    await tester.pumpAndSettle();
    final field = find.byKey(const ValueKey('sleep-hours-field'));
    await tester.enterText(field, '7,5');
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    final save = find.text('Сохранить самочувствие');
    expect(tester.getBottomRight(save).dy, lessThanOrEqualTo(853 - 300));
    final input = tester.widget<EditableText>(
        find.descendant(of: field, matching: find.byType(EditableText)));
    expect(input.textInputAction, TextInputAction.done);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(input.focusNode.hasFocus, isFalse);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect((await repository.fetchByDate(date))?.sleepHours, 7.5);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'same attack has consistent severity and two minute duration across screens',
      (tester) async {
    _size(tester);
    final controller = await _controller([_record(1, DateTime.now())]);
    addTearDown(controller.dispose);
    final pages = <Widget>[
      DiaryPage(
          controller: controller,
          onOpenAttack: (_) {},
          onOpenDailyEntry: (_) {}),
      TodayPage(
          controller: controller,
          onCreateAttack: () {},
          onOpenAttack: (_) {},
          onProfileTap: () {},
          onOpenDailyEntry: () {}),
      AttackDetailsPage(controller: controller, recordId: 1),
    ];
    for (final page in pages) {
      await tester.pumpWidget(HeadacheTrackerApp(home: Scaffold(body: page)));
      await tester.pumpAndSettle();
      expect(find.textContaining('Умеренная боль'), findsOneWidget);
      expect(find.textContaining('2 мин'), findsOneWidget);
      expect(find.textContaining('2 минут'), findsNothing);
      expect(tester.takeException(), isNull);
    }
  });
}

void _size(WidgetTester tester) {
  tester.view.physicalSize = const Size(384, 853);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<TrackerController> _controller(List<AttackRecord> records) async {
  final controller =
      TrackerController(repository: InMemoryAttackRepository(records));
  await controller.load();
  return controller;
}

AttackRecord _record(int id, DateTime date) => AttackRecord(
      id: id,
      startTime: date,
      endTime: date.add(const Duration(minutes: 2)),
      intensity: 6,
      painLocation: '',
      symptoms: const [],
    );
