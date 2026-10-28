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
  int? _waterMl;
  int? _caffeineMg;
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
      _waterMl = entry?.waterMl;
      _caffeineMg = entry?.caffeineIntake;
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
        _waterMl == null &&
        _caffeineMg == null &&
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
          waterMl: _waterMl,
          caffeineIntake: _caffeineMg,
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
                                  border: OutlineInputBorder(),
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
                        WaterTrackerCard(
                          waterMl: _waterMl ?? 0,
                          onChanged: (val) => setState(() => _waterMl = val),
                        ),
                        const SizedBox(height: 16),
                        CaffeineTrackerCard(
                          caffeineMg: _caffeineMg ?? 0,
                          onChanged: (val) => setState(() => _caffeineMg = val),
                        ),
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
  final int waterMl;
  final ValueChanged<int> onChanged;

  const WaterTrackerCard({
    super.key,
    required this.waterMl,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final glasses = (waterMl / 250).round();

    return Card(
      elevation: 0,
      color: Colors.blue.shade50.withOpacity(0.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.water_drop_rounded, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  'Сколько воды выпили?',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$waterMl мл',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                    ),
                    Text(
                      '$glasses ${glasses == 1 ? "стакан" : (glasses >= 2 && glasses <= 4) ? "стакана" : "стаканов"}',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                    ),
                  ],
                ),
                Row(
                  children: [
                    IconButton.filledTonal(
                      onPressed: waterMl >= 250 ? () => onChanged(waterMl - 250) : null,
                      icon: const Icon(Icons.remove),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: () => onChanged(waterMl + 250),
                      icon: const Icon(Icons.add),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [500, 1000, 1500, 2000].map((preset) {
                final isSelected = waterMl == preset;
                return ChoiceChip(
                  label: Text('$preset мл'),
                  selected: isSelected,
                  onSelected: (_) => onChanged(preset),
                  selectedColor: Colors.blue.shade200,
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class CaffeineTrackerCard extends StatelessWidget {
  final int caffeineMg;
  final ValueChanged<int> onChanged;

  const CaffeineTrackerCard({
    super.key,
    required this.caffeineMg,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cups = (caffeineMg / 100).round();

    return Card(
      elevation: 0,
      color: Colors.orange.shade50.withOpacity(0.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.coffee_rounded, color: Colors.brown),
                SizedBox(width: 8),
                Text(
                  'Сколько кофеина употребили?',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$cups ${cups == 1 ? "чашка" : (cups >= 2 && cups <= 4) ? "чашки" : "чашек"}',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.brown),
                    ),
                    Text(
                      '~$caffeineMg мг кофеина',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                    ),
                  ],
                ),
                Row(
                  children: [
                    IconButton.filledTonal(
                      onPressed: caffeineMg >= 100 ? () => onChanged(caffeineMg - 100) : null,
                      icon: const Icon(Icons.remove),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: () => onChanged(caffeineMg + 100),
                      icon: const Icon(Icons.add),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [0, 100, 200, 300].map((mg) {
                final c = (mg / 100).round();
                final isSelected = caffeineMg == mg;
                return ChoiceChip(
                  label: Text(mg == 0 ? 'Не пил' : '$c ${c == 1 ? "чашка" : "чашки"}'),
                  selected: isSelected,
                  onSelected: (_) => onChanged(mg),
                  selectedColor: Colors.orange.shade200,
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
