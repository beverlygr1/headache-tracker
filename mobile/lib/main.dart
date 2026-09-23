import 'package:flutter/material.dart';

import 'core/api/api_client.dart';
import 'features/analytics/data/analytics_api.dart';
import 'features/attacks/data/attacks_api.dart';
import 'features/auth/data/auth_api.dart';
import 'features/diary/data/diary_api.dart';
import 'features/forecast/data/forecast_api.dart';
import 'features/profile/data/profile_api.dart';


void main() {
  final client = ApiClient();

  // Эти API-классы дальше передаются в repository/provider/bloc,
  // когда начнётся подключение реальных экранов.
  final authApi = AuthApi(client);
  final profileApi = ProfileApi(client);
  final attacksApi = AttacksApi(client);
  final diaryApi = DiaryApi(client);
  final analyticsApi = AnalyticsApi(client);
  final forecastApi = ForecastApi(client);

  runApp(
    HeadacheTrackerApp(
      apiServices: [
        authApi,
        profileApi,
        attacksApi,
        diaryApi,
        analyticsApi,
        forecastApi,
      ],
    ),
  );
}


class HeadacheTrackerApp extends StatelessWidget {
  const HeadacheTrackerApp({
    required this.apiServices,
    super.key,
  });

  final List<Object> apiServices;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Headache Tracker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blue,
      ),
      home: const Scaffold(
        body: Center(
          child: Text('API layer is ready'),
        ),
      ),
    );
  }
}
