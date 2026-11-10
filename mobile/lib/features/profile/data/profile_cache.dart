import 'dart:convert';
import '../../../core/api/api_client.dart';
import '../../../core/storage/local_store.dart';
import 'user_profile.dart';

class ProfileCache {
  ProfileCache(this.client, {this.storage = const SecureLocalStore()});
  final ApiClient client;
  final LocalStore storage;

  Future<UserProfile?> read() async {
    final scope = await client.accountScope();
    if (scope == null) return null;
    final raw = await storage.read('profile.v1.$scope');
    if (raw == null) return null;
    return UserProfile.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> write(UserProfile profile) async {
    final token = await client.tokenStorage.getAccessToken();
    final scope = client.scopeForToken(token);
    if (scope == null) return;
    // A response from a previous account must never populate the new cache.
    final claims = jsonDecode(utf8.decode(
        base64Url.decode(base64Url.normalize(token!.split('.')[1])))) as Map;
    if ('${claims['sub']}' != '${profile.id}') return;
    await storage.write(
        'profile.v1.$scope',
        jsonEncode({
          'id': profile.id,
          'email': profile.email,
          'name': profile.name,
          'time_zone': profile.timeZone,
          'gender': profile.gender,
          'birth_date': profile.birthDate?.toIso8601String().split('T').first,
          'onboarding_step': profile.onboardingStep,
          'onboarding_completed': profile.onboardingCompleted,
          'avatar_updated_at': profile.avatarUpdatedAt?.toIso8601String(),
        }));
  }
}
