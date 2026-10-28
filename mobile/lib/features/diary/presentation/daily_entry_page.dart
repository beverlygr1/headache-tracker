import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/utils/russian_date.dart';
import '../../tracker/presentation/widgets/common.dart';
import '../../tracker/state/tracker_controller.dart';
import '../data/daily_entry.dart';
import '../data/diary_repository.dart';

class DailyEntryPage extends StatefulWidget {
  const DailyEntryPage({
    required this.repository,
    required this.date,
    super.key,
  });
  final DiaryRepository repository;
  final DateTime date;

  @override
  State<DailyEntryPage> createState() => _DailyEntryPageState();
}

class _DailyEntryPageState extends State<DailyEntryPage> {
  final _formKey = GlobalKey<FormState>();
  final _sleep = TextEditingController();
  final _water = TextEditingController();
  final _caffeine = TextEditingController();
  bool? _headachePresent;
  int? _sleepQuality;
  int? _stress;
  bool _loading = true;
  bool _saving = false;
  bool _hasExistingEntry = false;
  String? _loadError;
  String? _saveError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _sleep.dispose();
    _water.dispose();
    _caffeine.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final entry = await widget.repository.fetchByDate(widget.date);
      if (!mounted) return;
      _hasExistingEntry = entry != null;
      _sleep.text = entry?.sleepHours == null
          ? ''
          : DailyEntry.formatHours(entry!.sleepHours!);
      _water.text = entry?.waterMl?.toString() ?? '';
      _caffeine.text = entry?.caffeineIntake?.toString() ?? '';
      _headachePresent = entry?.headachePresent;
      _sleepQuality = entry?.sleepQuality;
      _stress = entry?.stressLevel;
    } catch (error) {
      if (mounted) _loadError = describeError(error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    if (!_hasExistingEntry &&
        _sleep.text.trim().isEmpty &&
        _water.text.trim().isEmpty &&
        _caffeine.text.trim().isEmpty &&
        _headachePresent == null &&
        _sleepQuality == null &&
        _stress == null) {
      setState(() => _saveError = 'Заполните хотя бы один пункт');
      return;
    }
    setState(() {
      _saving = true;
      _saveError = null;
    });
    FocusManager.instance.primaryFocus?.unfocus();
    try {
      final entry = await widget.repository.save(
        DailyEntry(
          date: widget.date,
          headachePresent: _headachePresent,
          sleepHours: double.tryParse(_sleep.text.trim().replaceAll(',', '.')),
          sleepQuality: _sleepQuality,
          waterMl: int.tryParse(_water.text.trim()),
          caffeineIntake: int.tryParse(_caffeine.text.trim()),
          stressLevel: _stress,
        ),
      );
      if (mounted) Navigator.of(context).pop(entry);
    } catch (error) {
      if (mounted) setState(() => _saveError = describeError(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        appBar: const BackTitleBar(title: 'Самочувствие'),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _loadError != null
                ? ErrorRetryView(message: _loadError!, onRetry: _load)
                : Form(
                    key: _formKey,
                    child: ListView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                      children: [
                        Text(
                          RussianDate.dayMonth(widget.date),
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Отмечайте и дни без боли. Можно заполнить только то, что помните.',
                          style: TextStyle(color: AppColors.muted, height: 1.5),
                        ),
                        const SizedBox(height: 24),
                        AppCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _FieldTitle(
                                icon: Icons.favorite_border_rounded,
                                title: RussianDate.isSameDay(
                                  widget.date,
                                  DateTime.now(),
                                )
                                    ? 'Была ли сегодня головная боль?'
                                    : 'Была ли в этот день головная боль?',
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  ChoiceChip(
                                    key: const ValueKey('headache-yes'),
                                    label: const Text('Да, была'),
                                    selected: _headachePresent == true,
                                    showCheckmark: false,
                                    selectedColor: AppColors.blueSoft,
                                    onSelected: _saving
                                        ? null
                                        : (selected) => setState(
                                              () => _headachePresent =
                                                  selected ? true : null,
                                            ),
                                  ),
                                  ChoiceChip(
                                    key: const ValueKey('headache-no'),
                                    label: const Text('Нет, не было'),
                                    selected: _headachePresent == false,
                                    showCheckmark: false,
                                    selectedColor: AppColors.mint,
                                    onSelected: _saving
                                        ? null
                                        : (selected) => setState(
                                              () => _headachePresent =
                                                  selected ? false : null,
                                            ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        AppCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const _FieldTitle(
                                icon: Icons.bedtime_outlined,
                                title: 'Сколько вы спали?',
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                key: const ValueKey('sleep-hours-field'),
                                controller: _sleep,
                                enabled: !_saving,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                                textInputAction: TextInputAction.done,
                                onFieldSubmitted: (_) => FocusManager
                                    .instance.primaryFocus
                                    ?.unfocus(),
                                decoration: const InputDecoration(
                                  labelText: 'Продолжительность сна',
                                  hintText: 'Например, 7,5',
                                  suffixText: 'часы',
                                ),
                                validator: (text) {
                                  if (text == null || text.trim().isEmpty) {
                                    return null;
                                  }
                                  final value = double.tryParse(
                                    text.trim().replaceAll(',', '.'),
                                  );
                                  return value == null ||
                                          !value.isFinite ||
                                          value < 0 ||
                                          value > 24
                                      ? 'Введите число от 0 до 24'
                                      : null;
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        _RatingCard(
                          title: 'Как вы спали?',
                          hint: '1 — очень плохо, 10 — отлично',
                          icon: Icons.nights_stay_outlined,
                          value: _sleepQuality,
                          enabled: !_saving,
                          keyPrefix: 'sleep-quality',
                          onChanged: (value) =>
                              setState(() => _sleepQuality = value),
                        ),
                        const SizedBox(height: 16),
                        WaterTrackerCard(controller: _water, enabled: !_saving),
                        const SizedBox(height: 16),
                        CaffeineTrackerCard(
                            controller: _caffeine, enabled: !_saving),
                        const SizedBox(height: 16),
                        _RatingCard(
                          title: 'Насколько напряжённым был день?',
                          hint: '1 — спокойно, 10 — сильный стресс',
                          icon: Icons.spa_outlined,
                          value: _stress,
                          enabled: !_saving,
                          keyPrefix: 'stress',
                          onChanged: (value) => setState(() => _stress = value),
                        ),
                        const SizedBox(height: 16),
                        const AppCard(
                          color: AppColors.mint,
                          child: Text(
                            'Запись можно открыть и дополнить позже. '
                            'Незаполненные пункты не считаются нулевыми значениями.',
                          ),
                        ),
                      ],
                    ),
                  ),
        bottomNavigationBar: _loading || _loadError != null
            ? null
            : Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.viewInsetsOf(context).bottom,
                ),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_saveError != null) ...[
                          Semantics(
                            liveRegion: true,
                            child: Text(
                              _saveError!,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],
                        PrimaryActionButton(
                          label:
                              _saving ? 'Сохраняем…' : 'Сохранить самочувствие',
                          onPressed: _saving ? null : _save,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

class _FieldTitle extends StatelessWidget {
  const _FieldTitle({required this.icon, required this.title});
  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, color: AppColors.blue, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(title, style: Theme.of(context).textTheme.titleMedium),
          ),
        ],
      );
}

class _RatingCard extends StatelessWidget {
  const _RatingCard({
    required this.title,
    required this.hint,
    required this.icon,
    required this.value,
    required this.enabled,
    required this.keyPrefix,
    required this.onChanged,
  });

  final String title;
  final String hint;
  final IconData icon;
  final int? value;
  final bool enabled;
  final String keyPrefix;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) => AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _FieldTitle(icon: icon, title: title),
            const SizedBox(height: 8),
            Text(
              hint,
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var level = 1; level <= 10; level++)
                  ChoiceChip(
                    key: ValueKey('$keyPrefix-$level'),
                    label: Text('$level'),
                    selected: value == level,
                    showCheckmark: false,
                    selectedColor: AppColors.blueSoft,
                    onSelected: enabled
                        ? (selected) => onChanged(selected ? level : null)
                        : null,
                    tooltip: '$title: $level из 10',
                  ),
              ],
            ),
          ],
        ),
      );
}

class WaterTrackerCard extends StatelessWidget {
  const WaterTrackerCard(
      {super.key, required this.controller, this.enabled = true});
  final TextEditingController controller;
  final bool enabled;
  @override
  Widget build(BuildContext context) => _QuantityTrackerCard(
      title: 'Сколько воды выпили?',
      label: 'Количество воды',
      hint: 'Для быстрого ввода: один стакан — 250 мл.',
      prefix: 'water',
      icon: Icons.water_drop_outlined,
      unit: 'мл',
      step: 250,
      presets: const [250, 500, 1000, 1500, 2000],
      controller: controller,
      enabled: enabled);
}

class CaffeineTrackerCard extends StatelessWidget {
  const CaffeineTrackerCard(
      {super.key, required this.controller, this.enabled = true});
  final TextEditingController controller;
  final bool enabled;
  @override
  Widget build(BuildContext context) => _QuantityTrackerCard(
      title: 'Сколько кофеина употребили?',
      label: 'Количество кофеина',
      hint:
          'Быстрый ввод: условная чашка — 100 мг. Точное количество можно указать вручную.',
      prefix: 'caffeine',
      icon: Icons.coffee_outlined,
      unit: 'мг',
      step: 100,
      presets: const [0, 50, 100, 200],
      controller: controller,
      enabled: enabled);
}

class _QuantityTrackerCard extends StatelessWidget {
  const _QuantityTrackerCard(
      {required this.title,
      required this.label,
      required this.hint,
      required this.prefix,
      required this.icon,
      required this.unit,
      required this.step,
      required this.presets,
      required this.controller,
      required this.enabled});
  final String title, label, hint, prefix, unit;
  final IconData icon;
  final int step;
  final List<int> presets;
  final TextEditingController controller;
  final bool enabled;
  static const _max = 2147483647;

  void _set(int value) {
    controller.value = TextEditingValue(
        text: '$value',
        selection: TextSelection.collapsed(offset: '$value'.length));
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<
          TextEditingValue>(
      valueListenable: controller,
      builder: (context, text, _) {
        final current = int.tryParse(text.text.trim());
        final valid = text.text.trim().isEmpty ||
            current != null && current >= 0 && current <= _max;
        return AppCard(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _FieldTitle(icon: icon, title: title),
          const SizedBox(height: 10),
          Text(hint,
              style: const TextStyle(color: AppColors.muted, fontSize: 11)),
          const SizedBox(height: 14),
          TextFormField(
            key: ValueKey('$prefix-field'),
            controller: controller,
            enabled: enabled,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) =>
                FocusManager.instance.primaryFocus?.unfocus(),
            decoration: InputDecoration(
                labelText: label, suffixText: unit, hintText: 'Не указано'),
            validator: (text) {
              if (text == null || text.trim().isEmpty) return null;
              final number = int.tryParse(text.trim());
              return number == null || number < 0 || number > _max
                  ? 'Введите целое неотрицательное число'
                  : null;
            },
          ),
          const SizedBox(height: 10),
          Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                IconButton.filledTonal(
                    key: ValueKey('$prefix-decrease'),
                    tooltip: 'Уменьшить на $step $unit',
                    onPressed: enabled && valid && (current ?? 0) > 0
                        ? () => _set(((current ?? 0) - step).clamp(0, _max))
                        : null,
                    icon: const Icon(Icons.remove_rounded)),
                Text('$step $unit',
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600)),
                IconButton.filledTonal(
                    key: ValueKey('$prefix-increase'),
                    tooltip: 'Добавить $step $unit',
                    onPressed: enabled && valid && (current ?? 0) <= _max - step
                        ? () => _set((current ?? 0) + step)
                        : null,
                    icon: const Icon(Icons.add_rounded)),
                TextButton(
                    key: ValueKey('clear-$prefix'),
                    onPressed: enabled && text.text.isNotEmpty
                        ? controller.clear
                        : null,
                    child: const Text('Очистить')),
              ]),
          const SizedBox(height: 6),
          Wrap(spacing: 8, runSpacing: 6, children: [
            for (final preset in presets)
              ChoiceChip(
                  key: ValueKey('$prefix-preset-$preset'),
                  label: Text('$preset $unit'),
                  selected: current == preset,
                  onSelected: enabled ? (_) => _set(preset) : null,
                  selectedColor: AppColors.blueSoft,
                  showCheckmark: false,
                  labelStyle:
                      const TextStyle(fontFamily: 'Onest', fontSize: 11),
                  side: BorderSide.none,
                  backgroundColor: AppColors.background),
          ]),
        ]));
      });
}
