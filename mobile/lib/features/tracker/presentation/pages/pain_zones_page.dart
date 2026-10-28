import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../domain/pain_zones.dart';
import '../widgets/common.dart';
import '../widgets/pain_head_map.dart';

/// The three Figma frames are states of this page: no selection, front and back.
/// Nothing is saved remotely; Continue returns the selection to the editor.
class PainZonesPage extends StatefulWidget {
  const PainZonesPage({
    this.initialZones = const [],
    this.initialView = HeadView.front,
    super.key,
  });

  final List<String> initialZones;
  final HeadView initialView;

  @override
  State<PainZonesPage> createState() => _PainZonesPageState();
}

class _PainZonesPageState extends State<PainZonesPage> {
  late final Set<String> _selected;
  late HeadView _view;

  @override
  void initState() {
    super.initState();
    _selected = Set.of(widget.initialZones);
    _view = widget.initialView;
  }

  void _toggle(String zone) {
    if (!_selected.contains(zone) &&
        [..._selected, zone].join(', ').length > 120) {
      showErrorSnackBar(context, 'Названия выбранных зон слишком длинные');
      return;
    }
    setState(() {
      if (!_selected.add(zone)) _selected.remove(zone);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const BackTitleBar(
        title: 'Зоны боли',
        subtitle: 'Запись приступа · указание места',
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                children: [
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Где болит?',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 7),
                        const Text(
                          'Нажмите на области головы. Можно выбрать '
                          'несколько зон.',
                          style: TextStyle(
                            color: AppColors.muted,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0F3F8),
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: Row(
                            children: [
                              for (final view in HeadView.values)
                                Expanded(
                                  child: _ViewButton(
                                    label: view == HeadView.front
                                        ? 'Спереди'
                                        : 'Сзади',
                                    selected: _view == view,
                                    onPressed: () =>
                                        setState(() => _view = view),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 220),
                            child: PainHeadMap(
                              view: _view,
                              selectedZones: _selected,
                              onToggle: _toggle,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Center(
                          child: Text(
                            'П и Л — ваши правая и левая стороны',
                            style:
                                TextStyle(color: AppColors.muted, fontSize: 10),
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Зоны на схеме',
                          style:
                              TextStyle(color: AppColors.muted, fontSize: 10),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            for (final zone in [
                              ...(_view == HeadView.front
                                  ? PainZones.front
                                  : PainZones.back),
                              PainZones.wholeHead,
                            ])
                              ChoiceChip(
                                label: Text(zone),
                                selected: _selected.contains(zone),
                                onSelected: (_) => _toggle(zone),
                                showCheckmark: false,
                                visualDensity: VisualDensity.compact,
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                                selectedColor: AppColors.blueSoft,
                                backgroundColor: const Color(0xFFF0F3F8),
                                side: BorderSide.none,
                                labelStyle: TextStyle(
                                  color: _selected.contains(zone)
                                      ? AppColors.blue
                                      : AppColors.muted,
                                  fontSize: 11,
                                ),
                              ),
                          ],
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
                          'Выбранные зоны',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 10),
                        if (_selected.isEmpty)
                          const Text(
                            'Пока ничего не выбрано',
                            style: TextStyle(
                              color: AppColors.muted,
                              fontSize: 11,
                            ),
                          )
                        else
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              for (final zone in _selected)
                                InputChip(
                                  key: ValueKey('selected-zone-$zone'),
                                  label: Text(zone),
                                  onDeleted: () => _toggle(zone),
                                  deleteIcon: const Icon(
                                    Icons.close_rounded,
                                    size: 14,
                                  ),
                                  deleteButtonTooltipMessage: 'Убрать $zone',
                                  deleteIconColor: AppColors.blue,
                                  backgroundColor: AppColors.bluePale,
                                  side: BorderSide.none,
                                  labelStyle: const TextStyle(
                                    color: AppColors.blue,
                                    fontSize: 11,
                                  ),
                                ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
              child: PrimaryActionButton(
                label: 'Продолжить',
                backgroundColor: const Color(0xFFF0F3F8),
                foregroundColor: AppColors.ink,
                onPressed: _selected.isEmpty
                    ? null
                    : () => Navigator.of(context).pop(_selected.toList()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ViewButton extends StatelessWidget {
  const _ViewButton({
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          backgroundColor: selected ? Colors.white : Colors.transparent,
          foregroundColor: selected ? AppColors.ink : AppColors.muted,
          shape: const StadiumBorder(),
          textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        ),
        child: Text(label),
      ),
    );
  }
}
