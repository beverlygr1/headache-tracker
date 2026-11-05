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
    this.medicationEffects = const {},
    this.pendingSync = false,
  });

  final Map<String, String> medicationEffects;
  final bool pendingSync;
  final int id;
  final DateTime startTime;
  final DateTime? endTime;
  final int intensity;
  final String painLocation;
  final List<String> symptoms;
  final String? painType;
  final List<String> medications;
  final List<String> reliefFactors;

  Map<String, dynamic> toJson() => {
        'id': id,
        'start_time': startTime.toUtc().toIso8601String(),
        'end_time': endTime?.toUtc().toIso8601String(),
        'intensity': intensity,
        'localization': painLocation,
        'symptoms': symptoms,
        'pain_type': painType,
        'medications': medications,
        'relief_factors': reliefFactors,
        'medication_effects': medicationEffects,
        'pending_sync': pendingSync,
      };

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
    Map<String, String>? medicationEffects,
  }) {
    return AttackRecord(
      id: id,
      pendingSync: pendingSync,
      medicationEffects:
          Map.unmodifiable(medicationEffects ?? this.medicationEffects),
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
