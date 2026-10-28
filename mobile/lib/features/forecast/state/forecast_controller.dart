import 'package:flutter/foundation.dart';

import '../data/forecast_api.dart';

/// Хранит `risk_level` готового прогноза; `null` — прогноза нет.
///
/// Любая ошибка запроса (сеть, 503, неожиданный ответ) молча оставляет
/// текущее значение: виджет на экране «Сегодня» не меняется.
class ForecastController extends ValueNotifier<String?> {
  ForecastController(this._api) : super(null);

  final ForecastApi _api;

  Future<void> load() async {
    try {
      final dto = await _api.getRisk();
      value = dto.isReady ? dto.riskLevel : null;
    } catch (_) {
      // Ошибки намеренно не показываются.
    }
  }
}
