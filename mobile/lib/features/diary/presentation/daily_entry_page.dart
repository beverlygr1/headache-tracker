import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../offline/data/local_workspace.dart';
import '../../offline/presentation/persistent_draft.dart';
import '../../../core/utils/russian_date.dart';
import '../../tracker/presentation/widgets/common.dart';
import '../../tracker/state/tracker_controller.dart';
import '../data/daily_entry.dart';
import '../data/diary_repository.dart';

class DailyEntryPage extends StatefulWidget {
  const DailyEntryPage({
    required this.repository,
    required this.date,
    this.workspace,
    super.key,
  });
  final DiaryRepository repository;
  final DateTime date;
  final LocalWorkspace? workspace;

  @override
  State<DailyEntryPage> createState() => _DailyEntryPageState();
}

class _DailyEntryPageState extends State<DailyEntryPage>
    with PersistentDraft<DailyEntryPage> {
  @override
  LocalWorkspace? get draftWorkspace => widget.workspace;
  @override
  String get draftKey =>
      'daily:${DailyEntry(date: widget.date).toJson()['date']}';
  @override
  Map<String, dynamic> captureDraft() => {
        'sleep': _sleep.text,
        'water': _water.text,
        'caffeine': _caffeine.text,
        'headache': _headachePresent,
        'quality': _sleepQuality,
        'stress': _stress,
        'physical_fatigue': _physicalFatigue,
      };
  @override
  void applyDraft(Map<String, dynamic> values) {
    _sleep.text = values['sleep'] as String;
    _water.text = values['water'] as String;
    _caffeine.text = values['caffeine'] as String;
    _headachePresent = values['headache'] as bool?;
    _sleepQuality = values['quality'] as int?;
    _stress = values['stress'] as int?;
    _physicalFatigue = values['physical_fatigue'] as bool?;
  }

  final _formKey = GlobalKey<FormState>();
  final _sleep = TextEditingController();
  final _water = TextEditingController();
  final _caffeine = TextEditingController();
  bool? _headachePresent;
  bool? _physicalFatigue;
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
    _sleep.addListener(persistDraft);
    _water.addListener(persistDraft);
    _caffeine.addListener(persistDraft);
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
    suspendDraft();
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
      _physicalFatigue = entry?.physicalFatigue;
    } catch (error) {
      if (mounted) _loadError = describeError(error);
    } finally {
      if (mounted) await restoreDraft();
      if (mounted) {
        setState(() {
          _loading = false;
          if (draftRestored) _loadError = null;
        });
      }
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
        _stress == null &&
        _physicalFatigue == null) {
      setState(() => _saveError = 'Заполните хотя бы один пункт');
      return;
    }
    setState(() {
      _saving = true;
      _saveError = null;
    });
    FocusManager.instance.primaryFocus?.unfocus();
    try {
      final entry = await saveWithDraft(() => widget.repository.save(
            DailyEntry(
              date: widget.date,
              headachePresent: _headachePresent,
              sleepHours:
                  double.tryParse(_sleep.text.trim().replaceAll(',', '.')),
              sleepQuality: _sleepQuality,
              waterMl: int.tryParse(_water.text.trim()),
              caffeineIntake: int.tryParse(_caffeine.text.trim()),
              stressLevel: _stress,
              physicalFatigue: _physicalFatigue,
            ),
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
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                      children: [
                        if (draftRestored || draftError != null) draftNotice,
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
                                  _diaryChoiceChip(
                                    key: const ValueKey('headache-yes'),
                                    label: const Text('Да, была'),
                                    selected: _headachePresent == true,
                                    onSelected: _saving
                                        ? null
                                        : (selected) => draftChange(
                                              () => _headachePresent =
                                                  selected ? true : null,
                                            ),
                                  ),
                                  _diaryChoiceChip(
                                    key: const ValueKey('headache-no'),
                                    label: const Text('Нет, не было'),
                                    selected: _headachePresent == false,
                                    onSelected: _saving
                                        ? null
                                        : (selected) => draftChange(
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
                          horizontal: true,
                          onChanged: (value) =>
                              draftChange(() => _sleepQuality = value),
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
                          onChanged: (value) =>
                              draftChange(() => _stress = value),
                        ),
                        const SizedBox(height: 16),
                        AppCard(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              const _FieldTitle(
                                  icon: Icons.directions_run_rounded,
                                  title: 'Была ли физическая усталость?'),
                              const SizedBox(height: 12),
                              Wrap(spacing: 8, runSpacing: 8, children: [
                                for (final answer in [true, false])
                                  _diaryChoiceChip(
                                    key: ValueKey(
                                        answer ? 'fatigue-yes' : 'fatigue-no'),
                                    label: Text(answer ? 'Да' : 'Нет'),
                                    selected: _physicalFatigue == answer,
                                    onSelected: _saving
                                        ? null
                                        : (selected) => draftChange(() =>
                                            _physicalFatigue =
                                                selected ? answer : null),
                                  ),
                              ]),
                            ])),
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
    this.horizontal = false,
  });

  final String title;
  final String hint;
  final IconData icon;
  final int? value;
  final bool enabled;
  final String keyPrefix;
  final ValueChanged<int?> onChanged;
  final bool horizontal;

  Widget _choice(int level) => _diaryChoiceChip(
        key: ValueKey('$keyPrefix-$level'),
        label: Text('$level'),
        compact: true,
        selected: value == level,
        onSelected:
            enabled ? (selected) => onChanged(selected ? level : null) : null,
        tooltip: '$title: $level из 10',
      );

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
            if (horizontal)
              _HorizontalRatingStrip(
                value: value,
                keyPrefix: keyPrefix,
                children: [
                  for (var level = 1; level <= 10; level++) ...[
                    if (level > 1) const SizedBox(width: 8),
                    SizedBox(width: 48, child: _choice(level)),
                  ],
                ],
              )
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns =
                      ((constraints.maxWidth + 8) / 56).floor().clamp(1, 5);
                  final width =
                      (constraints.maxWidth - (columns - 1) * 8) / columns;
                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (var level = 1; level <= 10; level++)
                        SizedBox(
                          width: width,
                          child: _choice(level),
                        ),
                    ],
                  );
                },
              ),
          ],
        ),
      );
}

