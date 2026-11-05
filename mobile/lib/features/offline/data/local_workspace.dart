import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/storage/local_store.dart';

/// Account/server-scoped drafts, cached records and a durable FIFO outbox.
/// An operation is persisted before transmission. A lost POST response can be
/// replayed using the same client_request_id without creating a second attack.
class LocalWorkspace extends ChangeNotifier {
  LocalWorkspace(
      {required ApiClient client,
      LocalStore storage = const SecureLocalStore(),
      String? accountScope})
      : _client = client,
        _storage = storage,
        _scope = accountScope;

  final ApiClient _client;
  final LocalStore _storage;
  String? _scope;
  Future<void>? _loading;
  Future<void> _transactions = Future.value();
  Future<void>? _synchronizing;
  Map<String, dynamic> _state = {};
  bool _disposed = false;
  bool offline = false;
  String? syncError;
  Object? _lastFailure;
  String? _failedOperation;
  bool get syncing => _synchronizing != null;
  int get pendingCount => (_state['outbox'] as List? ?? []).length;
  List<Map<String, dynamic>> get _outbox =>
      (_state['outbox'] as List).cast<Map<String, dynamic>>();
  Map<String, dynamic> get _drafts => _state['drafts'] as Map<String, dynamic>;
  Map<String, dynamic> _collection(String name) =>
      (_state['cache'] as Map<String, dynamic>)[name] as Map<String, dynamic>;

  Future<void> _ready() => _loading ??= _load();
  Future<void> _load() async {
    _scope ??= await _client.accountScope();
    if (_scope == null) {
      throw ApiException(
          message: 'Войдите в аккаунт для сохранения на устройстве.',
          statusCode: 401);
    }
    final raw = await _storage.read('workspace.v1.$_scope');
    _state = raw == null
        ? {
            'cache': {
              'attacks': <String, dynamic>{},
              'diary': <String, dynamic>{}
            },
            'outbox': <Map<String, dynamic>>[],
            'drafts': <String, dynamic>{},
            'aliases': <String, dynamic>{},
            'next_id': -1,
          }
        : jsonDecode(raw) as Map<String, dynamic>;
  }

  Future<void> _change(void Function() change) {
    final next = _transactions.catchError((Object _) {}).then((_) async {
      await _ready();
      if (_disposed) {
        throw ApiException(
            message: 'Аккаунт закрыт. Отправка остановлена.', statusCode: 401);
      }
      final before = jsonEncode(_state);
      change();
      try {
        await _storage.write('workspace.v1.$_scope', jsonEncode(_state));
      } catch (_) {
        _state = jsonDecode(before) as Map<String, dynamic>;
        throw ApiException(
            message:
                'Не удалось сохранить данные на устройстве. Оставьте форму открытой и повторите сохранение.');
      }
      _notify();
    });
    _transactions = next;
    return next;
  }

  Future<Map<String, dynamic>?> readDraft(String key) async {
    await _ready();
    await _transactions.catchError((Object _) {});
    final value = _drafts[key];
    return value is Map ? Map<String, dynamic>.from(value) : null;
  }

  Future<void> saveDraft(String key, Map<String, dynamic> value) =>
      _change(() => _drafts[key] = value);
  Future<void> clearDraft(String key) => _change(() => _drafts.remove(key));

