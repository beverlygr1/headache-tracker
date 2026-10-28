import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/api/api_client.dart';
import '../../../core/config/server_settings.dart';
import '../../../core/utils/russian_date.dart';
import '../../analytics/data/analytics_api.dart';
import '../../analytics/presentation/analytics_page.dart';
import '../../analytics/state/analytics_controller.dart';
import '../../diary/data/daily_entry.dart';
import '../../diary/data/diary_repository.dart';
import '../../diary/presentation/daily_entry_page.dart';
import '../../forecast/data/forecast_api.dart';
import '../../forecast/state/forecast_controller.dart';
import '../../onboarding/presentation/onboarding_page.dart';
import '../../reminders/presentation/reminder_settings_page.dart';
import '../../reminders/state/reminder_controller.dart';
import '../../settings/presentation/server_address_dialog.dart';
import '../domain/attack_record.dart';
import '../state/tracker_controller.dart';
import 'pages/attack_details_page.dart';
import 'pages/attack_entry_page.dart';
import 'pages/diary_page.dart';
import 'pages/today_page.dart';
import 'widgets/common.dart';

class AppShell extends StatefulWidget {
  const AppShell({
    required this.controller,
    this.userName,
    this.userEmail,
    this.onLogout,
    this.diaryRepository,
    this.apiClient,
    this.serverSettings,
    this.reminderController,
    this.analyticsController,
    this.forecastController,
    this.timeZone = 'UTC',
    this.now,
    this.initialAction = OnboardingAction.today,
    super.key,
  });

  final TrackerController controller;
  final String? userName;
  final String? userEmail;
  final DiaryRepository? diaryRepository;
  final ApiClient? apiClient;
  final AnalyticsController? analyticsController;
  final ForecastController? forecastController;
  final String timeZone;
  final DateTime Function()? now;
  final OnboardingAction initialAction;

  /// Адрес сервера, который можно поменять из профиля. `null` в демо-режиме.
  final ServerSettings? serverSettings;

  /// Ежедневное напоминание о дневнике. `null` в тестах.
  final ReminderController? reminderController;

  /// `null` в демо-режиме: выходить не из чего.
  final Future<void> Function()? onLogout;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
  DateTime get _now => widget.now?.call() ?? DateTime.now();
  late DateTime _today;
  Timer? _dayTimer;
  ForecastController? _forecastController;
  int _selectedIndex = 0;
  late final DiaryRepository _diaryRepository;
  AnalyticsController? _analyticsController;
  List<DailyEntry> _dailyEntries = [];
  String? _diaryError;
  bool _openedInitialAction = false;

  @override
  void initState() {
    super.initState();
    _diaryRepository = widget.diaryRepository ?? InMemoryDiaryRepository();
    _today = DateUtils.dateOnly(_now);
    WidgetsBinding.instance.addObserver(this);
    _scheduleDayChange();
    _forecastController = widget.forecastController ??
        (widget.apiClient == null
            ? null
            : ForecastController(ForecastApi(widget.apiClient!)));
    _forecastController?.refresh();

    // Инициализация контроллера аналитики, если он передан или есть apiClient
    if (widget.analyticsController != null) {
      _analyticsController = widget.analyticsController;
    } else if (widget.apiClient != null) {
      _analyticsController = AnalyticsController(
          AnalyticsApi(widget.apiClient!),
          timeZone: widget.timeZone);
    }

    widget.reminderController?.addListener(_onReminderChanged);
    _initialize();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _dayTimer?.cancel();
    if (widget.forecastController == null) _forecastController?.dispose();
    widget.reminderController?.removeListener(_onReminderChanged);
    // Освобождаем контроллер аналитики только если создавали его внутри
    if (widget.analyticsController == null) {
      _analyticsController?.dispose();
    }
    super.dispose();
  }

  void _scheduleDayChange() {
    _dayTimer?.cancel();
    final now = _now;
    final nextDay = DateTime(now.year, now.month, now.day + 1);
    _dayTimer = Timer(nextDay.difference(now), _checkDay);
  }

