/// Ответ `GET /forecast/risk` (`RiskForecastResponse` backend).
///
/// Клиенту нужны только `status` и `risk_level`; остальные поля ответа
/// игнорируются.
class ForecastDto {
  const ForecastDto({required this.status, this.riskLevel});

  factory ForecastDto.fromJson(Map<String, dynamic> json) {
    return ForecastDto(
      status: json['status'] as String,
      riskLevel: json['risk_level'] as String?,
    );
  }

  /// `ready` или `insufficient_data`.
  final String status;

  /// Округлённый процент строкой. `null`, если прогноз не рассчитан.
  final String? riskLevel;

  bool get isReady => status == 'ready' && riskLevel != null;
}
