import '../../attacks/data/attack_dto.dart';
import '../../attacks/data/attacks_api.dart';
import '../domain/attack_record.dart';

/// Источник данных о приступах для [TrackerController].
abstract interface class AttackRepository {
  Future<List<AttackRecord>> fetchAll();

  Future<AttackRecord> create({
    required DateTime startTime,
    required int intensity,
    required String painLocation,
    required List<String> symptoms,
    String? painType,
    List<String>? medications,
    List<String>? reliefFactors,
  });

  Future<AttackRecord> update(
    int id, {
    required DateTime startTime,
    required int intensity,
    required String painLocation,
    required List<String> symptoms,
    String? painType,
    bool clearPainType = false,
    List<String>? medications,
    List<String>? reliefFactors,
  });

  Future<AttackRecord> finish(int id, DateTime endTime);

  Future<void> delete(int id);
}

/// Приступы из FastAPI backend.
class ApiAttackRepository implements AttackRepository {
  ApiAttackRepository(this._api);

  final AttacksApi _api;

  @override
  Future<List<AttackRecord>> fetchAll() async {
    final result = <AttackRecord>[];
    var offset = 0;
    while (true) {
      final page = await _api.getList(
        limit: AttacksApi.maxPageSize,
        offset: offset,
      );
      result.addAll(page.map(_toRecord));
      if (page.length < AttacksApi.maxPageSize) return result;
      offset += page.length;
    }
  }

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
    final dto = await _api.create(
      startTime: startTime,
      intensity: intensity,
      localization: painLocation,
      symptoms: symptoms,
      painType: painType,
      medications: medications,
      reliefFactors: reliefFactors,
    );
    return _toRecord(dto);
  }

  @override
  Future<AttackRecord> update(
    int id, {
    required DateTime startTime,
    required int intensity,
    required String painLocation,
    required List<String> symptoms,
    String? painType,
    bool clearPainType = false,
    List<String>? medications,
    List<String>? reliefFactors,
  }) async {
    final dto = await _api.update(
      id,
      startTime: startTime,
      intensity: intensity,
      localization: painLocation,
      symptoms: symptoms,
      painType: painType,
      includePainType: clearPainType || painType != null,
      medications: medications,
      reliefFactors: reliefFactors,
    );
    return _toRecord(dto);
  }

  @override
  Future<AttackRecord> finish(int id, DateTime endTime) async {
    return _toRecord(await _api.update(id, endTime: endTime));
  }

  @override
  Future<void> delete(int id) => _api.delete(id);

  static AttackRecord _toRecord(AttackDto dto) {
    return AttackRecord(
      id: dto.id,
      startTime: dto.startTime,
      endTime: dto.endTime,
      intensity: dto.intensity,
      painLocation: dto.localization ?? '',
      symptoms: dto.symptoms,
      painType: dto.painType,
      medications: dto.medications,
      reliefFactors: dto.reliefFactors,
    );
  }
}

/// Локальные данные без сети: демо-режим и тесты.
class InMemoryAttackRepository implements AttackRepository {
  InMemoryAttackRepository([List<AttackRecord> records = const []])
      : _records = List.of(records),
        _nextId = records.fold<int>(0, (max, r) => r.id > max ? r.id : max) + 1;

  final List<AttackRecord> _records;
  int _nextId;

  @override
  Future<List<AttackRecord>> fetchAll() async => List.of(_records);

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
    final record = AttackRecord(
      id: _nextId++,
      startTime: startTime,
      intensity: intensity,
      painLocation: painLocation,
      symptoms: List.unmodifiable(symptoms),
      painType: painType,
      medications: List.unmodifiable(medications ?? const []),
      reliefFactors: List.unmodifiable(reliefFactors ?? const []),
    );
    _records.add(record);
    return record;
  }

  @override
  Future<AttackRecord> update(
    int id, {
    required DateTime startTime,
    required int intensity,
    required String painLocation,
    required List<String> symptoms,
    String? painType,
    bool clearPainType = false,
    List<String>? medications,
    List<String>? reliefFactors,
  }) async {
    return _replace(
      id,
      (record) => record.copyWith(
        startTime: startTime,
        intensity: intensity,
        painLocation: painLocation,
        symptoms: symptoms,
        painType: painType,
        clearPainType: clearPainType,
        medications: medications,
        reliefFactors: reliefFactors,
      ),
    );
  }

  @override
  Future<AttackRecord> finish(int id, DateTime endTime) async {
    return _replace(id, (record) => record.copyWith(endTime: endTime));
  }

  @override
  Future<void> delete(int id) async {
    final index = _records.indexWhere((record) => record.id == id);
    if (index == -1) throw StateError('Приступ $id не найден');
    _records.removeAt(index);
  }

  AttackRecord _replace(int id, AttackRecord Function(AttackRecord) change) {
    final index = _records.indexWhere((record) => record.id == id);
    if (index == -1) throw StateError('Приступ $id не найден');
    return _records[index] = change(_records[index]);
  }
}
