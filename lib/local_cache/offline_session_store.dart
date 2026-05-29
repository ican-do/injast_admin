import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// آخرین نشست ورود موفق (برای ورود آفلاین وقتی سرور در دسترس نیست).
class OfflineSessionStore {
  static const _kUserKey = 'offline_last_user_v1';
  static const _kUnionKey = 'offline_last_union_v1';

  Future<void> saveSession({
    required Map<String, dynamic> user,
    Map<String, dynamic>? unionInfo,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kUserKey, jsonEncode(user));
    if (unionInfo != null) {
      await prefs.setString(_kUnionKey, jsonEncode(unionInfo));
    }
  }

  Future<({Map<String, dynamic>? user, Map<String, dynamic>? unionInfo})> readSession() async {
    final prefs = await SharedPreferences.getInstance();
    Map<String, dynamic>? user;
    Map<String, dynamic>? union;
    final u = prefs.getString(_kUserKey);
    if (u != null && u.trim().isNotEmpty) {
      try {
        final d = jsonDecode(u);
        if (d is Map) user = Map<String, dynamic>.from(d);
      } catch (_) {}
    }
    final c = prefs.getString(_kUnionKey);
    if (c != null && c.trim().isNotEmpty) {
      try {
        final d = jsonDecode(c);
        if (d is Map) union = Map<String, dynamic>.from(d);
      } catch (_) {}
    }
    return (user: user, unionInfo: union);
  }

  Future<bool> hasSavedSession() async {
    final s = await readSession();
    final codeCo = s.user?['code_co']?.toString().trim() ?? '';
    return codeCo.isNotEmpty;
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kUserKey);
    await prefs.remove(_kUnionKey);
  }
}
