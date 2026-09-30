import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../../../core/utils/russian_date.dart';
import '../../domain/attack_record.dart';
import '../../state/tracker_controller.dart';
import '../widgets/common.dart';

class AttackEntryPage extends StatefulWidget {
  const AttackEntryPage({
    required this.controller,
    this.initialRecord,
    super.key,
  });

  final TrackerController controller;
  final AttackRecord? initialRecord;

  @override
  State<AttackEntryPage> createState() => _AttackEntryPageState();
}

class _AttackEntryPageState extends State<AttackEntryPage> {
  late DateTime _startTime;
  late int _intensity;
  late String _painLocation;
  late Set<String> _symptoms;

  final List<String> _painOptions = ['Лоб', 'Виски', 'Затылок'];
  final List<String> _symptomOptions = ['Тошнота', 'Свет мешает'];

  @override
  void initState() {
    super.initState();
    final record = widget.initialRecord;
    final now = DateTime.now();
    _startTime = record?.startTime ??
        DateTime(now.year, now.month, now.day, now.hour, now.minute);
    _intensity = record?.intensity ?? 6;
    _painLocation = record?.painLocation ?? 'Виски';
    _symptoms = Set.of(record?.symptoms ?? const ['Свет мешает']);

    if (!_painOptions.contains(_painLocation)) {
      _painOptions.add(_painLocation);
    }
    for (final symptom in _symptoms) {
      if (!_symptomOptions.contains(symptom)) {
        _symptomOptions.add(symptom);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final saving = widget.controller.isSaving;
    return Scaffold(
      appBar: const BackTitleBar(title: 'Запись приступа'),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                children: [
                  AppCard(
                    onTap: _selectStartTime,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 2),
                          child: Icon(
                            Icons.schedule_rounded,
                            color: AppColors.muted,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 13),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Когда началась боль?',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                RussianDate.isSameDay(
                                        _startTime, DateTime.now())
                                    ? 'Сегодня, ${RussianDate.time(_startTime)}'
                                    : '${RussianDate.dayMonth(_startTime)}, '
                                        '${RussianDate.time(_startTime)}',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 7),
                              Text(
                                widget.initialRecord?.isActive == false
                                    ? 'Время начала сохранённого приступа'
                                    : 'Приступ ещё продолжается',
                                style: const TextStyle(
                                  color: AppColors.blue,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.edit_outlined,
                          color: AppColors.muted,
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Насколько сильно болит?',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Text(
                              '$_intensity',
                              style: const TextStyle(
                                fontSize: 28,
                                height: 1,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(width: 7),
                            const Expanded(
                              child: Text(
                                'из 10 · ощутимая боль',
                                style: TextStyle(
                                  color: AppColors.muted,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                            _IntensityButton(
                              icon: Icons.remove_rounded,
                              onPressed: _intensity > 1
                                  ? () => setState(() => _intensity--)
                                  : null,
                            ),
                            const SizedBox(width: 8),
                            _IntensityButton(
                              icon: Icons.add_rounded,
                              onPressed: _intensity < 10
                                  ? () => setState(() => _intensity++)
                                  : null,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: List.generate(10, (index) {
                            final active = index < _intensity;
                            return Expanded(
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 160),
                                height: 7,
                                margin:
                                    EdgeInsets.only(right: index == 9 ? 0 : 5),
                                decoration: BoxDecoration(
                                  color: active
                                      ? AppColors.blue
                                      : const Color(0xFFE7ECF4),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            );
                          }),
                        ),
                        const SizedBox(height: 9),
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '1 · слабая',
                              style: TextStyle(
                                color: AppColors.muted,
                                fontSize: 9,
                              ),
                            ),
                            Text(
                              '10 · очень сильная',
                              style: TextStyle(
                                color: AppColors.muted,
                                fontSize: 9,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _ChoiceSection(
                    title: 'Где болит?',
                    options: _painOptions,
                    selected: {_painLocation},
                    onSelected: (option) {
                      setState(() => _painLocation = option);
                    },
                    onAdd: () => _addCustomOption(isPainLocation: true),
                  ),
                  const SizedBox(height: 14),
                  _ChoiceSection(
                    title: 'Что ещё чувствуете?',
                    options: _symptomOptions,
                    selected: _symptoms,
                    onSelected: (option) {
                      setState(() {
                        if (!_symptoms.add(option)) {
                          _symptoms.remove(option);
                        }
                      });
                    },
                    onAdd: () => _addCustomOption(isPainLocation: false),
                  ),
                  const SizedBox(height: 20),
                  const Center(
                    child: Text(
                      'Дополнить запись можно позже',
                      style: TextStyle(
                        color: AppColors.muted,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
              child: PrimaryActionButton(
                label: saving ? 'Сохранение…' : 'Сохранить приступ',
                onPressed: saving ? null : _save,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectStartTime() async {
    final result = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_startTime),
      helpText: 'Время начала боли',
      cancelText: 'Отмена',
      confirmText: 'Готово',
    );
    if (result == null || !mounted) return;
    setState(() {
      _startTime = DateTime(
        _startTime.year,
        _startTime.month,
        _startTime.day,
        result.hour,
        result.minute,
      );
    });
  }

  Future<void> _addCustomOption({required bool isPainLocation}) async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isPainLocation ? 'Добавить область' : 'Добавить симптом'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: 'Введите название'),
          onSubmitted: (value) => Navigator.of(context).pop(value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Добавить'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (value == null || value.isEmpty || !mounted) return;
    setState(() {
      if (isPainLocation) {
        if (!_painOptions.contains(value)) _painOptions.add(value);
        _painLocation = value;
      } else {
        if (!_symptomOptions.contains(value)) _symptomOptions.add(value);
        _symptoms.add(value);
      }
    });
  }

  Future<void> _save() async {
    // Перерисовать кнопку в состоянии «Сохранение…».
    final save = widget.controller.saveAttack(
      id: widget.initialRecord?.id,
      startTime: _startTime,
      intensity: _intensity,
      painLocation: _painLocation,
      symptoms: _symptoms.toList(),
    );
    setState(() {});
    try {
      await save;
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {});
      showErrorSnackBar(context, describeError(error));
    }
  }
}

class _IntensityButton extends StatelessWidget {
  const _IntensityButton({
    required this.icon,
    required this.onPressed,
  });

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: AppColors.blueSoft,
        foregroundColor: AppColors.blue,
        disabledBackgroundColor: AppColors.line,
        disabledForegroundColor: AppColors.muted,
        minimumSize: const Size(38, 38),
      ),
      icon: Icon(icon, size: 20),
    );
  }
}

class _ChoiceSection extends StatelessWidget {
  const _ChoiceSection({
    required this.title,
    required this.options,
    required this.selected,
    required this.onSelected,
    required this.onAdd,
  });

  final String title;
  final List<String> options;
  final Set<String> selected;
  final ValueChanged<String> onSelected;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 13),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final option in options)
                ChoiceChip(
                  label: Text(option),
                  selected: selected.contains(option),
                  onSelected: (_) => onSelected(option),
                  showCheckmark: false,
                  selectedColor: AppColors.blueSoft,
                  backgroundColor: const Color(0xFFF1F3F7),
                  side: BorderSide.none,
                  labelStyle: TextStyle(
                    color: selected.contains(option)
                        ? AppColors.blue
                        : AppColors.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                ),
              ActionChip(
                avatar: const Icon(Icons.add_rounded, size: 18),
                label: const SizedBox.shrink(),
                onPressed: onAdd,
                backgroundColor: Colors.white,
                side: const BorderSide(
                  color: AppColors.blue,
                  style: BorderStyle.solid,
                ),
                shape: const StadiumBorder(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
