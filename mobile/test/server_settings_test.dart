import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:headache_tracker_app/app/app.dart';
import 'package:headache_tracker_app/core/api/api_client.dart';
import 'package:headache_tracker_app/core/config/app_config.dart';
import 'package:headache_tracker_app/core/config/server_settings.dart';
import 'package:headache_tracker_app/core/storage/token_storage.dart';
import 'package:headache_tracker_app/features/auth/data/auth_api.dart';
import 'package:headache_tracker_app/features/auth/presentation/auth_page.dart';
import 'package:headache_tracker_app/features/auth/state/auth_controller.dart';
import 'package:headache_tracker_app/features/profile/data/profile_api.dart';

void main() {
  group('normalize', () {
    test('bare IP gets http, port 8000 and /api/v1', () {
      expect(ServerSettings.normalize(' 192.168.1.50 '),
          'http://192.168.1.50:8000/api/v1');
    });

    test('custom port is kept', () {
      expect(ServerSettings.normalize('192.168.1.50:9000'),
          'http://192.168.1.50:9000/api/v1');
    });

    test('full URL is kept as is', () {
      expect(ServerSettings.normalize('http://10.0.0.5:8000/api/v1/'),
          'http://10.0.0.5:8000/api/v1');
      expect(ServerSettings.normalize('https://api.example.com'),
          'https://api.example.com/api/v1');
    });

    test('garbage is rejected', () {
      expect(ServerSettings.normalize(''), isNull);
      expect(ServerSettings.normalize('192.168 .1.50'), isNull);
      expect(ServerSettings.normalize('ftp://host'), isNull);
    });
  });

  test('health check goes to server root, not under /api/v1', () {
    expect(
      ServerSettings.healthUri('http://192.168.1.50:8000/api/v1').toString(),
      'http://192.168.1.50:8000/health',
    );
  });

  test('saved address survives restart and reset returns to build default',
      () async {
    final store = _MemoryStore();
    final first = _client();
    final settings = ServerSettings(client: first, store: store);
    await settings.save('http://192.168.1.50:8000/api/v1');
    expect(first.baseUrl, 'http://192.168.1.50:8000/api/v1');

    final restarted = _client();
    await ServerSettings(client: restarted, store: store).load();
    expect(restarted.baseUrl, 'http://192.168.1.50:8000/api/v1');

    await settings.reset();
    expect(first.baseUrl, AppConfig.apiBaseUrl);
    expect(store.value, isNull);
  });

  test('broken storage does not prevent start', () async {
    final client = _client();
    await ServerSettings(client: client, store: _BrokenStore()).load();
    expect(client.baseUrl, AppConfig.apiBaseUrl);
  });

  test('reachability checks /health', () async {
    final adapter = _HealthAdapter(reachableHost: '192.168.1.50');
    final settings = ServerSettings(
      client: _client(),
      store: _MemoryStore(),
      healthDio: Dio()..httpClientAdapter = adapter,
    );

    expect(
        await settings.isReachable('http://192.168.1.50:8000/api/v1'), isTrue);
    expect(adapter.requested.single.path, '/health');
    expect(
        await settings.isReachable('http://192.168.1.99:8000/api/v1'), isFalse);
  });

  testWidgets('login screen changes server address without rebuilding APK',
      (tester) async {
    final client = _client();
    final settings = ServerSettings(
      client: client,
      store: _MemoryStore(),
      healthDio: Dio()
        ..httpClientAdapter = _HealthAdapter(reachableHost: '192.168.1.50'),
    );
    final auth = AuthController(
      client: client,
      authApi: AuthApi(client),
      profileApi: ProfileApi(client),
    );
    await tester.pumpWidget(HeadacheTrackerApp(
      home: AuthPage(controller: auth, serverSettings: settings),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('Сервер: '), findsOneWidget);

    // Недоступный адрес: остаёмся в диалоге с предупреждением.
    await tester.tap(find.textContaining('Сервер: '));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '192.168.1.99');
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Сервер не отвечает'), findsOneWidget);
    expect(client.baseUrl, isNot(contains('192.168.1.99')));

    // Доступный адрес сохраняется и сразу применяется к API-клиенту.
    await tester.enterText(find.byType(TextField).last, '192.168.1.50');
    await tester.pump();
    // Правка адреса снимает предупреждение и «Сохранить всё равно».
    expect(find.textContaining('Сервер не отвечает'), findsNothing);
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Адрес сервера'), findsNothing);
    expect(find.text('Сервер: 192.168.1.50:8000'), findsOneWidget);
    expect(client.baseUrl, 'http://192.168.1.50:8000/api/v1');
  });
}

ApiClient _client() => ApiClient(tokenStorage: _NoTokens());

class _NoTokens extends TokenStorage {
  @override
  Future<String?> getAccessToken() async => null;

  @override
  Future<String?> getRefreshToken() async => null;

  @override
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {}

  @override
  Future<void> clear() async {}
}

class _MemoryStore implements ServerAddressStore {
  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String value) async => this.value = value;

  @override
  Future<void> delete() async => value = null;
}

class _BrokenStore implements ServerAddressStore {
  @override
  Future<String?> read() async => throw StateError('OperationError');

  @override
  Future<void> write(String value) async => throw StateError('OperationError');

  @override
  Future<void> delete() async => throw StateError('OperationError');
}

class _HealthAdapter implements HttpClientAdapter {
  _HealthAdapter({required this.reachableHost});

  final String reachableHost;
  final requested = <Uri>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requested.add(options.uri);
    if (options.uri.host != reachableHost) {
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'refused',
      );
    }
    return ResponseBody.fromString(
      '{"status":"ok"}',
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
