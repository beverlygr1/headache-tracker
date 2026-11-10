import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:headache_tracker_app/app/app.dart';
import 'package:headache_tracker_app/core/api/api_client.dart';
import 'package:headache_tracker_app/core/api/api_exception.dart';
import 'package:headache_tracker_app/core/storage/local_store.dart';
import 'package:headache_tracker_app/core/storage/token_storage.dart';
import 'package:headache_tracker_app/features/diary/data/diary_repository.dart';
import 'package:headache_tracker_app/features/diary/presentation/daily_entry_page.dart';
import 'package:headache_tracker_app/features/offline/data/local_workspace.dart';
import 'package:headache_tracker_app/features/auth/data/auth_api.dart';
import 'package:headache_tracker_app/features/auth/state/auth_controller.dart';
import 'package:headache_tracker_app/features/profile/data/profile_api.dart';
import 'package:headache_tracker_app/features/profile/data/profile_cache.dart';
import 'package:headache_tracker_app/features/profile/data/user_profile.dart';
import 'package:headache_tracker_app/features/analytics/data/analytics_api.dart';
import 'package:headache_tracker_app/features/analytics/presentation/report_page.dart';
import 'package:headache_tracker_app/features/tracker/data/attack_repository.dart';
import 'package:headache_tracker_app/features/tracker/domain/attack_record.dart';
import 'package:headache_tracker_app/features/tracker/presentation/pages/attack_entry_page.dart';
import 'package:headache_tracker_app/features/tracker/presentation/pages/attack_details_page.dart';
import 'package:headache_tracker_app/features/tracker/state/tracker_controller.dart';

