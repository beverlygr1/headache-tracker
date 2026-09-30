import '../../../core/api/api_client.dart';

class AttacksApi {
  AttacksApi(this._client);

  final ApiClient _client;

  Future<Map<String, dynamic>> create({
    required DateTime startTime,
    required int intensity,
    String? painType,
    String? localization,
    List<String>? medications,
  }) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/attacks',
      data: {
        'start_time': startTime.toUtc().toIso8601String(),
        'intensity': intensity,
        if (painType != null) 'pain_type': painType,
        if (localization != null) 'localization': localization,
        if (medications != null) 'medications': medications,
      },
    );

    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> update(
    int id, {
    DateTime? endTime,
    int? intensity,
    List<String>? symptoms,
    List<String>? reliefFactors,
  }) async {
    final response = await _client.put<Map<String, dynamic>>(
      '/attacks/$id',
      data: {
        if (endTime != null) 'end_time': endTime.toUtc().toIso8601String(),
        if (intensity != null) 'intensity': intensity,
        if (symptoms != null) 'symptoms': symptoms,
        if (reliefFactors != null) 'relief_factors': reliefFactors,
      },
    );

    return response.data ?? <String, dynamic>{};
  }

  Future<List<Map<String, dynamic>>> getList({
    DateTime? fromDate,
    DateTime? toDate,
    int limit = 20,
    int offset = 0,
  }) async {
    final response = await _client.get<List<dynamic>>(
      '/attacks',
      queryParameters: {
        if (fromDate != null) 'from_date': _dateOnly(fromDate),
        if (toDate != null) 'to_date': _dateOnly(toDate),
        'limit': limit,
        'offset': offset,
      },
    );

    return (response.data ?? const <dynamic>[]).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> getById(int id) async {
    final response = await _client.get<Map<String, dynamic>>('/attacks/$id');
    return response.data ?? <String, dynamic>{};
  }

  Future<void> delete(int id) async {
    await _client.delete<void>('/attacks/$id');
  }

  String _dateOnly(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }
}
