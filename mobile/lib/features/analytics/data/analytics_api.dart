import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../core/api/api_client.dart';


class AnalyticsApi {
  AnalyticsApi(this._client);

  final ApiClient _client;

  Future<Map<String, dynamic>> getSummary({
    String period = 'month',
  }) async {
    final response = await _client.get<Map<String, dynamic>>(
      '/analytics/summary',
      queryParameters: {
        'period': period,
      },
    );

    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> getTriggers() async {
    final response = await _client.get<Map<String, dynamic>>(
      '/analytics/triggers',
    );

    return response.data ?? <String, dynamic>{};
  }

  Future<Uint8List> export({
    required String format,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    final response = await _client.get<List<int>>(
      '/analytics/export',
      queryParameters: {
        'format': format,
        if (fromDate != null) 'from_date': _dateOnly(fromDate),
        if (toDate != null) 'to_date': _dateOnly(toDate),
      },
      options: Options(responseType: ResponseType.bytes),
    );

    return Uint8List.fromList(response.data ?? const <int>[]);
  }

  String _dateOnly(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }
}
