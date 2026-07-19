import 'package:injast_admin/file_management/excel_import/excel_import_columns.dart';
import 'package:injast_admin/file_management/excel_import/excel_import_models.dart';
import 'package:injast_admin/file_management/excel_import/excel_import_shenase.dart';
import 'package:injast_admin/file_management/jalali_date_util.dart';
import 'package:injast_admin/file_management/parvande_vaziyat.dart';

/// نتیجهٔ مرتب‌سازی و حذف تکراری کد صنفی در فایل CSV.
class CsvImportDedupeResult {
  const CsvImportDedupeResult({
    required this.kept,
    required this.removedCount,
  });

  final List<ExcelParsedRow> kept;
  final int removedCount;
}

/// مرتب‌سازی بر اساس کد صنفی و حذف تکراری‌ها با قوانین وضعیت/تاریخ صدور.
///
/// قوانین برای هر گروه با کد صنفی یکسان:
/// ۱) اگر حداقل یک «فعال/صادر شده» باشد → همان نگه داشته می‌شود (در چندتایی، تاریخ صدور جدیدتر).
/// ۲) وگرنه ردیف‌های «ابطال» / «ابطال متقاضی» حذف می‌شوند و از باقی‌مانده یکی نگه داشته می‌شود.
/// ۳) اگر همه ابطال/ابطال متقاضی باشند → ردیف با تاریخ صدور جدیدتر (مقایسه پس از تبدیل به میلادی).
class CsvImportDedupe {
  CsvImportDedupe._();

  static const activeStatus = 'فعال/صادر شده';
  static const revokedStatuses = {'ابطال', 'ابطال متقاضی'};

  static CsvImportDedupeResult apply(List<ExcelParsedRow> rows) {
    if (rows.isEmpty) {
      return const CsvImportDedupeResult(kept: [], removedCount: 0);
    }

    final sorted = List<ExcelParsedRow>.from(rows)
      ..sort((a, b) {
        final sa = _shenase(a);
        final sb = _shenase(b);
        final byShenase = sa.compareTo(sb);
        if (byShenase != 0) return byShenase;
        return a.rowIndex.compareTo(b.rowIndex);
      });

    final kept = <ExcelParsedRow>[];
    var i = 0;
    while (i < sorted.length) {
      final shenase = _shenase(sorted[i]);
      var j = i + 1;
      while (j < sorted.length && _shenase(sorted[j]) == shenase) {
        j++;
      }
      final group = sorted.sublist(i, j);
      if (shenase.isEmpty) {
        // بدون کد صنفی: همه را نگه می‌داریم تا اعتبارسنجی بعدی گزارش دهد.
        kept.addAll(group);
      } else {
        kept.add(_pickFromGroup(group));
      }
      i = j;
    }

    return CsvImportDedupeResult(
      kept: kept,
      removedCount: rows.length - kept.length,
    );
  }

  static ExcelParsedRow _pickFromGroup(List<ExcelParsedRow> group) {
    if (group.length == 1) return group.first;

    final active = group.where((r) => _status(r) == activeStatus).toList();
    if (active.isNotEmpty) {
      return _latestIssueDate(active);
    }

    final nonRevoked =
        group.where((r) => !revokedStatuses.contains(_status(r))).toList();
    if (nonRevoked.isNotEmpty) {
      return _latestIssueDate(nonRevoked);
    }

    return _latestIssueDate(group);
  }

  static ExcelParsedRow _latestIssueDate(List<ExcelParsedRow> rows) {
    ExcelParsedRow best = rows.first;
    var bestMs = _issueDateMs(best);
    for (var i = 1; i < rows.length; i++) {
      final row = rows[i];
      final ms = _issueDateMs(row);
      if (ms > bestMs || (ms == bestMs && row.rowIndex < best.rowIndex)) {
        best = row;
        bestMs = ms;
      }
    }
    return best;
  }

  /// میلی‌ثانیهٔ میلادی برای مقایسه؛ تاریخ نامعتبر = کمینه.
  static int _issueDateMs(ExcelParsedRow row) {
    final raw = row.values[ExcelImportColumns.issueDate];
    final cleaned = _cleanJalaliDateText(raw);
    if (cleaned.isEmpty) return 0;
    final dt = JalaliDateUtil.parseToGregorian(cleaned);
    return dt?.millisecondsSinceEpoch ?? 0;
  }

  static String _status(ExcelParsedRow row) =>
      ParvandeVaziyat.normalizeLabel(row.values[ExcelImportColumns.status]);

  static String _shenase(ExcelParsedRow row) {
    final raw = row.values[ExcelImportColumns.shenase]?.trim() ?? '';
    return ExcelImportShenase.normalize(raw);
  }

  static String _cleanJalaliDateText(String? raw) {
    var t = raw?.trim() ?? '';
    if (t.isEmpty || t == 'null') return '';
    final comma = t.indexOf(',');
    if (comma > 0) t = t.substring(0, comma).trim();
    return t;
  }
}
