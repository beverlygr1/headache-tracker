import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:headache_tracker_app/app/app.dart';
import 'package:headache_tracker_app/app/auth_gate.dart';
import 'package:headache_tracker_app/core/api/api_client.dart';
import 'package:headache_tracker_app/core/api/api_exception.dart';
import 'package:headache_tracker_app/core/storage/token_storage.dart';
import 'package:headache_tracker_app/features/attacks/data/attacks_api.dart';
import 'package:headache_tracker_app/features/auth/data/auth_api.dart';
import 'package:headache_tracker_app/features/auth/state/auth_controller.dart';
import 'package:headache_tracker_app/features/diary/data/diary_api.dart';
import 'package:headache_tracker_app/features/diary/presentation/daily_entry_page.dart';
import 'package:headache_tracker_app/features/onboarding/presentation/onboarding_page.dart';
import 'package:headache_tracker_app/features/profile/data/profile_api.dart';
import 'package:headache_tracker_app/features/tracker/presentation/pages/attack_entry_page.dart';

void main() {
  AuthController authFor(_AccountClient client) => AuthController(
      client: client, authApi: AuthApi(client), profileApi: ProfileApi(client));

  Widget appFor(_AccountClient client, AuthController auth) =>
      HeadacheTrackerApp(
          home: AuthGate(
              authController: auth,
              attacksApi: AttacksApi(client),
              diaryApi: DiaryApi(client)));

  testWidgets(
      'restored progress opens editor and finished account skips onboarding on restart',
      (tester) async {
    tester.view.physicalSize = const Size(412, 892);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final client = _AccountClient();
    client.profiles[1]!['onboarding_step'] = 1;
    final auth = authFor(client);
    await auth.restoreSession();
    await tester.pumpWidget(appFor(client, auth));
    await tester.pumpAndSettle();
    expect(find.text('С чего начнём?'), findsOneWidget);
    await tester.tap(find.text('Сейчас есть боль'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Записать приступ'));
    await tester.pumpAndSettle();
    expect(client.profiles[1]!['onboarding_completed'], isTrue);
    expect(find.byType(AttackEntryPage), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await auth.restoreSession();
    await tester.pumpWidget(appFor(client, auth));
    await tester.pumpAndSettle();
    expect(find.byType(OnboardingPage), findsNothing);
    expect(find.byType(AttackEntryPage), findsNothing);
    expect(find.text('Как вы\nсегодня?'), findsOneWidget);
  });

  testWidgets(
      'session expiry closes daily form and a second account gets its own onboarding',
      (tester) async {
    final client = _AccountClient();
    client.profiles[1]!['onboarding_completed'] = true;
    final auth = authFor(client);
    await auth.restoreSession();
    await tester.pumpWidget(appFor(client, auth));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Как прошёл ваш день?'));
    await tester.tap(find.text('Как прошёл ваш день?'));
    await tester.pumpAndSettle();
    expect(find.byType(DailyEntryPage), findsOneWidget);
    client.onSessionExpired!();
    await tester.pumpAndSettle();
    expect(find.byType(DailyEntryPage), findsNothing);
    expect(find.text('Вход'), findsOneWidget);
    client.userId = 2;
    await auth.restoreSession();
    await tester.pumpAndSettle();
    expect(find.text('Начнём с вашего\nсамочувствия'), findsOneWidget);
    expect(client.profiles[2]!['onboarding_completed'], isFalse);
  });

  test('late onboarding response cannot change the next account', () async {
    final client = _AccountClient();
    final auth = authFor(client);
    await auth.restoreSession();
    client.pending = Completer<Map<String, dynamic>>();
    final saving = auth.saveOnboardingProgress(step: 1, completed: true);
    await auth.logout();
    client.userId = 2;
    await auth.restoreSession();
    client.pending!
        .complete({...client.profiles[1]!, 'onboarding_completed': true});
    await saving;
    expect(auth.profile!.id, 2);
    expect(auth.profile!.onboardingCompleted, isFalse);
  });
}

class _AccountClient extends ApiClient {
  _AccountClient() : super(tokenStorage: _SavedTokenStorage());

  int userId = 1;
  Completer<Map<String, dynamic>>? pending;
  final profiles = <int, Map<String, dynamic>>{
    for (var id = 1; id <= 2; id++)
      id: {
        'id': id,
        'name': 'User $id',
        'email': 'user$id@example.com',
        'onboarding_step': 0,
        'onboarding_completed': false,
      },
  };

  @override
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    if (path.startsWith('/diary/')) {
      throw ApiException(
          message: 'Запись дневника не найдена', statusCode: 404);
    }
    final Object body =
        path == '/user/profile' ? {...profiles[userId]!} : <dynamic>[];
    return Response<T>(
        data: body as T,
        requestOptions: RequestOptions(path: path),
        statusCode: 200);
  }

  @override
  Future<Response<T>> put<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    final Map<String, dynamic> body;
    if (pending != null) {
      body = await pending!.future;
    } else {
      final values = data! as Map<String, dynamic>;
      profiles[userId]!.addAll({
        'onboarding_step': values['step'],
        'onboarding_completed': values['completed'],
      });
      body = {...profiles[userId]!};
    }
    return Response<T>(
        data: body as T,
        requestOptions: RequestOptions(path: path),
        statusCode: 200);
  }
}

class _SavedTokenStorage extends TokenStorage {
  @override
  Future<String?> getAccessToken() async => 'saved-token';

  @override
  Future<void> clear() async {}
}
