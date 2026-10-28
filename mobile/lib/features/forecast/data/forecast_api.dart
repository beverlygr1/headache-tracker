import '../../../core/api/api_client.dart';
import 'forecast_dto.dart';

class ForecastApi {
  ForecastApi(this._client);

  final ApiClient _client;

  /// Прогноз на следующий день. Путь: `<API_BASE_URL>/forecast/risk`.
  Future<ForecastDto> getRisk() async {
    final response = await _client.get<Map<String, dynamic>>('/forecast/risk');
    final data = response.data;
    if (data == null) {
      throw StateError('Пустой ответ от /forecast/risk');
    }
    return ForecastDto.fromJson(data);
  }
}
