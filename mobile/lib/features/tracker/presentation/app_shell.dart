import 'package:flutter/material.dart';

import '../../../app/theme.dart';
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
    super.key,
  });

  final TrackerController controller;
  final String? userName;
  final String? userEmail;

  /// `null` в демо-режиме: выходить не из чего.
  final Future<void> Function()? onLogout;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    if (widget.controller.status == TrackerStatus.initial) {
      widget.controller.load();
    }
  }

  Future<void> _refresh() async {
    try {
      await widget.controller.load();
    } catch (error) {
      if (mounted) showErrorSnackBar(context, describeError(error));
    }
  }

  Future<void> _openProfile() async {
    final onLogout = widget.onLogout;
    if (onLogout == null) {
      showErrorSnackBar(context, 'Демо-режим: данные хранятся только в памяти');
      return;
    }

    final logout = await showModalBottomSheet<bool>(
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
                label: 'Выйти из аккаунта',
                onPressed: () => Navigator.pop(context, true),
              ),
            ],
          ),
        ),
      ),
    );

    if (logout == true) await onLogout();
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
              onRetry: widget.controller.load,
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
                  )
                : DiaryPage(
                    key: const ValueKey('diary'),
                    controller: widget.controller,
                    onOpenAttack: _openDetails,
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
