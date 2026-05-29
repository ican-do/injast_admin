import 'dart:convert';
import 'dart:developer' show log;
import 'dart:typed_data';

import 'package:injast_admin/file_management/excel_import/excel_import_columns.dart';
import 'package:injast_admin/file_management/excel_import/excel_import_models.dart';

const _logName = 'excel_import';

List<ExcelParsedRow> parseCsvBytes(Uint8List bytes) {
  final text = _decodeCsvText(bytes);
  final records = _parseCsvRecords(text);
  if (records.isEmpty) {
    log('csv parse: empty file', name: _logName);
    return const [];
  }

  final headerRow = records.first;
  final headers = headerRow.map(ExcelImportColumns.normalizeHeader).toList();
  log('csv header columns=${headers.length}', name: _logName);

  final out = <ExcelParsedRow>[];
  for (var i = 1; i < records.length; i++) {
    final cells = records[i];
    if (_isEmptyCsvRow(cells)) continue;

    final values = <String, String>{};
    for (var c = 0; c < headers.length; c++) {
      final key = headers[c];
      if (key.isEmpty) continue;
      values[key] = c < cells.length ? cells[c].trim() : '';
    }
    if (!_rowHasAnyData(values)) continue;
    out.add(ExcelParsedRow(rowIndex: i + 1, values: values));
  }

  final withShenase = out
      .where((r) => (r.values[ExcelImportColumns.shenase] ?? '').trim().isNotEmpty)
      .length;
  log('csv data rows=${out.length} withShenase=$withShenase', name: _logName);
  return out;
}

String _decodeCsvText(Uint8List bytes) {
  if (bytes.isEmpty) return '';
  var start = 0;
  if (bytes.length >= 3 &&
      bytes[0] == 0xEF &&
      bytes[1] == 0xBB &&
      bytes[2] == 0xBF) {
    start = 3;
  }
  return utf8.decode(bytes.sublist(start), allowMalformed: true);
}

List<List<String>> _parseCsvRecords(String input) {
  final rows = <List<String>>[];
  final row = <String>[];
  final cell = StringBuffer();
  var i = 0;
  var inQuotes = false;

  while (i < input.length) {
    final ch = input[i];
    if (inQuotes) {
      if (ch == '"') {
        if (i + 1 < input.length && input[i + 1] == '"') {
          cell.write('"');
          i += 2;
          continue;
        }
        inQuotes = false;
        i++;
        continue;
      }
      cell.write(ch);
      i++;
      continue;
    }

    switch (ch) {
      case '"':
        inQuotes = true;
        i++;
      case ',':
        row.add(cell.toString());
        cell.clear();
        i++;
      case '\r':
        i++;
      case '\n':
        row.add(cell.toString());
        cell.clear();
        if (row.any((v) => v.isNotEmpty) || rows.isNotEmpty) {
          rows.add(List<String>.from(row));
        }
        row.clear();
        i++;
      default:
        cell.write(ch);
        i++;
    }
  }

  if (cell.isNotEmpty || row.isNotEmpty) {
    row.add(cell.toString());
    if (row.any((v) => v.isNotEmpty) || rows.isNotEmpty) {
      rows.add(List<String>.from(row));
    }
  }

  return rows;
}

bool _isEmptyCsvRow(List<String> cells) {
  for (final cell in cells) {
    if (cell.trim().isNotEmpty) return false;
  }
  return true;
}

bool _rowHasAnyData(Map<String, String> values) {
  for (final v in values.values) {
    if (v.trim().isNotEmpty) return true;
  }
  return false;
}
