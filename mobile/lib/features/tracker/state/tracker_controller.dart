import 'package:flutter/foundation.dart';

import '../domain/attack_record.dart';

class TrackerController extends ChangeNotifier {
  TrackerController({required List<AttackRecord> records})
      : _records = List.of(records);

  factory TrackerController.demo() {
    return TrackerController(
      records: [
        AttackRecord(
          id: 1,
          startTime: DateTime(2026, 9, 29, 9, 30),
          intensity: 6,
          painLocation: 'Виски',
          symptoms: const ['Светочувствительность'],
        ),
        AttackRecord(
          id: 2,
          startTime: DateTime(2026, 9, 27, 18, 20),
          endTime: DateTime(2026, 9, 27, 19, 5),
          intensity: 4,
          painLocation: 'Лоб',
          symptoms: const [],
        ),
      ],
    );
  }

  final List<AttackRecord> _records;
  int _nextId = 3;

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

  void saveAttack({
    int? id,
    required DateTime startTime,
    required int intensity,
    required String painLocation,
    required List<String> symptoms,
  }) {
    if (id != null) {
      final index = _records.indexWhere((record) => record.id == id);
      if (index != -1) {
        _records[index] = _records[index].copyWith(
          startTime: startTime,
          intensity: intensity,
          painLocation: painLocation,
          symptoms: symptoms,
        );
        notifyListeners();
        return;
      }
    }

    _records.add(
      AttackRecord(
        id: _nextId++,
        startTime: startTime,
        intensity: intensity,
        painLocation: painLocation,
        symptoms: List.unmodifiable(symptoms),
      ),
    );
    notifyListeners();
  }

  void finishAttack(int id) {
    final index = _records.indexWhere((record) => record.id == id);
    if (index == -1 || !_records[index].isActive) return;

    final record = _records[index];
    final now = DateTime.now();
    final endTime = now.isAfter(record.startTime)
        ? now
        : record.startTime.add(const Duration(minutes: 45));
    _records[index] = record.copyWith(endTime: endTime);
    notifyListeners();
  }
}
