import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Three-method interface so persistence backends are swappable.
/// Production uses [FlutterSecureKeyValueStore]; tests use an in-memory map.
abstract class SecureKeyValueStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class FlutterSecureKeyValueStore implements SecureKeyValueStore {
  FlutterSecureKeyValueStore(this._inner);
  final FlutterSecureStorage _inner;

  @override
  Future<String?> read(String key) => _inner.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _inner.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _inner.delete(key: key);
}
