import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:headache_tracker_app/app/app.dart';
import 'package:headache_tracker_app/features/diary/data/daily_entry.dart';
import 'package:headache_tracker_app/features/diary/data/diary_repository.dart';
import 'package:headache_tracker_app/features/diary/presentation/daily_entry_page.dart';
import 'package:headache_tracker_app/features/tracker/data/attack_repository.dart';
import 'package:headache_tracker_app/features/tracker/domain/attack_record.dart';
import 'package:headache_tracker_app/features/tracker/presentation/pages/attack_entry_page.dart';
import 'package:headache_tracker_app/features/tracker/state/tracker_controller.dart';

void main() {
  testWidgets('editing keeps previously saved medications', (tester) async {
    phone(tester);
    final record = AttackRecord(
        id: 1,
        startTime: DateTime(2026, 10, 28, 9),
        intensity: 4,
        painLocation: '',
        symptoms: const [],
        medications: const ['Сохранённый препарат']);
    final controller =
        TrackerController(repository: InMemoryAttackRepository([record]));
    addTearDown(controller.dispose);
    await controller.load();
    await tester.pumpWidget(HeadacheTrackerApp(
        home: Builder(
            builder: (context) => Scaffold(
                body: TextButton(
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                            builder: (_) => AttackEntryPage(
                                controller: controller,
                                initialRecord: record))),
                    child: const Text('Открыть'))))));
    await tester.tap(find.text('Открыть'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Продолжить'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Сохранить приступ'));
    await tester.pumpAndSettle();
    await controller.load();
    expect(controller.records.single.medications, ['Сохранённый препарат']);
  });
  testWidgets('portions retain exact amounts and allow clearing an answer',
      (tester) async {
    phone(tester);
    final repo = InMemoryDiaryRepository();
    final date = DateTime(2026, 10, 28);
    await repo.save(DailyEntry(date: date, waterMl: 375, caffeineIntake: 80));
    await tester.pumpWidget(
        HeadacheTrackerApp(home: DailyEntryPage(repository: repo, date: date)));
    await tester.pumpAndSettle();
    final water = find.byKey(const ValueKey('water-field'));
    await tester.scrollUntilVisible(water, 200,
        scrollable: find.byType(Scrollable).first);
    expect(tester.widget<TextFormField>(water).controller!.text, '375');
    await tester.enterText(water, '');
    final caffeine = find.byKey(const ValueKey('caffeine-field'));
    await tester.scrollUntilVisible(caffeine, 200,
        scrollable: find.byType(Scrollable).first);
    expect(tester.widget<TextFormField>(caffeine).controller!.text, '80');
    await tester.tap(find.text('Сохранить самочувствие'));
    await tester.pumpAndSettle();
    expect((await repo.fetchByDate(date))!.waterMl, isNull);
    expect((await repo.fetchByDate(date))!.caffeineIntake, 80);
  });
  testWidgets('water controls are locked during save', (tester) async {
    phone(tester);
    final repo = _PendingDiary();
    addTearDown(() {
      if (!repo.result.isCompleted) repo.result.complete(repo.entry);
    });
    await tester.pumpWidget(HeadacheTrackerApp(
        home: DailyEntryPage(repository: repo, date: repo.entry.date)));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.byType(WaterTrackerCard), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Сохранить самочувствие'));
    await tester.pump();
    final buttons = find.descendant(
        of: find.byType(WaterTrackerCard), matching: find.byType(IconButton));
    expect(tester.widget<IconButton>(buttons.last).onPressed, isNull);
    repo.result.complete(repo.entry);
    await tester.pumpAndSettle();
  });
}

void phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(430, 932);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

class _PendingDiary extends InMemoryDiaryRepository {
  final entry = DailyEntry(
      date: DateTime(2026, 10, 28), waterMl: 375, caffeineIntake: 80);
  final result = Completer<DailyEntry>();
  @override
  Future<DailyEntry?> fetchByDate(DateTime date) async => entry;
  @override
  Future<DailyEntry> save(DailyEntry value) => result.future;
}
