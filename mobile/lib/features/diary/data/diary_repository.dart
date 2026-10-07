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
  Future<List<DailyEntry>> fetchAll() async =>
      (await _api.getList()).map(DailyEntry.fromJson).toList();

  @override
  Future<DailyEntry?> fetchByDate(DateTime date) async {
    try {
      return DailyEntry.fromJson(await _api.getByDate(date));
    } on ApiException catch (error) {
      if (error.statusCode == 404) return null;
      rethrow;
    }
  }

  @override
  Future<DailyEntry> save(DailyEntry entry) async => DailyEntry.fromJson(
        await _api.upsert(entry.date,
            sleepHours: entry.sleepHours,
            stressLevel: entry.stressLevel,
            waterMl: entry.waterMl,
            replaceDailyFields: true),
      );
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
