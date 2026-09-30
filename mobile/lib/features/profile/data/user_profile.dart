/// Профиль пользователя (`UserProfileResponse` backend).
class UserProfile {
  const UserProfile({
    required this.id,
    required this.email,
    required this.name,
    this.timeZone,
    this.gender,
    this.birthDate,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final birthDate = json['birth_date'];
    return UserProfile(
      id: json['id'] as int,
      email: json['email'] as String,
      name: json['name'] as String,
      timeZone: json['time_zone'] as String?,
      gender: json['gender'] as String?,
      birthDate: birthDate is String ? DateTime.parse(birthDate) : null,
    );
  }

  final int id;
  final String email;
  final String name;
  final String? timeZone;
  final String? gender;
  final DateTime? birthDate;
}
