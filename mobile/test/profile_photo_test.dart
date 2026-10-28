import 'dart:typed_data';

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
import 'package:image_picker/image_picker.dart';

// Минимальный валидный PNG 1×1, чтобы Image.memory мог его декодировать.
final _png = Uint8List.fromList(const [
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x06,
  0x00,
  0x00,
  0x00,
  0x1F,
  0x15,
  0xC4,
  0x89,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0x9C,
  0x63,
  0xF8,
  0xCF,
  0xC0,
  0xF0,
  0x1F,
  0x00,
  0x05,
  0x00,
  0x01,
  0xFF,
  0x89,
  0x99,
  0x3D,
  0x1D,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4E,
  0x44,
  0xAE,
  0x42,
  0x60,
  0x82,
]);

void main() {
  test('image type is detected by content', () {
    expect(ProfileApi.imageSubtype(_png), 'png');
    expect(ProfileApi.imageSubtype(Uint8List.fromList([0xFF, 0xD8, 0xFF, 0])),
        'jpeg');
    expect(
      ProfileApi.imageSubtype(
          Uint8List.fromList('RIFF\x00\x00\x00\x00WEBPVP8 '.codeUnits)),
      'webp',
    );
    expect(
        ProfileApi.imageSubtype(Uint8List.fromList('<svg>'.codeUnits)), isNull);
  });

  test('restored session loads the saved photo', () async {
    final server = _Server()..avatar = _png;
    await server.auth.restoreSession();
    await pumpEventQueue();
    expect(server.auth.avatar, _png);
  });

  testWidgets('photo is added from gallery, replaced and deleted',
      (tester) async {
    _phone(tester);
    final server = _Server();
    await server.auth.restoreSession();
    final picked = <ImageSource>[];
    await tester.pumpWidget(HeadacheTrackerApp(
      home: ProfileSettingsPage(
        controller: server.auth,
        pickPhoto: (source) async {
          picked.add(source);
          return _png;
        },
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('profile-avatar-photo')), findsNothing);
    expect(find.text('Удалить фото'), findsNothing);

    await tester.tap(find.text('Добавить фото'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Выбрать из галереи'));
    await tester.pumpAndSettle();

    expect(picked, [ImageSource.gallery]);
    expect(server.avatar, _png);
    expect(server.auth.avatar, _png);
    expect(find.byKey(const ValueKey('profile-avatar-photo')), findsOneWidget);
    expect(find.text('Сменить фото'), findsOneWidget);

    await tester.tap(find.text('Удалить фото'));
    await tester.pumpAndSettle();
    expect(server.avatar, isNull);
    expect(server.auth.avatar, isNull);
    expect(find.byKey(const ValueKey('profile-avatar-photo')), findsNothing);
    expect(find.text('Добавить фото'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cancelled pick uploads nothing, failed upload shows error',
      (tester) async {
    _phone(tester);
    final server = _Server();
    await server.auth.restoreSession();
    Uint8List? next;
    await tester.pumpWidget(HeadacheTrackerApp(
      home: ProfileSettingsPage(
        controller: server.auth,
        pickPhoto: (_) async => next,
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Добавить фото'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Выбрать из галереи'));
    await tester.pumpAndSettle();
    expect(server.uploads, 0);

    next = _png;
    server.failUpload = true;
    await tester.tap(find.text('Добавить фото'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Выбрать из галереи'));
    await tester.pumpAndSettle();
    expect(find.text('Фото больше 2 МБ'), findsOneWidget);
    expect(server.auth.avatar, isNull);
    expect(find.text('Добавить фото'), findsOneWidget);
  });

  testWidgets('personal data saves birth date, gender and phone time zone',
      (tester) async {
    _phone(tester);
    final server = _Server()
      ..profile['birth_date'] = '1999-05-04'
      ..profile['gender'] = 'male';
    await server.auth.restoreSession();
    await tester.pumpWidget(HeadacheTrackerApp(
      home: ProfileSettingsPage(
        controller: server.auth,
        deviceTimeZone: () async => 'Asia/Tomsk',
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('4 мая 1999'), findsOneWidget);

    final clearDate = find.byTooltip('Очистить дату');
    await tester.ensureVisible(clearDate);
    await tester.tap(clearDate);
    await tester.pump();
    await tester.tap(find.text('Не указан').first);
    await tester.pump();
    await tester.tap(find.text('Как на телефоне'));
    await tester.pump();
    expect(find.text('Asia/Tomsk'), findsOneWidget);

    final save = find.text('Сохранить данные');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(server.personal, {
      'birth_date': null,
      'gender': null,
      'time_zone': 'Asia/Tomsk',
    });
    expect(server.auth.profile!.timeZone, 'Asia/Tomsk');
    expect(server.auth.profile!.gender, isNull);
    expect(find.text('Данные сохранены'), findsOneWidget);
  });
}

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

class _Server {
  _Server() {
    final client = ApiClient(tokenStorage: _Tokens());
    auth = AuthController(
      client: client,
      authApi: AuthApi(client),
      profileApi: _FakeProfileApi(client, this),
    );
  }

  late final AuthController auth;
  final profile = <String, dynamic>{
    'id': 1,
    'email': 'photo@example.com',
    'name': 'Анна',
    'onboarding_step': 1,
    'onboarding_completed': true,
  };
  Uint8List? avatar;
  bool failUpload = false;
  int uploads = 0;
  Map<String, Object?>? personal;

  UserProfile snapshot() => UserProfile.fromJson({
        ...profile,
        'avatar_updated_at': avatar == null ? null : '2026-10-28T10:00:00Z',
      });
}

class _FakeProfileApi extends ProfileApi {
  _FakeProfileApi(super.client, this.server);
  final _Server server;

  @override
  Future<UserProfile> getProfile() async => server.snapshot();

  @override
  Future<Uint8List?> fetchAvatar() async => server.avatar;

  @override
  Future<UserProfile> uploadAvatar(Uint8List bytes) async {
    server.uploads++;
    if (server.failUpload) {
      throw ApiException(message: 'Фото больше 2 МБ', statusCode: 413);
    }
    server.avatar = bytes;
    return server.snapshot();
  }

  @override
  Future<UserProfile> deleteAvatar() async {
    server.avatar = null;
    return server.snapshot();
  }

  @override
  Future<UserProfile> updatePersonal({
    required DateTime? birthDate,
    required String? gender,
    required String? timeZone,
  }) async {
    server.personal = {
      'birth_date': birthDate?.toIso8601String(),
      'gender': gender,
      'time_zone': timeZone,
    };
    server.profile
      ..['birth_date'] = birthDate?.toIso8601String().substring(0, 10)
      ..['gender'] = gender
      ..['time_zone'] = timeZone;
    return server.snapshot();
  }
}

class _Tokens extends TokenStorage {
  @override
  Future<String?> getAccessToken() async => 'access';
  @override
  Future<String?> getRefreshToken() async => 'refresh';
  @override
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {}
  @override
  Future<void> clear() async {}
}
