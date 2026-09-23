import '../../../core/api/api_client.dart';


class ForecastApi {
  ForecastApi(this._client);

  final ApiClient _client;

  Future<Map<String, dynamic>> getRisk({
    double? latitude,
    double? longitude,
  }) async {
    final response = await _client.get<Map<String, dynamic>>(
      '/forecast/risk',
      queryParameters: {
        if (latitude != null) 'lat': latitude,
        if (longitude != null) 'lon': longitude,
      },
    );

    return response.data ?? <String, dynamic>{};
  }
}