void main() {
  testWidgets('report blocks export while local records are pending',
      (tester) async {
    final f = _Fixture();
    final work = f.workspace();
    work.markOffline();
    await work.write('attacks', 'POST', _attack);
    expect(f.server.requests, 0);
    await tester.pumpWidget(HeadacheTrackerApp(
        home: ReportPage(
            api: AnalyticsApi(f.client),
            timeZone: 'Asia/Tomsk',
            workspace: work,
            share: (_, __) async =>
                throw StateError('An incomplete report must not be shared'))));
    await tester.pumpAndSettle();
    final save = find.text('Сохранить или поделиться PDF');
    await tester.scrollUntilVisible(save, 150,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(
        find.text(
            'Есть записи, ожидающие отправки. Сначала отправьте их из дневника.'),
        findsOneWidget);
    expect(f.server.requests, 0);
    await tester.pumpWidget(const SizedBox.shrink());
    work.dispose();
  });
  test('cached profile permits offline restart only for the same account',
      () async {
    final f = _Fixture();
    final cache = ProfileCache(f.client, storage: f.store);
    await cache.write(const UserProfile(
        id: 1,
        email: 'alice@example.com',
        name: 'Алиса',
        onboardingCompleted: true));
    final a = AuthController(
        client: f.client,
        authApi: AuthApi(f.client),
        profileApi: ProfileApi(f.client),
        profileCache: cache);
    await a.restoreSession();
    expect(a.status, AuthStatus.authenticated);
    expect(a.profile!.id, 1);
    expect(a.profile!.onboardingCompleted, isTrue);
    a.dispose();
    f.tokens.user = '2';
    final b = AuthController(
        client: f.client,
        authApi: AuthApi(f.client),
        profileApi: ProfileApi(f.client),
        profileCache: cache);
    await b.restoreSession();
    expect(b.profile, isNull);
    b.dispose();
  });

  test('drafts survive restart and are isolated by account and server',
      () async {
    final f = _Fixture();
    final a = f.workspace();
    await a.saveDraft('daily:2026-11-05', {'sleep': '7,', 'caffeine': ''});
    a.dispose();
    final restored = f.workspace();
    expect((await restored.readDraft('daily:2026-11-05'))!['sleep'], '7,');
    f.tokens.user = '2';
    final b = f.workspace();
    expect(await b.readDraft('daily:2026-11-05'), isNull);
    f.tokens.user = '1';
    f.client.baseUrl = 'https://second.test/api/v1';
    final otherServer = f.workspace();
    expect(await otherServer.readDraft('daily:2026-11-05'), isNull);
    restored.dispose();
    b.dispose();
    otherServer.dispose();
  });

  test(
      'offline save moves draft into durable outbox and replays edits and finish in order',
      () async {
    final f = _Fixture();
    final work = f.workspace();
    await work.saveDraft('attack:new', {'intensity': 5});
    final local = await work.submitDraft(
        'attack:new', () => work.write('attacks', 'POST', _attack));
    expect(local!['id'], lessThan(0));
    expect(local['pending_sync'], isTrue);
    expect(await work.readDraft('attack:new'), isNull);
    await work.write(
        'attacks',
        'PUT',
        {
          'intensity': 8,
          'medications': ['A'],
          'medication_effects': {'A': 'partly'}
        },
        entity: '${local['id']}');
    await work.write('attacks', 'PUT', {'end_time': '2026-11-05T04:00:00Z'},
        entity: '${local['id']}');
    expect(work.pendingCount, 3);
    work.dispose();
    final restored = f.workspace();
    f.server.online = true;
    await restored.sync();
    expect(restored.pendingCount, 0);
    expect(f.server.attacks, hasLength(1));
    final actual = f.server.attacks.values.single;
    expect(actual['intensity'], 8);
    expect(actual['end_time'], '2026-11-05T04:00:00Z');
    expect(actual['medication_effects'], {'A': 'partly'});
    final cached = (await restored.readRecords('attacks')).single;
    expect(cached['id'], greaterThan(0));
    expect(cached['pending_sync'], isNot(true));
    restored.dispose();
  });

  test('lost response retries the same request id without duplicate attack',
      () async {
    final f = _Fixture();
    f.server.online = true;
    f.server.loseResponse = true;
    final work = f.workspace();
    await work.write('attacks', 'POST', _attack);
    expect(f.server.attacks, hasLength(1));
    expect(work.pendingCount, 1);
    work.dispose();
    final restored = f.workspace();
    await Future.wait([restored.sync(), restored.sync()]);
    expect(restored.pendingCount, 0);
    expect(f.server.attacks, hasLength(1));
    expect(f.server.createRequests, 2);
    restored.dispose();
  });

  test('switching account prevents replaying or exposing another account queue',
      () async {
    final f = _Fixture();
    final a = f.workspace();
    await a.write('attacks', 'POST', _attack);
    final requests = f.server.requests;
    f.tokens.user = '2';
    f.server.online = true;
    await a.sync();
    expect(f.server.requests, requests);
    expect(a.pendingCount, 1);
    final b = f.workspace();
    expect(await b.readRecords('attacks'), isEmpty);
    await b.sync();
    expect(f.server.attacks, isEmpty);
    a.dispose();
    b.dispose();
  });

  test('an edit queued during replay is preserved and sent after creation',
      () async {
    final f = _Fixture();
    final work = f.workspace();
    final local = await work.write('attacks', 'POST', _attack);
    f.server.online = true;
    f.server.hold = Completer<void>();
    final sync = work.sync();
    await f.server.started.future;
    final edited = await work.write('attacks', 'PUT', {'intensity': 9},
        entity: '${local!['id']}');
    expect(edited!['intensity'], 9);
    f.server.hold!.complete();
    await sync;
    expect(f.server.attacks.values.single['intensity'], 9);
    expect((await work.readRecords('attacks')).single['intensity'], 9);
    expect(work.pendingCount, 0);
    work.dispose();
  });

  test('unknown offline diary fields do not erase existing server values',
      () async {
    final f = _Fixture();
    f.server.diaries['2026-11-05'] = {
      'date': '2026-11-05',
      'sleep_hours': 8,
      'caffeine_intake': 0
    };
    final work = f.workspace();
    work.markOffline();
    await work.write('diary', 'PUT',
        {'water_ml': 250, 'sleep_hours': null, 'caffeine_intake': null},
        entity: '2026-11-05');
    f.server.online = true;
    await work.sync();
    expect(f.server.diaries['2026-11-05']!['sleep_hours'], 8);
    expect(f.server.diaries['2026-11-05']!['caffeine_intake'], 0);
    expect(f.server.diaries['2026-11-05']!['water_ml'], 250);
    await work.write('diary', 'PUT', {'water_ml': null}, entity: '2026-11-05');
    expect(f.server.diaries['2026-11-05']!['water_ml'], isNull);
    work.dispose();
  });

  test('validation errors retain draft and do not count as an offline save',
      () async {
    final f = _Fixture();
    f.server.online = true;
    f.server.reject = true;
    final work = f.workspace();
    await work.saveDraft('attack:new', {'intensity': 11});
    await expectLater(
        work.submitDraft(
            'attack:new', () => work.write('attacks', 'POST', _attack)),
        throwsA(isA<ApiException>()));
    expect(work.pendingCount, 0);
    expect(await work.readRecords('attacks'), isEmpty);
    expect((await work.readDraft('attack:new'))!['intensity'], 11);
    work.dispose();
  });

  test('storage failure does not send data or claim it was saved locally',
      () async {
    final f = _Fixture();
    f.store.failWrites = true;
    f.server.online = true;
    final work = f.workspace();
    await expectLater(
        work.write('attacks', 'POST', _attack), throwsA(isA<ApiException>()));
    expect(f.server.requests, 0);
    expect(work.pendingCount, 0);
    work.dispose();
  });

  testWidgets('daily raw input restores after closing the form',
      (tester) async {
    final f = _Fixture();
    var work = f.workspace();
    final repo = InMemoryDiaryRepository();
    final day = DateTime(2026, 11, 5);
    await tester.pumpWidget(HeadacheTrackerApp(
        home: DailyEntryPage(repository: repo, date: day, workspace: work)));
    await tester.pumpAndSettle();
    final field = find.byKey(const ValueKey('sleep-hours-field'));
    await tester.scrollUntilVisible(field, 150,
        scrollable: find.byType(Scrollable).first);
    await tester.enterText(field, '7,');
    expect((await work.readDraft('daily:2026-11-05'))!['sleep'], '7,');
    await tester.pumpWidget(const SizedBox.shrink());
    work.dispose();
    work = f.workspace();
    await tester.pumpWidget(HeadacheTrackerApp(
        home: DailyEntryPage(repository: repo, date: day, workspace: work)));
    await tester.pumpAndSettle();
    expect(find.text('Черновик восстановлен'), findsOneWidget);
    await tester.scrollUntilVisible(field, 150,
        scrollable: find.byType(Scrollable).first);
    expect(tester.widget<TextFormField>(field).controller!.text, '7,');
    await tester.pumpWidget(const SizedBox.shrink());
    work.dispose();
  });

  testWidgets(
      'attack draft restores intensity, details and individual medication result',
      (tester) async {
    final f = _Fixture();
    final work = f.workspace();
    await work.saveDraft('attack:new', {
      'start_time': '2026-11-05T10:00:00',
      'intensity': 9,
      'zones': ['Лоб'],
      'symptoms': ['Тошнота'],
      'pain_type': 'Давящая',
      'medications': ['A'],
      'relief': ['Отдых'],
      'effects': {'A': 'helped'},
      'details': true,
    });
    final tracker = TrackerController(
        repository: InMemoryAttackRepository(), workspace: work);
    await tracker.load();
    await tester.pumpWidget(
        HeadacheTrackerApp(home: AttackEntryPage(controller: tracker)));
    await tester.pumpAndSettle();
    expect(find.text('Черновик восстановлен'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('9'), 150,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('9'), findsOneWidget);
    final effect = find.byKey(const ValueKey('effect-A-helped'));
    await tester.scrollUntilVisible(effect, 250,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    expect(tester.widget<ChoiceChip>(effect).selected, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
    tracker.dispose();
    work.dispose();
  });

  testWidgets(
      'medication result saves and displays without preselecting another result',
      (tester) async {
    final record = AttackRecord(
        id: 1,
        startTime: DateTime(2026, 11, 5, 10),
        intensity: 5,
        painLocation: '',
        symptoms: const [],
        medications: const ['A', 'B']);
    final tracker =
        TrackerController(repository: InMemoryAttackRepository([record]));
    await tracker.load();
    await tester.pumpWidget(HeadacheTrackerApp(
        home: Builder(
            builder: (context) => Scaffold(
                  body: TextButton(
                      onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                              builder: (_) => AttackEntryPage(
                                  controller: tracker, initialRecord: record))),
                      child: const Text('Открыть')),
                ))));
    await tester.tap(find.text('Открыть'));
    await tester.pumpAndSettle();
    final effect = find.byKey(const ValueKey('effect-A-helped'));
    await tester.scrollUntilVisible(effect, 250,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await Scrollable.ensureVisible(tester.element(effect), alignment: .3);
    await tester.pumpAndSettle();
    expect(effect.hitTestable(), findsOneWidget);
    await tester.tap(effect);
    await tester.pump();
    expect(tester.widget<ChoiceChip>(effect).selected, isTrue);
    await tester.tap(find.text('Продолжить'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Сохранить приступ'));
    await tester.pumpAndSettle();
    expect(tracker.byId(1)!.medicationEffects, {'A': 'helped'});
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(HeadacheTrackerApp(
        home: AttackDetailsPage(controller: tracker, recordId: 1)));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.textContaining('A — Помог'), 200,
        scrollable: find.byType(Scrollable).first);
    expect(find.textContaining('A — Помог'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    tracker.dispose();
  });
}

final _attack = <String, dynamic>{
  'start_time': '2026-11-05T03:00:00Z',
  'intensity': 5,
  'medications': <String>[],
  'symptoms': <String>[]
};

class _Store implements LocalStore {
  final values = <String, String>{};
  bool failWrites = false;
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async {
    if (failWrites) throw StateError('disk full');
    values[key] = value;
  }
}

class _Tokens extends TokenStorage {
  String user = '1';
  @override
  Future<String?> getAccessToken() async =>
      'header.${base64Url.encode(utf8.encode(jsonEncode({
            'sub': user
          })))}.signature';
}

class _Fixture {
  final store = _Store();
  final tokens = _Tokens();
  final server = _Server();
  late final client = ApiClient(
      dio: Dio(BaseOptions(baseUrl: 'https://example.test/api/v1'))
        ..httpClientAdapter = server,
      tokenStorage: tokens);
  LocalWorkspace workspace() => LocalWorkspace(
      client: client,
      storage: store,
      accountScope: client.scopeForSubject(tokens.user));
}

class _Server implements HttpClientAdapter {
  bool online = false, loseResponse = false, reject = false;
  int requests = 0, createRequests = 0;
  final attacks = <int, Map<String, dynamic>>{};
  final diaries = <String, Map<String, dynamic>>{};
  final ids = <String, int>{};
  Completer<void>? hold;
  final started = Completer<void>();
  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? stream,
      Future<void>? cancel) async {
    requests++;
    if (!online) {
      throw DioException(
          requestOptions: options, type: DioExceptionType.connectionError);
    }
    if (hold != null && !hold!.isCompleted) {
      if (!started.isCompleted) started.complete();
      await hold!.future;
    }
    if (reject) return _json({'detail': 'Проверьте данные'}, 422);
    final data = Map<String, dynamic>.from(options.data as Map? ?? {});
    if (options.path == '/attacks' && options.method == 'POST') {
      createRequests++;
      final requestId = data['client_request_id'] as String;
      final id = ids.putIfAbsent(requestId, () => ids.length + 1);
      attacks.putIfAbsent(id, () => {'id': id, ...data});
      if (loseResponse) {
        loseResponse = false;
        throw DioException(
            requestOptions: options, type: DioExceptionType.receiveTimeout);
      }
      return _json(attacks[id], 201);
    }
    if (options.path.startsWith('/attacks/')) {
      final id = int.parse(options.path.split('/').last);
      if (options.method == 'DELETE') {
        attacks.remove(id);
        return _json(null, 204);
      }
      attacks[id] = {...?attacks[id], ...data};
      return _json(attacks[id], 200);
    }
    if (options.path.startsWith('/diary/')) {
      final day = options.path.split('/').last;
      diaries[day] = {'date': day, ...?diaries[day], ...data};
      return _json(diaries[day], 200);
    }
    return _json([], 200);
  }

  ResponseBody _json(Object? data, int status) =>
      ResponseBody.fromString(data == null ? '' : jsonEncode(data), status,
          headers: {
            Headers.contentTypeHeader: ['application/json']
          });
  @override
  void close({bool force = false}) {}
}
