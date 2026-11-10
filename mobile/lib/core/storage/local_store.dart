import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class LocalStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
}

class SecureLocalStore implements LocalStore {
  const SecureLocalStore();
  static const _storage = FlutterSecureStorage();
  @override
  Future<String?> read(String key) => _storage.read(key: key);
  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);
}
