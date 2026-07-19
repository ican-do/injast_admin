import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class LocalCalendarTask {
  const LocalCalendarTask({
    required this.id,
    required this.title,
    required this.description,
    required this.dueDate,
    required this.createdAt,
    this.source = 'calendar',
  });

  final String id;
  final String title;
  final String description;
  final DateTime dueDate;
  final DateTime createdAt;
  final String source;

  factory LocalCalendarTask.fromJson(Map<String, dynamic> json) =>
      LocalCalendarTask(
        id: json['id']?.toString() ?? '',
        title: json['title']?.toString() ?? '',
        description: json['description']?.toString() ?? '',
        dueDate: DateTime.tryParse(json['due_date']?.toString() ?? '') ??
            DateTime.now(),
        createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
            DateTime.now(),
        source: json['source']?.toString() ?? 'calendar',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'due_date': dueDate.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
        'source': source,
      };
}

/// یادآور تقویم محلی (تا پیاده‌سازی کامل تقویم)
class LocalCalendarStore {
  LocalCalendarStore._();
  static final LocalCalendarStore instance = LocalCalendarStore._();

  static const _keyPrefix = 'local_calendar_tasks_v1_';

  String _key(String codeCo, String? userId) =>
      '$_keyPrefix$codeCo${userId == null ? '' : '_$userId'}';

  Future<List<LocalCalendarTask>> listTasks({
    required String codeCo,
    String? userId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(codeCo, userId));
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      final tasks = decoded
          .whereType<Map>()
          .map((e) => LocalCalendarTask.fromJson(
                Map<String, dynamic>.from(e),
              ))
          .toList();
      tasks.sort((a, b) => a.dueDate.compareTo(b.dueDate));
      return tasks;
    } catch (_) {
      return [];
    }
  }

  Future<LocalCalendarTask> addTask({
    required String codeCo,
    String? userId,
    required String title,
    String description = '',
    required DateTime dueDate,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final tasks = await listTasks(codeCo: codeCo, userId: userId);
    final task = LocalCalendarTask(
      id: const Uuid().v4(),
      title: title,
      description: description,
      dueDate: dueDate,
      createdAt: DateTime.now(),
    );
    tasks.add(task);
    await prefs.setString(
      _key(codeCo, userId),
      jsonEncode(tasks.map((e) => e.toJson()).toList()),
    );
    return task;
  }

  Future<void> deleteTask({
    required String codeCo,
    String? userId,
    required String taskId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final tasks = await listTasks(codeCo: codeCo, userId: userId)
      ..removeWhere((task) => task.id == taskId);
    await prefs.setString(
      _key(codeCo, userId),
      jsonEncode(tasks.map((e) => e.toJson()).toList()),
    );
  }

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
