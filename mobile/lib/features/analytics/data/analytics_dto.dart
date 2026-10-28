class AnalyticsDto {
  const AnalyticsDto({
    required this.totalAttacks,
    required this.averageIntensity,
    required this.averageDurationMinutes,
    this.completedAttacks = 0,
  });

  final int totalAttacks;
  final double averageIntensity;
  final double averageDurationMinutes;
  final int completedAttacks;

  factory AnalyticsDto.fromJson(Map<String, dynamic> json) => AnalyticsDto(
        totalAttacks: (json['total_attacks'] as num).toInt(),
        averageIntensity: (json['avg_intensity'] as num).toDouble(),
        averageDurationMinutes:
            (json['avg_duration_minutes'] as num).toDouble(),
        completedAttacks: (json['completed_attacks'] as num?)?.toInt() ?? 0,
      );

  String get formattedDuration => formatDuration(averageDurationMinutes);

  static String formatDuration(double minutes) {
    if (minutes > 0 && minutes < 1) return '<1 мин';
    final rounded = minutes.round();
    if (rounded < 60) return '$rounded мин';
    final remainder = rounded % 60;
    return '${rounded ~/ 60} ч${remainder == 0 ? '' : ' $remainder мин'}';
  }
}

class AnalyticsPoint {
  const AnalyticsPoint(
      {required this.date,
      required this.totalAttacks,
      required this.averageIntensity,
      required this.averageDurationMinutes,
      required this.completedAttacks});

  final DateTime date;
  final int totalAttacks;
  final double? averageIntensity;
  final double? averageDurationMinutes;
  final int completedAttacks;

  factory AnalyticsPoint.fromJson(Map<String, dynamic> json) => AnalyticsPoint(
        date: DateTime.parse(json['date'] as String),
        totalAttacks: (json['total_attacks'] as num).toInt(),
        averageIntensity: (json['avg_intensity'] as num?)?.toDouble(),
        averageDurationMinutes:
            (json['avg_duration_minutes'] as num?)?.toDouble(),
        completedAttacks: (json['completed_attacks'] as num?)?.toInt() ?? 0,
      );
}

class AnalyticsSeries {
  const AnalyticsSeries({required this.points, required this.timeZone});
  final List<AnalyticsPoint> points;
  final String timeZone;

  factory AnalyticsSeries.fromJson(Map<String, dynamic> json) =>
      AnalyticsSeries(
        points: (json['points'] as List)
            .map((point) => AnalyticsPoint.fromJson(
                Map<String, dynamic>.from(point as Map)))
            .toList(),
        timeZone: json['time_zone'] as String,
      );
}
