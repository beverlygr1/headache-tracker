import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../api/api_client.dart';
import 'app_config.dart';

/// Хранилище адреса сервера. В тестах подменяется на память.
abstract interface class ServerAddressStore {
  Future<String?> read();
  Future<void> write(String value);
  Future<void> delete();
}

class SecureServerAddressStore implements ServerAddressStore {
  SecureServerAddressStore([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'api_base_url';
  final FlutterSecureStorage _storage;

  @override
  Future<String?> read() => _storage.read(key: _key);

  @override
  Future<void> write(String value) => _storage.write(key: _key, value: value);

  @override
  Future<void> delete() => _storage.delete(key: _key);
}

/// Адрес backend, который можно поменять прямо в приложении: IP ноутбука
/// с сервером меняется вместе с сетью, а пересобирать APK на месте нечем.
class ServerSettings extends ChangeNotifier {
  ServerSettings({
    required ApiClient client,
    ServerAddressStore? store,
    Dio? healthDio,
  })  : _client = client,
        _store = store ?? SecureServerAddressStore(),
        _healthDio = healthDio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 5),
                receiveTimeout: const Duration(seconds: 5),
              ),
            );

  final ApiClient _client;
  final ServerAddressStore _store;
  final Dio _healthDio;

  /// Текущий адрес API.
  String get baseUrl => _client.baseUrl;

  /// Адрес, собранный в APK (`API_BASE_URL` или значение по умолчанию).
  String get defaultBaseUrl => AppConfig.apiBaseUrl;

  bool get isCustom => baseUrl != defaultBaseUrl;

  /// Короткая запись для экрана: `192.168.1.50:8000`.
  String get displayAddress => describe(baseUrl);

  /// Применяет сохранённый адрес при запуске приложения.
  Future<void> load() async {
    try {
      final saved = normalize(await _store.read() ?? '');
      if (saved != null) _client.baseUrl = saved;
    } catch (_) {
      // Хранилище недоступно — работаем с адресом из сборки.
    }
  }

  Future<void> save(String baseUrl) async {
    _client.baseUrl = baseUrl;
    notifyListeners();
    try {
      await _store.write(baseUrl);
    } catch (_) {
      // Адрес применён до перезапуска, даже если сохранить не удалось.
    }
  }

  Future<void> reset() async {
    _client.baseUrl = defaultBaseUrl;
    notifyListeners();
    try {
      await _store.delete();
    } catch (_) {}
  }

  /// Проверяет `GET /health` по адресу сервера.
  Future<bool> isReachable(String baseUrl) async {
    try {
      final response = await _healthDio.getUri<dynamic>(healthUri(baseUrl));
      return response.statusCode == 200;
    } on DioException {
      return false;
    }
  }

  /// Превращает ввод пользователя в адрес API:
  /// `192.168.1.50` → `http://192.168.1.50:8000/api/v1`,
  /// `192.168.1.50:9000` → `http://192.168.1.50:9000/api/v1`,
  /// полный URL сохраняется как есть. Возвращает `null`, если адрес неверный.
  static String? normalize(String input) {
    var value = input.trim();
    if (value.isEmpty || value.contains(' ')) return null;

    final hasScheme = value.contains('://');
    if (!hasScheme) value = 'http://$value';

    final uri = Uri.tryParse(value);
    if (uri == null ||
        uri.host.isEmpty ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      return null;
    }

    var path = uri.path;
    while (path.endsWith('/')) {
      path = path.substring(0, path.length - 1);
    }
    return Uri(
      scheme: uri.scheme,
      host: uri.host,
      port: uri.hasPort ? uri.port : (hasScheme ? null : 8000),
      path: path.isEmpty ? '/api/v1' : path,
    ).toString();
  }

  /// `/health` лежит в корне сервера, а не под `/api/v1`.
  @visibleForTesting
  static Uri healthUri(String baseUrl) {
    final uri = Uri.parse(baseUrl);
    return uri.replace(path: '/health', query: null);
  }

  static String describe(String baseUrl) {
    final uri = Uri.tryParse(baseUrl);
    if (uri == null || uri.host.isEmpty) return baseUrl;
    final address = uri.hasPort ? '${uri.host}:${uri.port}' : uri.host;
    final scheme = uri.scheme == 'https' ? 'https://' : '';
    final path = uri.path == '/api/v1' ? '' : uri.path;
    return '$scheme$address$path';
  }
}
