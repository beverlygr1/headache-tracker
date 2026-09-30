import 'package:flutter_test/flutter_test.dart';
import 'package:headache_tracker_app/features/tracker/state/tracker_controller.dart';

void main() {
  test('demo state contains active and completed attacks', () {
    final controller = TrackerController.demo();

    expect(controller.records, hasLength(2));
    expect(controller.activeAttack, isNotNull);
    expect(
        controller.records.where((record) => !record.isActive), hasLength(1));
  });

  test('active attack can be updated and finished', () {
    final controller = TrackerController.demo();
    final active = controller.activeAttack!;

    controller.saveAttack(
      id: active.id,
      startTime: active.startTime,
      intensity: 8,
      painLocation: 'Затылок',
      symptoms: const ['Тошнота'],
    );
    controller.finishAttack(active.id);

    final updated = controller.byId(active.id)!;
    expect(updated.intensity, 8);
    expect(updated.painLocation, 'Затылок');
    expect(updated.symptoms, ['Тошнота']);
    expect(updated.isActive, isFalse);
  });
}
