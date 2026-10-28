import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../../../core/utils/pain_intensity.dart';
import '../../../../core/utils/russian_date.dart';
import '../../../diary/data/daily_entry.dart';
import '../../domain/attack_record.dart';
import '../../state/tracker_controller.dart';
import '../widgets/common.dart';

enum _DiaryFilter { all, active, completed }

class DiaryPage extends StatefulWidget {
  const DiaryPage({
    required this.controller,
    required this.onOpenAttack,
    required this.onOpenDailyEntry,
    this.dailyEntries = const [],
    this.today,
    this.diaryError,
    this.onRetryDiary,
    super.key,
  });

  final TrackerController controller;
  final DateTime? today;
  final ValueChanged<AttackRecord> onOpenAttack;
  final ValueChanged<DateTime> onOpenDailyEntry;
  final List<DailyEntry> dailyEntries;
  final String? diaryError;
  final VoidCallback? onRetryDiary;

  @override
  State<DiaryPage> createState() => _DiaryPageState();
}

class _DiaryPageState extends State<DiaryPage> {
  _DiaryFilter _filter = _DiaryFilter.all;
  DateTime? _selectedDate;

  Future<void> _chooseDate() async {
    final today = DateUtils.dateOnly(widget.today ?? DateTime.now());
    final selected = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? today,
      firstDate: DateTime(1900),
      lastDate: today,
      initialEntryMode: DatePickerEntryMode.calendarOnly,
      helpText: 'Выберите день дневника',
      confirmText: 'Открыть',
      cancelText: 'Отмена',
    );
    if (selected != null && mounted) {
      setState(() => _selectedDate = DateUtils.dateOnly(selected));
    }
  }

  @override
  Widget build(BuildContext context) {
    final today = DateUtils.dateOnly(widget.today ?? DateTime.now());
    final anchorDate = _selectedDate ?? today;
    final records = widget.controller.records.where((record) {
      if (_selectedDate != null &&
          !RussianDate.isSameDay(record.startTime, _selectedDate!)) {
        return false;
      }
      return switch (_filter) {
        _DiaryFilter.all => true,
        _DiaryFilter.active => record.isActive,
        _DiaryFilter.completed => !record.isActive,
      };
    }).toList();
    final dailyEntries = widget.dailyEntries
        .where(
          (entry) =>
              _selectedDate == null ||
              RussianDate.isSameDay(entry.date, _selectedDate!),
        )
        .toList();
    final hasActiveAttack = records.any((record) => record.isActive);

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Дневник',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              RoundIconButton(
                icon: Icons.tune_rounded,
                onPressed: _selectFilter,
              ),
            ],
          ),
          const SizedBox(height: 20),
          AppCard(
            padding: const EdgeInsets.fromLTRB(15, 14, 15, 13),
            child: Column(
              children: [
                TextButton(
                  key: const ValueKey('diary-calendar-picker'),
                  onPressed: _chooseDate,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.ink,
                    padding: EdgeInsets.zero,
                    alignment: Alignment.centerLeft,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          RussianDate.monthYear(anchorDate),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
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
                _CalendarWeek(
                  anchorDate: anchorDate,
                  today: today,
                  selectedDate: _selectedDate ?? today,
                  onSelected: (date) => setState(() => _selectedDate = date),
                  records: widget.controller.records,
                  dailyEntries: widget.dailyEntries,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          if (_selectedDate != null)
            Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${RussianDate.dayMonth(_selectedDate!)} ${_selectedDate!.year}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    TextButton(
                      key: const ValueKey('diary-all-dates'),
                      onPressed: () => setState(() => _selectedDate = null),
                      child: const Text('Все даты'),
                    ),
                  ],
                )),
          if (hasActiveAttack)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              decoration: BoxDecoration(
                color: AppColors.mint,
                borderRadius: BorderRadius.circular(17),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_rounded, color: AppColors.ink, size: 19),
                  SizedBox(width: 10),
                  Text(
                    'Приступ сохранён в дневнике',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          if (hasActiveAttack) const SizedBox(height: 18),
          if (records.isEmpty)
            _EmptyDiary(
              filtered: _filter != _DiaryFilter.all,
              hasDailyEntries: dailyEntries.isNotEmpty,
              selectedDate: _selectedDate,
              onCreateDailyEntry: () =>
                  widget.onOpenDailyEntry(_selectedDate ?? today),
            )
          else
            ..._buildRecordGroups(records, today),
          if (widget.diaryError != null) ...[
            const SizedBox(height: 16),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Не удалось загрузить самочувствие'),
                  const SizedBox(height: 8),
                  Text(
                    widget.diaryError!,
                    style: const TextStyle(color: AppColors.muted),
                  ),
                  TextButton(
                    onPressed: widget.onRetryDiary,
                    child: const Text('Повторить'),
                  ),
                ],
              ),
            ),
          ],
          if (_filter == _DiaryFilter.all && dailyEntries.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(
              'Самочувствие',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            for (final entry in dailyEntries) ...[
              AppCard(
                onTap: () => widget.onOpenDailyEntry(entry.date),
                child: Row(
                  children: [
                    const Icon(Icons.spa_outlined, color: AppColors.teal),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            RussianDate.dayMonth(entry.date),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            entry.summary,
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: 12,
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
              const SizedBox(height: 10),
            ],
          ],
        ],
      ),
    );
  }

  List<Widget> _buildRecordGroups(
    List<AttackRecord> records,
    DateTime anchorDate,
  ) {
    final widgets = <Widget>[];
    DateTime? lastDate;

    for (final record in records) {
      final recordDate = DateTime(
        record.startTime.year,
        record.startTime.month,
        record.startTime.day,
      );
      if (lastDate == null || !RussianDate.isSameDay(lastDate, recordDate)) {
        if (widgets.isNotEmpty) widgets.add(const SizedBox(height: 19));
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              RussianDate.isSameDay(recordDate, anchorDate)
                  ? 'Сегодня, ${RussianDate.dayMonth(recordDate)}'
                  : RussianDate.dayMonth(recordDate),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
          ),
        );
        lastDate = recordDate;
      }

      widgets.add(
        _AttackDiaryCard(
          record: record,
          onTap: () => widget.onOpenAttack(record),
        ),
      );
      widgets.add(const SizedBox(height: 10));
    }
    return widgets;
  }

  Future<void> _selectFilter() async {
    final result = await showModalBottomSheet<_DiaryFilter>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Показывать записи',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              RadioGroup<_DiaryFilter>(
                groupValue: _filter,
                onChanged: (value) => Navigator.pop(context, value),
                child: const Column(
                  children: [
                    RadioListTile<_DiaryFilter>(
                      value: _DiaryFilter.all,
                      title: Text('Все'),
                    ),
                    RadioListTile<_DiaryFilter>(
                      value: _DiaryFilter.active,
                      title: Text('Только продолжающиеся'),
                    ),
                    RadioListTile<_DiaryFilter>(
                      value: _DiaryFilter.completed,
                      title: Text('Только завершённые'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (result != null && mounted) {
      setState(() => _filter = result);
    }
  }
}

class _CalendarWeek extends StatelessWidget {
  const _CalendarWeek({
    required this.anchorDate,
    required this.today,
    required this.selectedDate,
    required this.onSelected,
    required this.records,
    required this.dailyEntries,
  });

  final DateTime today;
  final DateTime anchorDate;
  final DateTime selectedDate;
  final ValueChanged<DateTime> onSelected;
  final List<AttackRecord> records;
  final List<DailyEntry> dailyEntries;

  static const _weekdays = ['ПН', 'ВТ', 'СР', 'ЧТ', 'ПТ', 'СБ', 'ВС'];

  @override
  Widget build(BuildContext context) {
    final monday = DateTime(
      anchorDate.year,
      anchorDate.month,
      anchorDate.day - anchorDate.weekday + 1,
    );
    return Row(
      children: List.generate(7, (index) {
        final date = DateTime(monday.year, monday.month, monday.day + index);
        final item = (weekday: _weekdays[index], day: date.day);
        final selected = RussianDate.isSameDay(date, selectedDate);
        final enabled = !date.isAfter(today);
        final hasAttack = records.any(
          (record) => RussianDate.isSameDay(record.startTime, date),
        );
        final hasDailyEntry = dailyEntries.any(
          (entry) => RussianDate.isSameDay(entry.date, date),
        );
        return Expanded(
          child: Semantics(
            button: true,
            selected: selected,
            enabled: enabled,
            label: '${RussianDate.dayMonth(date)} ${date.year}',
            child: InkWell(
              key: ValueKey('diary-day-${date.year}-${date.month}-${date.day}'),
              onTap: enabled ? () => onSelected(date) : null,
              borderRadius: BorderRadius.circular(18),
              child: Column(
                children: [
                  Text(
                    item.weekday,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: 35,
                    height: 35,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected ? AppColors.navy : Colors.transparent,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${item.day}',
                      style: TextStyle(
                        color: selected
                            ? Colors.white
                            : enabled
                                ? AppColors.ink
                                : AppColors.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: hasAttack
                          ? AppColors.blue
                          : hasDailyEntry
                              ? AppColors.teal
                              : Colors.transparent,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _AttackDiaryCard extends StatelessWidget {
  const _AttackDiaryCard({required this.record, required this.onTap});

  final AttackRecord record;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(17),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (record.isActive) ...[
            const StatusLabel(),
            const SizedBox(height: 13),
          ],
          Row(
            children: [
              Text(
                '${record.intensity} / 10',
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Text(
                  record.isActive && record.painLocation.isNotEmpty
                      ? '${PainIntensity.description(record.intensity)} · ${record.painLocation.toLowerCase()}'
                      : PainIntensity.description(record.intensity),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            record.isActive
                ? '${RussianDate.time(record.startTime)} · '
                    '${record.symptoms.isEmpty ? 'без дополнительных симптомов' : record.symptoms.join(', ')}'
                : '${RussianDate.time(record.startTime)}–'
                    '${RussianDate.time(record.endTime!)} · '
                    '${record.durationMinutes ?? 0} мин',
            style: const TextStyle(color: AppColors.muted, fontSize: 10),
          ),
          if (record.isActive) ...[
            const SizedBox(height: 8),
            const Text(
              'Укажите окончание, когда боль пройдёт',
              style: TextStyle(color: AppColors.muted, fontSize: 10),
            ),
          ],
        ],
      ),
    );
  }
}

class _EmptyDiary extends StatelessWidget {
  const _EmptyDiary({
    required this.filtered,
    required this.hasDailyEntries,
    this.selectedDate,
    required this.onCreateDailyEntry,
  });
  final bool filtered;
  final bool hasDailyEntries;
  final DateTime? selectedDate;
  final VoidCallback onCreateDailyEntry;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        children: [
          const Icon(
            Icons.menu_book_outlined,
            color: AppColors.muted,
            size: 34,
          ),
          const SizedBox(height: 12),
          Text(
            filtered
                ? 'Под выбранный фильтр приступов нет'
                : selectedDate != null
                    ? 'За этот день приступов нет'
                    : hasDailyEntries
                        ? 'Приступов пока нет'
                        : 'Дневник начинается с первой записи',
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          if (!filtered && !hasDailyEntries) ...[
            const SizedBox(height: 8),
            Text(
              selectedDate == null
                  ? 'Отмечайте самочувствие даже в дни без боли.'
                  : 'Можно отметить самочувствие за выбранный день.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 16),
            PrimaryActionButton(
              label: 'Отметить самочувствие',
              onPressed: onCreateDailyEntry,
            ),
          ],
        ],
      ),
    );
  }
}
