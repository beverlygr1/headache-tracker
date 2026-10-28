import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../../../core/utils/russian_date.dart';
import '../../tracker/presentation/widgets/common.dart';
import '../data/analytics_dto.dart';
import '../state/analytics_controller.dart';

enum _Metric { count, intensity, duration }

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key, required this.controller});
  final AnalyticsController controller;
  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  _Metric _metric = _Metric.intensity;
  final _chartKey = GlobalKey();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.controller.loadAnalytics();
    });
  }

  void _selectMetric(_Metric metric) {
    setState(() => _metric = metric);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = _chartKey.currentContext;
      if (context != null) {
        Scrollable.ensureVisible(context,
            duration: const Duration(milliseconds: 200), alignment: .1);
      }
    });
  }

  @override
  Widget build(BuildContext context) => SafeArea(
        bottom: false,
        child: ValueListenableBuilder<AnalyticsState>(
          valueListenable: widget.controller,
          builder: (context, state, _) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
            children: [
              Text('Статистика',
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 20),
              SegmentedButton<String>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: 'week', label: Text('Неделя')),
                  ButtonSegment(value: 'month', label: Text('Месяц')),
                  ButtonSegment(value: 'year', label: Text('Год')),
                ],
                selected: {state.selectedPeriod},
                onSelectionChanged: (selection) =>
                    widget.controller.changePeriod(selection.first),
              ),
              const SizedBox(height: 20),
              if (state.status == AnalyticsStatus.initial ||
                  state.status == AnalyticsStatus.loading)
                const Padding(
                    padding: EdgeInsets.all(60),
                    child: Center(child: CircularProgressIndicator()))
              else if (state.status == AnalyticsStatus.error)
                AppCard(
                    child: Column(children: [
                  Text(state.errorMessage!, textAlign: TextAlign.center),
                  TextButton.icon(
                      onPressed: () => widget.controller.loadAnalytics(),
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Повторить')),
                ]))
              else if (state.status == AnalyticsStatus.empty)
                const AppCard(
                    child: Text(
                        'За выбранный период записей о приступах нет. Отсутствие записей не означает отсутствие боли.'))
              else ...[
                _stat('Всего приступов', '${state.data!.totalAttacks}',
                    Icons.bolt_rounded, _Metric.count),
                const SizedBox(height: 12),
                _stat(
                    'Средняя интенсивность',
                    '${state.data!.averageIntensity.toStringAsFixed(1)} / 10',
                    Icons.bar_chart_rounded,
                    _Metric.intensity),
                const SizedBox(height: 12),
                _stat(
                    'Средняя длительность',
                    state.data!.completedAttacks == 0
                        ? 'Нет завершённых'
                        : state.data!.formattedDuration,
                    Icons.schedule_rounded,
                    _Metric.duration),
                const SizedBox(height: 24),
                _DailyChart(
                    key: _chartKey, metric: _metric, series: state.series!),
              ],
            ],
          ),
        ),
      );

  Widget _stat(String title, String value, IconData icon, _Metric metric) =>
      Semantics(
          button: true,
          selected: _metric == metric,
          child: AppCard(
            color: _metric == metric ? AppColors.bluePale : Colors.white,
            onTap: () => _selectMetric(metric),
            child: Row(children: [
              Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      color: AppColors.blueSoft,
                      borderRadius: BorderRadius.circular(13)),
                  child: Icon(icon, color: AppColors.blue, size: 22)),
              const SizedBox(width: 14),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(title,
                        style: const TextStyle(
                            color: AppColors.muted, fontSize: 11)),
                    const SizedBox(height: 5),
                    Text(value,
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w800)),
                  ])),
              const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
            ]),
          ));
}

class _DailyChart extends StatefulWidget {
  const _DailyChart({super.key, required this.metric, required this.series});
  final _Metric metric;
  final AnalyticsSeries series;
  @override
  State<_DailyChart> createState() => _DailyChartState();
}

