import 'package:flutter/material.dart';

import '../../../../app/theme.dart';

class AppCard extends StatelessWidget {
  const AppCard({
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.color = AppColors.card,
    this.onTap,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x080A1526),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );

    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: content,
      ),
    );
  }
}

class PrimaryActionButton extends StatelessWidget {
  const PrimaryActionButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.backgroundColor = AppColors.navy,
    this.foregroundColor = Colors.white,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: icon == null
          ? FilledButton(
              onPressed: onPressed,
              style: _style(),
              child: Text(label),
            )
          : FilledButton.icon(
              onPressed: onPressed,
              style: _style(),
              icon: Icon(icon, size: 18),
              label: Text(label),
            ),
    );
  }

  ButtonStyle _style() {
    return FilledButton.styleFrom(
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      disabledBackgroundColor: AppColors.line,
      disabledForegroundColor: AppColors.muted,
      elevation: 0,
      shape: const StadiumBorder(),
      textStyle: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class SecondaryActionButton extends StatelessWidget {
  const SecondaryActionButton({
    required this.label,
    required this.onPressed,
    super.key,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: AppColors.ink,
          backgroundColor: const Color(0xFFF0F3F8),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
        child: Text(label),
      ),
    );
  }
}

class RoundIconButton extends StatelessWidget {
  const RoundIconButton({
    required this.icon,
    required this.onPressed,
    this.backgroundColor = Colors.white,
    this.foregroundColor = AppColors.ink,
    super.key,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: backgroundColor,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, color: foregroundColor, size: 21),
        ),
      ),
    );
  }
}

class StatusLabel extends StatelessWidget {
  const StatusLabel({
    this.active = true,
    super.key,
  });

  final bool active;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: active ? AppColors.blue : AppColors.teal,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 7),
        Text(
          active ? 'ПРОДОЛЖАЕТСЯ' : 'ЗАВЕРШЁН',
          style: TextStyle(
            color: active ? AppColors.blue : AppColors.teal,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.35,
          ),
        ),
      ],
    );
  }
}

class AppBottomNavigation extends StatelessWidget {
  const AppBottomNavigation({
    required this.selectedIndex,
    required this.onSelected,
    super.key,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  static const _items = <({IconData icon, String label})>[
    (icon: Icons.home_outlined, label: 'Сегодня'),
    (icon: Icons.menu_book_outlined, label: 'Дневник'),
    (icon: Icons.bar_chart_rounded, label: 'Обзор'),
    (icon: Icons.person_outline_rounded, label: 'Профиль'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 70,
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: AppColors.navy,
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x250A1321),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: List.generate(_items.length, (index) {
          final item = _items[index];
          final selected = selectedIndex == index;

          return Expanded(
            child: Material(
              color: selected ? Colors.white : Colors.transparent,
              borderRadius: BorderRadius.circular(21),
              child: InkWell(
                onTap: () => onSelected(index),
                borderRadius: BorderRadius.circular(21),
                child: AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 180),
                  style: TextStyle(
                    color: selected ? AppColors.ink : Colors.white70,
                    fontSize: 9,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        item.icon,
                        size: 20,
                        color: selected ? AppColors.ink : Colors.white70,
                      ),
                      const SizedBox(height: 3),
                      Text(item.label),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class BackTitleBar extends StatelessWidget implements PreferredSizeWidget {
  const BackTitleBar({
    required this.title,
    super.key,
  });

  final String title;

  @override
  Size get preferredSize => const Size.fromHeight(66);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      toolbarHeight: 66,
      leadingWidth: 68,
      leading: Padding(
        padding: const EdgeInsets.only(left: 16),
        child: RoundIconButton(
          icon: Icons.chevron_left_rounded,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      titleSpacing: 8,
      title: Text(title),
    );
  }
}
