import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:headache_tracker_app/core/api/api_client.dart';
import 'package:headache_tracker_app/core/storage/token_storage.dart';
import 'package:headache_tracker_app/features/diary/data/daily_entry.dart';
import 'package:headache_tracker_app/features/diary/data/diary_api.dart';
import 'package:headache_tracker_app/features/diary/data/diary_repository.dart';

void main() {
  test('daily entry decodes explicit no-pain separately from unknown', () {
    final absent = DailyEntry.fromJson({'date': '2026-10-10'});
    final noPain = DailyEntry.fromJson({
      'date': '2026-10-10',
      'headache_present': false,
      'sleep_quality': 8,
      'caffeine_intake': 120,
    });
    expect(absent.headachePresent, isNull);
    expect(noPain.headachePresent, isFalse);
    expect(noPain.summary, contains('Без боли'));
    expect(noPain.summary, contains('Качество сна 8/10'));
    expect(noPain.summary, contains('Кофеин 120 мг'));
  });

  test('saving sends nullable diary fields while leaving location untouched',
      () async {
    late RequestOptions sent;
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost/api/v1'));
    dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      sent = options;
      handler.resolve(Response<Map<String, dynamic>>(
        requestOptions: options,
        statusCode: 200,
        data: {
          'date': '2026-10-10',
          ...options.data as Map<String, dynamic>,
        },
      ));
    }));
    final repository = ApiDiaryRepository(
      DiaryApi(ApiClient(dio: dio, tokenStorage: _NoTokens())),
    );

    final saved = await repository.save(DailyEntry(
      date: DateTime(2026, 10, 10),
      headachePresent: false,
      sleepQuality: 8,
      caffeineIntake: 120,
    ));

    expect(sent.method, 'PUT');
    expect(sent.path, '/diary/2026-10-10');
    expect(sent.data, {
      'headache_present': false,
      'sleep_hours': null,
      'sleep_quality': 8,
      'stress_level': null,
      'caffeine_intake': 120,
      'water_ml': null,
    });
    expect(saved.headachePresent, isFalse);
    expect(saved.sleepQuality, 8);
    expect(saved.caffeineIntake, 120);
  });
}

class _NoTokens extends TokenStorage {
  @override
  Future<String?> getAccessToken() async => null;
}
