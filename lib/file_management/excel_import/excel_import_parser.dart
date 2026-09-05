import 'dart:developer' show log;
import 'dart:typed_data';

import 'package:excel/excel.dart' hide Border;
import 'package:injast_admin/file_management/excel_import/csv_header_mapper.dart';
import 'package:injast_admin/file_management/excel_import/csv_import_parser.dart';
import 'package:injast_admin/file_management/excel_import/excel_import_columns.dart';
import 'package:injast_admin/file_management/excel_import/excel_import_models.dart';
import 'package:injast_admin/file_management/jalali_date_util.dart';

const _logName = 'excel_import';

enum ImportFileFormat { csv, xlsxZip, unknown }

ImportFileFormat detectImportFormat(Uint8List bytes, {String? fileName}) {
  final name = fileName?.trim().toLowerCase() ?? '';
  if (name.endsWith('.csv')) return ImportFileFormat.csv;
  if (bytes.length >= 4 && bytes[0] == 0x50 && bytes[1] == 0x4B) {
    return ImportFileFormat.xlsxZip;
  }
  if (_looksLikeCsvText(bytes)) return ImportFileFormat.csv;
  return ImportFileFormat.unknown;
}

@Deprecated('Use detectImportFormat')
typedef ExcelWorkbookFormat = ImportFileFormat;

@Deprecated('Use detectImportFormat')
ImportFileFormat detectWorkbookFormat(Uint8List bytes) =>
    detectImportFormat(bytes);

Future<ImportParseResult> parseImportFile(
  Uint8List bytes, {
  String? fileName,
}) async {
  final format = detectImportFormat(bytes, fileName: fileName);
  log(
    'parse start | bytes=${bytes.length} | format=$format | file=$fileName',
    name: _logName,
  );

  final parsed = switch (format) {
    ImportFileFormat.csv => parseCsvFile(bytes),
    ImportFileFormat.xlsxZip => _parseXlsxFile(bytes),
    ImportFileFormat.unknown => throw Exception(
        'فرمت فایل شناسایی نشد. فایل CSV (.csv) یا Excel جدید (.xlsx) انتخاب کنید.',
      ),
  };

  log(
    'parse ok | rows=${parsed.rows.length} | headers=${parsed.rawHeaders.length} | '
    'match=${parsed.headerMatch.matchPercent}%',
    name: _logName,
  );
  return parsed;
}

Future<List<ExcelParsedRow>> parseImportFileBytes(
  Uint8List bytes, {
  String? fileName,
}) async =>
    (await parseImportFile(bytes, fileName: fileName)).rows;

@Deprecated('Use parseImportFileBytes')
Future<List<ExcelParsedRow>> parseWorkbookBytes(Uint8List bytes) =>
    parseImportFileBytes(bytes);

ImportParseResult _parseXlsxFile(Uint8List bytes) {
  try {
    final book = Excel.decodeBytes(bytes);
    if (book.tables.isEmpty) {
      throw Exception('فایل .xlsx شیت قابل خواندن ندارد.');
    }
    final sheetName = book.tables.keys.first;
    final sheet = book.tables[sheetName]!;
    final tableRows = sheet.rows;
    log(
      'xlsx sheet="$sheetName" rows=${tableRows.length} '
      'maxCols=${sheet.maxColumns}',
      name: _logName,
    );
    if (tableRows.isEmpty) {
      return const ImportParseResult(
        rawHeaders: [],
        headerMatch: CsvHeaderMatchReport.empty,
        rows: [],
      );
    }

    final headers = <String>[];
    for (final cell in tableRows.first) {
      headers.add(ExcelImportColumns.normalizeHeader(_xlsxCellText(cell)));
    }
    final headerMatch = CsvHeaderMapper.analyze(headers);

    final out = <ExcelParsedRow>[];
    for (var r = 1; r < tableRows.length; r++) {
      final row = tableRows[r];
      if (_isEmptyXlsxRow(row)) continue;
      final cells = <String>[];
      for (var c = 0; c < headers.length; c++) {
        final cell = c < row.length ? row[c] : null;
        cells.add(_xlsxCellText(cell));
      }
      final values = CsvHeaderMapper.remapValues(
        rawHeaders: headers,
        cells: cells,
        report: headerMatch,
      );
      if (_rowHasAnyData(values)) {
        out.add(ExcelParsedRow(rowIndex: r + 1, values: values));
      }
    }
    return ImportParseResult(
      rawHeaders: headers,
      headerMatch: headerMatch,
      rows: out,
    );
  } catch (e, st) {
    log('xlsx parse failed: $e\n$st', name: _logName);
    rethrow;
  }
}

bool _looksLikeCsvText(Uint8List bytes) {
  if (bytes.isEmpty) return false;
  final sample = bytes.length > 512 ? bytes.sublist(0, 512) : bytes;
  for (final b in sample) {
    if (b == 0) return false;
  }
  return true;
}

String _xlsxCellText(dynamic cell) {
  if (cell == null) return '';
  final v = cell.value;
  if (v == null) return '';
  if (v is DateCellValue) {
    return JalaliDateUtil.formatFromDateTime(
      DateTime(v.year, v.month, v.day),
    );
  }
  if (v is TextCellValue) {
    return v.value.toString().trim();
  }
  if (v is IntCellValue) return v.value.toString();
  if (v is DoubleCellValue) {
    final n = v.value;
    if (n == n.roundToDouble()) return n.toInt().toString();
    return n.toString();
  }
  return v.toString().trim();
}

bool _isEmptyXlsxRow(List<dynamic> row) {
  for (final cell in row) {
    if (_xlsxCellText(cell).isNotEmpty) return false;
  }
  return true;
}

bool _rowHasAnyData(Map<String, String> values) {
  for (final v in values.values) {
    if (v.trim().isNotEmpty) return true;
  }
  return false;
}

