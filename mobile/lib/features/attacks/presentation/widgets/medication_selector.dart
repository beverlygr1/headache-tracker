import 'package:flutter/material.dart';

class MedicationSelector extends StatefulWidget {
  final List<String> selectedMedications;
  final ValueChanged<List<String>> onChanged;
  final Future<List<String>> Function(String query) onSearch;
  final Future<String> Function(String customName)? onAddCustom;

  const MedicationSelector({
    super.key,
    required this.selectedMedications,
    required this.onChanged,
    required this.onSearch,
    this.onAddCustom,
  });

  @override
  State<MedicationSelector> createState() => _MedicationSelectorState();
}

class _MedicationSelectorState extends State<MedicationSelector> {
  final TextEditingController _typeAheadController = TextEditingController();

  void _addMedication(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;

    if (!widget.selectedMedications.contains(trimmed)) {
      final updated = List<String>.from(widget.selectedMedications)..add(trimmed);
      widget.onChanged(updated);
    }
    _typeAheadController.clear();
  }

  void _removeMedication(String name) {
    final updated = List<String>.from(widget.selectedMedications)..remove(name);
    widget.onChanged(updated);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Принятые препараты',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),

        // Поле ввода с автодополнением
        Autocomplete<String>(
          optionsBuilder: (TextEditingValue textEditingValue) async {
            if (textEditingValue.text.trim().isEmpty) {
              return const Iterable<String>.empty();
            }
            final results = await widget.onSearch(textEditingValue.text);

            // Если точного совпадения нет, добавляем опцию создания
            final query = textEditingValue.text.trim();
            final hasExactMatch = results.any((m) => m.toLowerCase() == query.toLowerCase());

            if (!hasExactMatch && query.isNotEmpty) {
              return [...results, '+ Добавить «$query»'];
            }
            return results;
          },
          onSelected: (String selection) async {
            if (selection.startsWith('+ Добавить «')) {
              // Извлекаем название из строки "+ Добавить «...»"
              final rawName = selection
                  .replaceFirst('+ Добавить «', '')
                  .replaceAll(RegExp(r'»$'), '');

              if (widget.onAddCustom != null) {
                final created = await widget.onAddCustom!(rawName);
                _addMedication(created);
              } else {
                _addMedication(rawName);
              }
            } else {
              _addMedication(selection);
            }
          },
          fieldViewBuilder: (context, controller, focusNode, onEditingComplete) {
            return TextField(
              controller: controller,
              focusNode: focusNode,
              decoration: InputDecoration(
                hintText: 'Начните вводить название (например, Нурофен)...',
                prefixIcon: const Icon(Icons.search_rounded),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            );
          },
        ),

        const SizedBox(height: 12),

        // Список выбранных тегов/чипсов
        if (widget.selectedMedications.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: widget.selectedMedications.map((med) {
              return InputChip(
                label: Text(med),
                selected: true,
                selectedColor: Colors.deepPurple.shade100,
                deleteIcon: const Icon(Icons.close, size: 18),
                onDeleted: () => _removeMedication(med),
              );
            }).toList(),
          ),
      ],
    );
  }
}