import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../app/theme.dart';
import '../../../tracker/state/tracker_controller.dart';

const presetMedications = [
  'Ибупрофен',
  'Парацетамол',
  'Суматриптан',
  'Нурофен',
  'Миг 400',
  'Аспирин',
  'Пенталгин',
  'Солпадеин'
];

class MedicationSelector extends StatefulWidget {
  const MedicationSelector(
      {super.key,
      required this.selectedMedications,
      required this.onChanged,
      required this.onSearch,
      this.onAddCustom});
  final List<String> selectedMedications;
  final ValueChanged<List<String>> onChanged;
  final Future<List<String>> Function(String) onSearch;
  final Future<String> Function(String)? onAddCustom;
  @override
  State<MedicationSelector> createState() => _MedicationSelectorState();
}

class _MedicationSelectorState extends State<MedicationSelector> {
  final _text = TextEditingController();
  Timer? _delay;
  List<String> _results = [];
  bool _loading = true, _adding = false;
  String? _error;
  int _request = 0;
  @override
  void initState() {
    super.initState();
    _search('');
  }

  @override
  void dispose() {
    _request++;
    _delay?.cancel();
    _text.dispose();
    super.dispose();
  }

  void _changed(String query) {
    _delay?.cancel();
    final request = ++_request;
    setState(() {
      _loading = true;
      _error = null;
    });
    _delay =
        Timer(const Duration(milliseconds: 250), () => _search(query, request));
  }

  Future<void> _search(String query, [int? requestId]) async {
    final request = requestId ?? ++_request;
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final results = await widget.onSearch(query.trim());
      if (!mounted || request != _request) return;
      setState(() {
        _results = results;
        _loading = false;
      });
    } catch (error) {
      if (!mounted || request != _request) return;
      setState(() {
        _loading = false;
        _results = [];
        _error = describeError(error);
      });
    }
  }

  void _select(String name) {
    if (!widget.selectedMedications
        .any((item) => item.toLowerCase() == name.toLowerCase())) {
      widget.onChanged([...widget.selectedMedications, name]);
    }
    _delay?.cancel();
    _text.clear();
    FocusManager.instance.primaryFocus?.unfocus();
    _search('');
  }

  Future<void> _add() async {
    final name = _text.text.trim();
    if (name.isEmpty || name.length > 120 || _adding) return;
    setState(() {
      _adding = true;
      _error = null;
    });
    try {
      final saved = await widget.onAddCustom?.call(name) ?? name;
      if (!mounted) return;
      _select(saved);
    } catch (error) {
      if (mounted) setState(() => _error = describeError(error));
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final available = _results
        .where((name) => !widget.selectedMedications
            .any((selected) => selected.toLowerCase() == name.toLowerCase()))
        .toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Препараты',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
      const SizedBox(height: 10),
      TextField(
        key: const ValueKey('medication-search-field'),
        controller: _text,
        enabled: !_adding,
        maxLength: 120,
        onChanged: _changed,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) {
          if (!_loading &&
              available.length == 1 &&
              available.single.toLowerCase() ==
                  _text.text.trim().toLowerCase()) {
            _select(available.single);
          } else {
            _add();
          }
        },
        decoration: const InputDecoration(
            hintText: 'Найти или добавить препарат',
            prefixIcon: Icon(Icons.search_rounded, size: 20),
            counterText: ''),
      ),
      const SizedBox(height: 10),
      if (widget.selectedMedications.isNotEmpty)
        LayoutBuilder(
            builder: (context, constraints) => Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    for (final name in widget.selectedMedications)
                      ConstrainedBox(
                          constraints:
                              BoxConstraints(maxWidth: constraints.maxWidth),
                          child: InputChip(
                            key: ValueKey('selected-medication-$name'),
                            label: Text(name, overflow: TextOverflow.ellipsis),
                            tooltip: name,
                            selected: true,
                            selectedColor: AppColors.blueSoft,
                            showCheckmark: false,
                            labelStyle: const TextStyle(
                                fontFamily: 'Onest', fontSize: 11),
                            deleteIcon:
                                const Icon(Icons.close_rounded, size: 16),
                            onDeleted: _adding
                                ? null
                                : () => widget.onChanged(widget
                                    .selectedMedications
                                    .where((value) => value != name)
                                    .toList()),
                          )),
                  ],
                )),
      if (_loading)
        const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: LinearProgressIndicator(minHeight: 2))
      else if (_error == null)
        Wrap(spacing: 8, runSpacing: 6, children: [
          for (final name in available)
            ActionChip(
                key: ValueKey('medication-option-$name'),
                label: Text(name),
                labelStyle: const TextStyle(fontFamily: 'Onest', fontSize: 11),
                backgroundColor: AppColors.background,
                side: BorderSide.none,
                onPressed: _adding ? null : () => _select(name)),
        ]),
      if (_error != null) ...[
        Text(_error!,
            style: TextStyle(
                color: Theme.of(context).colorScheme.error, fontSize: 12)),
        TextButton(
            key: const ValueKey('retry-medications'),
            onPressed: _adding ? null : () => _search(_text.text),
            child: const Text('Повторить поиск')),
      ],
      if (_text.text.trim().isNotEmpty &&
          !_results.any(
              (name) => name.toLowerCase() == _text.text.trim().toLowerCase()))
        TextButton.icon(
            key: const ValueKey('add-custom-medication'),
            onPressed: _adding ? null : _add,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: Text(
                _adding ? 'Добавление…' : 'Добавить «${_text.text.trim()}»',
                overflow: TextOverflow.ellipsis)),
    ]);
  }
}
