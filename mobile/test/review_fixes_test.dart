import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:headache_tracker_app/app/app.dart';
import 'package:headache_tracker_app/core/api/api_client.dart';
import 'package:headache_tracker_app/core/api/api_exception.dart';
import 'package:headache_tracker_app/core/storage/token_storage.dart';
import 'package:headache_tracker_app/core/utils/app_time_picker.dart';
import 'package:headache_tracker_app/features/analytics/data/analytics_api.dart';
import 'package:headache_tracker_app/features/analytics/data/analytics_dto.dart';
import 'package:headache_tracker_app/features/analytics/state/analytics_controller.dart';
import 'package:headache_tracker_app/features/analytics/presentation/analytics_page.dart';
import 'package:headache_tracker_app/features/diary/data/daily_entry.dart';
import 'package:headache_tracker_app/features/diary/data/diary_repository.dart';
import 'package:headache_tracker_app/features/diary/presentation/daily_entry_page.dart';
import 'package:headache_tracker_app/features/forecast/data/forecast_data.dart';
import 'package:headache_tracker_app/features/forecast/presentation/forecast_card.dart';
import 'package:headache_tracker_app/features/forecast/state/forecast_controller.dart';
import 'package:headache_tracker_app/features/tracker/data/attack_repository.dart';
import 'package:headache_tracker_app/features/tracker/domain/attack_record.dart';
import 'package:headache_tracker_app/features/tracker/presentation/app_shell.dart';
import 'package:headache_tracker_app/features/tracker/presentation/pages/attack_details_page.dart';
import 'package:headache_tracker_app/features/tracker/presentation/pages/attack_entry_page.dart';
import 'package:headache_tracker_app/features/tracker/state/tracker_controller.dart';

