import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:headache_tracker_app/app/app.dart';
import 'package:headache_tracker_app/features/diary/data/daily_entry.dart';
import 'package:headache_tracker_app/features/diary/data/diary_repository.dart';
import 'package:headache_tracker_app/features/diary/presentation/daily_entry_page.dart';

void main() {
  testWidgets('empty and invalid values cannot be saved as observations',
      (tester) async {
    final repository = InMemoryDiaryRepository();
    final date = DateTime(2026, 10, 7);
    await tester.pumpWidget(HeadacheTrackerApp(
        home: DailyEntryPage(repository: repository, date: date)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Сохранить самочувствие'));
    await tester.pumpAndSettle();
    expect(find.text('Заполните хотя бы один пункт'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).first, 'NaN');
    await tester.tap(find.text('Сохранить самочувствие'));
    await tester.pumpAndSettle();
    expect(find.text('Введите число от 0 до 24'), findsOneWidget);
    expect(await repository.fetchAll(), isEmpty);
  });

  testWidgets(
      'existing observation loads and network failure keeps entered values',
      (tester) async {
    final repository = _FailingSaveRepository();
    final date = DateTime(2026, 10, 7);
    await tester.pumpWidget(HeadacheTrackerApp(
        home: DailyEntryPage(repository: repository, date: date)));
    await tester.pumpAndSettle();
    expect(find.text('7,5'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).first, '8');
    await tester.tap(find.text('Сохранить самочувствие'));
    await tester.pumpAndSettle();
    expect(
        find.text('Что-то пошло не так. Попробуйте ещё раз'), findsOneWidget);
    expect(find.text('8'), findsWidgets);
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull);
  });
}

class _FailingSaveRepository extends InMemoryDiaryRepository {
  @override
  Future<DailyEntry?> fetchByDate(DateTime date) async =>
      DailyEntry(date: date, sleepHours: 7.5);

  @override
  Future<DailyEntry> save(DailyEntry entry) async =>
      throw StateError('network');
}
