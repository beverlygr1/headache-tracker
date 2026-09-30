import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../../../core/utils/russian_date.dart';
import '../../domain/attack_record.dart';
import '../../state/tracker_controller.dart';
import '../widgets/common.dart';

class TodayPage extends StatelessWidget {
  const TodayPage({
    required this.controller,
    required this.onCreateAttack,
    required this.onOpenAttack,
    super.key,
  });

  final TrackerController controller;
  final VoidCallback onCreateAttack;
  final ValueChanged<AttackRecord> onOpenAttack;

  @override
  Widget build(BuildContext context) {
    final today = DateTime(2026, 9, 29);
    final latest = controller.latestAttack;

    return Stack(
      children: [
        Positioned.fill(
          child: Align(
            alignment: Alignment.topCenter,
            child: Container(
              height: 390,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFD9F6FB),
                    Color(0xFFE6FFF6),
                    AppColors.background,
                  ],
                  stops: [0, 0.55, 1],
                ),
              ),
            ),
          ),
        ),
        SafeArea(
          bottom: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          RussianDate.full(today),
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.25,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Как вы\nсегодня?',
                          style: Theme.of(context).textTheme.headlineLarge,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Container(
                    width: 62,
                    height: 62,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Text(
                      'А',
                      style: TextStyle(
                        color: AppColors.ink,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 26),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.wb_sunny_outlined,
                          size: 18,
                          color: AppColors.blue,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'ЛИЧНЫЙ ПРОГНОЗ',
                          style: TextStyle(
                            color: AppColors.muted,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.35,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    Text(
                      'Узнаём ваш ритм',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 7),
                    const Text(
                      'Продолжайте вести дневник.\nДля прогноза пока мало данных.',
                      style: TextStyle(
                        color: AppColors.muted,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: List.generate(10, (index) {
                        final complete = index < 6;
                        return Expanded(
                          child: Container(
                            height: 7,
                            margin: EdgeInsets.only(right: index == 9 ? 0 : 6),
                            decoration: BoxDecoration(
                              color: complete
                                  ? AppColors.teal
                                  : const Color(0xFFEFF2F7),
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      '7 дней наблюдений',
                      style: TextStyle(
                        color: AppColors.muted,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              PrimaryActionButton(
                label: controller.activeAttack == null
                    ? 'Записать приступ'
                    : 'Добавить сведения о приступе',
                icon: Icons.add_rounded,
                onPressed: onCreateAttack,
              ),
              const SizedBox(height: 14),
              AppCard(
                color: AppColors.blueSoft,
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Форма дневника дня будет добавлена позже'),
                    ),
                  );
                },
                child: const Row(
                  children: [
                    Icon(
                      Icons.article_outlined,
                      color: AppColors.blue,
                      size: 22,
                    ),
                    SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Как прошёл ваш день?',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Сон, вода и стресс · около минуты',
                            style: TextStyle(
                              color: AppColors.muted,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.muted,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              if (latest != null)
                AppCard(
                  onTap: () => onOpenAttack(latest),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        latest.isActive
                            ? 'Текущий приступ'
                            : 'Последняя запись',
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _timeDescription(latest),
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 9),
                      Row(
                        children: [
                          Text(
                            '${latest.intensity} / 10',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              latest.isActive
                                  ? 'Ощутимая боль'
                                  : 'Умеренная · ${latest.durationMinutes ?? 0} мин',
                              style: const TextStyle(
                                color: AppColors.muted,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right_rounded,
                            color: AppColors.muted,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  String _timeDescription(AttackRecord record) {
    final start = RussianDate.time(record.startTime);
    final end = record.endTime;
    if (end == null) {
      return '${RussianDate.dayMonth(record.startTime)} · начался в $start';
    }
    return '${RussianDate.dayMonth(record.startTime)} · '
        '$start–${RussianDate.time(end)}';
  }
}
