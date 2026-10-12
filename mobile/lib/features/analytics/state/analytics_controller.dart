import 'package:flutter/foundation.dart';
import '../data/analytics_api.dart';
import '../data/analytics_dto.dart';

enum AnalyticsStatus { initial, loading, success, empty, error }

class AnalyticsState {
  final AnalyticsStatus status;
  final AnalyticsDto? data;
  final String selectedPeriod;
  final String? errorMessage;

  const AnalyticsState({
    this.status = AnalyticsStatus.initial,
    this.data,
    this.selectedPeriod = 'month',
    this.errorMessage,
  });

  AnalyticsState copyWith({
    AnalyticsStatus? status,
    AnalyticsDto? data,
    String? selectedPeriod,
    String? errorMessage,
  }) {
    return AnalyticsState(
      status: status ?? this.status,
      data: data ?? this.data,
      selectedPeriod: selectedPeriod ?? this.selectedPeriod,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class AnalyticsController extends ValueNotifier<AnalyticsState> {
  final AnalyticsApi api;

  AnalyticsController(this.api) : super(const AnalyticsState());

  Future<void> loadAnalytics([String? period]) async {
    final targetPeriod = period ?? value.selectedPeriod;

    value = value.copyWith(
      status: AnalyticsStatus.loading,
      selectedPeriod: targetPeriod,
      errorMessage: null,
    );

    try {
      final rawData = await api.getSummary(period: targetPeriod);
      final result = AnalyticsDto.fromJson(rawData);

      if (result.totalAttacks == 0) {
        value = value.copyWith(
          status: AnalyticsStatus.empty,
          data: result,
        );
      } else {
        value = value.copyWith(
          status: AnalyticsStatus.success,
          data: result,
        );
      }
    } catch (e) {
      value = value.copyWith(
        status: AnalyticsStatus.error,
        errorMessage: 'Не удалось загрузить статистику. Проверьте соединение.',
      );
    }
  }

  void changePeriod(String newPeriod) {
    if (value.selectedPeriod == newPeriod && value.status != AnalyticsStatus.error) {
      return;
    }
    loadAnalytics(newPeriod);
  }
}