class _DailyChartState extends State<_DailyChart> {
  int? _selected;
  @override
  void didUpdateWidget(covariant _DailyChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.series != widget.series) _selected = null;
  }

  double? _value(AnalyticsPoint point) => switch (widget.metric) {
        _Metric.count => point.totalAttacks.toDouble(),
        _Metric.intensity => point.averageIntensity,
        _Metric.duration => point.averageDurationMinutes,
      };
  String _label(AnalyticsPoint point) {
    final value = _value(point);
    if (value == null) {
      return widget.metric == _Metric.duration
          ? 'Нет завершённых приступов'
          : 'Нет записей о приступах';
    }
    return switch (widget.metric) {
      _Metric.count => 'Записей о приступах: ${value.toInt()}',
      _Metric.intensity => '${value.toStringAsFixed(1)} / 10',
      _Metric.duration => AnalyticsDto.formatDuration(value),
    };
  }

  @override
  Widget build(BuildContext context) {
    final points = widget.series.points;
    final title = switch (widget.metric) {
      _Metric.count => 'Приступы по дням',
      _Metric.intensity => 'Интенсивность по дням',
      _Metric.duration => 'Длительность по дням',
    };
    final maxValue = widget.metric == _Metric.intensity
        ? 10.0
        : points.fold<double>(1, (max, p) => math.max(max, _value(p) ?? 0));
    final selected = _selected ?? (points.isEmpty ? null : points.length - 1);
    return AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 8),
      Text('Часовой пояс: ${widget.series.timeZone}',
          style: const TextStyle(color: AppColors.muted, fontSize: 10)),
      const SizedBox(height: 16),
      if (selected != null)
        Text(
            '${RussianDate.dayMonth(points[selected].date)} · ${_label(points[selected])}',
            key: const ValueKey('chart-selected-value'),
            style: const TextStyle(fontWeight: FontWeight.w600)),
      const SizedBox(height: 16),
      Text(
          'Шкала: 0–${maxValue.ceil()}${widget.metric == _Metric.duration ? ' мин' : ''}',
          style: const TextStyle(color: AppColors.muted, fontSize: 10)),
      const SizedBox(height: 8),
      SizedBox(
          height: 150,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            reverse: true,
            child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              for (var i = 0; i < points.length; i++)
                Semantics(
                    button: true,
                    selected: i == selected,
                    label:
                        '${RussianDate.dayMonth(points[i].date)}: ${_label(points[i])}',
                    child: InkWell(
                      key: ValueKey('chart-day-$i'),
                      onTap: () => setState(() => _selected = i),
                      borderRadius: BorderRadius.circular(6),
                      child: SizedBox(
                          width: 32,
                          child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Container(
                                    width: 16,
                                    height: _value(points[i]) == null
                                        ? 3
                                        : math.max(
                                            3.0,
                                            _value(points[i])! /
                                                maxValue *
                                                112),
                                    decoration: BoxDecoration(
                                        color: _value(points[i]) == null
                                            ? AppColors.line
                                            : i == selected
                                                ? AppColors.blue
                                                : AppColors.blueSoft,
                                        borderRadius:
                                            BorderRadius.circular(5))),
                                const SizedBox(height: 8),
                                Text('${points[i].date.day}',
                                    style: const TextStyle(fontSize: 10)),
                                Text(
                                    points[i]
                                        .date
                                        .month
                                        .toString()
                                        .padLeft(2, '0'),
                                    style: const TextStyle(
                                        color: AppColors.muted, fontSize: 9)),
                              ])),
                    )),
            ]),
          )),
      const SizedBox(height: 12),
      const Text('Листайте график и нажимайте на день, чтобы увидеть значение.',
          style: TextStyle(color: AppColors.muted, fontSize: 11)),
      if (widget.metric == _Metric.duration)
        const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('Среднее только по завершённым приступам.',
                style: TextStyle(color: AppColors.muted, fontSize: 11))),
    ]));
  }
}