void main() {
  test('statistics parses actual API field names and fractional duration', () {
    final data = AnalyticsDto.fromJson(_summary);
    expect(data.averageIntensity, 6.5);
    expect(data.averageDurationMinutes, 65.5);
    expect(data.formattedDuration, '1 ч 6 мин');
    expect(AnalyticsDto.formatDuration(.5), '<1 мин');
  });

  test(
      'rapid period changes cannot replace newest chart with an older response',
      () async {
    final oldSummary = Completer<Map<String, dynamic>>();
    final api = _AnalyticsApi()..pendingMonth = oldSummary;
    final controller = AnalyticsController(api, timeZone: 'Asia/Tomsk');
    addTearDown(controller.dispose);
    final oldLoad = controller.loadAnalytics('month');
    await controller.loadAnalytics('week');
    oldSummary.complete({..._summary, 'total_attacks': 99});
    await oldLoad;
    expect(controller.value.selectedPeriod, 'week');
    expect(controller.value.data!.totalAttacks, 2);
    expect(api.zones.toSet(), {'Asia/Tomsk'});
  });

  test(
      'forecast keeps no invented probability on missing data or service failure',
      () async {
    var fail = true;
    final controller = ForecastController.withLoader(() async {
      if (fail) throw ApiException(statusCode: 503, message: 'Unavailable');
      return _forecast(false);
    });
    addTearDown(controller.dispose);
    await controller.refresh();
    expect(controller.value.status, ForecastStatus.error);
    expect(controller.value.data, isNull);
    fail = false;
    await controller.refresh();
    expect(controller.value.status, ForecastStatus.loaded);
    expect(controller.value.data!.probability, isNull);
    expect(controller.value.data!.missingDescription,
        'длительность сна, уровень стресса');
    expect(controller.value.error, isNull);
  });

  test('forecast discards responses after disposal', () async {
    final response = Completer<ForecastData>();
    final controller = ForecastController.withLoader(() => response.future);
    final load = controller.refresh();
    controller.dispose();
    response.complete(_forecast(true));
    await load;
  });

  testWidgets(
      'forecast shows server probability and date, missing data opens diary',
      (tester) async {
    _phone(tester);
    var ready = false;
    var opened = false;
    final controller =
        ForecastController.withLoader(() async => _forecast(ready));
    addTearDown(controller.dispose);
    await controller.refresh();
    await tester.pumpWidget(HeadacheTrackerApp(
        home: Scaffold(
            body: ForecastCard(
                controller: controller,
                onOpenDailyEntry: () => opened = true))));
    expect(find.textContaining('длительность сна, уровень стресса'),
        findsOneWidget);
    await tester.tap(find.text('Заполнить самочувствие'));
    expect(opened, isTrue);
    ready = true;
    await controller.refresh();
    await tester.pump();
    expect(find.text('37% — вероятность боли'), findsOneWidget);
    expect(find.text('На 29 октября'), findsOneWidget);
    expect(find.text('Заполнить самочувствие'), findsNothing);
  });

  testWidgets('statistics cards open each metric and day values from server',
      (tester) async {
    _phone(tester);
    final controller = AnalyticsController(_AnalyticsApi());
    addTearDown(controller.dispose);
    await tester.pumpWidget(HeadacheTrackerApp(
        home: Scaffold(body: AnalyticsPage(controller: controller))));
    await tester.pumpAndSettle();
    expect(find.text('6.5 / 10'), findsOneWidget);
    await tester.tap(find.text('Средняя длительность'));
    await tester.pumpAndSettle();
    expect(find.text('Длительность по дням'), findsOneWidget);
    expect(find.textContaining('Нет завершённых приступов'), findsWidgets);
    await tester.tap(find.byKey(const ValueKey('chart-day-0')));
    await tester.pump();
    expect(find.text('27 октября · 1 ч 6 мин'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Всего приступов'), -200,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Всего приступов'));
    await tester.pumpAndSettle();
    expect(find.text('Приступы по дням'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final size in [const Size(360, 800), const Size(1440, 900)]) {
    testWidgets('24-hour time confirmation fits screen $size and keyboard',
        (tester) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      TimeOfDay? saved;
      await tester.pumpWidget(HeadacheTrackerApp(
          home: Builder(
              builder: (context) => Scaffold(
                  body: TextButton(
                      onPressed: () async {
                        saved = await showAppTimePicker(
                            context: context,
                            initialTime: const TimeOfDay(hour: 21, minute: 45),
                            helpText: 'Время начала боли');
                      },
                      child: const Text('Время'))))));
      await tester.tap(find.text('Время'));
      await tester.pumpAndSettle();
      expect(find.text('21'), findsWidgets);
      expect(find.text('AM'), findsNothing);
      expect(find.text('PM'), findsNothing);
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      expect(find.text('Сохранить').hitTestable(), findsOneWidget);
      await tester.tap(find.text('Сохранить'));
      await tester.pumpAndSettle();
      expect(saved, const TimeOfDay(hour: 21, minute: 45));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('pain and relief use presets and retain legacy selected values',
      (tester) async {
    _phone(tester);
    final record = _record().copyWith(
        painType: 'Прежнее описание', reliefFactors: ['Прежний способ']);
    final controller =
        TrackerController(repository: InMemoryAttackRepository([record]));
    addTearDown(controller.dispose);
    await controller.load();
    await tester.pumpWidget(HeadacheTrackerApp(
        home: AttackEntryPage(controller: controller, initialRecord: record)));
    await tester.pumpAndSettle();
    expect(
        find.byKey(const ValueKey('add-option-Характер боли')), findsNothing);
    expect(find.byKey(const ValueKey('add-option-Что помогло?')), findsNothing);
    await tester.scrollUntilVisible(find.text('Прежнее описание'), 180,
        scrollable: find.byType(Scrollable).first);
    final oldPain = tester.widget<ChoiceChip>(
        find.widgetWithText(ChoiceChip, 'Прежнее описание'));
    expect(oldPain.selected, isTrue);
    await tester.scrollUntilVisible(find.text('Звук мешает'), 180,
        scrollable: find.byType(Scrollable).first);
    expect(find.widgetWithText(ChoiceChip, 'Звук мешает'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Прежний способ'), 180,
        scrollable: find.byType(Scrollable).first);
    expect(
        tester
            .widget<ChoiceChip>(
                find.widgetWithText(ChoiceChip, 'Прежний способ'))
            .selected,
        isTrue);
  });

  testWidgets(
      'delete cancellation and network failure retain record, retry deletes',
      (tester) async {
    _phone(tester);
    final repository = _DeleteRepository();
    final controller = TrackerController(repository: repository);
    addTearDown(controller.dispose);
    await controller.load();
    await tester.pumpWidget(HeadacheTrackerApp(
        home: Builder(
            builder: (context) => Scaffold(
                body: TextButton(
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                            builder: (_) => AttackDetailsPage(
                                controller: controller, recordId: 1))),
                    child: const Text('Открыть'))))));
    await tester.tap(find.text('Открыть'));
    await tester.pumpAndSettle();
    Future<void> askDelete() async {
      await tester.scrollUntilVisible(
          find.byKey(const ValueKey('delete-attack')), 200);
      await Scrollable.ensureVisible(
          tester.element(find.byKey(const ValueKey('delete-attack'))),
          alignment: .5);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('delete-attack')));
      await tester.pumpAndSettle();
    }

    await askDelete();
    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();
    expect(repository.deleteCalls, 0);
    await askDelete();
    await tester.tap(find.byKey(const ValueKey('confirm-delete-attack')));
    await tester.pumpAndSettle();
    expect(controller.byId(1), isNotNull);
    expect(find.byType(AttackDetailsPage), findsOneWidget);
    expect(find.text('Нет соединения с сервером'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    repository.fail = false;
    await askDelete();
    await tester.tap(find.byKey(const ValueKey('confirm-delete-attack')));
    await tester.pumpAndSettle();
    expect(controller.byId(1), isNull);
    expect(await repository.fetchAll(), isEmpty);
    expect(find.byType(AttackDetailsPage), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final resumed in [false, true]) {
    testWidgets(
        'new day offers a fresh diary without replacing yesterday (resume=$resumed)',
        (tester) async {
      _phone(tester);
      var now = DateTime(2026, 10, 28, 23, 59);
      final repository = InMemoryDiaryRepository();
      await repository
          .save(DailyEntry(date: DateTime(2026, 10, 28), sleepHours: 7));
      final controller =
          TrackerController(repository: InMemoryAttackRepository());
      addTearDown(controller.dispose);
      await controller.load();
      await tester.pumpWidget(HeadacheTrackerApp(
          home: AppShell(
              controller: controller,
              diaryRepository: repository,
              now: () => now)));
      await tester.pumpAndSettle();
      expect(find.text('Самочувствие сегодня'), findsOneWidget);
      now = DateTime(2026, 10, 29, 0, 1);
      if (resumed) {
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        tester.binding
            .handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        await tester.pumpAndSettle();
      } else {
        await tester.pump(const Duration(minutes: 1));
        await tester.pumpAndSettle();
      }
      expect(find.text('Как прошёл ваш день?'), findsOneWidget);
      await tester.tap(find.text('Как прошёл ваш день?'));
      await tester.pumpAndSettle();
      expect(
          tester.widget<DailyEntryPage>(find.byType(DailyEntryPage)).date.day,
          29);
      expect(
          tester
              .widget<TextFormField>(
                  find.byKey(const ValueKey('sleep-hours-field')))
              .controller!
              .text,
          isEmpty);
      await tester.enterText(
          find.byKey(const ValueKey('sleep-hours-field')), '8');
      await tester.tap(find.text('Сохранить самочувствие'));
      await tester.pumpAndSettle();
      expect((await repository.fetchByDate(DateTime(2026, 10, 28)))!.sleepHours,
          7);
      expect((await repository.fetchByDate(DateTime(2026, 10, 29)))!.sleepHours,
          8);
      await tester.pumpWidget(const SizedBox());
    });
  }
}

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(430, 932);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

const _summary = <String, dynamic>{
  'total_attacks': 2,
  'avg_intensity': 6.5,
  'avg_duration_minutes': 65.5,
  'completed_attacks': 1
};

class _AnalyticsApi extends AnalyticsApi {
  _AnalyticsApi() : super(ApiClient(dio: Dio(), tokenStorage: _NoTokens()));
  Completer<Map<String, dynamic>>? pendingMonth;
  final zones = <String>[];
  @override
  Future<Map<String, dynamic>> getSummary(
      {String period = 'month', String timeZone = 'UTC'}) async {
    zones.add(timeZone);
    return period == 'month' && pendingMonth != null
        ? pendingMonth!.future
        : _summary;
  }

  @override
  Future<Map<String, dynamic>> getIntensity(
      {String period = 'month', String timeZone = 'UTC'}) async {
    zones.add(timeZone);
    return {
      'time_zone': timeZone,
      'points': [
        {
          'date': '2026-10-27',
          'total_attacks': 1,
          'avg_intensity': 5,
          'avg_duration_minutes': 65.5,
          'completed_attacks': 1
        },
        {
          'date': '2026-10-28',
          'total_attacks': 1,
          'avg_intensity': 8,
          'avg_duration_minutes': null,
          'completed_attacks': 0
        },
      ]
    };
  }
}

class _NoTokens extends TokenStorage {
  @override
  Future<String?> getAccessToken() async => null;
}

ForecastData _forecast(bool ready) => ForecastData.fromJson({
      'status': ready ? 'ready' : 'insufficient_data',
      'prediction_date': '2026-10-29',
      'time_zone': 'Asia/Tomsk',
      'probability': ready ? .37 : null,
      'missing_fields': ready ? <String>[] : ['sleep_hours', 'stress_level'],
    });
AttackRecord _record() => AttackRecord(
    id: 1,
    startTime: DateTime(2026, 10, 20, 10),
    intensity: 4,
    painLocation: '',
    symptoms: const []);

class _DeleteRepository extends InMemoryAttackRepository {
  _DeleteRepository() : super([_record()]);
  bool fail = true;
  int deleteCalls = 0;
  @override
  Future<void> delete(int id) async {
    deleteCalls++;
    if (fail) {
      throw ApiException(
          message: 'Нет соединения с сервером', isNetworkError: true);
    }
    await super.delete(id);
  }
}
