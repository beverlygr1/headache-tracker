import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../../../core/utils/pain_intensity.dart';
import '../../../../core/utils/russian_date.dart';
import '../../domain/attack_draft.dart';
import '../../domain/attack_record.dart';
import '../../state/tracker_controller.dart';
import '../widgets/common.dart';
import 'attack_review_page.dart';
import 'pain_zones_page.dart';

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
  late Set<String> _painLocations;
  late Set<String> _symptoms;
  late String? _painType;
  late Set<String> _medications;
  List<String> _selectedMedications = [];
  late Set<String> _reliefFactors;
  bool _showDetails = false;
  bool _openingMap = false;
  bool _openingReview = false;

  final List<String> _painOptions = ['Лоб', 'Виски', 'Темя', 'Затылок'];
  final List<String> _symptomOptions = ['Тошнота', 'Свет мешает'];
  final List<String> _painTypeOptions = [
    'Пульсирующая',
    'Давящая',
    'Ноющая',
    'Острая',
  ];
  final List<String> _medicationOptions = [];
  final List<String> _reliefOptions = ['Отдых', 'Сон', 'Тишина', 'Вода'];

  @override
  void initState() {
    super.initState();
    final record = widget.initialRecord;
    final now = DateTime.now();
    _startTime = record?.startTime ??
        DateTime(now.year, now.month, now.day, now.hour, now.minute);
    _intensity = record?.intensity ?? 6;
    _painLocations = Set.of(
      record == null ? const <String>[] : AttackDraft.zonesFromRecord(record),
    );
    _symptoms = Set.of(record?.symptoms ?? const <String>[]);
    _painType = record?.painType;
    _medications = Set.of(record?.medications ?? const <String>[]);
    _reliefFactors = Set.of(record?.reliefFactors ?? const <String>[]);
    _showDetails = record != null;

    for (final zone in _painLocations) {
      if (!_painOptions.contains(zone)) _painOptions.add(zone);
    }
    for (final symptom in _symptoms) {
      if (!_symptomOptions.contains(symptom)) {
        _symptomOptions.add(symptom);
      }
    }
    if (_painType != null && !_painTypeOptions.contains(_painType)) {
      _painTypeOptions.add(_painType!);
    }
    for (final medication in _medications) {
      if (!_medicationOptions.contains(medication)) {
        _medicationOptions.add(medication);
      }
    }
    for (final factor in _reliefFactors) {
      if (!_reliefOptions.contains(factor)) _reliefOptions.add(factor);
    }
  }

  @override
  Widget build(BuildContext context) {
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
                  const AppCard(
                    color: AppColors.blueSoft,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Быстрая запись',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Укажите время и силу боли. Остальное можно добавить позже.',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
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
                                  _startTime,
                                  DateTime.now(),
                                )
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
                            Expanded(
                              child: Text(
                                'из 10 · ${PainIntensity.description(_intensity).toLowerCase()}',
                                style: const TextStyle(
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
                                margin: EdgeInsets.only(
                                  right: index == 9 ? 0 : 5,
                                ),
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
                  AppCard(
                    key: const ValueKey('toggle-attack-details'),
                    onTap: () => setState(() => _showDetails = !_showDetails),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Дополнительные сведения',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              SizedBox(height: 5),
                              Text(
                                'Характер боли, симптомы, препараты и облегчение',
                                style: TextStyle(
                                  color: AppColors.muted,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          _showDetails
                              ? Icons.expand_less_rounded
                              : Icons.expand_more_rounded,
                          color: AppColors.blue,
                        ),
                      ],
                    ),
                  ),
                  if (_showDetails) ...[
                    const SizedBox(height: 14),
                    _ChoiceSection(
                      title: 'Характер боли',
                      options: _painTypeOptions,
                      selected: _painType == null
                          ? const <String>{}
                          : <String>{_painType!},
                      onSelected: (option) => setState(() {
                        _painType = _painType == option ? null : option;
                      }),
                    ),
                    const SizedBox(height: 14),
                    _ChoiceSection(
                      title: 'Где болит?',
                      options: _painOptions,
                      selected: _painLocations,
                      onSelected: _togglePainZone,
                      onAdd: () => _addCustomOption(
                        title: 'Добавить область',
                        options: _painOptions,
                        selected: _painLocations,
                        maxLength: 120,
                        isPainLocation: true,
                      ),
                      onOpenMap: _choosePainZones,
                    ),
                    const SizedBox(height: 14),
                    _ChoiceSection(
                      title: 'Что ещё чувствуете?',
                      options: _symptomOptions,
                      selected: _symptoms,
                      onSelected: (option) => _toggle(_symptoms, option),
                      onAdd: () => _addCustomOption(
                        title: 'Добавить симптом',
                        options: _symptomOptions,
                        selected: _symptoms,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Card(
                      elevation: 0,
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: MedicationSelector(
                          selectedMedications: _selectedMedications,
                          onChanged: (newList) {
                            setState(() => _selectedMedications = newList);
                          },
                          onSearch: (query) async {
                            final preset = [
                              'Ибупрофен',
                              'Парацетамол',
                              'Суматриптан',
                              'Нурофен',
                              'Миг 400',
                              'Аспирин',
                              'Пенталгин',
                              'Солпадеин',
                            ];
                            return preset
                                .where((m) => m
                                    .toLowerCase()
                                    .contains(query.toLowerCase()))
                                .toList();
                          },
                        ),
                      ),
                    ),
                    //const SizedBox(height: 20),
                    // _ChoiceSection(
                    //   title: 'Препараты',
                    //   options: _medicationOptions,
                    //   selected: _medications,
                    //   onSelected: (option) => _toggle(_medications, option),
                    //   onAdd: () => _addCustomOption(
                    //     title: 'Добавить препарат',
                    //     options: _medicationOptions,
                    //     selected: _medications,
                    //     maxLength: 80,
                    //   ),
                    // ),
                    const SizedBox(height: 14),
                    _ChoiceSection(
                      title: 'Что помогло?',
                      options: _reliefOptions,
                      selected: _reliefFactors,
                      onSelected: (option) => _toggle(_reliefFactors, option),
                      onAdd: () => _addCustomOption(
                        title: 'Добавить способ облегчения',
                        options: _reliefOptions,
                        selected: _reliefFactors,
                        maxLength: 80,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
              child: PrimaryActionButton(
                label: 'Продолжить',
                onPressed: _openingMap || _openingReview ? null : _openReview,
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

  Future<void> _addCustomOption({
    required String title,
    required List<String> options,
    required Set<String> selected,
    int? maxLength,
    bool isPainLocation = false,
  }) async {
    final value = await showDialog<String>(
      context: context,
      builder: (context) =>
          _AddOptionDialog(title: title, maxLength: maxLength),
    );

    if (value == null || value.isEmpty || !mounted) return;
    if (isPainLocation && {...selected, value}.join(', ').length > 120) {
      showErrorSnackBar(context, 'Названия выбранных зон слишком длинные');
      return;
    }
    setState(() {
      if (!options.contains(value)) options.add(value);
      selected.add(value);
    });
  }

  Future<void> _addCustomPainType() async {
    final value = await showDialog<String>(
      context: context,
      builder: (context) => const _AddOptionDialog(
        title: 'Добавить характер боли',
        maxLength: 80,
      ),
    );
    if (value == null || value.isEmpty || !mounted) return;
    setState(() {
      if (!_painTypeOptions.contains(value)) _painTypeOptions.add(value);
      _painType = value;
    });
  }

  void _toggle(Set<String> selected, String value) {
    setState(() {
      if (!selected.add(value)) selected.remove(value);
    });
  }

  void _togglePainZone(String zone) {
    if (!_painLocations.contains(zone) &&
        [..._painLocations, zone].join(', ').length > 120) {
      showErrorSnackBar(context, 'Названия выбранных зон слишком длинные');
      return;
    }
    setState(() {
      if (!_painLocations.add(zone)) _painLocations.remove(zone);
    });
  }

  Future<bool> _choosePainZones() async {
    if (_openingMap) return false;
    setState(() => _openingMap = true);
    try {
      final selected = await Navigator.of(context).push<List<String>>(
        MaterialPageRoute(
          builder: (context) =>
              PainZonesPage(initialZones: _painLocations.toList()),
        ),
      );
      if (selected == null || !mounted) return false;
      setState(() {
        _painLocations = Set.of(selected);
        for (final zone in selected) {
          if (!_painOptions.contains(zone)) _painOptions.add(zone);
        }
      });
      return true;
    } finally {
      if (mounted) setState(() => _openingMap = false);
    }
  }

  Future<void> _openReview() async {
    if (_openingReview || _openingMap) return;
    setState(() => _openingReview = true);
    try {
      if (!mounted) return;
      final saved = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (context) => AttackReviewPage(
            controller: widget.controller,
            draft: AttackDraft(
              id: widget.initialRecord?.id,
              startTime: _startTime,
              intensity: _intensity,
              painZones: _painLocations,
              symptoms: _symptoms,
              painType: _painType,
              medications: _selectedMedications,
              // medications: _medications,
              reliefFactors: _reliefFactors,
            ),
          ),
        ),
      );
      if (saved == true && mounted) Navigator.of(context).pop(true);
    } finally {
      if (mounted) setState(() => _openingReview = false);
    }
  }
}

/// Диалог владеет своим контроллером: после `pop` он ещё анимирует закрытие
/// и перестраивает поле ввода, поэтому освобождать контроллер снаружи сразу
/// после `showDialog` нельзя.
class _AddOptionDialog extends StatefulWidget {
  const _AddOptionDialog({required this.title, this.maxLength});

  final String title;
  final int? maxLength;

  @override
  State<_AddOptionDialog> createState() => _AddOptionDialogState();
}

class _AddOptionDialogState extends State<_AddOptionDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() => Navigator.of(context).pop(_controller.text.trim());

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        maxLength: widget.maxLength,
        decoration: const InputDecoration(hintText: 'Введите название'),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Отмена'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Добавить')),
      ],
    );
  }
}

