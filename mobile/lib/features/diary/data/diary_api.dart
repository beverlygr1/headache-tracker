import '../../../core/api/api_client.dart';

class DiaryApi {
  DiaryApi(this._client);

  final ApiClient _client;

  Future<Map<String, dynamic>> upsert(
    DateTime date, {
    double? sleepHours,
    int? sleepQuality,
    int? stressLevel,
    int? caffeineIntake,
    int? waterMl,
    double? latitude,
    double? longitude,
    bool replaceDailyFields = false,
  }) async {
    final response = await _client.put<Map<String, dynamic>>(
      '/diary/${_dateOnly(date)}',
      data: {
        if (sleepHours != null || replaceDailyFields) 'sleep_hours': sleepHours,
        if (sleepQuality != null) 'sleep_quality': sleepQuality,
        if (stressLevel != null || replaceDailyFields)
          'stress_level': stressLevel,
        if (caffeineIntake != null) 'caffeine_intake': caffeineIntake,
        if (waterMl != null || replaceDailyFields) 'water_ml': waterMl,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
      },
    );

    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> getByDate(DateTime date) async {
    final response = await _client.get<Map<String, dynamic>>(
      '/diary/${_dateOnly(date)}',
    );

    return response.data ?? <String, dynamic>{};
  }

  Future<List<Map<String, dynamic>>> getList({
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    final response = await _client.get<List<dynamic>>(
      '/diary',
      queryParameters: {
        if (fromDate != null) 'from_date': _dateOnly(fromDate),
        if (toDate != null) 'to_date': _dateOnly(toDate),
      },
    );

    return (response.data ?? const <dynamic>[]).cast<Map<String, dynamic>>();
  }

  String _dateOnly(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }
}
