import 'package:shared_preferences/shared_preferences.dart';

/// توکن نشست API پس از ورود QR؛ توسط [apiHttp] روی درخواست‌های سرور خودمان می‌نشیند.
class ApiToken {
  static const _kToken = 'api_session_token';
  static const _kExpires = 'api_session_token_exp';

  static String _token = '';
  static int _expiresAt = 0;

  static String get value {
    if (_token.isEmpty) return '';
    if (_expiresAt > 0 && DateTime.now().millisecondsSinceEpoch >= _expiresAt) {
      return '';
    }
    return _token;
  }

  static bool get hasToken => value.isNotEmpty;

  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _token = prefs.getString(_kToken) ?? '';
      _expiresAt = prefs.getInt(_kExpires) ?? 0;
    } catch (_) {
      _token = '';
      _expiresAt = 0;
    }
  }

  static Future<void> save(String token, {int expiresAt = 0}) async {
    _token = token.trim();
    _expiresAt = expiresAt;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kToken, _token);
      await prefs.setInt(_kExpires, _expiresAt);
    } catch (_) {}
  }

  static Future<void> clear() async {
    _token = '';
    _expiresAt = 0;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kToken);
      await prefs.remove(_kExpires);
    } catch (_) {}
  }
}
