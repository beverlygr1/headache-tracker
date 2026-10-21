import 'package:flutter/foundation.dart';

import '../data/reminder_scheduler.dart';
import '../data/reminder_settings.dart';

enum ReminderToggleResult { enabled, disabled, permissionDenied, unsupported }

class ReminderController extends ChangeNotifier {
  ReminderController({
    required ReminderScheduler scheduler,
    required ReminderSettingsStore store,
  })  : _scheduler = scheduler,
        _store = store;

  final ReminderScheduler _scheduler;
  final ReminderSettingsStore _store;

  ReminderSettings _settings = ReminderSettings.initial;
  bool _busy = false;
  bool _openDiaryRequested = false;

  ReminderSettings get settings => _settings;
  bool get isSupported => _scheduler.isSupported;
  bool get isBusy => _busy;

  /// Нажали на напоминание, а дневник ещё не открыт.
  bool get hasOpenDiaryRequest => _openDiaryRequested;

  /// Подписка на нажатия, сохранённые настройки и перепланирование.
  /// Повторное планирование при запуске учитывает смену часового пояса.
  Future<void> load() async {
    try {
      await _scheduler.init(onOpen: _requestOpenDiary);
      if (await _scheduler.launchedFromReminder()) _openDiaryRequested = true;
    } catch (_) {
      // Без уведомлений приложение всё равно должно запуститься.
    }

    try {
      _settings = await _store.read() ?? ReminderSettings.initial;
    } catch (_) {
      _settings = ReminderSettings.initial;
    }

    if (_settings.enabled && isSupported) {
      try {
        await _scheduler.scheduleDaily(
          hour: _settings.hour,
          minute: _settings.minute,
        );
      } catch (_) {}
    }
    notifyListeners();
  }

  /// Включает или выключает напоминание. При включении спрашивает
  /// разрешение на уведомления; при отказе напоминание остаётся выключенным.
  Future<ReminderToggleResult> setEnabled(bool enabled) async {
    if (!isSupported) return ReminderToggleResult.unsupported;
    return _run(() async {
      if (enabled) {
        if (!await _scheduler.requestPermission()) {
          return ReminderToggleResult.permissionDenied;
        }
        await _scheduler.scheduleDaily(
          hour: _settings.hour,
          minute: _settings.minute,
        );
      } else {
        await _scheduler.cancel();
      }
      await _save(_settings.copyWith(enabled: enabled));
      return enabled
          ? ReminderToggleResult.enabled
          : ReminderToggleResult.disabled;
    });
  }

  /// Меняет время. Включённое напоминание сразу перепланируется.
  Future<void> setTime({required int hour, required int minute}) {
    return _run(() async {
      final next = _settings.copyWith(hour: hour, minute: minute);
      if (next.enabled && isSupported) {
        await _scheduler.scheduleDaily(hour: hour, minute: minute);
      }
      await _save(next);
    });
  }

  Future<void> openSystemSettings() => _scheduler.openSystemSettings();

  /// Забирает запрос «открыть дневник» — открыть его нужно один раз.
  bool takeOpenDiaryRequest() {
    if (!_openDiaryRequested) return false;
    _openDiaryRequested = false;
    return true;
  }

  void _requestOpenDiary() {
    _openDiaryRequested = true;
    notifyListeners();
  }

  Future<void> _save(ReminderSettings settings) async {
    _settings = settings;
    try {
      await _store.write(settings);
    } catch (_) {
      // Уведомление уже запланировано; настройка применится до перезапуска.
    }
  }

  Future<T> _run<T>(Future<T> Function() action) async {
    _busy = true;
    notifyListeners();
    try {
      return await action();
    } finally {
      _busy = false;
      notifyListeners();
    }
  }
}
