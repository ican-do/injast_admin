import 'dart:convert';
import 'dart:typed_data';

import 'package:injast_admin/file_management/hagh_ozviat_columns.dart';

/// خواندن CSV مطالبات صنفی — UTF-8 با BOM، جداکننده , یا ;
class HaghOzviatCsvParser {
  HaghOzviatCsvParser._();

  static List<({int rowIndex, Map<String, String> values})> parseBytes(
    Uint8List bytes,
  ) {
    final text = _decodeText(bytes);
    if (text.trim().isEmpty) return const [];

    final delimiter = _detectDelimiter(text);
    final records = _parseRecords(text, delimiter);
    if (records.isEmpty) return const [];

    final headerRow = records.first;
    final headers = headerRow.map(_normalizeHeader).toList();

    final out = <({int rowIndex, Map<String, String> values})>[];
    for (var i = 1; i < records.length; i++) {
      final cells = records[i];
      if (_isEmptyRow(cells)) continue;

      final values = <String, String>{};
      for (var c = 0; c < headers.length; c++) {
        final key = headers[c];
        if (key.isEmpty) continue;
        values[key] = c < cells.length ? _normalizeCell(cells[c]) : '';
      }
      if (!_hasData(values)) continue;
      out.add((rowIndex: i + 1, values: values));
    }
    return out;
  }

  static String _decodeText(Uint8List bytes) {
    if (bytes.isEmpty) return '';
    if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xFE) {
      final decoded = Encoding.getByName('utf-16le')?.decode(bytes.sublist(2));
      if (decoded != null) return decoded;
    }
    var start = 0;
    if (bytes.length >= 3 &&
        bytes[0] == 0xEF &&
        bytes[1] == 0xBB &&
        bytes[2] == 0xBF) {
      start = 3;
    }
    return utf8.decode(bytes.sublist(start), allowMalformed: true);
  }

  static String _detectDelimiter(String text) {
    final line = text.split(RegExp(r'\r?\n')).firstWhere(
      (l) => l.trim().isNotEmpty,
      orElse: () => '',
    );
    final semi = ';'.allMatches(line).length;
    final comma = ','.allMatches(line).length;
    return semi > comma ? ';' : ',';
  }

  static List<List<String>> _parseRecords(String input, String delimiter) {
    final sep = delimiter == ';' ? ';' : ',';
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

      if (ch == '"') {
        inQuotes = true;
        i++;
      } else if (ch == sep) {
        row.add(cell.toString());
        cell.clear();
        i++;
      } else if (ch == '\r') {
        i++;
      } else if (ch == '\n') {
        row.add(cell.toString());
        cell.clear();
        if (row.any((v) => v.isNotEmpty) || rows.isNotEmpty) {
          rows.add(List<String>.from(row));
        }
        row.clear();
        i++;
      } else {
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

  static String _normalizeHeader(String raw) =>
      raw
          .replaceAll('\uFEFF', '')
          .replaceAll('\u200c', '')
          .replaceAll('\u200f', '')
          .replaceAll('ي', 'ی')
          .replaceAll('ك', 'ک')
          .trim();

  static String _normalizeCell(String raw) {
    var t = raw.trim();
    if (RegExp(r'^\d+\.0$').hasMatch(t)) {
      t = t.substring(0, t.length - 2);
    }
    return t;
  }

  static bool _isEmptyRow(List<String> cells) {
    for (final c in cells) {
      if (c.trim().isNotEmpty) return false;
    }
    return true;
  }

  static bool _hasData(Map<String, String> values) {
    for (final v in values.values) {
      if (v.trim().isNotEmpty) return true;
    }
    return false;
  }
}
