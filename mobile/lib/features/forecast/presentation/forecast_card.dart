import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/utils/russian_date.dart';
import '../../diary/data/daily_entry.dart';
import '../../tracker/presentation/widgets/common.dart';
import '../data/forecast_data.dart';
import '../state/forecast_controller.dart';

class ForecastCard extends StatelessWidget {
  const ForecastCard({
    super.key,
    this.controller,
    this.dailyEntries = const [],
    required this.onOpenDailyEntry,
  });

  final ForecastController? controller;
  final List<DailyEntry> dailyEntries;
  final ValueChanged<DateTime> onOpenDailyEntry;

  @override
  Widget build(BuildContext context) {
    final controller = this.controller;
    if (controller == null) {
      return _card('Личный прогноз', [
        const Text(
            'Войдите в аккаунт, чтобы получать прогноз по своим записям.'),
      ]);
    }

    return ValueListenableBuilder<ForecastState>(
      valueListenable: controller,
      builder: (context, state, _) {
        final data = state.data;
        if (state.status == ForecastStatus.error) {
          return _card('Личный прогноз', [
            Text(state.error!),
            TextButton(
              onPressed: controller.refresh,
              child: const Text('Повторить'),
            ),
          ]);
        }
        if (data == null) {
          return _card('Личный прогноз', [
            const Row(children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 12),
              Expanded(child: Text('Загружаем прогноз…')),
            ]),
          ]);
        }

        final predictionDate = data.predictionDate;
        final entryDate = DateTime(
          predictionDate.year,
          predictionDate.month,
          predictionDate.day - 1,
        );
        final title = 'Прогноз на ${RussianDate.dayMonth(predictionDate)}';
        void openEntry() => onOpenDailyEntry(entryDate);
        if (!data.isReady) {
          return _card(
            title,
            [
              Text(
                data.missingDescription.isEmpty
                    ? 'Добавьте данные за ${RussianDate.dayMonth(entryDate)}'
                    : 'Для расчёта нужны: ${data.missingDescription}.',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 10),
              const Text('Заполнить самочувствие', style: _actionStyle),
            ],
            onTap: openEntry,
          );
        }

        return _card(
          title,
          [
            Text(
              '${(data.probability! * 100).round()}%',
              style: const TextStyle(
                color: Color(0xFF173F77),
                fontSize: 52,
                fontWeight: FontWeight.w800,
                height: 1.05,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Вероятность головной боли',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 14),
            const Text('Подробнее о прогнозе', style: _actionStyle),
          ],
          onTap: () => _showDetails(context, data, title, entryDate),
        );
      },
    );
  }

  static const _actionStyle = TextStyle(
    color: Color(0xFF245490),
    fontWeight: FontWeight.w700,
  );

  Widget _card(String title, List<Widget> children, {VoidCallback? onTap}) {
    return AppCard(
      color: AppColors.blueSoft,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.wb_sunny_outlined,
                  size: 19, color: Color(0xFF245490)),
              const SizedBox(width: 8),
              Expanded(child: Text(title, style: _actionStyle)),
              if (onTap != null)
                const Icon(Icons.chevron_right_rounded,
                    color: Color(0xFF245490)),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Future<void> _showDetails(
    BuildContext context,
    ForecastData data,
    String title,
    DateTime entryDate,
  ) async {
    final entry = dailyEntries
        .where((entry) => RussianDate.isSameDay(entry.date, entryDate))
        .firstOrNull;
    final sleep = entry?.sleepHours;
    final stress = entry?.stressLevel;
    final caffeine = entry?.caffeineIntake;
    final calculatedAt = data.calculatedAt?.toUtc();
    final openEntry = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 430),
      builder: (context) => SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 6),
              Text(
                  '${(data.probability! * 100).round()}% — вероятность головной боли'),
              const SizedBox(height: 20),
              Text('Данные для расчёта',
                  style: Theme.of(context).textTheme.titleMedium),
              Text('Запись за ${RussianDate.dayMonth(entryDate)}'),
              const SizedBox(height: 12),
              if (entry == null)
                const Text('Данные записи пока не загружены.')
              else
                AppCard(
                  color: AppColors.bluePale,
                  child: Column(
                    children: [
                      _detailRow(
                          'Сон',
                          sleep == null
                              ? '—'
                              : '${DailyEntry.formatHours(sleep)} ч'),
                      const Divider(height: 20),
                      _detailRow(
                          'Стресс', stress == null ? '—' : '$stress из 10'),
                      const Divider(height: 20),
                      _detailRow(
                          'Кофеин', caffeine == null ? '—' : '$caffeine мг'),
                    ],
                  ),
                ),
              for (final factor in data.factors) Text(factor),
              for (final recommendation in data.recommendations)
                Text(recommendation),
              const SizedBox(height: 16),
              if (calculatedAt != null)
                Text(
                    'Рассчитано ${RussianDate.dayMonth(calculatedAt)} в ${RussianDate.time(calculatedAt)} UTC'),
              Text('Часовой пояс прогноза · ${data.timeZone}'),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(
                    'Посмотреть запись за ${RussianDate.dayMonth(entryDate)}'),
              ),
            ],
          ),
        ),
      ),
    );
    if (openEntry == true && context.mounted) onOpenDailyEntry(entryDate);
  }

  Widget _detailRow(String label, String value) => Row(
        children: [
          Expanded(child: Text(label)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      );
}
