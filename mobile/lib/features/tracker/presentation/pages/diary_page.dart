import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../../../core/utils/russian_date.dart';
import '../../domain/attack_record.dart';
import '../../state/tracker_controller.dart';
import '../widgets/common.dart';

enum _DiaryFilter { all, active, completed }

class DiaryPage extends StatefulWidget {
  const DiaryPage({
    required this.controller,
    required this.onOpenAttack,
    super.key,
  });

  final TrackerController controller;
  final ValueChanged<AttackRecord> onOpenAttack;

  @override
  State<DiaryPage> createState() => _DiaryPageState();
}

class _DiaryPageState extends State<DiaryPage> {
  _DiaryFilter _filter = _DiaryFilter.all;

  @override
  Widget build(BuildContext context) {
    final anchorDate = DateTime.now();
    final records = widget.controller.records.where((record) {
      return switch (_filter) {
        _DiaryFilter.all => true,
        _DiaryFilter.active => record.isActive,
        _DiaryFilter.completed => !record.isActive,
      };
    }).toList();

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
                Row(
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
                const SizedBox(height: 14),
                _CalendarWeek(
                  today: anchorDate,
                  records: widget.controller.records,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (widget.controller.activeAttack != null)
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
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          if (widget.controller.activeAttack != null)
            const SizedBox(height: 18),
          if (records.isEmpty)
            const _EmptyDiary()
          else
            ..._buildRecordGroups(records, anchorDate),
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
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
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
    required this.today,
    required this.records,
  });

  final DateTime today;
  final List<AttackRecord> records;

  static const _weekdays = ['ПН', 'ВТ', 'СР', 'ЧТ', 'ПТ', 'СБ', 'ВС'];

  @override
  Widget build(BuildContext context) {
    final monday =
        DateTime(today.year, today.month, today.day - today.weekday + 1);
    return Row(
      children: List.generate(7, (index) {
        final date = DateTime(monday.year, monday.month, monday.day + index);
        final item = (weekday: _weekdays[index], day: date.day);
        final selected = RussianDate.isSameDay(date, today);
        final hasAttack = records.any(
          (record) => RussianDate.isSameDay(record.startTime, date),
        );
        return Expanded(
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
                    color: selected ? Colors.white : AppColors.ink,
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
                  color: hasAttack ? AppColors.blue : Colors.transparent,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

class _AttackDiaryCard extends StatelessWidget {
  const _AttackDiaryCard({
    required this.record,
    required this.onTap,
  });

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
                  record.isActive
                      ? 'Боль в ${record.painLocation.toLowerCase()}'
                      : 'Умеренная боль',
                  style: const TextStyle(
                    fontSize: 13,
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
          const SizedBox(height: 5),
          Text(
            record.isActive
                ? '${RussianDate.time(record.startTime)} · '
                    '${record.symptoms.isEmpty ? 'без дополнительных симптомов' : record.symptoms.join(', ')}'
                : '${RussianDate.time(record.startTime)}–'
                    '${RussianDate.time(record.endTime!)} · '
                    '${record.durationMinutes ?? 0} минут',
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 10,
            ),
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
  const _EmptyDiary();

  @override
  Widget build(BuildContext context) {
    return const AppCard(
      child: Column(
        children: [
          Icon(Icons.menu_book_outlined, color: AppColors.muted, size: 34),
          SizedBox(height: 12),
          Text(
            'Под выбранный фильтр записей нет',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