  Future<T> submitDraft<T>(String key, Future<T> Function() operation) =>
      runZoned(operation, zoneValues: {#localDraftKey: key});

  int resolveAttackId(int id) => int.parse(_resolve('attacks', '$id'));

  Future<List<Map<String, dynamic>>> readRecords(String name) async {
    await _ready();
    await _transactions.catchError((Object _) {});
    return _collection(name)
        .values
        .map((v) => Map<String, dynamic>.from(v as Map))
        .toList();
  }

  Future<Map<String, dynamic>?> readRecord(String name, String key) async {
    await _ready();
    await _transactions.catchError((Object _) {});
    final value = _collection(name)[_resolve(name, key)];
    return value is Map ? Map<String, dynamic>.from(value) : null;
  }

  void markOffline() {
    offline = true;
    _notify();
  }

  Future<List<Map<String, dynamic>>> loadRecords(
      String name, Future<List<Map<String, dynamic>>> Function() load) async {
    try {
      final records = await load();
      await _change(() {
        final old = Map<String, dynamic>.from(_collection(name));
        _collection(name).clear();
        for (final item in records) {
          _collection(name)[_key(name, item)] = item;
        }
        for (final operation in _outbox.where((o) => o['collection'] == name)) {
          final entity = operation['entity'] as String;
          if (!_collection(name).containsKey(entity) && old[entity] != null) {
            _collection(name)[entity] = old[entity];
          }
          _apply(operation);
        }
        offline = false;
      });
    } on ApiException catch (error) {
      if (!error.isNetworkError) rethrow;
      markOffline();
    }
    return readRecords(name);
  }

  Future<void> cacheRecord(String name, Map<String, dynamic> record) =>
      _change(() {
        final entity = _key(name, record);
        _collection(name)[entity] = record;
        for (final op in _outbox
            .where((o) => o['collection'] == name && o['entity'] == entity)) {
          _apply(op);
        }
        offline = false;
      });

  String _key(String name, Map<String, dynamic> record) =>
      name == 'attacks' ? '${record['id']}' : record['date'] as String;
  String _resolve(String name, String entity) => name == 'attacks'
      ? '${(_state['aliases'] as Map?)?[entity] ?? entity}'
      : entity;

  void _apply(Map<String, dynamic> op) {
    final name = op['collection'] as String;
    final entity = op['entity'] as String;
    if (op['method'] == 'DELETE') {
      _collection(name).remove(entity);
      return;
    }
    _collection(name)[entity] = {
      ...?_collection(name)[entity] as Map<String, dynamic>?,
      ...op['data'] as Map<String, dynamic>,
      if (name == 'attacks') 'id': int.parse(entity),
      if (name == 'diary') 'date': entity,
      'pending_sync': true,
    };
  }

  Future<Map<String, dynamic>?> write(
      String name, String method, Map<String, dynamic> data,
      {String? entity}) async {
    await _ready();
    final operationId = _uuid();
    Map<String, dynamic>? before;
    final draftKey = Zone.current[#localDraftKey] as String?;
    Map<String, dynamic>? draftBefore;
    late String key;
    var wasEmpty = false;
    await _change(() {
      wasEmpty = _outbox.isEmpty && !syncing;
      key = entity == null ? '${_state['next_id']}' : _resolve(name, entity);
      if (entity == null) _state['next_id'] = (_state['next_id'] as int) - 1;
      final record = _collection(name)[key];
      before = record is Map ? Map<String, dynamic>.from(record) : null;
      if (draftKey != null) {
        final draft = _drafts.remove(draftKey);
        if (draft is Map) draftBefore = Map<String, dynamic>.from(draft);
      }
      final body = Map<String, dynamic>.from(data);
      if (method == 'POST') body['client_request_id'] = operationId;
      // A new offline diary form may have no server snapshot. Omit unknown
      // fields so replay cannot erase values entered on another device.
      if (name == 'diary' && before == null && offline) {
        body.removeWhere((k, v) => v == null);
      }
      final operation = <String, dynamic>{
        'id': operationId,
        'collection': name,
        'entity': key,
        'method': method,
        'data': body
      };
      _outbox.add(operation);
      _apply(operation);
    });
    if (wasEmpty && !offline) {
      await sync();
      final failure = _lastFailure;
      if (_failedOperation == operationId &&
          failure is ApiException &&
          !failure.isNetworkError &&
          (failure.statusCode ?? 500) < 500) {
        await _change(() {
          _outbox.removeWhere((o) => o['id'] == operationId);
          if (draftKey != null && draftBefore != null) {
            _drafts[draftKey] = draftBefore;
          }
          final resolved = _resolve(name, key);
          if (before == null) {
            _collection(name).remove(resolved);
          } else {
            _collection(name)[resolved] = before;
          }
          syncError = null;
        });
        throw failure;
      }
    }
    return method == 'DELETE' ? null : readRecord(name, key);
  }

  Future<void> sync() {
    if (_disposed) return Future.value();
    return _synchronizing ??= _flush().whenComplete(() {
      _synchronizing = null;
      _notify();
    });
  }

  Future<void> _flush() async {
    await _ready();
    syncError = null;
    _lastFailure = null;
    _failedOperation = null;
    _notify();
    while (!_disposed && _outbox.isNotEmpty) {
      final operation = Map<String, dynamic>.from(_outbox.first);
      try {
        if (await _client.accountScope() != _scope || _disposed) return;
        final name = operation['collection'] as String;
        final entity = _resolve(name, operation['entity'] as String);
        final method = operation['method'] as String;
        final path = name == 'attacks'
            ? '/attacks${method == 'POST' ? '' : '/$entity'}'
            : '/diary/$entity';
        Map<String, dynamic>? response;
        try {
          response = await _client.sendForAccount(_scope!, method, path,
              Map<String, dynamic>.from(operation['data'] as Map));
        } on ApiException catch (error) {
          if (method != 'DELETE' || error.statusCode != 404) rethrow;
        }
        if (method != 'DELETE' && response == null) {
          throw StateError('Пустой ответ сервера');
        }
        if (_disposed) return;
        await _change(() {
          _outbox.removeWhere((o) => o['id'] == operation['id']);
          if (response != null) {
            final remoteKey = _key(name, response);
            if (remoteKey != entity) {
              (_state['aliases'] as Map)[entity] = remoteKey;
              _collection(name).remove(entity);
              for (final next in _outbox.where(
                  (o) => o['collection'] == name && o['entity'] == entity)) {
                next['entity'] = remoteKey;
              }
            }
            _collection(name)[remoteKey] = response;
          }
          for (final next in _outbox.where((o) => o['collection'] == name)) {
            _apply(next);
          }
          offline = false;
        });
      } catch (error) {
        _lastFailure = error;
        _failedOperation = operation['id'] as String;
        offline = error is ApiException && error.isNetworkError;
        syncError = offline
            ? 'Нет связи с сервером. Записи сохранены на устройстве.'
            : 'Не удалось отправить записи. ${error is ApiException ? error.message : 'Повторите отправку.'}';
        _notify();
        return;
      }
    }
  }

  static String _uuid() {
    final random = Random.secure();
    final bytes = List.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 15) | 64;
    bytes[8] = (bytes[8] & 63) | 128;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
