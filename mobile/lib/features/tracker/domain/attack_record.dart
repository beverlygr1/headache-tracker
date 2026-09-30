class AttackRecord {
  const AttackRecord({
    required this.id,
    required this.startTime,
    required this.intensity,
    required this.painLocation,
    required this.symptoms,
    this.endTime,
  });

  final int id;
  final DateTime startTime;
  final DateTime? endTime;
  final int intensity;
  final String painLocation;
  final List<String> symptoms;

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
  }) {
    return AttackRecord(
      id: id,
      startTime: startTime ?? this.startTime,
      endTime: clearEndTime ? null : endTime ?? this.endTime,
      intensity: intensity ?? this.intensity,
      painLocation: painLocation ?? this.painLocation,
      symptoms: List.unmodifiable(symptoms ?? this.symptoms),
    );
  }
}
