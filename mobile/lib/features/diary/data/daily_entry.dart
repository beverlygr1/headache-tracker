class DailyEntry {
  const DailyEntry({
    required this.date,
    this.headachePresent,
    this.sleepHours,
    this.sleepQuality,
    this.waterMl,
    this.caffeineIntake,
    this.stressLevel,
  });

  factory DailyEntry.fromJson(Map<String, dynamic> json) => DailyEntry(
        date: DateTime.parse(json['date'] as String),
        headachePresent: json['headache_present'] as bool?,
        sleepHours: (json['sleep_hours'] as num?)?.toDouble(),
        sleepQuality: json['sleep_quality'] as int?,
        waterMl: json['water_ml'] as int?,
        caffeineIntake: json['caffeine_intake'] as int?,
        stressLevel: json['stress_level'] as int?,
      );

  final DateTime date;
  final bool? headachePresent;
  final double? sleepHours;
  final int? sleepQuality;
  final int? waterMl;
  final int? caffeineIntake;
  final int? stressLevel;

  String get summary {
    final parts = <String>[
      if (headachePresent != null) headachePresent! ? 'Боль была' : 'Без боли',
      if (sleepHours != null) 'Сон ${formatHours(sleepHours!)} ч',
      if (sleepQuality != null) 'Качество сна $sleepQuality/10',
      if (caffeineIntake != null) 'Кофеин $caffeineIntake мг',
      if (waterMl != null) 'Вода $waterMl мл',
      if (stressLevel != null) 'Стресс $stressLevel/10',
    ];
    return parts.isEmpty ? 'Запись самочувствия' : parts.join(' · ');
  }

  static String formatHours(double hours) => (hours == hours.roundToDouble()
          ? hours.toInt().toString()
          : hours.toString())
      .replaceAll('.', ',');
}
