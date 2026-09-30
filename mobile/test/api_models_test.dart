import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:headache_tracker_app/core/api/api_exception.dart';
import 'package:headache_tracker_app/features/attacks/data/attack_dto.dart';

void main() {
  group('AttackDto', () {
    test('parses backend response and converts time to local', () {
      final dto = AttackDto.fromJson({
        'id': 7,
        'user_id': 1,
        'start_time': '2026-09-23T06:30:00Z',
        'end_time': '2026-09-23T07:15:00+00:00',
        'intensity': 6,
        'pain_type': null,
        'localization': 'Виски',
        'medications': null,
        'symptoms': ['Тошнота'],
        'relief_factors': null,
      });

      expect(dto.id, 7);
      expect(dto.startTime.isUtc, isFalse);
      expect(dto.startTime.toUtc(), DateTime.utc(2026, 9, 23, 6, 30));
      expect(dto.endTime!.toUtc(), DateTime.utc(2026, 9, 23, 7, 15));
      expect(dto.localization, 'Виски');
      expect(dto.symptoms, ['Тошнота']);
      expect(dto.medications, isEmpty);
    });

    test('treats time without offset as UTC', () {
      expect(
        parseApiDateTime('2026-09-23T06:30:00').toUtc(),
        DateTime.utc(2026, 9, 23, 6, 30),
      );
    });

    test('sends time in UTC', () {
      final local = DateTime.utc(2026, 9, 23, 6, 30).toLocal();
      expect(formatApiDateTime(local), '2026-09-23T06:30:00.000Z');
    });
  });

  group('ApiException', () {
    DioException responseError(int status, Object? data) {
      final options = RequestOptions(path: '/attacks');
      return DioException(
        requestOptions: options,
        response: Response(
          requestOptions: options,
          statusCode: status,
          data: data,
        ),
      );
    }

    test('uses string detail from FastAPI', () {
      final error = ApiException.fromDio(
        responseError(401, {'detail': 'Неверный email или пароль'}),
      );
      expect(error.message, 'Неверный email или пароль');
      expect(error.isUnauthorized, isTrue);
    });

    test('joins Pydantic validation messages', () {
      final error = ApiException.fromDio(
        responseError(422, {
          'detail': [
            {
              'loc': ['body', 'intensity'],
              'msg': 'Input should be <= 10'
            },
          ],
        }),
      );
      expect(error.message, 'Input should be <= 10');
    });

    test('falls back to status text', () {
      final error = ApiException.fromDio(responseError(503, 'Bad gateway'));
      expect(error.message, 'Ошибка сервера (503)');
    });

    test('marks connection problems as network errors', () {
      final error = ApiException.fromDio(
        DioException.connectionError(
          requestOptions: RequestOptions(path: '/attacks'),
          reason: 'refused',
        ),
      );
      expect(error.isNetworkError, isTrue);
      expect(error.message, 'Нет соединения с сервером');
    });
  });
}