class _IntensityButton extends StatelessWidget {
  const _IntensityButton({required this.icon, required this.onPressed});

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
    this.onAdd,
    this.onOpenMap,
  });

  final String title;
  final List<String> options;
  final Set<String> selected;
  final ValueChanged<String> onSelected;
  final VoidCallback? onAdd;
  final VoidCallback? onOpenMap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (onOpenMap != null)
                TextButton(
                  key: const ValueKey('open-pain-map'),
                  onPressed: onOpenMap,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.blue,
                    textStyle: const TextStyle(fontSize: 11),
                  ),
                  child: const Text('Выбрать на схеме'),
                ),
            ],
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
              if (onAdd != null)
                ActionChip(
                  key: ValueKey('add-option-$title'),
                  avatar: const Icon(Icons.add_rounded, size: 16, color: AppColors.blue),
                  label: options.isEmpty ? const Text('Добавить') : const SizedBox.shrink(),
                  labelPadding: options.isEmpty
                      ? const EdgeInsets.only(right: 6)
                      : EdgeInsets.zero,
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                  visualDensity: VisualDensity.compact,
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

class MedicationSelector extends StatelessWidget {
  final List<String> selectedMedications;
  final ValueChanged<List<String>> onChanged;
  final Future<List<String>> Function(String query) onSearch;

  const MedicationSelector({
    super.key,
    required this.selectedMedications,
    required this.onChanged,
    required this.onSearch,
  });

  void _addMedication(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;

    if (!selectedMedications.contains(trimmed)) {
      final updated = List<String>.from(selectedMedications)..add(trimmed);
      onChanged(updated);
    }
  }

  void _removeMedication(String name) {
    final updated = List<String>.from(selectedMedications)..remove(name);
    onChanged(updated);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Компактный заголовок в стиле соседних карточек
        const Text(
          'Принятые препараты',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 10),

        Autocomplete<String>(
          optionsBuilder: (TextEditingValue textEditingValue) async {
            final query = textEditingValue.text.trim();
            if (query.isEmpty) {
              return const Iterable<String>.empty();
            }
            final results = await onSearch(query);

            final hasExactMatch = results.any(
              (m) => m.toLowerCase() == query.toLowerCase(),
            );

            if (!hasExactMatch && query.isNotEmpty) {
              return [...results, '+ Добавить «$query»'];
            }
            return results;
          },
          onSelected: (String selection) {
            if (selection.startsWith('+ Добавить «')) {
              final rawName = selection
                  .replaceFirst('+ Добавить «', '')
                  .replaceAll(RegExp(r'»$'), '');
              _addMedication(rawName);
            } else {
              _addMedication(selection);
            }
          },
          fieldViewBuilder:
              (context, controller, focusNode, onEditingComplete) {
            return TextField(
              controller: controller,
              focusNode: focusNode,
              style: const TextStyle(fontSize: 12),
              // Аккуратный размер вводимого текста
              decoration: InputDecoration(
                hintText: 'Начните вводить (например, Нурофен)...',
                hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10, // Уменьшенные отступы внутри инпута
                ),
              ),
            );
          },
        ),

        if (selectedMedications.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: selectedMedications.map((med) {
              return InputChip(
                label: Text(med, style: const TextStyle(fontSize: 12)),
                selected: true,
                selectedColor: Colors.deepPurple.shade50,
                deleteIcon: const Icon(Icons.close, size: 16),
                onDeleted: () => _removeMedication(med),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }
}
