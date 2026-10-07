import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/utils/russian_date.dart';
import '../../tracker/presentation/widgets/common.dart';
import '../../tracker/state/tracker_controller.dart';
import '../data/daily_entry.dart';
import '../data/diary_repository.dart';

class DailyEntryPage extends StatefulWidget {
  const DailyEntryPage(
      {required this.repository, required this.date, super.key});
  final DiaryRepository repository;
  final DateTime date;

  @override
  State<DailyEntryPage> createState() => _DailyEntryPageState();
}

class _DailyEntryPageState extends State<DailyEntryPage> {
  final _formKey = GlobalKey<FormState>();
  final _sleep = TextEditingController();
  final _water = TextEditingController();
  int? _stress;
  bool _loading = true;
  bool _saving = false;
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
      _sleep.text = entry?.sleepHours == null
          ? ''
          : DailyEntry.formatHours(entry!.sleepHours!);
      _water.text = entry?.waterMl?.toString() ?? '';
      _stress = entry?.stressLevel;
    } catch (error) {
      if (mounted) _loadError = describeError(error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    if (_sleep.text.trim().isEmpty &&
        _water.text.trim().isEmpty &&
        _stress == null) {
      setState(() => _saveError = 'Заполните хотя бы один пункт');
      return;
    }
    setState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      final entry = await widget.repository.save(DailyEntry(
        date: widget.date,
        sleepHours: double.tryParse(_sleep.text.trim().replaceAll(',', '.')),
        waterMl: int.tryParse(_water.text.trim()),
        stressLevel: _stress,
      ));
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
                      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                      children: [
                        Text(RussianDate.dayMonth(widget.date),
                            style: Theme.of(context).textTheme.headlineSmall),
                        const SizedBox(height: 10),
                        const Text(
                            'Отмечайте и дни без боли. Можно заполнить только то, что помните.',
                            style:
                                TextStyle(color: AppColors.muted, height: 1.5)),
                        const SizedBox(height: 24),
                        AppCard(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              const _FieldTitle(
                                  icon: Icons.bedtime_outlined,
                                  title: 'Сколько вы спали?'),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _sleep,
                                enabled: !_saving,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                textInputAction: TextInputAction.next,
                                decoration: const InputDecoration(
                                    labelText: 'Продолжительность сна',
                                    hintText: 'Например, 7,5',
                                    suffixText: 'часы',
                                    border: OutlineInputBorder()),
                                validator: (text) {
                                  if (text == null || text.trim().isEmpty) {
                                    return null;
                                  }
                                  final value = double.tryParse(
                                      text.trim().replaceAll(',', '.'));
                                  return value == null ||
                                          !value.isFinite ||
                                          value < 0 ||
                                          value > 24
                                      ? 'Введите число от 0 до 24'
                                      : null;
                                },
                              ),
                            ])),
                        const SizedBox(height: 16),
                        AppCard(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              const _FieldTitle(
                                  icon: Icons.water_drop_outlined,
                                  title: 'Сколько воды выпили?'),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _water,
                                enabled: !_saving,
                                keyboardType: TextInputType.number,
                                textInputAction: TextInputAction.done,
                                decoration: const InputDecoration(
                                    labelText: 'Количество воды',
                                    hintText: 'Например, 1500',
                                    suffixText: 'мл',
                                    border: OutlineInputBorder()),
                                validator: (text) {
                                  if (text == null || text.trim().isEmpty) {
                                    return null;
                                  }
                                  final value = int.tryParse(text.trim());
                                  return value == null ||
                                          value < 0 ||
                                          value > 2147483647
                                      ? 'Введите целое неотрицательное число'
                                      : null;
                                },
                              ),
                            ])),
                        const SizedBox(height: 16),
                        AppCard(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              const _FieldTitle(
                                  icon: Icons.spa_outlined,
                                  title: 'Насколько напряжённым был день?'),
                              const SizedBox(height: 8),
                              const Text('1 — спокойно, 10 — сильный стресс',
                                  style: TextStyle(
                                      color: AppColors.muted, fontSize: 12)),
                              const SizedBox(height: 12),
                              Wrap(spacing: 8, runSpacing: 8, children: [
                                for (var level = 1; level <= 10; level++)
                                  ChoiceChip(
                                    label: Text('$level'),
                                    selected: _stress == level,
                                    showCheckmark: false,
                                    selectedColor: AppColors.blueSoft,
                                    onSelected: _saving
                                        ? null
                                        : (selected) => setState(() =>
                                            _stress = selected ? level : null),
                                    tooltip: 'Уровень стресса $level из 10',
                                  ),
                              ]),
                            ])),
                        const SizedBox(height: 16),
                        const AppCard(
                            color: AppColors.mint,
                            child: Text(
                                'Запись можно открыть и дополнить позже. '
                                'Незаполненные пункты не считаются нулевыми значениями.')),
                      ],
                    ),
                  ),
        bottomNavigationBar: _loading || _loadError != null
            ? null
            : SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    if (_saveError != null) ...[
                      Semantics(
                          liveRegion: true,
                          child: Text(_saveError!,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: Theme.of(context).colorScheme.error))),
                      const SizedBox(height: 10),
                    ],
                    PrimaryActionButton(
                        label:
                            _saving ? 'Сохраняем…' : 'Сохранить самочувствие',
                        onPressed: _saving ? null : _save),
                  ]),
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
  Widget build(BuildContext context) => Row(children: [
        Icon(icon, color: AppColors.blue, size: 22),
        const SizedBox(width: 10),
        Expanded(
            child: Text(title, style: Theme.of(context).textTheme.titleMedium)),
      ]);
}
