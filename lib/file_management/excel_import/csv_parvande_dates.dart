import 'package:injast_admin/file_management/jalali_date_util.dart';

/// محاسبهٔ `date_exp_store` از تاریخ صدور و وضعیت «اعتبار» در CSV اصناف.
/// `date_etebar_store` در import CSV عمداً خالی می‌ماند.
class CsvParvandeDates {
  CsvParvandeDates._();

  /// [csvValidity] ستون «اعتبار» (مدت دار، منقضی شده، …).
  /// [issueDateServer] تاریخ صدور میلادی `YYYY-MM-DD`.
  static String computeExpServer({
    required String csvValidity,
    required String issueDateServer,
  }) {
    final validity = csvValidity.trim();
    final issue = _parseServerDate(issueDateServer);
    if (issue == null) return '';

    final years = _yearsForCsvValidity(validity);
    if (years <= 0) return '';

    final exp = DateTime(issue.year + years, issue.month, issue.day);
    return JalaliDateUtil.formatGregorian(exp);
  }

  static int _yearsForCsvValidity(String validity) {
    switch (validity) {
      case 'منقضی شده':
      case 'مدت دار':
      case 'در حال بررسی':
        return 5;
      case 'در حال انقضا':
        return 1;
      case 'یک ساله':
        return 1;
      case 'پنج ساله':
        return 5;
      case 'ده ساله':
        return 10;
      default:
        return 5;
    }
  }

  static DateTime? _parseServerDate(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return null;
    if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(t)) {
      final p = t.split('-');
      return DateTime(
        int.parse(p[0]),
        int.parse(p[1]),
        int.parse(p[2]),
      );
    }
    return JalaliDateUtil.parseToGregorian(t);
  }
}
