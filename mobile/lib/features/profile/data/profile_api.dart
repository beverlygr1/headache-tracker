import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';
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

  /// Сохраняет все личные поля разом: `null` очищает значение.
  Future<UserProfile> updatePersonal({
    required DateTime? birthDate,
    required String? gender,
    required String? timeZone,
  }) async {
    final response = await _client.put<Map<String, dynamic>>(
      '/user/profile',
      data: {
        'birth_date': birthDate == null ? null : _dateOnly(birthDate),
        'gender': gender,
        'time_zone': timeZone,
      },
    );
    return UserProfile.fromJson(_requireBody(response.data));
  }

  Future<UserProfile> uploadAvatar(Uint8List bytes) async {
    final type = imageSubtype(bytes);
    if (type == null) {
      throw ApiException(message: 'Нужно фото в формате JPEG, PNG или WebP');
    }
    final response = await _client.put<Map<String, dynamic>>(
      '/user/avatar',
      data: FormData.fromMap({
        'file': MultipartFile.fromBytes(
          bytes,
          filename: 'avatar.$type',
          contentType: DioMediaType('image', type),
        ),
      }),
    );
    return UserProfile.fromJson(_requireBody(response.data));
  }

  /// Байты фото или `null`, если фото нет.
  Future<Uint8List?> fetchAvatar() async {
    try {
      final response = await _client.get<List<int>>(
        '/user/avatar',
        options: Options(responseType: ResponseType.bytes),
      );
      final data = response.data;
      return data == null ? null : Uint8List.fromList(data);
    } on ApiException catch (error) {
      if (error.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<UserProfile> deleteAvatar() async {
    await _client.delete<void>('/user/avatar');
    return getProfile();
  }

  /// `jpeg` / `png` / `webp` по первым байтам файла.
  static String? imageSubtype(Uint8List bytes) {
    bool startsWith(List<int> prefix) =>
        bytes.length >= prefix.length &&
        Iterable<int>.generate(prefix.length)
            .every((i) => bytes[i] == prefix[i]);

    if (startsWith(const [0xFF, 0xD8, 0xFF])) return 'jpeg';
    if (startsWith(const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])) {
      return 'png';
    }
    if (bytes.length >= 12 &&
        startsWith(const [0x52, 0x49, 0x46, 0x46]) &&
        String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP') {
      return 'webp';
    }
    return null;
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
