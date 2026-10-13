import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:headache_tracker_app/app/app.dart';
import 'package:headache_tracker_app/core/api/api_exception.dart';
import 'package:headache_tracker_app/features/diary/data/daily_entry.dart';
import 'package:headache_tracker_app/features/diary/data/diary_repository.dart';
import 'package:headache_tracker_app/features/diary/presentation/daily_entry_page.dart';
import 'package:headache_tracker_app/features/tracker/data/attack_repository.dart';
import 'package:headache_tracker_app/features/tracker/presentation/app_shell.dart';
import 'package:headache_tracker_app/features/tracker/presentation/pages/diary_page.dart';
import 'package:headache_tracker_app/features/tracker/state/tracker_controller.dart';

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

  testWidgets('daily entry reopens and edits new fields without losing values',
      (tester) async {
    final repository = InMemoryDiaryRepository();
    final date = DateTime(2026, 10, 10);
    await tester.pumpWidget(_host(repository, date));
    await _open(tester);

    await tester.tap(find.byKey(const ValueKey('headache-no')));
    await tester.enterText(
        find.byKey(const ValueKey('sleep-hours-field')), '7,5');
    await tester.scrollUntilVisible(
        find.byKey(const ValueKey('sleep-quality-8')), 250,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.byKey(const ValueKey('sleep-quality-8')));
    await tester.scrollUntilVisible(
        find.byKey(const ValueKey('caffeine-field')), 250,
        scrollable: find.byType(Scrollable).first);
    await tester.enterText(find.byKey(const ValueKey('caffeine-field')), '120');
    await tester.tap(find.text('Сохранить самочувствие'));
    await tester.pumpAndSettle();

    var saved = await repository.fetchByDate(date);
    expect(saved?.headachePresent, isFalse);
    expect(saved?.sleepHours, 7.5);
    expect(saved?.sleepQuality, 8);
    expect(saved?.caffeineIntake, 120);
    expect(saved?.summary, contains('Без боли'));

    await _open(tester);
    expect(
        tester
            .widget<ChoiceChip>(
              find.byKey(const ValueKey('headache-no')),
            )
            .selected,
        isTrue);
    await tester.scrollUntilVisible(
        find.byKey(const ValueKey('sleep-quality-8')), 250,
        scrollable: find.byType(Scrollable).first);
    expect(
        tester
            .widget<ChoiceChip>(
              find.byKey(const ValueKey('sleep-quality-8')),
            )
            .selected,
        isTrue);
    await tester.scrollUntilVisible(
        find.byKey(const ValueKey('caffeine-field')), 250,
        scrollable: find.byType(Scrollable).first);
    expect(
        tester
            .widget<TextFormField>(
              find.byKey(const ValueKey('caffeine-field')),
            )
            .controller!
            .text,
        '120');
    await tester.scrollUntilVisible(
        find.byKey(const ValueKey('water-field')), -250,
        scrollable: find.byType(Scrollable).first);
    await tester.enterText(find.byKey(const ValueKey('water-field')), '1800');
    await tester.tap(find.text('Сохранить самочувствие'));
    await tester.pumpAndSettle();

    saved = await repository.fetchByDate(date);
    expect(saved?.waterMl, 1800);
    expect(saved?.headachePresent, isFalse);
    expect(saved?.sleepQuality, 8);
    expect(saved?.caffeineIntake, 120);
  });

  testWidgets('failed save leaves diary input available for retry',
      (tester) async {
    final repository = _FailOnceRepository();
    final date = DateTime(2026, 10, 10);
    await repository.save(DailyEntry(date: date, headachePresent: true));
    repository.attempts = 0;
    repository.failNext = true;
    await tester.pumpWidget(_host(repository, date));
    await _open(tester);
    await tester.tap(find.byKey(const ValueKey('headache-no')));
    await tester.scrollUntilVisible(
        find.byKey(const ValueKey('caffeine-field')), 250,
        scrollable: find.byType(Scrollable).first);
    await tester.enterText(find.byKey(const ValueKey('caffeine-field')), '200');
    await tester.tap(find.text('Сохранить самочувствие'));
    await tester.pumpAndSettle();

    expect(find.text('Нет соединения с сервером'), findsOneWidget);
    await tester.scrollUntilVisible(
        find.byKey(const ValueKey('headache-no')), -250,
        scrollable: find.byType(Scrollable).first);
    expect(
        tester
            .widget<ChoiceChip>(
              find.byKey(const ValueKey('headache-no')),
            )
            .selected,
        isTrue);
    await tester.scrollUntilVisible(
        find.byKey(const ValueKey('caffeine-field')), 250,
        scrollable: find.byType(Scrollable).first);
    expect(
        tester
            .widget<TextFormField>(
              find.byKey(const ValueKey('caffeine-field')),
            )
            .controller!
            .text,
        '200');
    expect((await repository.fetchByDate(date))?.headachePresent, isTrue);

    await tester.tap(find.text('Сохранить самочувствие'));
    await tester.pumpAndSettle();
    final saved = await repository.fetchByDate(date);
    expect(saved?.headachePresent, isFalse);
    expect(saved?.caffeineIntake, 200);
    expect(repository.attempts, 2);
  });

  testWidgets('diary list reopens a saved day and stays in diary after edit',
      (tester) async {
    final repository = InMemoryDiaryRepository();
    await repository
        .save(DailyEntry(date: DateTime.now(), headachePresent: false));
    final controller =
        TrackerController(repository: InMemoryAttackRepository());
    addTearDown(controller.dispose);
    await tester.pumpWidget(HeadacheTrackerApp(
        home: AppShell(
      controller: controller,
      diaryRepository: repository,
    )));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Дневник'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Без боли'), 250,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Без боли'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
        find.byKey(const ValueKey('caffeine-field')), 250,
        scrollable: find.byType(Scrollable).first);
    await tester.enterText(find.byKey(const ValueKey('caffeine-field')), '120');
    await tester.tap(find.text('Сохранить самочувствие'));
    await tester.pumpAndSettle();

    expect(find.byType(DiaryPage), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Без боли · Кофеин 120 мг'), 250,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Без боли · Кофеин 120 мг'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
        find.byKey(const ValueKey('caffeine-field')), 250,
        scrollable: find.byType(Scrollable).first);
    expect(
        tester
            .widget<TextFormField>(
              find.byKey(const ValueKey('caffeine-field')),
            )
            .controller!
            .text,
        '120');
  });

  testWidgets('expanded daily form scrolls on a narrow screen', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(HeadacheTrackerApp(
      home: MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.4)),
        child: DailyEntryPage(
          repository: InMemoryDiaryRepository(),
          date: DateTime(2026, 10, 10),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
        find.byKey(const ValueKey('stress-10')), 220,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('Сохранить самочувствие'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('editing can clear the only recorded answer back to unknown',
      (tester) async {
    final repository = InMemoryDiaryRepository();
    final date = DateTime(2026, 10, 10);
    await repository.save(DailyEntry(date: date, headachePresent: true));
    await tester.pumpWidget(_host(repository, date));
    await _open(tester);
    await tester.tap(find.byKey(const ValueKey('headache-yes')));
    await tester.tap(find.text('Сохранить самочувствие'));
    await tester.pumpAndSettle();
    expect((await repository.fetchByDate(date))?.headachePresent, isNull);
  });
}

Widget _host(DiaryRepository repository, DateTime date) => HeadacheTrackerApp(
      home: Builder(
          builder: (context) => Scaffold(
                body: Center(
                    child: TextButton(
                  onPressed: () =>
                      Navigator.of(context).push<DailyEntry>(MaterialPageRoute(
                    builder: (_) =>
                        DailyEntryPage(repository: repository, date: date),
                  )),
                  child: const Text('Открыть дневник'),
                )),
              )),
    );

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.text('Открыть дневник'));
  await tester.pumpAndSettle();
}

class _FailOnceRepository extends InMemoryDiaryRepository {
  bool failNext = false;
  int attempts = 0;

  @override
  Future<DailyEntry> save(DailyEntry entry) async {
    attempts++;
    if (failNext) {
      failNext = false;
      throw ApiException(message: 'Нет соединения с сервером');
    }
    return super.save(entry);
  }
}

class _FailingSaveRepository extends InMemoryDiaryRepository {
  @override
  Future<DailyEntry?> fetchByDate(DateTime date) async =>
      DailyEntry(date: date, sleepHours: 7.5);

  @override
  Future<DailyEntry> save(DailyEntry entry) async =>
      throw StateError('network');
}
