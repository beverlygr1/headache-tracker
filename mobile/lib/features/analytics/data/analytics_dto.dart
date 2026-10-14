class AnalyticsDto {
  final int totalAttacks;
  final double averageIntensity;
  final int averageDurationMinutes;

  const AnalyticsDto({
    required this.totalAttacks,
    required this.averageIntensity,
    required this.averageDurationMinutes,
  });

  factory AnalyticsDto.fromJson(Map<String, dynamic> json) {
    return AnalyticsDto(
      totalAttacks: (json['total_attacks'] as num?)?.toInt() ?? 0,
      averageIntensity: (json['average_intensity'] as num?)?.toDouble() ?? 0.0,
      averageDurationMinutes: (json['average_duration_minutes'] as num?)?.toInt() ?? 0,
    );
  }

  String get formattedDuration {
    if (averageDurationMinutes <= 0) return '0 мин';
    final hours = averageDurationMinutes ~/ 60;
    final minutes = averageDurationMinutes % 60;
    if (hours > 0) {
      return '$hours ч $minutes мин';
    }
    return '$minutes мин';
  }
}