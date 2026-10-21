import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../tracker/presentation/widgets/common.dart';
import '../state/reminder_controller.dart';

/// Ежедневное напоминание заполнить дневник: включение и время.
class ReminderSettingsPage extends StatefulWidget {
  const ReminderSettingsPage({required this.controller, super.key});

  final ReminderController controller;

  @override
  State<ReminderSettingsPage> createState() => _ReminderSettingsPageState();
}

class _ReminderSettingsPageState extends State<ReminderSettingsPage> {
  bool _permissionDenied = false;

  ReminderController get _controller => widget.controller;

  Future<void> _toggle(bool enabled) async {
    try {
      final result = await _controller.setEnabled(enabled);
      if (!mounted) return;
      setState(() {
        _permissionDenied = result == ReminderToggleResult.permissionDenied;
      });
    } catch (_) {
      if (mounted) {
        showErrorSnackBar(context, 'Не удалось изменить напоминание');
      }
    }
  }

  Future<void> _pickTime() async {
    final settings = _controller.settings;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: settings.hour, minute: settings.minute),
      helpText: 'Время напоминания',
      cancelText: 'Отмена',
      confirmText: 'Готово',
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked == null || !mounted) return;
    try {
      await _controller.setTime(hour: picked.hour, minute: picked.minute);
    } catch (_) {
      if (mounted) showErrorSnackBar(context, 'Не удалось изменить время');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const BackTitleBar(title: 'Напоминание'),
      body: SafeArea(
        top: false,
        child: ListenableBuilder(
          listenable: _controller,
          builder: (context, _) {
            final settings = _controller.settings;
            final supported = _controller.isSupported;
            final busy = _controller.isBusy;

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                AppCard(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  // Свой Material, чтобы ListTile рисовал отклик на нажатие
                  // поверх белого фона карточки.
                  child: Material(
                    type: MaterialType.transparency,
                    child: Column(
                      children: [
                        SwitchListTile(
                          value: settings.enabled,
                          onChanged: supported && !busy ? _toggle : null,
                          title: const Text(
                            'Напоминать заполнить дневник',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: const Text('Одно уведомление в день'),
                        ),
                        const Divider(height: 1, indent: 16, endIndent: 16),
                        ListTile(
                          enabled: supported && !busy,
                          onTap: _pickTime,
                          leading: const Icon(Icons.schedule_rounded),
                          title: const Text('Время'),
                          trailing: Text(
                            settings.timeLabel,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                if (!supported)
                  const _Note(
                    'Напоминания работают в Android-приложении. '
                    'В браузере уведомления не планируются.',
                  )
                else if (_permissionDenied) ...[
                  const _Note(
                    'Уведомления для приложения запрещены. Разрешите их '
                    'в настройках телефона и включите напоминание снова.',
                    color: Colors.redAccent,
                  ),
                  const SizedBox(height: 10),
                  SecondaryActionButton(
                    label: 'Открыть настройки уведомлений',
                    onPressed: _controller.openSystemSettings,
                  ),
                ] else
                  _Note(
                    settings.enabled
                        ? 'Каждый день в ${settings.timeLabel} придёт '
                            'уведомление. Нажмите на него — откроется запись '
                            'самочувствия.'
                        : 'Напоминание выключено.',
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note(this.text, {this.color = AppColors.muted});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(text, style: TextStyle(color: color, fontSize: 12)),
    );
  }
}
