import '../../../core/api/api_client.dart';
import 'forecast_data.dart';

class ForecastApi {
  ForecastApi(this._client);

  final ApiClient _client;

  Future<ForecastData> getRisk({
    double? latitude,
    double? longitude,
  }) async {
    final response = await _client.get<Map<String, dynamic>>(
      '/forecast/risk',
      queryParameters: {
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
      },
    );

    final data = response.data;
    if (data == null) {
      throw StateError('Пустой ответ от /forecast/risk');
    }
    return ForecastData.fromJson(data);
  }
}
