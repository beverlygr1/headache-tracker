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
import '../../onboarding/presentation/onboarding_page.dart';
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
    this.analyticsController,
    this.initialAction = OnboardingAction.today,
    super.key,
  });

  final TrackerController controller;
  final String? userName;
  final String? userEmail;
  final DiaryRepository? diaryRepository;
  final ApiClient? apiClient;
  final AnalyticsController? analyticsController;
  final OnboardingAction initialAction;

  /// Адрес сервера, который можно поменять из профиля. `null` в демо-режиме.
  final ServerSettings? serverSettings;

  /// `null` в демо-режиме: выходить не из чего.
  final Future<void> Function()? onLogout;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
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

    // Инициализация контроллера аналитики, если он передан или есть apiClient
    if (widget.analyticsController != null) {
      _analyticsController = widget.analyticsController;
    } else if (widget.apiClient != null) {
      _analyticsController = AnalyticsController(AnalyticsApi(widget.apiClient!));
    }

    _initialize();
  }

  @override
  void dispose() {
    // Освобождаем контроллер аналитики только если создавали его внутри
    if (widget.analyticsController == null) {
      _analyticsController?.dispose();
    }
    super.dispose();
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _performAction(widget.initialAction);
    });
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
      builder: (_) => DailyEntryPage(
          repository: _diaryRepository, date: date ?? DateTime.now()),
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
  }

  void _selectSection(int index) {
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
                  child: Text('Контроллер аналитики не проинициализирован'),
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

enum _ProfileAction { onboarding, server, logout }