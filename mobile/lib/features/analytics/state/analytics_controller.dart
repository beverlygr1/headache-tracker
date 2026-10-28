import 'package:flutter/foundation.dart';
import '../data/analytics_api.dart';
import '../data/analytics_dto.dart';

enum AnalyticsStatus { initial, loading, success, empty, error }

class AnalyticsState {
  const AnalyticsState(
      {this.status = AnalyticsStatus.initial,
      this.data,
      this.series,
      this.selectedPeriod = 'month',
      this.errorMessage});
  final AnalyticsStatus status;
  final AnalyticsDto? data;
  final AnalyticsSeries? series;
  final String selectedPeriod;
  final String? errorMessage;
}

class AnalyticsController extends ValueNotifier<AnalyticsState> {
  AnalyticsController(this.api, {this.timeZone = 'UTC'})
      : super(const AnalyticsState());
  final AnalyticsApi api;
  final String timeZone;
  int _request = 0;
  bool _disposed = false;

  Future<void> loadAnalytics([String? period]) async {
    if (_disposed) return;
    final request = ++_request;
    final target = period ?? value.selectedPeriod;
    value =
        AnalyticsState(status: AnalyticsStatus.loading, selectedPeriod: target);
    try {
      final responses = await Future.wait([
        api.getSummary(period: target, timeZone: timeZone),
        api.getIntensity(period: target, timeZone: timeZone),
      ]);
      if (_disposed || request != _request) return;
      final data = AnalyticsDto.fromJson(responses[0]);
      value = AnalyticsState(
        status: data.totalAttacks == 0
            ? AnalyticsStatus.empty
            : AnalyticsStatus.success,
        selectedPeriod: target,
        data: data,
        series: AnalyticsSeries.fromJson(responses[1]),
      );
    } catch (_) {
      if (_disposed || request != _request) return;
      value = AnalyticsState(
          status: AnalyticsStatus.error,
          selectedPeriod: target,
          errorMessage:
              'Не удалось загрузить статистику. Проверьте соединение.');
    }
  }

  void changePeriod(String period) {
    if (period != value.selectedPeriod ||
        value.status == AnalyticsStatus.error) {
      loadAnalytics(period);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
