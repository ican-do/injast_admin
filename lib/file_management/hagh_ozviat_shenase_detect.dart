import 'package:injast_admin/file_management/excel_import/excel_import_shenase.dart';
import 'package:injast_admin/file_management/hagh_ozviat_columns.dart';

/// یافتن ستون «کد صنفی» واقعی وقتی چند ستون شبیه هم در export وجود دارد.
class HaghOzviatShenaseDetect {
  HaghOzviatShenaseDetect._();

  static String? pickBestColumn(
    List<String> headers,
    List<Map<String, String>> rows,
  ) {
    String? best;
    var bestDistinct = 0;

    for (final header in headers) {
      final nk = HaghOzviatColumns.normKey(header);
      if (!_headerLooksLikeShenase(nk)) continue;

      final distinct = <String>{};
      for (final row in rows) {
        final raw = row[header]?.trim() ?? '';
        if (raw.isEmpty) continue;
        final n = ExcelImportShenase.normalize(raw);
        if (_isPlausibleShenase(n)) distinct.add(n);
      }

      if (distinct.length > bestDistinct) {
        bestDistinct = distinct.length;
        best = header;
      }
    }
    return best;
  }

  static bool _headerLooksLikeShenase(String nk) {
    if (nk.contains('کدملی') || nk.contains('کدملی')) return false;
    if (nk.contains('مبلغ') || nk.contains('سال') || nk.contains('تاریخ')) {
      return false;
    }
    return nk.contains('کدصنفی') ||
        nk.contains('شناسهصنفی') ||
        nk.contains('شناسهواحد') ||
        (nk.contains('شناسه') && nk.contains('صنف'));
  }

  static bool _isPlausibleShenase(String n) {
    if (n.isEmpty) return false;
    if (!RegExp(r'^\d+$').hasMatch(n)) return false;
    return n.length >= 8 && n.length <= 12;
  }

  /// همهٔ مقادیر شبیه کد صنفی در یک ردیف (به‌جز کدملی).
  static List<String> scrapeFromRow(Map<String, String> values) {
    final melli = HaghOzviatColumns.readMelli(values);
    final found = <String>[];

    for (final e in values.entries) {
      final nk = HaghOzviatColumns.normKey(e.key);
      if (nk.contains('کدملی') || nk.contains('کدملی')) continue;
      if (nk.contains('مبلغ') ||
          nk.contains('سال') ||
          nk.contains('تاریخ') ||
          nk.contains('وضعیت') ||
          nk.contains('عنوان') && !nk.contains('رسته')) {
        continue;
      }

      final n = ExcelImportShenase.normalize(e.value);
      if (!_isPlausibleShenase(n)) continue;
      if (melli.isNotEmpty && n == melli) continue;
      if (!found.contains(n)) found.add(n);
    }
    return found;
  }
}
