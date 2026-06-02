import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:injast_admin/file_management/hagh_ozviat_models.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// کش محلی گزارش حق عضویت (برای حالت آفلاین).
class HaghOzviatReportCache {
  HaghOzviatReportCache._();
  static final HaghOzviatReportCache instance = HaghOzviatReportCache._();

  Future<File?> _cacheFile(String codeCo) async {
    if (kIsWeb) return null;
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, 'hagh_report_cache'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return File(p.join(dir.path, '$codeCo.json'));
  }

  Future<void> saveRows({
    required String codeCo,
    required List<HaghOzviatRow> rows,
  }) async {
    final file = await _cacheFile(codeCo);
    if (file == null) return;
    final payload = {
      'savedAt': DateTime.now().toIso8601String(),
      'rows': rows.map((e) => e.toSyncJson()).toList(),
    };
    await file.writeAsString(jsonEncode(payload));
  }

  Future<({DateTime? savedAt, List<HaghOzviatRow> rows})?> loadRows(
    String codeCo,
  ) async {
    final file = await _cacheFile(codeCo);
    if (file == null || !await file.exists()) return null;
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map) return null;
      final list = decoded['rows'];
      if (list is! List) return null;
      final rows = list
          .whereType<Map>()
          .map((e) => HaghOzviatRow.fromServerJson(
                Map<String, dynamic>.from(e),
              ))
          .where((r) => r.shenaseStore.isNotEmpty)
          .toList();
      final savedAt = DateTime.tryParse(decoded['savedAt']?.toString() ?? '');
      return (savedAt: savedAt, rows: rows);
    } catch (_) {
      return null;
    }
  }

  Future<bool> hasCache(String codeCo) async {
    final file = await _cacheFile(codeCo);
    return file != null && await file.exists();
  }
}
