class AttackRecord {
  const AttackRecord({
    required this.id,
    required this.startTime,
    required this.intensity,
    required this.painLocation,
    required this.symptoms,
    this.painType,
    this.medications = const [],
    this.reliefFactors = const [],
    this.endTime,
  });

  final int id;
  final DateTime startTime;
  final DateTime? endTime;
  final int intensity;
  final String painLocation;
  final List<String> symptoms;
  final String? painType;
  final List<String> medications;
  final List<String> reliefFactors;

  bool get isActive => endTime == null;

  int? get durationMinutes {
    final end = endTime;
    if (end == null) return null;
    return end.difference(startTime).inMinutes;
  }

  AttackRecord copyWith({
    DateTime? startTime,
    DateTime? endTime,
    bool clearEndTime = false,
    int? intensity,
    String? painLocation,
    List<String>? symptoms,
    String? painType,
    bool clearPainType = false,
    List<String>? medications,
    List<String>? reliefFactors,
  }) {
    return AttackRecord(
      id: id,
      startTime: startTime ?? this.startTime,
      endTime: clearEndTime ? null : endTime ?? this.endTime,
      intensity: intensity ?? this.intensity,
      painLocation: painLocation ?? this.painLocation,
      symptoms: List.unmodifiable(symptoms ?? this.symptoms),
      painType: clearPainType ? null : painType ?? this.painType,
      medications: List.unmodifiable(medications ?? this.medications),
      reliefFactors: List.unmodifiable(reliefFactors ?? this.reliefFactors),
    );
  }
}
