class DailyEntry {
  const DailyEntry({
    required this.date,
    this.headachePresent,
    this.sleepHours,
    this.sleepQuality,
    this.waterMl,
    this.caffeineIntake,
    this.stressLevel,
    this.physicalFatigue,
    this.pendingSync = false,
  });

  factory DailyEntry.fromJson(Map<String, dynamic> json) => DailyEntry(
        pendingSync: json['pending_sync'] == true,
        date: DateTime.parse(json['date'] as String),
        headachePresent: json['headache_present'] as bool?,
        sleepHours: (json['sleep_hours'] as num?)?.toDouble(),
        sleepQuality: json['sleep_quality'] as int?,
        waterMl: json['water_ml'] as int?,
        caffeineIntake: json['caffeine_intake'] as int?,
        stressLevel: json['stress_level'] as int?,
        physicalFatigue: json['physical_fatigue'] as bool?,
      );

  final bool pendingSync;
  final DateTime date;
  final bool? headachePresent;
  final double? sleepHours;
  final int? sleepQuality;
  final int? waterMl;
  final int? caffeineIntake;
  final int? stressLevel;
  final bool? physicalFatigue;

  Map<String, dynamic> toJson() => {
        'date':
            '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
        'headache_present': headachePresent,
        'sleep_hours': sleepHours,
        'sleep_quality': sleepQuality,
        'water_ml': waterMl,
        'caffeine_intake': caffeineIntake,
        'stress_level': stressLevel,
        'physical_fatigue': physicalFatigue,
        'pending_sync': pendingSync,
      };

  String get summary {
    final parts = <String>[
      if (headachePresent != null) headachePresent! ? 'Боль была' : 'Без боли',
      if (sleepHours != null) 'Сон ${formatHours(sleepHours!)} ч',
      if (sleepQuality != null) 'Качество сна $sleepQuality/10',
      if (caffeineIntake != null) 'Кофеин $caffeineIntake мг',
      if (waterMl != null) 'Вода $waterMl мл',
      if (stressLevel != null) 'Стресс $stressLevel/10',
      if (physicalFatigue != null)
        physicalFatigue!
            ? 'Была физическая усталость'
            : 'Без физической усталости',
    ];
    return parts.isEmpty ? 'Запись самочувствия' : parts.join(' · ');
  }

  static String formatHours(double hours) => (hours == hours.roundToDouble()
          ? hours.toInt().toString()
          : hours.toString())
      .replaceAll('.', ',');
}
