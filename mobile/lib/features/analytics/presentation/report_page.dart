import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../../../app/theme.dart';
import '../../../core/utils/russian_date.dart';
import '../../tracker/presentation/widgets/common.dart';
import '../../tracker/state/tracker_controller.dart';
import '../../offline/data/local_workspace.dart';
import '../data/analytics_api.dart';

class ReportPage extends StatefulWidget {
  const ReportPage(
      {required this.api,
      required this.timeZone,
      this.initialRange,
      this.share,
      this.workspace,
      super.key});
  final AnalyticsApi api;
  final String timeZone;
  final DateTimeRange? initialRange;
  final LocalWorkspace? workspace;
  final Future<bool> Function(Uint8List bytes, String filename)? share;
  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> {
  late DateTimeRange _range;
  bool _busy = false;
  String? _error;
  Uint8List? _bytes;

  @override
  void initState() {
    super.initState();
    final today = DateUtils.dateOnly(DateTime.now());
    _range = widget.initialRange ??
        DateTimeRange(
            start: today.subtract(const Duration(days: 29)), end: today);
  }

  Future<void> _chooseRange() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final range = await showDateRangePicker(
        context: context,
        initialDateRange: _range,
        firstDate: DateTime(1900),
        lastDate: today.isAfter(_range.end) ? today : _range.end,
        helpText: 'Период отчёта',
        saveText: 'Выбрать',
        cancelText: 'Отмена');
    if (range != null && mounted) {
      setState(() {
        _range = range;
        _bytes = null;
        _error = null;
      });
    }
  }

  Future<void> _save() async {
    if (_busy) return;
    if ((widget.workspace?.pendingCount ?? 0) > 0) {
      setState(() => _error =
          'Есть записи, ожидающие отправки. Сначала отправьте их из дневника.');
      return;
    }
    if (_range.duration.inDays >= 366) {
      setState(() => _error = 'Выберите период не больше 366 дней.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final bytes = _bytes ??= await widget.api.export(
          format: 'pdf',
          fromDate: _range.start,
          toDate: _range.end,
          timeZone: widget.timeZone);
      if (!mounted) return;
      final filename =
          'headache-report-${_range.start.toIso8601String().split('T').first}_${_range.end.toIso8601String().split('T').first}.pdf';
      final shared = widget.share != null
          ? await widget.share!(bytes, filename)
          : await Printing.sharePdf(bytes: bytes, filename: filename);
      if (mounted && !shared) {
        setState(
            () => _error = 'Сохранение отменено. Можно попробовать ещё раз.');
      }
    } catch (error) {
      if (mounted) setState(() => _error = describeError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: !_busy,
        child: Scaffold(
          appBar: const BackTitleBar(title: 'Отчёт для врача'),
          body: ListView(padding: const EdgeInsets.all(20), children: [
            const Text('Ваш дневник в одном PDF',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            const Text(
                'Приступы, интенсивность, длительность, препараты и самочувствие по дням.',
                style: TextStyle(color: AppColors.muted, height: 1.5)),
            const SizedBox(height: 24),
            AppCard(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  const Text('Период',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                      key: const ValueKey('report-period'),
                      onPressed: _busy ? null : _chooseRange,
                      icon: const Icon(Icons.date_range_rounded),
                      label: Text(
                          '${RussianDate.dayMonth(_range.start)} ${_range.start.year} — ${RussianDate.dayMonth(_range.end)} ${_range.end.year}',
                          textAlign: TextAlign.center)),
                  const SizedBox(height: 8),
                  Text('Часовой пояс: ${widget.timeZone}',
                      style: const TextStyle(
                          color: AppColors.muted, fontSize: 12)),
                ])),
            if (_error != null)
              Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(_error!,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error))),
            const SizedBox(height: 24),
            PrimaryActionButton(
                label: _busy
                    ? 'Готовим PDF…'
                    : kIsWeb
                        ? 'Скачать PDF'
                        : 'Сохранить или поделиться PDF',
                icon: Icons.file_download_outlined,
                onPressed: _busy ? null : _save),
          ]),
        ),
      );
}