class _HorizontalRatingStrip extends StatefulWidget {
  const _HorizontalRatingStrip({
    required this.value,
    required this.keyPrefix,
    required this.children,
  });

  final int? value;
  final String keyPrefix;
  final List<Widget> children;

  @override
  State<_HorizontalRatingStrip> createState() => _HorizontalRatingStripState();
}

class _HorizontalRatingStripState extends State<_HorizontalRatingStrip> {
  final _controller = ScrollController();

  @override
  void initState() {
    super.initState();
    _revealSelection();
  }

  @override
  void didUpdateWidget(covariant _HorizontalRatingStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) _revealSelection();
  }

  void _revealSelection() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_controller.hasClients || widget.value == null) return;
      final position = _controller.position;
      final start = (widget.value! - 1) * 56.0;
      final end = start + 48;
      final offset = start < position.pixels
          ? start
          : end > position.pixels + position.viewportDimension
              ? end - position.viewportDimension
              : position.pixels;
      final target = offset.clamp(0.0, position.maxScrollExtent);
      if (target != position.pixels) _controller.jumpTo(target);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
        child: ScrollbarTheme(
          data: ScrollbarThemeData(
            thumbColor:
                WidgetStatePropertyAll(AppColors.muted.withValues(alpha: .4)),
          ),
          child: Scrollbar(
            controller: _controller,
            thumbVisibility: true,
            thickness: 3,
            radius: const Radius.circular(3),
            child: SingleChildScrollView(
              key: ValueKey('${widget.keyPrefix}-scroll'),
              controller: _controller,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(children: widget.children),
            ),
          ),
        ),
      );
}

ChoiceChip _diaryChoiceChip({
  required Key key,
  required Widget label,
  required bool selected,
  required ValueChanged<bool>? onSelected,
  bool compact = false,
  String? tooltip,
}) =>
    ChoiceChip(
      key: key,
      label: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Center(widthFactor: compact ? null : 1, child: label),
      ),
      selected: selected,
      onSelected: onSelected,
      tooltip: tooltip,
      showCheckmark: false,
      backgroundColor: AppColors.background,
      selectedColor: AppColors.bluePale,
      disabledColor: AppColors.background,
      side: WidgetStateBorderSide.resolveWith((states) => BorderSide(
            color: !states.contains(WidgetState.disabled) &&
                    (selected || states.contains(WidgetState.focused))
                ? AppColors.blue
                : AppColors.line,
            width: states.contains(WidgetState.focused) ? 2 : 1,
          )),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      padding: const EdgeInsets.symmetric(vertical: 2),
      labelPadding: EdgeInsets.symmetric(horizontal: compact ? 0 : 12),
      labelStyle: TextStyle(
        fontFamily: 'Onest',
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: onSelected == null ? AppColors.muted : AppColors.ink,
      ),
      materialTapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.standard,
    );

