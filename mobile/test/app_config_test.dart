import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:headache_tracker_app/core/config/app_config.dart';

void main() {
  test('Android emulator reaches the host computer through 10.0.2.2', () {
    expect(
      AppConfig.defaultApiBaseUrl(
        isWeb: false,
        platform: TargetPlatform.android,
      ),
      'http://10.0.2.2:8000/api/v1',
    );
  });

  test('web and desktop use localhost', () {
    expect(
      AppConfig.defaultApiBaseUrl(
        isWeb: true,
        platform: TargetPlatform.android,
      ),
      'http://localhost:8000/api/v1',
    );
    expect(
      AppConfig.defaultApiBaseUrl(
        isWeb: false,
        platform: TargetPlatform.windows,
      ),
      'http://localhost:8000/api/v1',
    );
  });
}
