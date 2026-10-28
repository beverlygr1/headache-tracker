import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../../../core/utils/pain_intensity.dart';
import '../../../../core/utils/russian_date.dart';
import '../../../attacks/data/medications_api.dart';
import '../../domain/attack_record.dart';
import '../../state/tracker_controller.dart';
import '../widgets/common.dart';
import 'attack_entry_page.dart';

class AttackDetailsPage extends StatelessWidget {
  const AttackDetailsPage({
    required this.controller,
    required this.recordId,
    this.medicationsApi,
    super.key,
  });

  final TrackerController controller;
  final int recordId;
  final MedicationsApi? medicationsApi;

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
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 2),
                              child: Text(
                                PainIntensity.description(record.intensity),
                                style: const TextStyle(
                                  color: AppColors.muted,
                                  fontSize: 11,
                                ),
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
                                '${record.durationMinutes ?? 0} мин',
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
                  onPressed: controller.isSaving
                      ? null
                      : () => _openEditor(context, record),
                ),
                const SizedBox(height: 14),
                TextButton.icon(
                  key: const ValueKey('delete-attack'),
                  onPressed:
                      controller.isSaving ? null : () => _delete(context),
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: const Text('Удалить запись'),
                  style: TextButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.error),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _delete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить приступ?'),
        content: const Text(
            'Запись будет удалена из дневника и статистики. Восстановить её не получится.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Отмена')),
          TextButton(
              key: const ValueKey('confirm-delete-attack'),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Удалить')),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await controller.deleteAttack(recordId);
      if (context.mounted) Navigator.pop(context);
    } catch (error) {
      if (context.mounted) showErrorSnackBar(context, describeError(error));
    }
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
            medicationsApi: medicationsApi),
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
          _AttackFact(
            label: 'Где болит',
            value: record.painLocation.isEmpty
                ? 'Не указано'
                : record.painLocation,
          ),
          const Divider(height: 28),
          _AttackFact(
            label: 'Характер боли',
            value: record.painType?.isNotEmpty == true
                ? record.painType!
                : 'Не указан',
          ),
          const Divider(height: 28),
          _AttackFact(
            label: 'Сопутствующие симптомы',
            value: record.symptoms.isEmpty
                ? 'Не указаны'
                : record.symptoms.join(', '),
          ),
          const Divider(height: 28),
          _AttackFact(
            label: 'Препараты',
            value: record.medications.isEmpty
                ? 'Не указаны'
                : record.medications.join(', '),
          ),
          const Divider(height: 28),
          _AttackFact(
            label: 'Что помогло',
            value: record.reliefFactors.isEmpty
                ? 'Не указано'
                : record.reliefFactors.join(', '),
          ),
        ],
      ),
    );
  }
}

class _AttackFact extends StatelessWidget {
  const _AttackFact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: AppColors.muted, fontSize: 10),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
