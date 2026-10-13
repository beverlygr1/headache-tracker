import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../../../core/utils/russian_date.dart';
import '../../domain/attack_draft.dart';
import '../../state/tracker_controller.dart';
import '../widgets/common.dart';

/// The draft is written only after the user presses Save on this screen.
class AttackReviewPage extends StatefulWidget {
  const AttackReviewPage({
    required this.controller,
    required this.draft,
    super.key,
  });

  final TrackerController controller;
  final AttackDraft draft;

  @override
  State<AttackReviewPage> createState() => _AttackReviewPageState();
}

class _AttackReviewPageState extends State<AttackReviewPage> {
  bool _submitting = false;
  String? _error;

  Future<void> _save() async {
    if (_submitting || widget.controller.isSaving) return;
    if (widget.draft.painLocation.length > 120) {
      setState(() => _error = 'Названия выбранных зон слишком длинные');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final draft = widget.draft;
      await widget.controller.saveAttack(
        id: draft.id,
        startTime: draft.startTime,
        intensity: draft.intensity,
        painLocation: draft.painLocation,
        symptoms: draft.symptoms,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) setState(() => _error = describeError(error));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final draft = widget.draft;
    final startLabel =
        RussianDate.isSameDay(draft.startTime, DateTime.now())
            ? 'Сегодня, ${RussianDate.time(draft.startTime)}'
            : '${RussianDate.dayMonth(draft.startTime)}, '
                '${RussianDate.time(draft.startTime)}';

    return PopScope(
      canPop: !_submitting,
      child: Scaffold(
        appBar: const BackTitleBar(
          title: 'Проверка записи',
          subtitle: 'Запись приступа',
        ),
        body: SafeArea(
          top: false,
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  children: [
                    AppCard(
                      color: AppColors.blueSoft,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Готово к сохранению',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            draft.id == null
                                ? 'Проверьте данные — запись появится в дневнике.'
                                : 'Проверьте данные — изменения сохранятся '
                                    'в дневнике.',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _FactRow(label: 'Начало', value: startLabel),
                          const Divider(height: 26),
                          _FactRow(
                            label: 'Интенсивность',
                            value: '${draft.intensity} из 10',
                          ),
                          const Divider(height: 26),
                          _FactRow(
                            label: 'Зоны боли',
                            value: '${draft.painZones.length}',
                          ),
                          const SizedBox(height: 12),
                          _FactChips(
                            values: draft.painZones,
                            emptyLabel: 'Не указаны',
                          ),
                          if (draft.symptoms.isNotEmpty) ...[
                            const Divider(height: 26),
                            const Text(
                              'Сопутствующие симптомы',
                              style: TextStyle(
                                color: AppColors.muted,
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(height: 10),
                            _FactChips(values: draft.symptoms),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    const AppCard(
                      color: AppColors.mint,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Можно дополнить позже',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: 7),
                          Text(
                            'Симптомы и обстоятельства доступны '
                            'при редактировании записи.',
                            style: TextStyle(fontSize: 11, color: AppColors.ink),
                          ),
                        ],
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 14),
                      Semantics(
                        liveRegion: true,
                        child: AppCard(
                          color: const Color(0xFFFFECEC),
                          child: Text(
                            _error!,
                            style: const TextStyle(
                              color: Color(0xFFAE3030),
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
                child: AnimatedBuilder(
                  animation: widget.controller,
                  builder: (context, _) => PrimaryActionButton(
                    label: _submitting ? 'Сохранение…' : 'Сохранить приступ',
                    onPressed: _submitting || widget.controller.isSaving
                        ? null
                        : _save,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FactRow extends StatelessWidget {
  const _FactRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: AppColors.muted, fontSize: 11),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

class _FactChips extends StatelessWidget {
  const _FactChips({required this.values, this.emptyLabel = 'Не указаны'});

  final List<String> values;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) {
      return Text(
        emptyLabel,
        style: const TextStyle(color: AppColors.muted, fontSize: 11),
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final value in values)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.bluePale,
              borderRadius: BorderRadius.circular(30),
            ),
            child: Text(
              value,
              style: const TextStyle(color: AppColors.blue, fontSize: 11),
            ),
          ),
      ],
    );
  }
}
