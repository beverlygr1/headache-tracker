import '../../../core/api/api_client.dart';
import 'user_profile.dart';

class ProfileApi {
  ProfileApi(this._client);

  final ApiClient _client;

  Future<UserProfile> updateOnboarding({
    required int step,
    bool completed = false,
  }) async {
    final response = await _client.put<Map<String, dynamic>>(
      '/user/onboarding',
      data: {'step': step, 'completed': completed},
    );
    return UserProfile.fromJson(_requireBody(response.data));
  }

  Future<UserProfile> getProfile() async {
    final response = await _client.get<Map<String, dynamic>>('/user/profile');
    return UserProfile.fromJson(_requireBody(response.data));
  }

  Future<UserProfile> updateProfile({
    String? name,
    String? timeZone,
    String? gender,
    DateTime? birthDate,
  }) async {
    final response = await _client.put<Map<String, dynamic>>(
      '/user/profile',
      data: {
        if (name != null) 'name': name,
        if (timeZone != null) 'time_zone': timeZone,
        if (gender != null) 'gender': gender,
        if (birthDate != null) 'birth_date': _dateOnly(birthDate),
      },
    );

    return UserProfile.fromJson(_requireBody(response.data));
  }

  Map<String, dynamic> _requireBody(Map<String, dynamic>? data) {
    if (data == null) {
      throw StateError('Пустой ответ от /user/profile');
    }
    return data;
  }

  String _dateOnly(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }
}
