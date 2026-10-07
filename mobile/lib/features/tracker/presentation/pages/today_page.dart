import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../../../core/utils/russian_date.dart';
import '../../../diary/data/daily_entry.dart';
import '../../domain/attack_record.dart';
import '../../state/tracker_controller.dart';
import '../widgets/common.dart';

class TodayPage extends StatelessWidget {
  const TodayPage({
    required this.controller,
    required this.onCreateAttack,
    required this.onOpenAttack,
    required this.onProfileTap,
    required this.onOpenDailyEntry,
    this.dailyEntries = const [],
    this.diaryError,
    this.onRetryDiary,
    this.userName,
    super.key,
  });

  final TrackerController controller;
  final String? userName;
  final VoidCallback onProfileTap;
  final VoidCallback onCreateAttack;
  final ValueChanged<AttackRecord> onOpenAttack;
  final VoidCallback onOpenDailyEntry;
  final List<DailyEntry> dailyEntries;
  final String? diaryError;
  final VoidCallback? onRetryDiary;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final name = userName?.trim() ?? '';
    final latest = controller.latestAttack;
    DailyEntry? todayEntry;
    for (final entry in dailyEntries) {
      if (RussianDate.isSameDay(entry.date, today)) todayEntry = entry;
    }

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
            physics: const AlwaysScrollableScrollPhysics(),
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
                  Material(
                    color: Colors.white,
                    shape: const CircleBorder(),
                    child: InkWell(
                      onTap: onProfileTap,
                      customBorder: const CircleBorder(),
                      child: SizedBox(
                        width: 62,
                        height: 62,
                        child: Center(
                          child: name.isEmpty
                              ? const Icon(
                                  Icons.person_outline_rounded,
                                  color: AppColors.ink,
                                )
                              : Text(
                                  name.characters.first.toUpperCase(),
                                  style: const TextStyle(
                                    color: AppColors.ink,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                        ),
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
                      latest == null && dailyEntries.isEmpty
                          ? 'Начнём с наблюдений'
                          : 'Ваш дневник пополняется',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 7),
                    const Text(
                      'Записывайте приступы и самочувствие. Личный прогноз появится на следующем этапе.',
                      style: TextStyle(
                        color: AppColors.muted,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Сейчас доступны дневник и история',
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
                onTap: onOpenDailyEntry,
                child: Row(
                  children: [
                    const Icon(
                      Icons.article_outlined,
                      color: AppColors.blue,
                      size: 22,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            todayEntry == null
                                ? 'Как прошёл ваш день?'
                                : 'Самочувствие сегодня',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            todayEntry?.summary ??
                                'Сон, вода и стресс · около минуты',
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.muted,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              if (diaryError != null) ...[
                AppCard(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      const Text('Не удалось загрузить дневник самочувствия'),
                      const SizedBox(height: 8),
                      Text(diaryError!,
                          style: const TextStyle(color: AppColors.muted)),
                      TextButton(
                          onPressed: onRetryDiary,
                          child: const Text('Повторить')),
                    ])),
                const SizedBox(height: 14),
              ],
              if (latest == null)
                AppCard(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(
                          dailyEntries.isEmpty
                              ? 'Здесь появится ваша первая запись'
                              : 'Приступов пока нет',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      const Text(
                          'Если боли нет, начните с самочувствия. Приступ можно записать, когда он возникнет.',
                          style: TextStyle(color: AppColors.muted)),
                    ])),
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
