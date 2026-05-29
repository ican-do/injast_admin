import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// یادآور تقویم محلی (تا پیاده‌سازی کامل تقویم)
class LocalCalendarStore {
  LocalCalendarStore._();
  static final LocalCalendarStore instance = LocalCalendarStore._();

  static const _keyPrefix = 'local_calendar_tasks_v1_';

  Future<void> addBazrasiReminder({
    required String codeCo,
    required String idParvandeh,
    required String codeBazrasi,
    required String title,
    required String description,
    required DateTime dueDate,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_keyPrefix$codeCo';
    final raw = prefs.getString(key);
    final list = <Map<String, dynamic>>[];
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          list.addAll(decoded.map((e) => Map<String, dynamic>.from(e as Map)));
        }
      } catch (_) {}
    }
    list.add({
      'id': const Uuid().v4(),
      'source': 'bazrasi',
      'code_co': codeCo,
      'id_parvandeh': idParvandeh,
      'code_bazrasi': codeBazrasi,
      'title': title,
      'description': description,
      'due_date': dueDate.toIso8601String(),
      'created_at': DateTime.now().toIso8601String(),
    });
    await prefs.setString(key, jsonEncode(list));
  }
}
