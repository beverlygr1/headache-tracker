class ForecastData {
  const ForecastData(
      {required this.isReady,
      required this.predictionDate,
      required this.timeZone,
      this.probability,
      this.message,
      this.missingFields = const [],
      this.factors = const [],
      this.recommendations = const []});
  final bool isReady;
  final DateTime predictionDate;
  final String timeZone;
  final double? probability;
  final String? message;
  final List<String> missingFields;
  final List<String> factors;
  final List<String> recommendations;

  factory ForecastData.fromJson(Map<String, dynamic> json) {
    final status = json['status'];
    final probability = (json['probability'] as num?)?.toDouble();
    if (status != 'ready' && status != 'insufficient_data' ||
        status == 'ready' &&
            (probability == null ||
                !probability.isFinite ||
                probability < 0 ||
                probability > 1)) {
      throw const FormatException('Invalid forecast response');
    }
    List<String> strings(String key) =>
        (json[key] as List? ?? const []).cast<String>();
    return ForecastData(
        isReady: status == 'ready',
        predictionDate: DateTime.parse(json['prediction_date'] as String),
        timeZone: json['time_zone'] as String,
        probability: probability,
        message: json['message'] as String?,
        missingFields: strings('missing_fields'),
        factors: strings('factors'),
        recommendations: strings('recommendations'));
  }

  String get missingDescription => missingFields
      .map((field) => switch (field) {
            'sleep_hours' => 'длительность сна',
            'stress_level' => 'уровень стресса',
            'caffeine_intake' => 'количество кофеина',
            _ => field,
          })
      .join(', ');
}
