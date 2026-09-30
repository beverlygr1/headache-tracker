import '../../../core/api/api_client.dart';
import 'attack_dto.dart';

class AttacksApi {
  AttacksApi(this._client);

  final ApiClient _client;

  /// Максимальный `limit`, который принимает backend.
  static const maxPageSize = 100;

  Future<AttackDto> create({
    required DateTime startTime,
    required int intensity,
    String? painType,
    String? localization,
    List<String>? medications,
    List<String>? symptoms,
  }) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/attacks',
      data: {
        'start_time': formatApiDateTime(startTime),
        'intensity': intensity,
        if (painType != null) 'pain_type': painType,
        if (localization != null) 'localization': localization,
        if (medications != null) 'medications': medications,
        if (symptoms != null) 'symptoms': symptoms,
      },
    );

    return AttackDto.fromJson(_requireBody(response.data));
  }

  Future<AttackDto> update(
    int id, {
    DateTime? startTime,
    DateTime? endTime,
    int? intensity,
    String? painType,
    String? localization,
    List<String>? symptoms,
    List<String>? reliefFactors,
  }) async {
    final response = await _client.put<Map<String, dynamic>>(
      '/attacks/$id',
      data: {
        if (startTime != null) 'start_time': formatApiDateTime(startTime),
        if (endTime != null) 'end_time': formatApiDateTime(endTime),
        if (intensity != null) 'intensity': intensity,
        if (painType != null) 'pain_type': painType,
        if (localization != null) 'localization': localization,
        if (symptoms != null) 'symptoms': symptoms,
        if (reliefFactors != null) 'relief_factors': reliefFactors,
      },
    );

    return AttackDto.fromJson(_requireBody(response.data));
  }

  Future<List<AttackDto>> getList({
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

    return (response.data ?? const <dynamic>[])
        .cast<Map<String, dynamic>>()
        .map(AttackDto.fromJson)
        .toList();
  }

  Future<AttackDto> getById(int id) async {
    final response = await _client.get<Map<String, dynamic>>('/attacks/$id');
    return AttackDto.fromJson(_requireBody(response.data));
  }

  Future<void> delete(int id) async {
    await _client.delete<void>('/attacks/$id');
  }

  Map<String, dynamic> _requireBody(Map<String, dynamic>? data) {
    if (data == null) {
      throw StateError('Пустой ответ от /attacks');
    }
    return data;
  }

  String _dateOnly(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }
}
