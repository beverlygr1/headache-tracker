import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Планировщик системного уведомления. Реализация зависит от платформы,
/// в тестах и в вебе — заглушки.
abstract interface class ReminderScheduler {
  /// Умеет ли платформа показывать запланированные уведомления.
  bool get isSupported;

  /// [onOpen] вызывается, когда пользователь нажал на напоминание
  /// при запущенном приложении.
  Future<void> init({required VoidCallback onOpen});

  /// Приложение запущено нажатием на напоминание.
  Future<bool> launchedFromReminder();

  /// Запрашивает разрешение на уведомления (Android 13+). `false` — отказ.
  Future<bool> requestPermission();

  Future<void> scheduleDaily({required int hour, required int minute});

  Future<void> cancel();

  /// Открывает системные настройки уведомлений приложения.
  Future<void> openSystemSettings();
}

/// Ближайший момент `hour:minute` по локальному времени строго после [now].
DateTime nextReminderTime(DateTime now, int hour, int minute) {
  var next = DateTime(now.year, now.month, now.day, hour, minute);
  if (!next.isAfter(now)) {
    next = DateTime(now.year, now.month, now.day + 1, hour, minute);
  }
  return next;
}

class LocalNotificationReminderScheduler implements ReminderScheduler {
  LocalNotificationReminderScheduler([FlutterLocalNotificationsPlugin? plugin])
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const _notificationId = 2508;
  static const _payload = 'daily_diary';
  static const _channel = AndroidNotificationDetails(
    'daily_diary_reminder',
    'Напоминание о дневнике',
    channelDescription: 'Ежедневное напоминание заполнить дневник самочувствия',
    importance: Importance.defaultImportance,
    priority: Priority.defaultPriority,
  );

  final FlutterLocalNotificationsPlugin _plugin;

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  @override
  bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  Future<void> init({required VoidCallback onOpen}) async {
    tz_data.initializeTimeZones();
    try {
      final zone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(zone.identifier));
    } catch (_) {
      // Неизвестный пояс: остаёмся в UTC. Первое срабатывание всё равно
      // считается от локального времени устройства.
    }

    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      onDidReceiveNotificationResponse: (response) {
        if (response.payload == _payload) onOpen();
      },
    );
  }

  @override
  Future<bool> launchedFromReminder() async {
    final details = await _plugin.getNotificationAppLaunchDetails();
    return details?.didNotificationLaunchApp == true &&
        details?.notificationResponse?.payload == _payload;
  }

  @override
  Future<bool> requestPermission() async {
    final android = _android;
    if (android == null) return false;
    if (await android.areNotificationsEnabled() == true) return true;
    return await android.requestNotificationsPermission() ?? false;
  }

  @override
  Future<void> scheduleDaily({required int hour, required int minute}) async {
    await cancel();
    final next = nextReminderTime(DateTime.now(), hour, minute);
    await _plugin.zonedSchedule(
      id: _notificationId,
      scheduledDate: tz.TZDateTime.from(next, tz.local),
      notificationDetails: const NotificationDetails(android: _channel),
      // Неточный будильник не требует разрешения на точные будильники;
      // для напоминания о дневнике погрешность в несколько минут не важна.
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      title: 'Как прошёл ваш день?',
      body: 'Отметьте сон, воду, стресс и головную боль — это займёт минуту.',
      payload: _payload,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  @override
  Future<void> cancel() => _plugin.cancel(id: _notificationId);

  @override
  Future<void> openSystemSettings() async {
    await _plugin.openAppNotificationSettings();
  }
}

/// Платформа без запланированных уведомлений (веб, десктоп).
class UnsupportedReminderScheduler implements ReminderScheduler {
  const UnsupportedReminderScheduler();

  @override
  bool get isSupported => false;

  @override
  Future<void> init({required VoidCallback onOpen}) async {}

  @override
  Future<bool> launchedFromReminder() async => false;

  @override
  Future<bool> requestPermission() async => false;

  @override
  Future<void> scheduleDaily({required int hour, required int minute}) async {}

  @override
  Future<void> cancel() async {}

  @override
  Future<void> openSystemSettings() async {}
}
