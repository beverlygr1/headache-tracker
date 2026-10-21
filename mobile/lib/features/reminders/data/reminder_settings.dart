import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Настройки ежедневного напоминания заполнить дневник.
class ReminderSettings {
  const ReminderSettings({
    required this.enabled,
    required this.hour,
    required this.minute,
  });

  /// По умолчанию выключено: включение просит разрешение на уведомления.
  /// 20:00 — то же время, что у backend по умолчанию (`daily_reminder_time`).
  static const initial = ReminderSettings(enabled: false, hour: 20, minute: 0);

  final bool enabled;
  final int hour;
  final int minute;

  String get timeLabel =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  ReminderSettings copyWith({bool? enabled, int? hour, int? minute}) {
    return ReminderSettings(
      enabled: enabled ?? this.enabled,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
    );
  }

  /// Формат хранения: `on|20:00` или `off|08:30`.
  String encode() => '${enabled ? 'on' : 'off'}|$timeLabel';

  static ReminderSettings? decode(String? value) {
    final match =
        RegExp(r'^(on|off)\|(\d{2}):(\d{2})$').firstMatch(value ?? '');
    if (match == null) return null;
    final hour = int.parse(match.group(2)!);
    final minute = int.parse(match.group(3)!);
    if (hour > 23 || minute > 59) return null;
    return ReminderSettings(
      enabled: match.group(1) == 'on',
      hour: hour,
      minute: minute,
    );
  }
}

/// Хранилище настроек напоминания. В тестах подменяется на память.
abstract interface class ReminderSettingsStore {
  Future<ReminderSettings?> read();
  Future<void> write(ReminderSettings settings);
}

class SecureReminderSettingsStore implements ReminderSettingsStore {
  SecureReminderSettingsStore([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'diary_reminder';
  final FlutterSecureStorage _storage;

  @override
  Future<ReminderSettings?> read() async =>
      ReminderSettings.decode(await _storage.read(key: _key));

  @override
  Future<void> write(ReminderSettings settings) =>
      _storage.write(key: _key, value: settings.encode());
}
