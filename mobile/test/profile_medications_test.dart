import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:headache_tracker_app/app/app.dart';
import 'package:headache_tracker_app/core/api/api_client.dart';
import 'package:headache_tracker_app/core/api/api_exception.dart';
import 'package:headache_tracker_app/core/storage/token_storage.dart';
import 'package:headache_tracker_app/features/auth/data/auth_api.dart';
import 'package:headache_tracker_app/features/auth/state/auth_controller.dart';
import 'package:headache_tracker_app/features/profile/data/profile_api.dart';
import 'package:headache_tracker_app/features/profile/data/user_profile.dart';
import 'package:headache_tracker_app/features/profile/presentation/profile_settings_page.dart';
import 'package:headache_tracker_app/features/attacks/data/medications_api.dart';
import 'package:headache_tracker_app/features/attacks/presentation/widgets/medication_selector.dart';

void main() {
  testWidgets('profile name survives network error then updates the account',
      (tester) async {
    phone(tester);
    final server = _Server();
    final auth = server.auth;
    addTearDown(auth.dispose);
    await auth.restoreSession();
    server.failName = true;
    await tester.pumpWidget(
        HeadacheTrackerApp(home: ProfileSettingsPage(controller: auth)));
    await tester.enterText(
        find.byKey(const ValueKey('profile-name')), '  Новое имя  ');
    await tester.tap(find.text('Сохранить имя'));
    await tester.pumpAndSettle();
    expect(find.text('Нет соединения с сервером'), findsOneWidget);
    expect(auth.profile!.name, 'Прежнее имя');
    expect(
        tester
            .widget<TextFormField>(find.byKey(const ValueKey('profile-name')))
            .controller!
            .text,
        '  Новое имя  ');
    server.failName = false;
    await tester.tap(find.text('Сохранить имя'));
    await tester.pumpAndSettle();
    expect(auth.profile!.name, 'Новое имя');
    expect(server.profile['name'], 'Новое имя');
  });

  testWidgets(
      'password confirmation validates, keeps input on error and stores renewed tokens',
      (tester) async {
    phone(tester);
    final server = _Server();
    final auth = server.auth;
    addTearDown(auth.dispose);
    await auth.restoreSession();
    await tester.pumpWidget(
        HeadacheTrackerApp(home: ProfileSettingsPage(controller: auth)));
    Future<void> input(String key, String text) async {
      final field = find.byKey(ValueKey(key));
      await reveal(tester, field);
      await tester.enterText(field, text);
    }

    await input('current-password', 'current-password');
    await input('new-password', 'new-password');
    await input('confirm-password', 'different');
    await reveal(tester, find.text('Изменить пароль'));
    await tester.tap(find.text('Изменить пароль'));
    await tester.pumpAndSettle();
    expect(find.text('Пароли не совпадают'), findsOneWidget);
    expect(server.passwordCalls, 0);
    await input('confirm-password', 'new-password');
    server.failPassword = true;
    await reveal(tester, find.text('Изменить пароль'));
    await tester.tap(find.text('Изменить пароль'));
    await tester.pumpAndSettle();
    expect(find.text('Нет соединения с сервером'), findsOneWidget);
    expect(
        tester
            .widget<TextFormField>(find.byKey(const ValueKey('new-password')))
            .controller!
            .text,
        'new-password');
    server.failPassword = false;
    await reveal(tester, find.text('Изменить пароль'));
    await tester.tap(find.text('Изменить пароль'));
    await tester.pumpAndSettle();
    expect(server.tokens.access, 'renewed-access');
    expect(server.tokens.refresh, 'renewed-refresh');
    expect(
        tester
            .widget<TextFormField>(find.byKey(const ValueKey('new-password')))
            .controller!
            .text,
        isEmpty);
    expect(auth.status, AuthStatus.authenticated);
  });

  testWidgets(
      'medication search and custom creation preserve input on network failure',
      (tester) async {
    phone(tester);
    var failSearch = true, failAdd = true;
    final selected = <String>['Сохранённый препарат'];
    await tester.pumpWidget(HeadacheTrackerApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: StatefulBuilder(
      builder: (context, setState) => Padding(
          padding: const EdgeInsets.all(20),
          child: MedicationSelector(
            selectedMedications: List.of(selected),
            onChanged: (names) => setState(() {
              selected
                ..clear()
                ..addAll(names);
            }),
            onSearch: (query) async {
              if (failSearch) {
                throw ApiException(message: 'Нет соединения с сервером');
              }
              return query.isEmpty ? ['Ибупрофен'] : [];
            },
            onAddCustom: (name) async {
              if (failAdd) {
                throw ApiException(message: 'Нет соединения с сервером');
              }
              return name;
            },
          )),
    )))));
    await tester.pumpAndSettle();
    expect(
        find.byKey(const ValueKey('selected-medication-Сохранённый препарат')),
        findsOneWidget);
    final search = find.byKey(const ValueKey('medication-search-field'));
    await tester.enterText(search, 'Мой препарат');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(find.text('Нет соединения с сервером'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('add-custom-medication')));
    await tester.pumpAndSettle();
    expect(selected, ['Сохранённый препарат']);
    expect(tester.widget<TextField>(search).controller!.text, 'Мой препарат');
    failAdd = false;
    failSearch = false;
    await tester.tap(find.byKey(const ValueKey('add-custom-medication')));
    await tester.pumpAndSettle();
    expect(selected, ['Сохранённый препарат', 'Мой препарат']);
    expect(tester.widget<TextField>(search).controller!.text, isEmpty);
    await tester.tap(find.byKey(const ValueKey('medication-option-Ибупрофен')));
    await tester.pumpAndSettle();
    expect(selected, contains('Ибупрофен'));
    expect(tester.takeException(), isNull);
  });

  test('medication API uses server search and persists custom names', () async {
    final server = _Server();
    final api = MedicationsApi(server.client);
    expect(await api.search('ИБУ'), ['Ибупрофен']);
    expect(server.lastQuery, 'ИБУ');
    expect(await api.addCustom(' Свой препарат '), 'Свой препарат');
  });
}

