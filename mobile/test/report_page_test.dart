import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:headache_tracker_app/app/app.dart';
import 'package:headache_tracker_app/core/api/api_client.dart';
import 'package:headache_tracker_app/core/api/api_exception.dart';
import 'package:headache_tracker_app/features/analytics/data/analytics_api.dart';
import 'package:headache_tracker_app/features/analytics/presentation/report_page.dart';

void main() {
  testWidgets('report retries with the selected period and shares server PDF',
      (tester) async {
    final api = _Reports()..fail = true;
    var shared = false;
    await tester.pumpWidget(HeadacheTrackerApp(
        home: ReportPage(
      api: api,
      timeZone: 'Asia/Tomsk',
      initialRange: DateTimeRange(
          start: DateTime(2026, 11, 1), end: DateTime(2026, 11, 5)),
      share: (bytes, filename) async {
        expect(bytes, [37, 80, 68, 70]);
        expect(filename, 'headache-report-2026-11-01_2026-11-05.pdf');
        shared = true;
        return true;
      },
    )));
    await tester.pumpAndSettle();
    final save = find.text('Сохранить или поделиться PDF');
    await tester.scrollUntilVisible(save, 150,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(find.text('Нет связи с сервером'), findsOneWidget);
    expect(shared, isFalse);
    api.fail = false;
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(shared, isTrue);
    expect(api.start, DateTime(2026, 11, 1));
    expect(api.end, DateTime(2026, 11, 5));
    expect(api.zone, 'Asia/Tomsk');
    expect(api.calls, 2);
  });

  testWidgets('too long report period is explained before contacting server',
      (tester) async {
    final api = _Reports();
    await tester.pumpWidget(HeadacheTrackerApp(
        home: ReportPage(
      api: api,
      timeZone: 'UTC',
      initialRange: DateTimeRange(
          start: DateTime(2024, 1, 1), end: DateTime(2026, 11, 5)),
      share: (_, __) async => true,
    )));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Сохранить или поделиться PDF'));
    await tester.pumpAndSettle();
    expect(api.calls, 0);
    expect(find.text('Выберите период не больше 366 дней.'), findsOneWidget);
  });

  testWidgets(
      'closing the report while loading never opens a stale share sheet',
      (tester) async {
    final api = _Reports()..pending = Completer<Uint8List>();
    var shared = false;
    await tester.pumpWidget(HeadacheTrackerApp(
        home: ReportPage(
      api: api,
      timeZone: 'UTC',
      share: (_, __) async {
        shared = true;
        return true;
      },
    )));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Сохранить или поделиться PDF'));
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    api.pending!.complete(Uint8List.fromList([37, 80, 68, 70]));
    await tester.pumpAndSettle();
    expect(shared, isFalse);
    expect(tester.takeException(), isNull);
  });
}

class _Reports extends AnalyticsApi {
  _Reports() : super(ApiClient());
  bool fail = false;
  int calls = 0;
  DateTime? start, end;
  String? zone;
  Completer<Uint8List>? pending;
  @override
  Future<Uint8List> export(
      {required String format,
      DateTime? fromDate,
      DateTime? toDate,
      String? timeZone}) async {
    calls++;
    expect(format, 'pdf');
    start = fromDate;
    end = toDate;
    zone = timeZone;
    if (fail) {
      throw ApiException(message: 'Нет связи с сервером', isNetworkError: true);
    }
    return pending == null
        ? Uint8List.fromList([37, 80, 68, 70])
        : pending!.future;
  }
}
