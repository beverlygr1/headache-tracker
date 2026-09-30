/// Приступ в формате API (`AttackResponse` backend).
class AttackDto {
  const AttackDto({
    required this.id,
    required this.startTime,
    required this.intensity,
    this.endTime,
    this.painType,
    this.localization,
    this.medications = const [],
    this.symptoms = const [],
    this.reliefFactors = const [],
  });

  factory AttackDto.fromJson(Map<String, dynamic> json) {
    final endTime = json['end_time'];
    return AttackDto(
      id: json['id'] as int,
      startTime: parseApiDateTime(json['start_time'] as String),
      endTime: endTime is String ? parseApiDateTime(endTime) : null,
      intensity: json['intensity'] as int,
      painType: json['pain_type'] as String?,
      localization: json['localization'] as String?,
      medications: _stringList(json['medications']),
      symptoms: _stringList(json['symptoms']),
      reliefFactors: _stringList(json['relief_factors']),
    );
  }

  final int id;

  /// Время в локальной зоне устройства.
  final DateTime startTime;
  final DateTime? endTime;
  final int intensity;
  final String? painType;
  final String? localization;
  final List<String> medications;
  final List<String> symptoms;
  final List<String> reliefFactors;

  static List<String> _stringList(dynamic value) {
    if (value is! List) return const [];
    return List.unmodifiable(value.whereType<String>());
  }
}

/// Backend хранит время в UTC. Строка без смещения тоже считается UTC.
DateTime parseApiDateTime(String value) {
  final hasOffset =
      value.endsWith('Z') || RegExp(r'[+-]\d{2}:?\d{2}$').hasMatch(value);
  return DateTime.parse(hasOffset ? value : '${value}Z').toLocal();
}

String formatApiDateTime(DateTime value) => value.toUtc().toIso8601String();
