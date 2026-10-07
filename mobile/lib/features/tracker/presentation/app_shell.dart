import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/utils/russian_date.dart';
import '../../diary/data/daily_entry.dart';
import '../../diary/data/diary_repository.dart';
import '../../diary/presentation/daily_entry_page.dart';
import '../../onboarding/presentation/onboarding_page.dart';
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
    this.initialAction = OnboardingAction.today,
    super.key,
  });

  final TrackerController controller;
  final String? userName;
  final String? userEmail;
  final DiaryRepository? diaryRepository;
  final OnboardingAction initialAction;

  /// `null` в демо-режиме: выходить не из чего.
  final Future<void> Function()? onLogout;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;
  late final DiaryRepository _diaryRepository;
  List<DailyEntry> _dailyEntries = [];
  String? _diaryError;
  bool _openedInitialAction = false;

  @override
  void initState() {
    super.initState();
    _diaryRepository = widget.diaryRepository ?? InMemoryDiaryRepository();
    _initialize();
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
      _selectedIndex = 0;
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
    if (index <= 1) {
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
            );
          case TrackerStatus.ready:
            final page = _selectedIndex == 0
                ? TodayPage(
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
                  )
                : DiaryPage(
                    key: const ValueKey('diary'),
                    controller: widget.controller,
                    onOpenAttack: _openDetails,
                    dailyEntries: _dailyEntries,
                    onOpenDailyEntry: _openDailyEntry,
                    diaryError: _diaryError,
                    onRetryDiary: _loadDiary,
                  );
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

enum _ProfileAction { onboarding, logout }
