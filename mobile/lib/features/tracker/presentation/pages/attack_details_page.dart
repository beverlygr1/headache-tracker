import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../../../core/utils/russian_date.dart';
import '../../domain/attack_record.dart';
import '../../state/tracker_controller.dart';
import '../widgets/common.dart';
import 'attack_entry_page.dart';

class AttackDetailsPage extends StatelessWidget {
  const AttackDetailsPage({
    required this.controller,
    required this.recordId,
    super.key,
  });

  final TrackerController controller;
  final int recordId;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final record = controller.byId(recordId);
        if (record == null) {
          return const Scaffold(
            appBar: BackTitleBar(title: 'Приступ'),
            body: Center(child: Text('Запись не найдена')),
          );
        }

        return Scaffold(
          appBar: const BackTitleBar(title: 'Приступ'),
          body: SafeArea(
            top: false,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 22),
              children: [
                AppCard(
                  color: AppColors.blueSoft,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      StatusLabel(active: record.isActive),
                      const SizedBox(height: 16),
                      Text(
                        RussianDate.dayMonth(record.startTime),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 13),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${record.intensity} / 10',
                            style: const TextStyle(
                              fontSize: 29,
                              height: 1,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Padding(
                            padding: EdgeInsets.only(bottom: 2),
                            child: Text(
                              'Ощутимая боль',
                              style: TextStyle(
                                color: AppColors.muted,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        record.isActive
                            ? 'Начался ${RussianDate.isSameDay(record.startTime, DateTime.now()) ? 'сегодня' : RussianDate.dayMonth(record.startTime)} '
                                'в ${RussianDate.time(record.startTime)}'
                            : 'Завершён в ${RussianDate.time(record.endTime!)} · '
                                '${record.durationMinutes ?? 0} минут',
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                AppCard(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.schedule_rounded,
                        color: AppColors.muted,
                        size: 21,
                      ),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              record.isActive
                                  ? '${RussianDate.time(record.startTime)} — ещё продолжается'
                                  : '${RussianDate.time(record.startTime)} — '
                                      '${RussianDate.time(record.endTime!)}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              record.isActive
                                  ? 'Время окончания пока не указано'
                                  : 'Приступ завершён',
                              style: const TextStyle(
                                color: AppColors.muted,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _AttackFacts(record: record),
                const SizedBox(height: 28),
                Text(
                  record.isActive
                      ? 'Можно вернуться к записи и добавить\nподробности, когда станет легче'
                      : 'Запись сохранена в дневнике',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 28),
                PrimaryActionButton(
                  label: controller.isSaving
                      ? 'Сохранение…'
                      : record.isActive
                          ? 'Приступ закончился'
                          : 'Приступ завершён',
                  onPressed: record.isActive && !controller.isSaving
                      ? () => _finish(context, record)
                      : null,
                ),
                const SizedBox(height: 10),
                SecondaryActionButton(
                  label: 'Редактировать запись',
                  onPressed: () => _openEditor(context, record),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _finish(BuildContext context, AttackRecord record) async {
    try {
      await controller.finishAttack(record.id);
    } catch (error) {
      if (context.mounted) showErrorSnackBar(context, describeError(error));
    }
  }

  Future<void> _openEditor(BuildContext context, AttackRecord record) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => AttackEntryPage(
          controller: controller,
          initialRecord: record,
        ),
      ),
    );
  }
}

class _AttackFacts extends StatelessWidget {
  const _AttackFacts({required this.record});

  final AttackRecord record;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Где болит',
            style: TextStyle(color: AppColors.muted, fontSize: 10),
          ),
          const SizedBox(height: 6),
          Text(
            record.painLocation,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 15),
            child: Divider(height: 1),
          ),
          const Text(
            'Сопутствующие симптомы',
            style: TextStyle(color: AppColors.muted, fontSize: 10),
          ),
          const SizedBox(height: 6),
          Text(
            record.symptoms.isEmpty ? 'Не указаны' : record.symptoms.join(', '),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