  void _checkDay() {
    if (!mounted) return;
    final today = DateUtils.dateOnly(_now);
    if (today != _today) {
      setState(() => _today = today);
      _loadDiary();
      _forecastController?.refresh();
    }
    _scheduleDayChange();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkDay();
    }
  }

  Future<void> _initialize() async {
    if (widget.controller.status == TrackerStatus.initial) {
      await widget.controller.load();
    }
    if (!mounted) return;
    await _loadDiary();
    if (mounted && widget.controller.status == TrackerStatus.ready) {
      _openInitialAction();
    }
  }

  void _openInitialAction() {
    if (_openedInitialAction) return;
    _openedInitialAction = true;
    // Приложение открыли нажатием на напоминание — сразу к записи дня.
    final action = widget.reminderController?.takeOpenDiaryRequest() == true
        ? OnboardingAction.diary
        : widget.initialAction;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _performAction(action);
    });
  }

  /// Нажатие на напоминание, пока приложение уже открыто.
  void _onReminderChanged() {
    final reminders = widget.reminderController;
    if (reminders == null || !reminders.hasOpenDiaryRequest) return;
    // До первой загрузки запрос заберёт _openInitialAction.
    if (!_openedInitialAction ||
        widget.controller.status != TrackerStatus.ready) {
      return;
    }
    reminders.takeOpenDiaryRequest();
    Navigator.of(context).popUntil((route) => route.isFirst);
    _performAction(OnboardingAction.diary);
  }

  Future<void> _loadDiary() async {
    try {
      final entries = await _diaryRepository.fetchAll();
      entries.sort((a, b) => b.date.compareTo(a.date));
      if (mounted) {
        setState(() {
          _dailyEntries = entries;
          _diaryError = null;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _diaryError = describeError(error));
    }
  }

  Future<void> _performAction(OnboardingAction action) async {
    switch (action) {
      case OnboardingAction.today:
        setState(() => _selectedIndex = 0);
      case OnboardingAction.attack:
        await _openEditor(widget.controller.activeAttack);
      case OnboardingAction.diary:
        await _openDailyEntry();
    }
  }

  Future<void> _openDailyEntry([DateTime? date]) async {
    final entry =
        await Navigator.of(context).push<DailyEntry>(MaterialPageRoute(
      builder: (_) =>
          DailyEntryPage(repository: _diaryRepository, date: date ?? _now),
    ));
    if (entry == null || !mounted) return;
    setState(() {
      _dailyEntries
          .removeWhere((item) => RussianDate.isSameDay(item.date, entry.date));
      _dailyEntries.add(entry);
      _dailyEntries.sort((a, b) => b.date.compareTo(a.date));
    });
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Самочувствие сохранено')));
    _forecastController?.refresh();
  }

  Future<void> _showOnboarding() async {
    final action =
        await Navigator.of(context).push<OnboardingAction>(MaterialPageRoute(
      builder: (routeContext) => OnboardingPage(
        onStepChanged: (_) async {},
        onFinished: (action) async => Navigator.of(routeContext).pop(action),
      ),
    ));
    if (mounted && action != null) await _performAction(action);
  }

  Future<void> _refresh() async {
    _checkDay();
    _forecastController?.refresh();
    try {
      await widget.controller.load();
      if (!mounted) return;
      await _loadDiary();
      if (_selectedIndex == 2 && _analyticsController != null) {
        await _analyticsController!.loadAnalytics();
      }
      if (mounted && widget.controller.status == TrackerStatus.ready) {
        _openInitialAction();
      }
    } catch (error) {
      if (mounted) showErrorSnackBar(context, describeError(error));
    }
  }

  Future<void> _openProfile() async {
    final onLogout = widget.onLogout;
    final action = await showModalBottomSheet<_ProfileAction>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.userName ?? 'Профиль',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (widget.userEmail != null) ...[
                const SizedBox(height: 4),
                Text(
                  widget.userEmail!,
                  style: const TextStyle(color: AppColors.muted),
                ),
              ],
              const SizedBox(height: 20),
              SecondaryActionButton(
                label: 'Знакомство с приложением',
                onPressed: () =>
                    Navigator.pop(context, _ProfileAction.onboarding),
              ),
              const SizedBox(height: 12),
              if (widget.reminderController case final reminders?) ...[
                SecondaryActionButton(
                  label: reminders.settings.enabled
                      ? 'Напоминание о дневнике: ${reminders.settings.timeLabel}'
                      : 'Напоминание о дневнике: выкл.',
                  onPressed: () =>
                      Navigator.pop(context, _ProfileAction.reminder),
                ),
                const SizedBox(height: 12),
              ],
              if (widget.serverSettings case final settings?) ...[
                SecondaryActionButton(
                  label: 'Адрес сервера: ${settings.displayAddress}',
                  onPressed: () =>
                      Navigator.pop(context, _ProfileAction.server),
                ),
                const SizedBox(height: 12),
              ],
              if (onLogout != null)
                SecondaryActionButton(
                  label: 'Выйти из аккаунта',
                  onPressed: () =>
                      Navigator.pop(context, _ProfileAction.logout),
                )
              else
                const Text('Демо-режим: записи хранятся только в памяти',
                    style: TextStyle(color: AppColors.muted)),
            ],
          ),
        ),
      ),
    );

    if (!mounted) return;
    if (action == _ProfileAction.logout) await onLogout?.call();
    if (action == _ProfileAction.onboarding) await _showOnboarding();
    if (action == _ProfileAction.server) await _changeServer();
    if (action == _ProfileAction.reminder) await _openReminderSettings();
  }

  Future<void> _openReminderSettings() async {
    final reminders = widget.reminderController;
    if (reminders == null) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => ReminderSettingsPage(controller: reminders),
      ),
    );
  }

  Future<void> _changeServer() async {
    final settings = widget.serverSettings;
    if (settings == null) return;
    if (await showServerAddressDialog(context, settings)) {
      await _refresh();
    }
  }

  Future<void> _openEditor([AttackRecord? record]) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => AttackEntryPage(
          controller: widget.controller,
          initialRecord: record,
        ),
      ),
    );

    if (saved == true && mounted) {
      setState(() => _selectedIndex = 1);
      _forecastController?.refresh();
    }
  }

  Future<void> _openDetails(AttackRecord record) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => AttackDetailsPage(
          controller: widget.controller,
          recordId: record.id,
        ),
      ),
    );
    if (mounted) _forecastController?.refresh();
  }

  void _selectSection(int index) {
    _checkDay();
    if (index <= 2) {
      setState(() => _selectedIndex = index);
      return;
    }
    if (index == 3) {
      _openProfile();
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Этот раздел появится на следующем этапе'),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final Widget body;
        switch (widget.controller.status) {
          case TrackerStatus.initial || TrackerStatus.loading:
            body = const Center(child: CircularProgressIndicator());
          case TrackerStatus.failure:
            body = ErrorRetryView(
              message: widget.controller.errorMessage ?? '',
              onRetry: _refresh,
              secondaryLabel:
                  widget.serverSettings == null ? null : 'Адрес сервера',
              onSecondary: _changeServer,
            );
          case TrackerStatus.ready:
            final Widget page;
            if (_selectedIndex == 0) {
              page = TodayPage(
                key: const ValueKey('today'),
                today: _today,
                forecastController: _forecastController,
                controller: widget.controller,
                userName: widget.userName,
                onProfileTap: _openProfile,
                onCreateAttack: () =>
                    _openEditor(widget.controller.activeAttack),
                onOpenAttack: _openDetails,
                onOpenDailyEntry: () => _openDailyEntry(),
                dailyEntries: _dailyEntries,
                diaryError: _diaryError,
                onRetryDiary: _loadDiary,
              );
            } else if (_selectedIndex == 1) {
              page = DiaryPage(
                key: const ValueKey('diary'),
                today: _today,
                controller: widget.controller,
                onOpenAttack: _openDetails,
                dailyEntries: _dailyEntries,
                onOpenDailyEntry: _openDailyEntry,
                diaryError: _diaryError,
                onRetryDiary: _loadDiary,
              );
            } else if (_selectedIndex == 2) {
              if (_analyticsController != null) {
                page = AnalyticsPage(
                  key: const ValueKey('analytics'),
                  controller: _analyticsController!,
                );
              } else {
                page = const Center(
                  child:
                      Text('Войдите в аккаунт, чтобы посмотреть статистику.'),
                );
              }
            } else {
              page = const SizedBox.shrink();
            }

            body = RefreshIndicator(
              onRefresh: _refresh,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: page,
              ),
            );
        }

        return Scaffold(
          backgroundColor: AppColors.background,
          body: body,
          bottomNavigationBar: SafeArea(
            top: false,
            child: AppBottomNavigation(
              selectedIndex: _selectedIndex,
              onSelected: _selectSection,
            ),
          ),
        );
      },
    );
  }
}

enum _ProfileAction { onboarding, reminder, server, logout }
