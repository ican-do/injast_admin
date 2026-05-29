import 'package:injast_admin/file_management/excel_import/excel_import_shenase.dart';
import 'package:injast_admin/file_management/hagh_ozviat_columns.dart';

/// نگاشت‌های کمکی برای یافتن کد صنفی از پرونده‌های اتحادیه.
class HaghOzviatRegistry {
  const HaghOzviatRegistry({
    required this.byMelli,
    required this.byFullName,
  });

  final Map<String, String> byMelli;
  final Map<String, String> byFullName;

  static HaghOzviatRegistry fromParvandeRows(List<Map<String, dynamic>> rows) {
    final byMelli = <String, String>{};
    final byFullName = <String, String>{};

    for (final row in rows) {
      final shenase = ExcelImportShenase.normalize(
        row['shenase_store']?.toString() ?? '',
      );
      if (shenase.isEmpty) continue;

      final melli = HaghOzviatColumns.normalizeMelli(
        row['code_meli_admin']?.toString() ?? '',
      );
      if (melli.isNotEmpty) {
        byMelli[melli] = shenase;
      }

      final nameKey = _nameKey(
        row['name_admin']?.toString() ?? '',
        row['family_admin']?.toString() ?? '',
      );
      if (nameKey.isNotEmpty) {
        byFullName[nameKey] = shenase;
      }
    }

    return HaghOzviatRegistry(byMelli: byMelli, byFullName: byFullName);
  }

  String? resolveShenase({
    required String shenaseFromRow,
    required String melliFromRow,
    required String firstName,
    required String familyName,
  }) {
    if (shenaseFromRow.isNotEmpty) return shenaseFromRow;

    if (melliFromRow.isNotEmpty) {
      final fromMelli = byMelli[melliFromRow];
      if (fromMelli != null && fromMelli.isNotEmpty) return fromMelli;
    }

    final nameKey = _nameKey(firstName, familyName);
    if (nameKey.isNotEmpty) {
      final fromName = byFullName[nameKey];
      if (fromName != null && fromName.isNotEmpty) return fromName;
    }

    return null;
  }

  static String _nameKey(String first, String family) {
    final f = first.trim().replaceAll(RegExp(r'\s+'), ' ');
    final l = family.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (f.isEmpty && l.isEmpty) return '';
    return '$f|$l';
  }
}
