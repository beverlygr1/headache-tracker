class DailyEntry {
  const DailyEntry(
      {required this.date, this.sleepHours, this.waterMl, this.stressLevel});

  factory DailyEntry.fromJson(Map<String, dynamic> json) => DailyEntry(
        date: DateTime.parse(json['date'] as String),
        sleepHours: (json['sleep_hours'] as num?)?.toDouble(),
        waterMl: json['water_ml'] as int?,
        stressLevel: json['stress_level'] as int?,
      );

  final DateTime date;
  final double? sleepHours;
  final int? waterMl;
  final int? stressLevel;

  String get summary {
    final parts = <String>[
      if (sleepHours != null) 'Сон ${formatHours(sleepHours!)} ч',
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
