import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../../../core/utils/russian_date.dart';
import '../../tracker/presentation/widgets/common.dart';
import '../state/forecast_controller.dart';

class ForecastCard extends StatelessWidget {
  const ForecastCard(
      {super.key, this.controller, required this.onOpenDailyEntry});
  final ForecastController? controller;
  final VoidCallback onOpenDailyEntry;

  @override
  Widget build(BuildContext context) {
    final controller = this.controller;
    if (controller == null) {
      return _card(context, [
        Text('Личный прогноз', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        const Text(
            'Войдите в аккаунт, чтобы получать прогноз по своим записям.',
            style: TextStyle(color: AppColors.muted)),
      ]);
    }
    return ValueListenableBuilder<ForecastState>(
        valueListenable: controller,
        builder: (context, state, _) {
          final data = state.data;
          return _card(context, [
            if (state.status == ForecastStatus.initial ||
                state.status == ForecastStatus.loading)
              const Row(children: [
                SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2)),
                SizedBox(width: 12),
                Expanded(child: Text('Загружаем прогноз…'))
              ])
            else if (state.status == ForecastStatus.error) ...[
              Text(state.error!),
              TextButton.icon(
                  onPressed: controller.refresh,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Повторить')),
            ] else if (data != null) ...[
              Text('На ${RussianDate.dayMonth(data.predictionDate)}',
                  style: const TextStyle(color: AppColors.muted, fontSize: 12)),
              const SizedBox(height: 10),
              Text(
                  data.isReady
                      ? '${(data.probability! * 100).round()}% — вероятность боли'
                      : 'Заполните самочувствие за сегодня',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                  data.isReady
                      ? 'Прогноз на следующий день по вашим записям.'
                      : 'Для расчёта нужны: ${data.missingDescription}. Количество приступов само по себе не запускает прогноз.',
                  style: const TextStyle(color: AppColors.muted, height: 1.45)),
              if (!data.isReady)
                TextButton(
                    onPressed: onOpenDailyEntry,
                    child: const Text('Заполнить самочувствие')),
              if (data.isReady) ...[
                if (data.factors.isNotEmpty)
                  Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(data.factors.join(' · '))),
                for (final recommendation in data.recommendations)
                  Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(recommendation)),
              ],
              const SizedBox(height: 8),
              Text('Часовой пояс: ${data.timeZone}',
                  style: const TextStyle(color: AppColors.muted, fontSize: 10)),
            ],
          ]);
        });
  }

  Widget _card(BuildContext context, List<Widget> children) => AppCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.wb_sunny_outlined, size: 18, color: AppColors.blue),
          SizedBox(width: 8),
          Text('ЛИЧНЫЙ ПРОГНОЗ',
              style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: .35))
        ]),
        const SizedBox(height: 15),
        ...children,
      ]));
}
