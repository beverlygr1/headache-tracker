import 'attack_record.dart';

/// Values shared by the editor, pain map and review before any API write.
class AttackDraft {
  AttackDraft({
    this.id,
    required this.startTime,
    required this.intensity,
    required Iterable<String> painZones,
    required Iterable<String> symptoms,
    this.painType,
    Iterable<String> medications = const [],
    Iterable<String> reliefFactors = const [],
  })  : painZones = List.unmodifiable(painZones),
        symptoms = List.unmodifiable(symptoms),
        medications = List.unmodifiable(medications),
        reliefFactors = List.unmodifiable(reliefFactors);

  final int? id;
  final DateTime startTime;
  final int intensity;
  final List<String> painZones;
  final List<String> symptoms;
  final String? painType;
  final List<String> medications;
  final List<String> reliefFactors;

  // The existing backend accepts a single localization string (up to 120
  // characters). Multiple zones stay compatible with that API contract.
  String get painLocation => painZones.join(', ');

  static List<String> zonesFromRecord(AttackRecord record) =>
      record.painLocation
          .split(', ')
          .map((zone) => zone.trim())
          .where((zone) => zone.isNotEmpty)
          .toSet()
          .toList();
}