class WaterTrackerCard extends StatelessWidget {
  const WaterTrackerCard(
      {super.key, required this.controller, this.enabled = true});
  final TextEditingController controller;
  final bool enabled;
  @override
  Widget build(BuildContext context) => _QuantityTrackerCard(
      title: 'Сколько воды выпили?',
      label: 'Количество воды',
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
      required this.prefix,
      required this.icon,
      required this.unit,
      required this.step,
      required this.presets,
      required this.controller,
      required this.enabled});
  final String title, label, prefix, unit;
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
        final stepButtonStyle = IconButton.styleFrom(
          fixedSize: const Size.square(48),
          foregroundColor: AppColors.ink,
          backgroundColor: AppColors.bluePale,
          disabledForegroundColor: AppColors.muted.withValues(alpha: .5),
          disabledBackgroundColor: AppColors.background,
          side: const BorderSide(color: AppColors.line),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        );
        return AppCard(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _FieldTitle(icon: icon, title: title),
          const SizedBox(height: 14),
          TextFormField(
            key: ValueKey('$prefix-field'),
            controller: controller,
            enabled: enabled,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) =>
                FocusManager.instance.primaryFocus?.unfocus(),
            decoration: InputDecoration(
              labelText: label,
              floatingLabelBehavior: FloatingLabelBehavior.always,
              hintText: 'Не указано',
              hintStyle: const TextStyle(fontSize: 13, color: AppColors.muted),
              floatingLabelStyle:
                  const TextStyle(color: AppColors.muted, fontSize: 13),
              contentPadding: const EdgeInsets.symmetric(vertical: 18),
              prefixIcon: Padding(
                padding: const EdgeInsets.all(6),
                child: IconButton(
                  key: ValueKey('$prefix-decrease'),
                  tooltip: 'Уменьшить на $step $unit',
                  style: stepButtonStyle,
                  onPressed: enabled && valid && (current ?? 0) > 0
                      ? () => _set(((current ?? 0) - step).clamp(0, _max))
                      : null,
                  icon: const Icon(Icons.remove_rounded),
                ),
              ),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(unit,
                      style: const TextStyle(
                          color: AppColors.muted, fontSize: 13)),
                  Padding(
                    padding: const EdgeInsets.all(6),
                    child: IconButton(
                      key: ValueKey('$prefix-increase'),
                      tooltip: 'Добавить $step $unit',
                      style: stepButtonStyle,
                      onPressed:
                          enabled && valid && (current ?? 0) <= _max - step
                              ? () => _set((current ?? 0) + step)
                              : null,
                      icon: const Icon(Icons.add_rounded),
                    ),
                  ),
                ],
              ),
            ),
            validator: (text) {
              if (text == null || text.trim().isEmpty) return null;
              final number = int.tryParse(text.trim());
              return number == null || number < 0 || number > _max
                  ? 'Введите целое неотрицательное число'
                  : null;
            },
          ),
          const SizedBox(height: 12),
          Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (final preset in presets)
                  _diaryChoiceChip(
                      key: ValueKey('$prefix-preset-$preset'),
                      label: Text('$preset $unit'),
                      selected: current == preset,
                      onSelected: enabled ? (_) => _set(preset) : null),
                TextButton(
                  key: ValueKey('clear-$prefix'),
                  onPressed:
                      enabled && text.text.isNotEmpty ? controller.clear : null,
                  style: TextButton.styleFrom(
                    minimumSize: const Size(48, 48),
                    foregroundColor: AppColors.ink,
                    disabledForegroundColor:
                        AppColors.muted.withValues(alpha: .5),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    textStyle: const TextStyle(
                        fontFamily: 'Onest',
                        fontSize: 13,
                        fontWeight: FontWeight.w600),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    side: const BorderSide(color: AppColors.line),
                  ),
                  child: const Text('Очистить'),
                ),
              ]),
        ]));
      });
}