Future<void> reveal(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(target, 180,
      scrollable: find.byType(Scrollable).first);
  await Scrollable.ensureVisible(tester.element(target), alignment: .5);
  await tester.pumpAndSettle();
}

void phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(430, 932);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

class _Server {
  final tokens = _Tokens();
  late final ApiClient client;
  late final AuthController auth;
  bool failName = false, failPassword = false;
  int passwordCalls = 0;
  String? lastQuery;
  final profile = <String, dynamic>{
    'id': 1,
    'email': 'profile@example.com',
    'name': 'Прежнее имя',
    'onboarding_completed': true
  };
  _Server() {
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost/api/v1'));
    dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      dynamic body;
      if (options.path == '/user/profile') {
        if (options.method == 'PUT') {
          if (failName) {
            handler.reject(DioException.connectionError(
                requestOptions: options, reason: 'test'));
            return;
          }
          profile['name'] = (options.data as Map)['name'];
        }
        body = Map<String, dynamic>.from(profile);
      } else if (options.path == '/auth/password') {
        passwordCalls++;
        if (failPassword) {
          handler.reject(DioException.connectionError(
              requestOptions: options, reason: 'test'));
          return;
        }
        body = {
          'access_token': 'renewed-access',
          'refresh_token': 'renewed-refresh'
        };
      } else if (options.path == '/medications/catalog') {
        lastQuery = options.queryParameters['query'] as String;
        body = ['Ибупрофен'];
      } else if (options.path == '/medications') {
        body = {'name': (options.data as Map)['name']};
      } else {
        throw StateError('Unexpected test request');
      }
      handler.resolve(
          Response(requestOptions: options, statusCode: 200, data: body));
    }));
    client = ApiClient(dio: dio, tokenStorage: tokens);
    auth = AuthController(
        client: client,
        authApi: _FakeAuthApi(client, this),
        profileApi: _FakeProfileApi(client, this));
  }
}

class _Tokens extends TokenStorage {
  String? access = 'access-old', refresh = 'refresh-old';
  @override
  Future<String?> getAccessToken() async => access;
  @override
  Future<String?> getRefreshToken() async => refresh;
  @override
  Future<void> saveTokens(
      {required String accessToken, required String refreshToken}) async {
    access = accessToken;
    refresh = refreshToken;
  }

  @override
  Future<void> clear() async {
    access = null;
    refresh = null;
  }
}

class _FakeProfileApi extends ProfileApi {
  _FakeProfileApi(super.client, this.server);
  final _Server server;
  @override
  Future<UserProfile> getProfile() async =>
      UserProfile.fromJson(server.profile);
  @override
  Future<UserProfile> updateProfile(
      {String? name,
      String? timeZone,
      String? gender,
      DateTime? birthDate}) async {
    if (server.failName) {
      throw ApiException(message: 'Нет соединения с сервером');
    }
    server.profile['name'] = name;
    return UserProfile.fromJson(server.profile);
  }
}

class _FakeAuthApi extends AuthApi {
  _FakeAuthApi(super.client, this.server);
  final _Server server;
  @override
  Future<Map<String, dynamic>> changePassword(
      {required String currentPassword, required String newPassword}) async {
    server.passwordCalls++;
    if (server.failPassword) {
      throw ApiException(message: 'Нет соединения с сервером');
    }
    return {
      'access_token': 'renewed-access',
      'refresh_token': 'renewed-refresh'
    };
  }
}
