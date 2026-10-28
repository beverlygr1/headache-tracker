import 'package:flutter/foundation.dart';
import '../../../core/api/api_exception.dart';
import '../data/forecast_api.dart';
import '../data/forecast_data.dart';

enum ForecastStatus { initial, loading, loaded, error }

class ForecastState {
  const ForecastState(
      {this.status = ForecastStatus.initial, this.data, this.error});
  final ForecastStatus status;
  final ForecastData? data;
  final String? error;
}

class ForecastController extends ValueNotifier<ForecastState> {
  ForecastController(ForecastApi api)
      : this.withLoader(() async => ForecastData.fromJson(await api.getRisk()));
  ForecastController.withLoader(this._load) : super(const ForecastState());
  final Future<ForecastData> Function() _load;
  bool _disposed = false;
  int _request = 0;

  Future<void> refresh() async {
    if (_disposed) return;
    final request = ++_request;
    value = const ForecastState(status: ForecastStatus.loading);
    try {
      final data = await _load();
      if (_disposed || request != _request) return;
      value = ForecastState(status: ForecastStatus.loaded, data: data);
    } catch (error) {
      if (_disposed || request != _request) return;
      value = ForecastState(
          status: ForecastStatus.error,
          error: error is ApiException && error.statusCode == 503
              ? 'Прогноз временно недоступен. Попробуйте позже.'
              : 'Не удалось загрузить прогноз. Проверьте соединение.');
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
