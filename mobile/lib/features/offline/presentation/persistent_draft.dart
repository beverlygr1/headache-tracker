import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../../tracker/presentation/widgets/common.dart';
import '../data/local_workspace.dart';

/// Form-specific values (including incomplete numeric text) are stored locally.
/// Saving atomically moves the draft into the durable outbox.
mixin PersistentDraft<T extends StatefulWidget> on State<T> {
  LocalWorkspace? get draftWorkspace;
  String get draftKey;
  Map<String, dynamic> captureDraft();
  void applyDraft(Map<String, dynamic> values);

  bool draftRestored = false;
  bool draftRestoring = false;
  bool _draftReady = false;
  bool _draftDirty = false;
  String? draftError;
  Map<String, dynamic>? _initial;
  late final _DraftLifecycle _draftObserver;

  @override
  void initState() {
    super.initState();
    _draftObserver = _DraftLifecycle(() {
      if (_draftDirty) persistDraft();
    });
    WidgetsBinding.instance.addObserver(_draftObserver);
  }

  Future<void> restoreDraft() async {
    final workspace = draftWorkspace;
    if (workspace == null) {
      _draftReady = true;
      return;
    }
    draftRestoring = true;
    _initial = jsonDecode(jsonEncode(captureDraft())) as Map<String, dynamic>;
    try {
      final saved = await workspace.readDraft(draftKey);
      if (!mounted) return;
      if (saved != null) {
        applyDraft(saved);
        draftRestored = true;
        _draftDirty = true;
      }
    } catch (_) {
      draftError = 'Черновик недоступен. Сохраните запись перед закрытием.';
    } finally {
      if (mounted) {
        setState(() {
          draftRestoring = false;
          _draftReady = true;
        });
      }
    }
  }

  void draftChange(VoidCallback change) {
    setState(change);
    persistDraft();
  }

  void suspendDraft() => _draftReady = false;

  void persistDraft() {
    if (!_draftReady || draftWorkspace == null || !mounted) return;
    _draftDirty = true;
    final values = captureDraft();
    unawaited(draftWorkspace!.saveDraft(draftKey, values).then((_) {
      if (mounted && draftError != null) setState(() => draftError = null);
    }).catchError((Object _) {
      if (mounted) {
        setState(() => draftError =
            'Черновик не сохранился. Оставьте форму открытой и повторите сохранение.');
      }
    }));
  }

  Future<R> saveWithDraft<R>(Future<R> Function() save) async {
    _draftReady = false;
    try {
      final result = draftWorkspace == null
          ? await save()
          : await draftWorkspace!.submitDraft(draftKey, save);
      _draftDirty = false;
      return result;
    } catch (_) {
      _draftReady = true;
      persistDraft();
      rethrow;
    }
  }

  Future<void> discardDraft() async {
    try {
      _draftReady = false;
      await draftWorkspace?.clearDraft(draftKey);
      if (!mounted) return;
      setState(() {
        if (_initial != null) applyDraft(_initial!);
        draftRestored = false;
        _draftDirty = false;
        draftError = null;
      });
    } catch (_) {
      if (mounted) {
        setState(() =>
            draftError = 'Не удалось удалить черновик. Повторите попытку.');
      }
    } finally {
      _draftReady = true;
    }
  }

  Widget get draftNotice => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: AppCard(
            color: AppColors.bluePale,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(draftError ?? 'Черновик восстановлен',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                if (draftRestored && draftError == null) ...[
                  const SizedBox(height: 4),
                  const Text(
                      'Можно продолжить заполнение. Запись ещё не отправлена.',
                      style: TextStyle(color: AppColors.muted, fontSize: 12)),
                  TextButton(
                      onPressed: discardDraft,
                      child: const Text('Сбросить черновик')),
                ],
              ],
            )),
      );

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(_draftObserver);
    super.dispose();
  }
}

class _DraftLifecycle extends WidgetsBindingObserver {
  _DraftLifecycle(this.flush);
  final VoidCallback flush;
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) flush();
  }
}
