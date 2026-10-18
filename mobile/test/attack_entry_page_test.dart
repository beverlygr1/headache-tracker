import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:headache_tracker_app/app/app.dart';
import 'package:headache_tracker_app/features/tracker/presentation/pages/attack_entry_page.dart';
import 'package:headache_tracker_app/features/tracker/state/tracker_controller.dart';

void main() {
  Future<void> openAddDialog(WidgetTester tester, String sectionTitle) async {
    // Экран телефона: в окне 800×600 чип «+» у симптомов закрыт кнопкой
    // «Сохранить приступ».
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = TrackerController.demo();
    await controller.load();
    await tester.pumpWidget(
      HeadacheTrackerApp(home: AttackEntryPage(controller: controller)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Дополнительные сведения'));
    await tester.pumpAndSettle();
    final addChip = find.byKey(ValueKey('add-option-$sectionTitle'));
    await _reveal(tester, addChip);
    await tester.tap(addChip);
    await tester.pumpAndSettle();
  }

  testWidgets('cancelling custom pain area dialog closes it cleanly',
      (tester) async {
    await openAddDialog(tester, 'Где болит?');
    expect(find.text('Добавить область'), findsOneWidget);

    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Добавить область'), findsNothing);
  });

  testWidgets('adding custom symptom selects it without errors',
      (tester) async {
    await openAddDialog(tester, 'Что ещё чувствуете?');
    expect(find.text('Добавить симптом'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '  Головокружение ');
    await tester.tap(find.widgetWithText(FilledButton, 'Добавить'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Добавить симптом'), findsNothing);
    expect(find.text('Головокружение'), findsOneWidget);
  });

  testWidgets('custom pain area can be submitted from keyboard',
      (tester) async {
    await openAddDialog(tester, 'Где болит?');

    await tester.enterText(find.byType(TextField), 'Шея');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Шея'), findsOneWidget);
  });
}

Future<void> _reveal(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(target, 180);
  final height = tester.getSize(find.byType(Scaffold).last).height;
  for (var i = 0; i < 8; i++) {
    final y = tester.getCenter(target).dy;
    if (y > 80 && y < height - 140) return;
    await tester.drag(
      find.byType(ListView),
      Offset(0, y >= height - 140 ? -150 : 150),
    );
    await tester.pumpAndSettle();
  }
}
