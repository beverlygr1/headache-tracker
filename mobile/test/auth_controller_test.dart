import 'package:flutter_test/flutter_test.dart';
import 'package:headache_tracker_app/core/api/api_client.dart';
import 'package:headache_tracker_app/core/storage/token_storage.dart';
import 'package:headache_tracker_app/features/auth/data/auth_api.dart';
import 'package:headache_tracker_app/features/auth/state/auth_controller.dart';
import 'package:headache_tracker_app/features/profile/data/profile_api.dart';

void main() {
  AuthController buildController(TokenStorage storage) {
    final client = ApiClient(tokenStorage: storage);
    return AuthController(
      client: client,
      authApi: AuthApi(client),
      profileApi: ProfileApi(client),
    );
  }

  test('without saved token user must log in', () async {
    final controller = buildController(_MemoryTokenStorage());

    await controller.restoreSession();

    expect(controller.status, AuthStatus.unauthenticated);
  });

  test('unreadable token storage is cleared instead of hanging', () async {
    final storage = _BrokenTokenStorage();
    final controller = buildController(storage);

    await controller.restoreSession();

    expect(controller.status, AuthStatus.unauthenticated);
    expect(storage.cleared, isTrue);
  });
}

class _MemoryTokenStorage extends TokenStorage {
  String? _access;
  String? _refresh;

  @override
  Future<String?> getAccessToken() async => _access;

  @override
  Future<String?> getRefreshToken() async => _refresh;

  @override
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    _access = accessToken;
    _refresh = refreshToken;
  }

  @override
  Future<void> clear() async {
    _access = null;
    _refresh = null;
  }
}

class _BrokenTokenStorage extends _MemoryTokenStorage {
  bool cleared = false;

  @override
  Future<String?> getAccessToken() async => throw StateError('OperationError');

  @override
  Future<void> clear() async => cleared = true;
}
