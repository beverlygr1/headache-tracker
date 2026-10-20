/// Consistent interface labels for the user's 1–10 intensity scale.
abstract final class PainIntensity {
  static String description(int intensity) {
    if (intensity <= 3) return 'Слабая боль';
    if (intensity <= 6) return 'Умеренная боль';
    return 'Сильная боль';
  }
}
