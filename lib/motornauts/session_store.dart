import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract class MotornautsSessionStore {
  Future<String?> readCookie();

  Future<void> writeCookie(String cookie);

  Future<void> clearCookie();
}

class SecureMotornautsSessionStore implements MotornautsSessionStore {
  const SecureMotornautsSessionStore({
    FlutterSecureStorage storage = const FlutterSecureStorage(),
  }) : _storage = storage;

  static const _cookieKey = 'motornauts_customer_session_cookie';
  final FlutterSecureStorage _storage;

  @override
  Future<String?> readCookie() => _storage.read(key: _cookieKey);

  @override
  Future<void> writeCookie(String cookie) {
    return _storage.write(key: _cookieKey, value: cookie);
  }

  @override
  Future<void> clearCookie() => _storage.delete(key: _cookieKey);
}

class MemoryMotornautsSessionStore implements MotornautsSessionStore {
  String? cookie;

  @override
  Future<String?> readCookie() async => cookie;

  @override
  Future<void> writeCookie(String cookie) async {
    this.cookie = cookie;
  }

  @override
  Future<void> clearCookie() async {
    cookie = null;
  }
}

String? extractCustomerSessionCookie(Map<String, String> headers) {
  final setCookie = headers['set-cookie'];
  if (setCookie == null || setCookie.isEmpty) {
    return null;
  }

  final match = RegExp(
    r'(motornauts_customer_session=[^;,\s]+)',
    caseSensitive: false,
  ).firstMatch(setCookie);
  return match?.group(1);
}
