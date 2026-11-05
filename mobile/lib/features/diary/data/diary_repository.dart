import '../../../core/api/api_exception.dart';
import 'daily_entry.dart';
import 'diary_api.dart';

abstract interface class DiaryRepository {
  Future<List<DailyEntry>> fetchAll();
  Future<DailyEntry?> fetchByDate(DateTime date);
  Future<DailyEntry> save(DailyEntry entry);
}

class ApiDiaryRepository implements DiaryRepository {
  ApiDiaryRepository(this._api);
  final DiaryApi _api;

  @override
  Future<List<DailyEntry>> fetchAll() async {
    final records = _api.workspace == null
        ? await _api.getList()
        : await _api.workspace!.loadRecords('diary', _api.getList);
    return records.map(DailyEntry.fromJson).toList();
  }

  @override
  Future<DailyEntry?> fetchByDate(DateTime date) async {
    final workspace = _api.workspace;
    final key = DailyEntry(date: date).toJson()['date'] as String;
    final cached = await workspace?.readRecord('diary', key);
    if (cached?['pending_sync'] == true) return DailyEntry.fromJson(cached!);
    try {
      final record = await _api.getByDate(date);
      await workspace?.cacheRecord('diary', record);
      return DailyEntry.fromJson(record);
    } on ApiException catch (error) {
      if (error.statusCode == 404) return null;
      if (workspace != null && error.isNetworkError) {
        workspace.markOffline();
        return cached == null ? null : DailyEntry.fromJson(cached);
      }
      rethrow;
    }
  }

  @override
  Future<DailyEntry> save(DailyEntry entry) async {
    final workspace = _api.workspace;
    if (workspace != null) {
      final body = entry.toJson()..remove('pending_sync');
      final date = body.remove('date') as String;
      return DailyEntry.fromJson(
          (await workspace.write('diary', 'PUT', body, entity: date))!);
    }
    return DailyEntry.fromJson(
      await _api.upsert(entry.date,
          headachePresent: entry.headachePresent,
          sleepHours: entry.sleepHours,
          sleepQuality: entry.sleepQuality,
          stressLevel: entry.stressLevel,
          caffeineIntake: entry.caffeineIntake,
          waterMl: entry.waterMl,
          replaceDailyFields: true),
    );
  }
}

class InMemoryDiaryRepository implements DiaryRepository {
  final Map<String, DailyEntry> _entries = {};

  String _key(DateTime date) => '${date.year}-${date.month}-${date.day}';

  @override
  Future<List<DailyEntry>> fetchAll() async => _entries.values.toList();

  @override
  Future<DailyEntry?> fetchByDate(DateTime date) async => _entries[_key(date)];

  @override
  Future<DailyEntry> save(DailyEntry entry) async {
    _entries[_key(entry.date)] = entry;
    return entry;
  }
}
