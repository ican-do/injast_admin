import 'package:injast_admin/file_management/excel_import/excel_import_shenase.dart';
import 'package:injast_admin/file_management/hagh_ozviat_columns.dart';
import 'package:injast_admin/file_management/hagh_ozviat_member_fill.dart';
import 'package:injast_admin/file_management/hagh_ozviat_models.dart';
import 'package:injast_admin/file_management/hagh_ozviat_registry.dart';
import 'package:injast_admin/file_management/hagh_ozviat_shenase_detect.dart';

/// تحلیل ردیف‌های خام (از CSV یا XLS) به ردیف‌های حق عضویت.
class HaghOzviatRowParser {
  HaghOzviatRowParser._();

  static HaghOzviatAnalysis analyzeRawRows({
    required String fileName,
    required List<({int rowIndex, Map<String, String> values})> raw,
    HaghOzviatRegistry? registry,
    required String importSource,
    bool applyMergedCellFill = true,
  }) {
    if (raw.isEmpty) {
      throw Exception('فایل خالی است یا سطر داده ندارد.');
    }

    final headers = <String>{};
    for (final item in raw) {
      headers.addAll(item.values.keys);
    }
    final headerList = headers.toList();
    final missing = HaghOzviatColumns.missingIn(headerList);
    if (missing.isNotEmpty) {
      throw Exception('ستون‌های لازم یافت نشد: ${missing.join('، ')}');
    }

    final rawMaps = raw.map((e) => e.values).toList();
    final shenaseColumn =
        HaghOzviatShenaseDetect.pickBestColumn(headerList, rawMaps);

    final shenaseByMelli = <String, String>{};
    final shenaseByName = <String, String>{};
    for (final v in rawMaps) {
      final shenase = ExcelImportShenase.normalize(
        HaghOzviatColumns.readShenase(v, preferredColumn: shenaseColumn) ?? '',
      );
      if (shenase.isEmpty) continue;
      final melli = HaghOzviatColumns.readMelli(v);
      if (melli.isNotEmpty) shenaseByMelli[melli] = shenase;
      final nameKey = _nameKey(
        HaghOzviatColumns.read(v, 'نام'),
        HaghOzviatColumns.read(v, 'نام خانوادگی'),
      );
      if (nameKey.isNotEmpty) shenaseByName[nameKey] = shenase;
    }

    final filled = applyMergedCellFill
        ? HaghOzviatMemberFill.forwardFillMerged(raw)
        : raw;
    final reg = registry ?? const HaghOzviatRegistry(byMelli: {}, byFullName: {});

    final rows = <HaghOzviatRow>[];
    var skippedEmptyShenase = 0;
    var skippedDeleted = 0;
    var filledFromParvandeRegistry = 0;
    var filledFromMelliInFile = 0;
    var filledFromNameInFile = 0;
    var filledFromScrape = 0;
    var rowsWithExplicitShenase = 0;

    final mellisAfterFill = <String>{};
    final namesAfterFill = <String>{};
    var filledFromMergedCells = 0;

    for (var i = 0; i < raw.length; i++) {
      final before = raw[i].values;
      final v = filled[i].values;

      final shenaseBefore = ExcelImportShenase.normalize(
        HaghOzviatColumns.readShenase(before, preferredColumn: shenaseColumn) ??
            '',
      );
      var shenase = ExcelImportShenase.normalize(
        HaghOzviatColumns.readShenase(v, preferredColumn: shenaseColumn) ?? '',
      );

      if (shenaseBefore.isNotEmpty) {
        rowsWithExplicitShenase += 1;
      } else if (shenase.isNotEmpty) {
        filledFromMergedCells += 1;
      }

      final melli = HaghOzviatColumns.readMelli(v);
      if (melli.isNotEmpty) mellisAfterFill.add(melli);

      final firstName = HaghOzviatColumns.read(v, 'نام');
      final familyName = HaghOzviatColumns.read(v, 'نام خانوادگی');
      if (firstName.isNotEmpty || familyName.isNotEmpty) {
        namesAfterFill.add('$firstName|$familyName');
      }

      if (shenase.isEmpty && melli.isNotEmpty) {
        final fromMelli = shenaseByMelli[melli];
        if (fromMelli != null && fromMelli.isNotEmpty) {
          shenase = fromMelli;
          filledFromMelliInFile += 1;
        }
      }

      if (shenase.isEmpty) {
        final nameKey = _nameKey(firstName, familyName);
        if (nameKey.isNotEmpty) {
          final fromName = shenaseByName[nameKey];
          if (fromName != null && fromName.isNotEmpty) {
            shenase = fromName;
            filledFromNameInFile += 1;
          }
        }
      }

      if (shenase.isEmpty) {
        final resolved = reg.resolveShenase(
          shenaseFromRow: '',
          melliFromRow: melli,
          firstName: firstName,
          familyName: familyName,
        );
        if (resolved != null) {
          shenase = resolved;
          filledFromParvandeRegistry += 1;
        }
      }

      if (shenase.isEmpty) {
        final scraped = HaghOzviatShenaseDetect.scrapeFromRow(v);
        if (scraped.length == 1) {
          shenase = scraped.first;
          filledFromScrape += 1;
        }
      }

      if (shenase.isEmpty) {
        skippedEmptyShenase += 1;
        continue;
      }

      final vaziyat = HaghOzviatColumns.read(v, HaghOzviatColumns.vaziyat);
      if (vaziyat == 'حذف شده') {
        skippedDeleted += 1;
        continue;
      }

      rows.add(
        HaghOzviatRow(
          shenaseStore: shenase,
          onvan: HaghOzviatColumns.read(v, HaghOzviatColumns.onvan),
          mablaghRial:
              _parseRial(HaghOzviatColumns.read(v, HaghOzviatColumns.mablagh)),
          sal: _normalizeYear(HaghOzviatColumns.read(v, HaghOzviatColumns.sal)),
          tarikhIjad:
              HaghOzviatColumns.read(v, HaghOzviatColumns.tarikhIjad),
          noeEblagh: HaghOzviatColumns.read(v, HaghOzviatColumns.noeEblagh),
          vaziyat: vaziyat,
          radeSanfi: HaghOzviatColumns.read(v, HaghOzviatColumns.radeSanfi),
          onvanRaste:
              HaghOzviatColumns.read(v, HaghOzviatColumns.onvanRaste),
          sourceRowIndex: filled[i].rowIndex,
        ),
      );
    }

    final members = rows.map((r) => r.shenaseStore).toSet();
    var pending = 0;
    var confirmed = 0;
    for (final r in rows) {
      if (r.isPending) pending += r.mablaghRial;
      if (r.isConfirmed) confirmed += r.mablaghRial;
    }

    return HaghOzviatAnalysis(
      fileName: fileName,
      importSource: importSource,
      rawRowsInFile: raw.length,
      totalRows: rows.length,
      uniqueMembers: members.length,
      totalPendingRial: pending,
      totalConfirmedRial: confirmed,
      skippedEmptyShenase: skippedEmptyShenase,
      skippedDeleted: skippedDeleted,
      filledFromPreviousShenase: filledFromMergedCells,
      rowsWithExplicitShenase: rowsWithExplicitShenase,
      filledFromMelliInFile: filledFromMelliInFile,
      filledFromParvandeRegistry: filledFromParvandeRegistry,
      uniqueMelliInFile: mellisAfterFill.length,
      uniqueNamesInFile: namesAfterFill.length,
      registryParvandeCount: reg.byMelli.length,
      detectedShenaseColumn: shenaseColumn,
      filledFromNameInFile: filledFromNameInFile,
      filledFromScrape: filledFromScrape,
      rows: rows,
    );
  }

  static String _nameKey(String first, String family) {
    final f = first.trim().replaceAll(RegExp(r'\s+'), ' ');
    final l = family.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (f.isEmpty && l.isEmpty) return '';
    return '$f|$l';
  }

  static int _parseRial(String raw) {
    var s = raw.trim();
    if (s.isEmpty) return 0;
    s = s.replaceAll(',', '').replaceAll('،', '');
    if (RegExp(r'^\d+\.0$').hasMatch(s)) {
      s = s.substring(0, s.length - 2);
    }
    return int.tryParse(s.split('.').first) ?? 0;
  }

  static String _normalizeYear(String raw) {
    var s = raw.trim();
    if (s.isEmpty) return '';
    if (RegExp(r'^\d+\.0$').hasMatch(s)) {
      return s.substring(0, s.length - 2);
    }
    return s.split('.').first;
  }
}
