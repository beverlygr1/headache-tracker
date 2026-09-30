import 'package:flutter_test/flutter_test.dart';
import 'package:headache_tracker_app/core/api/api_exception.dart';
import 'package:headache_tracker_app/features/tracker/data/attack_repository.dart';
import 'package:headache_tracker_app/features/tracker/domain/attack_record.dart';
import 'package:headache_tracker_app/features/tracker/state/tracker_controller.dart';

void main() {
  test('demo state contains active and completed attacks', () async {
    final controller = TrackerController.demo();
    expect(controller.status, TrackerStatus.initial);

    await controller.load();

    expect(controller.status, TrackerStatus.ready);
    expect(controller.records, hasLength(2));
    expect(controller.activeAttack, isNotNull);
    expect(
        controller.records.where((record) => !record.isActive), hasLength(1));
  });

  test('active attack can be updated and finished', () async {
    final controller = TrackerController.demo();
    await controller.load();
    final active = controller.activeAttack!;

    await controller.saveAttack(
      id: active.id,
      startTime: active.startTime,
      intensity: 8,
      painLocation: 'Затылок',
      symptoms: const ['Тошнота'],
    );
    await controller.finishAttack(active.id);

    final updated = controller.byId(active.id)!;
    expect(updated.intensity, 8);
    expect(updated.painLocation, 'Затылок');
    expect(updated.symptoms, ['Тошнота']);
    expect(updated.isActive, isFalse);
    expect(controller.isSaving, isFalse);
  });

  test('new attack gets id from repository', () async {
    final controller = TrackerController.demo();
    await controller.load();

    await controller.saveAttack(
      startTime: DateTime.now(),
      intensity: 3,
      painLocation: 'Лоб',
      symptoms: const [],
    );

    expect(controller.records, hasLength(3));
    expect(controller.records.map((r) => r.id).toSet(), hasLength(3));
  });

  test('first load failure exposes error message', () async {
    final controller = TrackerController(
      repository: _FailingRepository(
        ApiException(message: 'Нет соединения с сервером'),
      ),
    );

    await controller.load();

    expect(controller.status, TrackerStatus.failure);
    expect(controller.errorMessage, 'Нет соединения с сервером');
  });

  test('save failure is rethrown and keeps records unchanged', () async {
    final controller = TrackerController(
      repository: _FailingRepository(
        ApiException(message: 'Ошибка сервера (500)', statusCode: 500),
        failFetch: false,
      ),
    );
    await controller.load();

    await expectLater(
      controller.saveAttack(
        startTime: DateTime.now(),
        intensity: 5,
        painLocation: 'Лоб',
        symptoms: const [],
      ),
      throwsA(isA<ApiException>()),
    );
    expect(controller.records, isEmpty);
    expect(controller.isSaving, isFalse);
  });
}

class _FailingRepository extends InMemoryAttackRepository {
  _FailingRepository(this.error, {this.failFetch = true});

  final ApiException error;
  final bool failFetch;

  @override
  Future<List<AttackRecord>> fetchAll() async {
    if (failFetch) throw error;
    return super.fetchAll();
  }

  @override
  Future<AttackRecord> create({
    required DateTime startTime,
    required int intensity,
    required String painLocation,
    required List<String> symptoms,
  }) async {
    throw error;
  }
}
