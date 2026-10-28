import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:headache_tracker_app/app/app.dart';
import 'package:headache_tracker_app/features/tracker/domain/pain_zones.dart';
import 'package:headache_tracker_app/features/tracker/presentation/pages/pain_zones_page.dart';

void main() {
  test('all zones together fit the backend localization limit', () {
    expect(PainZones.all.join(', ').length, lessThanOrEqualTo(120));
    expect(PainZones.all.toSet(), hasLength(PainZones.all.length));
  });

  Future<List<String>?> pickZones(
    WidgetTester tester,
    Future<void> Function() actions,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    List<String>? result;
    await tester.pumpWidget(HeadacheTrackerApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () async {
                result = await Navigator.of(context).push<List<String>>(
                  MaterialPageRoute(builder: (_) => const PainZonesPage()),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await actions();
    final next = find.text('Продолжить');
    await tester.ensureVisible(next);
    await tester.tap(next);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    return result;
  }

  testWidgets('every front and back region selects its own zone',
      (tester) async {
    final result = await pickZones(tester, () async {
      for (final id in [
        'forehead',
        'crown',
        'right-temple',
        'left-temple',
        'right-eye',
        'left-eye',
        'sinuses',
      ]) {
        await tester.tap(find.byKey(ValueKey('pain-zone-$id')));
        await tester.pump();
      }
      await tester.tap(find.text('Сзади'));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('pain-zone-occiput')));
      await tester.tap(find.byKey(const ValueKey('pain-zone-neck')));
      await tester.pump();
    });

    expect(result, [
      PainZones.forehead,
      PainZones.crown,
      PainZones.rightTemple,
      PainZones.leftTemple,
      PainZones.rightEye,
      PainZones.leftEye,
      PainZones.sinuses,
      PainZones.occiput,
      PainZones.neck,
    ]);
  });

  testWidgets('crown chosen on front stays selected on back view',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(const HeadacheTrackerApp(home: PainZonesPage()));
    await tester.tap(find.byKey(const ValueKey('pain-zone-crown')));
    await tester.pump();
    await tester.tap(find.text('Сзади'));
    await tester.pump();

    final crownChip = tester.widget<ChoiceChip>(
      find.widgetWithText(ChoiceChip, PainZones.crown),
    );
    expect(crownChip.selected, isTrue);
  });

  testWidgets('whole head is available as a chip on both views',
      (tester) async {
    final result = await pickZones(tester, () async {
      await tester.tap(find.widgetWithText(ChoiceChip, PainZones.wholeHead));
      await tester.pump();
      await tester.tap(find.text('Сзади'));
      await tester.pump();
      expect(
        tester
            .widget<ChoiceChip>(
                find.widgetWithText(ChoiceChip, PainZones.wholeHead))
            .selected,
        isTrue,
      );
    });
    expect(result, [PainZones.wholeHead]);
  });

  testWidgets('legacy zone from old records is kept and removable',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(const HeadacheTrackerApp(
      home: PainZonesPage(initialZones: ['Виски']),
    ));
    final legacy =
        find.byKey(const ValueKey('selected-zone-Виски'), skipOffstage: false);
    expect(legacy, findsOneWidget);
    await tester.ensureVisible(legacy);
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(
      of: legacy,
      matching: find.byIcon(Icons.close_rounded),
    ));
    await tester.pump();
    expect(legacy, findsNothing);
  });
}
