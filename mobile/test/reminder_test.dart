import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:headache_tracker_app/app/app.dart';
import 'package:headache_tracker_app/features/reminders/data/reminder_scheduler.dart';
import 'package:headache_tracker_app/features/reminders/data/reminder_settings.dart';
import 'package:headache_tracker_app/features/reminders/presentation/reminder_settings_page.dart';
import 'package:headache_tracker_app/features/reminders/state/reminder_controller.dart';

void main() {
  group('nextReminderTime', () {
    test('later today when the time has not passed yet', () {
      expect(
        nextReminderTime(DateTime(2026, 10, 21, 9, 0), 20, 0),
        DateTime(2026, 10, 21, 20, 0),
      );
    });

    test('tomorrow when the time has passed or is now', () {
      expect(
        nextReminderTime(DateTime(2026, 10, 21, 20, 0), 20, 0),
        DateTime(2026, 10, 22, 20, 0),
      );
      expect(
        nextReminderTime(DateTime(2026, 12, 31, 21, 0), 8, 30),
        DateTime(2027, 1, 1, 8, 30),
      );
    });
  });

  test('settings survive encode/decode and reject garbage', () {
    const settings = ReminderSettings(enabled: true, hour: 8, minute: 5);
    expect(settings.encode(), 'on|08:05');
    final decoded = ReminderSettings.decode('on|08:05')!;
    expect((decoded.enabled, decoded.hour, decoded.minute), (true, 8, 5));
    expect(ReminderSettings.decode('on|25:00'), isNull);
    expect(ReminderSettings.decode(null), isNull);
  });

  group('ReminderController', () {
    test('is off by default at 20:00 and schedules nothing', () async {
      final scheduler = _FakeScheduler();
      final controller = ReminderController(
        scheduler: scheduler,
        store: _MemoryStore(),
      );

      await controller.load();

      expect(controller.settings.enabled, isFalse);
      expect(controller.settings.timeLabel, '20:00');
      expect(scheduler.scheduled, isNull);
    });

    test('enabling asks permission, schedules and is remembered', () async {
      final scheduler = _FakeScheduler();
      final store = _MemoryStore();
      final controller = ReminderController(scheduler: scheduler, store: store);
      await controller.load();

      await controller.setTime(hour: 21, minute: 30);
      expect(scheduler.scheduled, isNull, reason: 'still disabled');

      expect(await controller.setEnabled(true), ReminderToggleResult.enabled);
      expect(scheduler.permissionRequests, 1);
      expect(scheduler.scheduled, (21, 30));

      // После перезапуска напоминание перепланируется.
      final restartedScheduler = _FakeScheduler();
      final restarted =
          ReminderController(scheduler: restartedScheduler, store: store);
      await restarted.load();
      expect(restarted.settings.enabled, isTrue);
      expect(restartedScheduler.scheduled, (21, 30));
    });

    test('changing time of enabled reminder reschedules it', () async {
      final scheduler = _FakeScheduler();
      final controller =
          ReminderController(scheduler: scheduler, store: _MemoryStore());
      await controller.load();
      await controller.setEnabled(true);

      await controller.setTime(hour: 7, minute: 15);

      expect(scheduler.scheduled, (7, 15));
      expect(controller.settings.timeLabel, '07:15');
    });

    test('disabling cancels the notification', () async {
      final scheduler = _FakeScheduler();
      final controller =
          ReminderController(scheduler: scheduler, store: _MemoryStore());
      await controller.load();
      await controller.setEnabled(true);

      expect(await controller.setEnabled(false), ReminderToggleResult.disabled);

      expect(scheduler.scheduled, isNull);
      expect(controller.settings.enabled, isFalse);
    });

    test('denied permission keeps reminder off', () async {
      final scheduler = _FakeScheduler(permission: false);
      final controller =
          ReminderController(scheduler: scheduler, store: _MemoryStore());
      await controller.load();

      expect(await controller.setEnabled(true),
          ReminderToggleResult.permissionDenied);

      expect(controller.settings.enabled, isFalse);
      expect(scheduler.scheduled, isNull);
    });

    test('tap on reminder requests diary once', () async {
      final scheduler = _FakeScheduler(launchedFromTap: true);
      final controller =
          ReminderController(scheduler: scheduler, store: _MemoryStore());
      await controller.load();

      expect(controller.takeOpenDiaryRequest(), isTrue);
      expect(controller.takeOpenDiaryRequest(), isFalse);

      var notified = false;
      controller.addListener(() => notified = true);
      scheduler.onOpen!();
      expect(notified, isTrue);
      expect(controller.hasOpenDiaryRequest, isTrue);
    });

    test('unsupported platform does nothing', () async {
      final controller = ReminderController(
        scheduler: const UnsupportedReminderScheduler(),
        store: _MemoryStore(),
      );
      await controller.load();

      expect(
          await controller.setEnabled(true), ReminderToggleResult.unsupported);
      expect(controller.settings.enabled, isFalse);
    });
  });

  testWidgets('settings page toggles reminder and picks time', (tester) async {
    final scheduler = _FakeScheduler();
    final controller =
        ReminderController(scheduler: scheduler, store: _MemoryStore());
    await controller.load();
    await tester.pumpWidget(HeadacheTrackerApp(
      home: ReminderSettingsPage(controller: controller),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Напоминание выключено.'), findsOneWidget);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(scheduler.scheduled, (20, 0));
    expect(find.textContaining('Каждый день в 20:00'), findsOneWidget);

    await tester.tap(find.text('Время'));
    await tester.pumpAndSettle();
    expect(find.text('Время напоминания'), findsOneWidget);
    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('settings page explains denied permission', (tester) async {
    final controller = ReminderController(
      scheduler: _FakeScheduler(permission: false),
      store: _MemoryStore(),
    );
    await controller.load();
    await tester.pumpWidget(HeadacheTrackerApp(
      home: ReminderSettingsPage(controller: controller),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(find.textContaining('Уведомления для приложения запрещены'),
        findsOneWidget);
    expect(find.text('Открыть настройки уведомлений'), findsOneWidget);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
  });
}

class _FakeScheduler implements ReminderScheduler {
  _FakeScheduler({this.permission = true, this.launchedFromTap = false});

  final bool permission;
  final bool launchedFromTap;
  (int, int)? scheduled;
  int permissionRequests = 0;
  VoidCallback? onOpen;

  @override
  bool get isSupported => true;

  @override
  Future<void> init({required VoidCallback onOpen}) async =>
      this.onOpen = onOpen;

  @override
  Future<bool> launchedFromReminder() async => launchedFromTap;

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return permission;
  }

  @override
  Future<void> scheduleDaily({required int hour, required int minute}) async =>
      scheduled = (hour, minute);

  @override
  Future<void> cancel() async => scheduled = null;

  @override
  Future<void> openSystemSettings() async {}
}

class _MemoryStore implements ReminderSettingsStore {
  ReminderSettings? value;

  @override
  Future<ReminderSettings?> read() async => value;

  @override
  Future<void> write(ReminderSettings settings) async => value = settings;
}
