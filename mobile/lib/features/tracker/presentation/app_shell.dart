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
    super.key,
  });

  final TrackerController controller;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;

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
        final page = _selectedIndex == 0
            ? TodayPage(
                key: const ValueKey('today'),
                controller: widget.controller,
                onCreateAttack: () =>
                    _openEditor(widget.controller.activeAttack),
                onOpenAttack: _openDetails,
              )
            : DiaryPage(
                key: const ValueKey('diary'),
                controller: widget.controller,
                onOpenAttack: _openDetails,
              );

        return Scaffold(
          backgroundColor: AppColors.background,
          body: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: page,
          ),
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
