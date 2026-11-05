import 'package:flutter/material.dart';
import '../../../../app/theme.dart';

const medicationEffectLabels = {
  'helped': 'Помог',
  'partly': 'Частично помог',
  'not_helped': 'Не помог',
};

class MedicationEffectsField extends StatelessWidget {
  const MedicationEffectsField(
      {required this.medications,
      required this.effects,
      required this.onChanged,
      super.key});
  final Iterable<String> medications;
  final Map<String, String> effects;
  final ValueChanged<Map<String, String>> onChanged;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Результат приёма',
              style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          const Text(
              'Можно отметить позже. Каждый препарат оценивается отдельно.',
              style: TextStyle(color: AppColors.muted, fontSize: 12)),
          for (final name in medications) ...[
            const SizedBox(height: 16),
            Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Wrap(spacing: 8, runSpacing: 6, children: [
              for (final entry in medicationEffectLabels.entries)
                ChoiceChip(
                  key: ValueKey('effect-$name-${entry.key}'),
                  label: Text(entry.value),
                  selected: effects[name] == entry.key,
                  materialTapTargetSize: MaterialTapTargetSize.padded,
                  selectedColor: AppColors.blueSoft,
                  showCheckmark: false,
                  onSelected: (selected) {
                    final updated = Map<String, String>.from(effects)
                      ..remove(name);
                    if (selected) updated[name] = entry.key;
                    onChanged(updated);
                  },
                ),
            ]),
          ],
        ],
      );
}
