import '../../../core/api/api_client.dart';

class ProfileApi {
  ProfileApi(this._client);

  final ApiClient _client;

  Future<Map<String, dynamic>> getProfile() async {
    final response = await _client.get<Map<String, dynamic>>('/user/profile');
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> updateProfile({
    String? timeZone,
    String? gender,
    DateTime? birthDate,
  }) async {
    final response = await _client.put<Map<String, dynamic>>(
      '/user/profile',
      data: {
        if (timeZone != null) 'time_zone': timeZone,
        if (gender != null) 'gender': gender,
        if (birthDate != null) 'birth_date': _dateOnly(birthDate),
      },
    );

    return response.data ?? <String, dynamic>{};
  }

  String _dateOnly(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }
}
