import 'package:flutter/foundation.dart';

import '../../../core/api/api_exception.dart';
import '../data/attack_repository.dart';
import '../domain/attack_record.dart';

enum TrackerStatus { initial, loading, ready, failure }

class TrackerController extends ChangeNotifier {
  TrackerController({required AttackRepository repository})
      : _repository = repository;

  factory TrackerController.demo() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return TrackerController(
      repository: InMemoryAttackRepository([
        AttackRecord(
          id: 1,
          startTime: today.add(const Duration(hours: 9, minutes: 30)),
          intensity: 6,
          painLocation: 'Виски',
          symptoms: const ['Светочувствительность'],
        ),
        AttackRecord(
          id: 2,
          startTime:
              today.subtract(const Duration(days: 2, hours: 5, minutes: 40)),
          endTime:
              today.subtract(const Duration(days: 2, hours: 4, minutes: 55)),
          intensity: 4,
          painLocation: 'Лоб',
          symptoms: const [],
        ),
      ]),
    );
  }

  final AttackRepository _repository;
  final List<AttackRecord> _records = [];

  TrackerStatus _status = TrackerStatus.initial;
  String? _errorMessage;
  bool _isSaving = false;
  bool _disposed = false;

  TrackerStatus get status => _status;

  /// Ошибка первой загрузки, когда показать пока нечего.
  String? get errorMessage => _errorMessage;

  /// Идёт создание, изменение или завершение приступа.
  bool get isSaving => _isSaving;

  List<AttackRecord> get records {
    final result = List<AttackRecord>.of(_records)
      ..sort((a, b) => b.startTime.compareTo(a.startTime));
    return List.unmodifiable(result);
  }

  AttackRecord? get activeAttack {
    for (final record in records) {
      if (record.isActive) return record;
    }
    return null;
  }

  AttackRecord? get latestAttack {
    return records.isEmpty ? null : records.first;
  }

  AttackRecord? byId(int id) {
    for (final record in _records) {
      if (record.id == id) return record;
    }
    return null;
  }

  /// Загружает приступы. При повторной загрузке (pull-to-refresh) уже
  /// показанные данные остаются на экране, а ошибка пробрасывается вызывающему.
  Future<void> load() async {
    final hasData = _status == TrackerStatus.ready;
    if (!hasData) {
      _status = TrackerStatus.loading;
      _errorMessage = null;
      _notify();
    }

    try {
      final records = await _repository.fetchAll();
      _records
        ..clear()
        ..addAll(records);
      _status = TrackerStatus.ready;
      _errorMessage = null;
    } catch (error) {
      if (hasData) rethrow;
      _status = TrackerStatus.failure;
      _errorMessage = describeError(error);
    } finally {
      _notify();
    }
  }

  Future<void> saveAttack({
    int? id,
    required DateTime startTime,
    required int intensity,
    required String painLocation,
    required List<String> symptoms,
  }) {
    return _save(() {
      if (id != null && byId(id) != null) {
        return _repository.update(
          id,
          startTime: startTime,
          intensity: intensity,
          painLocation: painLocation,
          symptoms: symptoms,
        );
      }
      return _repository.create(
        startTime: startTime,
        intensity: intensity,
        painLocation: painLocation,
        symptoms: symptoms,
      );
    });
  }

  Future<void> finishAttack(int id) async {
    final record = byId(id);
    if (record == null || !record.isActive) return;

    final now = DateTime.now();
    final endTime = now.isAfter(record.startTime)
        ? now
        : record.startTime.add(const Duration(minutes: 45));
    await _save(() => _repository.finish(id, endTime));
  }

  Future<void> _save(Future<AttackRecord> Function() request) async {
    if (_isSaving) return;
    _isSaving = true;
    _notify();
    try {
      _upsert(await request());
    } finally {
      _isSaving = false;
      _notify();
    }
  }

  void _upsert(AttackRecord record) {
    final index = _records.indexWhere((item) => item.id == record.id);
    if (index == -1) {
      _records.add(record);
    } else {
      _records[index] = record;
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// Текст ошибки для показа пользователю.
String describeError(Object error) {
  if (error is ApiException) return error.message;
  return 'Что-то пошло не так. Попробуйте ещё раз';
}
