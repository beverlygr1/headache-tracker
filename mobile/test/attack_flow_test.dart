import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:headache_tracker_app/app/app.dart';
import 'package:headache_tracker_app/core/api/api_exception.dart';
import 'package:headache_tracker_app/features/tracker/data/attack_repository.dart';
import 'package:headache_tracker_app/features/tracker/domain/attack_draft.dart';
import 'package:headache_tracker_app/features/tracker/domain/attack_record.dart';
import 'package:headache_tracker_app/features/tracker/presentation/pages/attack_entry_page.dart';
import 'package:headache_tracker_app/features/tracker/presentation/pages/attack_details_page.dart';
import 'package:headache_tracker_app/features/tracker/presentation/pages/attack_review_page.dart';
import 'package:headache_tracker_app/features/tracker/presentation/pages/pain_zones_page.dart';
import 'package:headache_tracker_app/features/tracker/presentation/widgets/common.dart';
import 'package:headache_tracker_app/features/tracker/state/tracker_controller.dart';

void main() {
  test('draft snapshots inputs and restores older localization strings', () {
    final zones = ['Лоб', 'Затылок'];
    final draft = _draft(zones: zones);
    zones.clear();
    expect(draft.painLocation, 'Лоб, Затылок');
    expect(AttackDraft.zonesFromRecord(_record()), ['Виски']);
    expect(
      AttackDraft.zonesFromRecord(_record(location: 'Лоб, Затылок')),
      ['Лоб', 'Затылок'],
    );
  });

  testWidgets('empty, front and back states keep a shared selection',
      (tester) async {
    _size(tester);
    await tester.pumpWidget(const HeadacheTrackerApp(home: PainZonesPage()));
    expect(find.text('Пока ничего не выбрано'), findsOneWidget);
    expect(_action(tester, 'Продолжить').onPressed, isNull);
    await tester.tap(find.byKey(const ValueKey('pain-zone-forehead')));
    await tester.pump();
    await tester.tap(find.text('Сзади'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('pain-zone-occiput')));
    await tester.pump();
    expect(find.byKey(const ValueKey('selected-zone-Лоб')), findsOneWidget);
    expect(find.byKey(const ValueKey('selected-zone-Затылок')), findsOneWidget);
    await tester.tap(find.text('Спереди'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('pain-zone-forehead')));
    await tester.pump();
    expect(find.byKey(const ValueKey('selected-zone-Лоб')), findsNothing);
    expect(find.byKey(const ValueKey('selected-zone-Затылок')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('optional map and review write only on Save', (tester) async {
    _size(tester);
    final controller =
        TrackerController(repository: InMemoryAttackRepository());
    addTearDown(controller.dispose);
    await controller.load();
    await tester.pumpWidget(_host(
      (_) => AttackEntryPage(controller: controller),
    ));
    await tester.tap(find.text('Начать'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Дополнительные сведения'));
    await tester.pumpAndSettle();
    final openMap = find.byKey(const ValueKey('open-pain-map'));
    await _reveal(tester, openMap);
    await tester.tap(openMap);
    await tester.pumpAndSettle();
    expect(find.byType(PainZonesPage), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('pain-zone-forehead')));
    await tester.pump();
    await tester.tap(find.text('Сзади'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('pain-zone-occiput')));
    await tester.pump();
    await tester.tap(find.text('Продолжить'));
    await tester.pumpAndSettle();
    expect(find.byType(AttackEntryPage), findsOneWidget);
    await tester.tap(find.text('Продолжить'));
    await tester.pumpAndSettle();
    expect(find.byType(AttackReviewPage), findsOneWidget);
    expect(controller.records, isEmpty);
    await _back(tester);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.widgetWithText(ChoiceChip, 'Лоб'));
    expect(
      tester
          .widget<ChoiceChip>(
            find.widgetWithText(ChoiceChip, 'Лоб'),
          )
          .selected,
      isTrue,
    );
    await tester.tap(find.text('Продолжить'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Сохранить приступ'));
    await tester.pumpAndSettle();
    expect(find.text('Начать'), findsOneWidget);
    expect(controller.records, hasLength(1));
    expect(controller.records.single.painLocation, 'Лоб, Затылок');
    expect(tester.takeException(), isNull);
  });

  testWidgets('quick entry saves without preselected zones or symptoms',
      (tester) async {
    _size(tester);
    final controller =
        TrackerController(repository: InMemoryAttackRepository());
    addTearDown(controller.dispose);
    await controller.load();
    await tester.pumpWidget(_host(
      (_) => AttackEntryPage(controller: controller),
    ));
    await tester.tap(find.text('Начать'));
    await tester.pumpAndSettle();

    expect(find.byType(ChoiceChip), findsNothing);
    await tester.tap(find.text('Продолжить'));
    await tester.pumpAndSettle();
    expect(find.byType(AttackReviewPage), findsOneWidget);
    expect(find.byType(PainZonesPage), findsNothing);
    await tester.tap(find.text('Сохранить приступ'));
    await tester.pumpAndSettle();

    await controller.load();
    final saved = controller.records.single;
    expect(saved.painLocation, isEmpty);
    expect(saved.symptoms, isEmpty);
    expect(saved.painType, isNull);
    expect(saved.medications, isEmpty);
    expect(saved.reliefFactors, isEmpty);
  });

  testWidgets('additional details persist and appear after reopening',
      (tester) async {
    _size(tester);
    final controller =
        TrackerController(repository: InMemoryAttackRepository());
    addTearDown(controller.dispose);
    await controller.load();
    await tester.pumpWidget(_host(
      (_) => AttackEntryPage(controller: controller),
    ));
    await tester.tap(find.text('Начать'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Дополнительные сведения'));
    await tester.pumpAndSettle();

    final pulsating = find.widgetWithText(ChoiceChip, 'Пульсирующая');
    await _reveal(tester, pulsating);
    await tester.tap(pulsating);
    await tester.pump();
    final forehead = find.widgetWithText(ChoiceChip, 'Лоб');
    await _reveal(tester, forehead);
    expect(tester.widget<ChoiceChip>(forehead).selected, isFalse);
    final nausea = find.widgetWithText(ChoiceChip, 'Тошнота');
    await _reveal(tester, nausea);
    expect(tester.widget<ChoiceChip>(nausea).selected, isFalse);
    final addMedication = find.byKey(const ValueKey('add-option-Препараты'));
    await _reveal(tester, addMedication);
    await tester.tap(addMedication);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Ибупрофен');
    await tester.tap(find.widgetWithText(FilledButton, 'Добавить'));
    await tester.pumpAndSettle();
    final rest = find.widgetWithText(ChoiceChip, 'Отдых');
    await _reveal(tester, rest);
    await tester.tap(rest);
    await tester.pump();

    await tester.tap(find.text('Продолжить'));
    await tester.pumpAndSettle();
    expect(find.text('Пульсирующая'), findsOneWidget);
    expect(find.text('Ибупрофен'), findsOneWidget);
    expect(find.text('Отдых'), findsOneWidget);
    await tester.tap(find.text('Сохранить приступ'));
    await tester.pumpAndSettle();
    await controller.load();
    final saved = controller.records.single;
    expect(saved.painType, 'Пульсирующая');
    expect(saved.medications, ['Ибупрофен']);
    expect(saved.reliefFactors, ['Отдых']);
    expect(saved.painLocation, isEmpty);
    expect(saved.symptoms, isEmpty);

    await tester.pumpWidget(HeadacheTrackerApp(
      home: AttackDetailsPage(controller: controller, recordId: saved.id),
    ));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Ибупрофен'), 250);
    expect(find.text('Ибупрофен'), findsOneWidget);
    expect(find.text('Отдых'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('editing clears optional pain details without losing the attack',
      (tester) async {
    _size(tester);
    final original = AttackRecord(
      id: 4,
      startTime: DateTime(2026, 10, 14, 9, 30),
      intensity: 5,
      painLocation: '',
      symptoms: const [],
      painType: 'Пульсирующая',
      medications: const ['Ибупрофен'],
      reliefFactors: const ['Отдых'],
    );
    final controller = TrackerController(
      repository: InMemoryAttackRepository([original]),
    );
    addTearDown(controller.dispose);
    await controller.load();
    await tester.pumpWidget(_host(
      (_) => AttackEntryPage(controller: controller, initialRecord: original),
    ));
    await tester.tap(find.text('Начать'));
    await tester.pumpAndSettle();

    for (final label in ['Пульсирующая', 'Ибупрофен', 'Отдых']) {
      final chip = find.widgetWithText(ChoiceChip, label);
      await _reveal(tester, chip);
      expect(tester.widget<ChoiceChip>(chip).selected, isTrue);
      await tester.tap(chip);
      await tester.pump();
    }
    await tester.tap(find.text('Продолжить'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Сохранить приступ'));
    await tester.pumpAndSettle();

    await controller.load();
    final edited = controller.records.single;
    expect(edited.id, original.id);
    expect(edited.painType, isNull);
    expect(edited.medications, isEmpty);
    expect(edited.reliefFactors, isEmpty);
    expect(edited.intensity, original.intensity);
  });

  testWidgets('cancelling the map discards its unconfirmed changes',
      (tester) async {
    _size(tester);
    final controller =
        TrackerController(repository: InMemoryAttackRepository());
    addTearDown(controller.dispose);
    await controller.load();
    await tester.pumpWidget(_host(
      (_) => AttackEntryPage(controller: controller, initialRecord: _record()),
    ));
    await tester.tap(find.text('Начать'));
    await tester.pumpAndSettle();
    final openMap = find.byKey(const ValueKey('open-pain-map'));
    await _reveal(tester, openMap);
    await tester.tap(openMap);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('pain-zone-forehead')));
    await tester.pump();
    await _back(tester);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<ChoiceChip>(
            find.widgetWithText(ChoiceChip, 'Лоб'),
          )
          .selected,
      isFalse,
    );
    expect(
      tester
          .widget<ChoiceChip>(
            find.widgetWithText(ChoiceChip, 'Виски'),
          )
          .selected,
      isTrue,
    );
    expect(controller.records, isEmpty);
  });

  testWidgets('save failure keeps draft available for retry', (tester) async {
    _size(tester);
    final repository = _ControlledRepository(failFirst: true);
    final controller = TrackerController(repository: repository);
    addTearDown(controller.dispose);
    await controller.load();
    await tester.pumpWidget(_host(
      (_) => AttackReviewPage(controller: controller, draft: _draft()),
    ));
    await tester.tap(find.text('Начать'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Сохранить приступ'));
    await tester.pumpAndSettle();
    expect(find.text('Нет соединения с сервером'), findsOneWidget);
    expect(controller.records, isEmpty);
    await tester.tap(find.text('Сохранить приступ'));
    await tester.pumpAndSettle();
    expect(find.text('Начать'), findsOneWidget);
    expect(repository.attempts, 2);
    expect(controller.records.single.symptoms, ['Тошнота']);
  });

  testWidgets('pending save blocks repeated taps and back', (tester) async {
    _size(tester);
    final pending = Completer<void>();
    final repository = _ControlledRepository(pending: pending);
    final controller = TrackerController(repository: repository);
    addTearDown(controller.dispose);
    await controller.load();
    await tester.pumpWidget(_host(
      (_) => AttackReviewPage(controller: controller, draft: _draft()),
    ));
    await tester.tap(find.text('Начать'));
    await tester.pumpAndSettle();
    final save = _action(tester, 'Сохранить приступ').onPressed!;
    save();
    save();
    await tester.pump();
    expect(repository.attempts, 1);
    expect(_action(tester, 'Сохранение…').onPressed, isNull);
    await _back(tester);
    await tester.pump();
    expect(find.byType(AttackReviewPage), findsOneWidget);
    pending.complete();
    await tester.pumpAndSettle();
    expect(find.text('Начать'), findsOneWidget);
    expect(controller.records, hasLength(1));
  });

  testWidgets('editing a completed attack preserves its id and end time',
      (tester) async {
    _size(tester);
    final original = _record(endTime: DateTime(2026, 10, 8, 10, 15));
    final controller = TrackerController(
      repository: InMemoryAttackRepository([original]),
    );
    addTearDown(controller.dispose);
    await controller.load();
    await tester.pumpWidget(_host(
      (_) => AttackReviewPage(
        controller: controller,
        draft: _draft(id: original.id),
      ),
    ));
    await tester.tap(find.text('Начать'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Сохранить приступ'));
    await tester.pumpAndSettle();
    expect(controller.records, hasLength(1));
    expect(controller.records.single.id, original.id);
    expect(controller.records.single.endTime, original.endTime);
    expect(controller.records.single.painLocation, 'Лоб, Затылок');
  });

  testWidgets('finishing an attack retries after network failure and reopens',
      (tester) async {
    _size(tester);
    final original = _record();
    final repository = _FailingFinishRepository([original]);
    final controller = TrackerController(repository: repository);
    addTearDown(controller.dispose);
    await controller.load();
    await tester.pumpWidget(_host(
      (_) => AttackDetailsPage(controller: controller, recordId: original.id),
    ));
    await tester.tap(find.text('Начать'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Приступ закончился'), 250);
    await tester.tap(find.text('Приступ закончился'));
    await tester.pumpAndSettle();
    expect(find.text('Нет соединения с сервером'), findsOneWidget);
    expect(controller.byId(original.id)?.isActive, isTrue);

    await tester.tap(find.text('Приступ закончился'));
    await tester.pumpAndSettle();
    expect(controller.byId(original.id)?.isActive, isFalse);
    expect(controller.byId(original.id)?.endTime, isNotNull);
    await _back(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Начать'));
    await tester.pumpAndSettle();
    expect(find.text('Приступ завершён'), findsWidgets);
    expect(controller.records, hasLength(1));
    expect(repository.attempts, 2);
  });

  testWidgets('new screens fit 320px with enlarged text and scrolling',
      (tester) async {
    _size(tester, const Size(320, 568));
    final controller =
        TrackerController(repository: InMemoryAttackRepository());
    addTearDown(controller.dispose);
    await controller.load();
    for (final page in [
      const PainZonesPage(initialZones: ['Лоб', 'Затылок', 'Своя область']),
      AttackReviewPage(controller: controller, draft: _draft()),
    ]) {
      await tester.pumpWidget(HeadacheTrackerApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.4)),
          child: page,
        ),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.drag(find.byType(ListView), const Offset(0, -400));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(PrimaryActionButton), findsOneWidget);
    }
  });
}

void _size(WidgetTester tester, [Size size = const Size(390, 844)]) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _reveal(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(target, 180);
  await Scrollable.ensureVisible(tester.element(target), alignment: 0.5);
  await tester.pumpAndSettle();
}

PrimaryActionButton _action(WidgetTester tester, String label) =>
    tester.widget(find.widgetWithText(PrimaryActionButton, label));

Future<void> _back(WidgetTester tester) =>
    tester.tap(find.byIcon(Icons.chevron_left_rounded));

Widget _host(WidgetBuilder page) => HeadacheTrackerApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).push<bool>(
                MaterialPageRoute(builder: page),
              ),
              child: const Text('Начать'),
            ),
          ),
        ),
      ),
    );

AttackDraft _draft({int? id, List<String> zones = const ['Лоб', 'Затылок']}) =>
    AttackDraft(
      id: id,
      startTime: DateTime(2026, 10, 8, 9, 30),
      intensity: 6,
      painZones: zones,
      symptoms: const ['Тошнота'],
    );

AttackRecord _record({String location = 'Виски', DateTime? endTime}) =>
    AttackRecord(
      id: 1,
      startTime: DateTime(2026, 10, 8, 9, 30),
      endTime: endTime,
      intensity: 6,
      painLocation: location,
      symptoms: const ['Тошнота'],
    );

class _ControlledRepository extends InMemoryAttackRepository {
  _ControlledRepository({this.failFirst = false, this.pending});

  final bool failFirst;
  final Completer<void>? pending;
  int attempts = 0;

  @override
  Future<AttackRecord> create({
    required DateTime startTime,
    required int intensity,
    required String painLocation,
    required List<String> symptoms,
    String? painType,
    List<String>? medications,
    List<String>? reliefFactors,
  }) async {
    attempts++;
    if (failFirst && attempts == 1) {
      throw ApiException(message: 'Нет соединения с сервером');
    }
    if (pending != null) await pending!.future;
    return super.create(
      startTime: startTime,
      intensity: intensity,
      painLocation: painLocation,
      symptoms: symptoms,
      painType: painType,
      medications: medications,
      reliefFactors: reliefFactors,
    );
  }
}

class _FailingFinishRepository extends InMemoryAttackRepository {
  _FailingFinishRepository(super.records);

  int attempts = 0;

  @override
  Future<AttackRecord> finish(int id, DateTime endTime) async {
    attempts++;
    if (attempts == 1) {
      throw ApiException(message: 'Нет соединения с сервером');
    }
    return super.finish(id, endTime);
  }
}
