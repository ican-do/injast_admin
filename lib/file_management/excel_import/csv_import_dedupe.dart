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
/// برای هر گروه با کد صنفی یکسان فقط یک ردیف می‌ماند:
/// ۱) «فعال/صادر شده» بر هر وضعیت دیگری مقدم است. بین چند فعال، تاریخ صدور جدیدتر.
/// ۲) هر وضعیتی غیر از دو نوع ابطال، بر «ابطال متقاضی» و «ابطال» مقدم است. بین آن‌ها تاریخ صدور جدیدتر.
/// ۳) «ابطال متقاضی» همیشه بر «ابطال» مقدم است، حتی اگر تاریخ صدور ابطال جدیدتر باشد.
/// ۴) بین چند «ابطال متقاضی»، یا چند «ابطال»، تاریخ صدور جدیدتر می‌ماند.
class CsvImportDedupe {
  CsvImportDedupe._();

  static const activeStatus = 'فعال/صادر شده';
  static const applicantRevokedStatus = 'ابطال متقاضی';
  static const revokedStatus = 'ابطال';

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

    final nonRevoked = group
        .where(
          (r) =>
              _status(r) != applicantRevokedStatus &&
              _status(r) != revokedStatus,
        )
        .toList();
    if (nonRevoked.isNotEmpty) {
      return _latestIssueDate(nonRevoked);
    }

    final applicant =
        group.where((r) => _status(r) == applicantRevokedStatus).toList();
    if (applicant.isNotEmpty) {
      return _latestIssueDate(applicant);
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
