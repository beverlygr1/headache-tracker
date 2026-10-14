import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/config/server_settings.dart';

/// Открывает диалог адреса сервера. Возвращает `true`, если адрес изменился.
Future<bool> showServerAddressDialog(
  BuildContext context,
  ServerSettings settings,
) async {
  final changed = await showDialog<bool>(
    context: context,
    builder: (context) => _ServerAddressDialog(settings: settings),
  );
  return changed ?? false;
}

enum _CheckState { idle, checking, invalid, unreachable }

class _ServerAddressDialog extends StatefulWidget {
  const _ServerAddressDialog({required this.settings});

  final ServerSettings settings;

  @override
  State<_ServerAddressDialog> createState() => _ServerAddressDialogState();
}

class _ServerAddressDialogState extends State<_ServerAddressDialog> {
  // Диалог владеет контроллером: после pop он ещё анимирует закрытие.
  late final _controller =
      TextEditingController(text: widget.settings.displayAddress);
  _CheckState _state = _CheckState.idle;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save({bool force = false}) async {
    final baseUrl = ServerSettings.normalize(_controller.text);
    if (baseUrl == null) {
      setState(() => _state = _CheckState.invalid);
      return;
    }

    if (!force) {
      setState(() => _state = _CheckState.checking);
      final reachable = await widget.settings.isReachable(baseUrl);
      if (!mounted) return;
      if (!reachable) {
        setState(() => _state = _CheckState.unreachable);
        return;
      }
    }

    await widget.settings.save(baseUrl);
    if (mounted) Navigator.of(context).pop(true);
  }

  Future<void> _reset() async {
    await widget.settings.reset();
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final checking = _state == _CheckState.checking;
    final unreachable = _state == _CheckState.unreachable;

    return AlertDialog(
      title: const Text('Адрес сервера'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _controller,
            enabled: !checking,
            autofocus: true,
            keyboardType: TextInputType.url,
            autocorrect: false,
            decoration: InputDecoration(
              hintText: '192.168.1.50:8000',
              errorText: _state == _CheckState.invalid
                  ? 'Введите IP или адрес, например 192.168.1.50:8000'
                  : null,
            ),
            onChanged: (_) {
              if (_state != _CheckState.idle) {
                setState(() => _state = _CheckState.idle);
              }
            },
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 12),
          if (checking)
            const Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 10),
                Text('Проверяем сервер…'),
              ],
            )
          else if (unreachable)
            const Text(
              'Сервер не отвечает. Проверьте, что backend запущен, '
              'а телефон и ноутбук в одной сети.',
              style: TextStyle(color: Colors.redAccent, fontSize: 12),
            )
          else
            const Text(
              'IP ноутбука, на котором запущен backend. '
              'Порт по умолчанию — 8000.',
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          if (widget.settings.isCustom) ...[
            const SizedBox(height: 4),
            TextButton(
              onPressed: checking ? null : _reset,
              child: Text(
                'Сбросить на ${ServerSettings.describe(widget.settings.defaultBaseUrl)}',
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: checking ? null : () => Navigator.of(context).pop(false),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: checking ? null : () => _save(force: unreachable),
          child: Text(unreachable ? 'Сохранить всё равно' : 'Сохранить'),
        ),
      ],
    );
  }
}
