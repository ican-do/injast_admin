import 'dart:developer' show log;
import 'dart:typed_data';

import 'package:excel2003/excel2003.dart';

const _logName = 'xls_raw_table';

/// خواندن جدول از `.xls` بدون Python (مناسب اپ macOS بسته‌بندی‌شده).
class XlsRawTableReader {
  XlsRawTableReader._();

  static List<({int rowIndex, Map<String, String> values})> parseRows(
    Uint8List bytes,
  ) {
    final reader = XlsReader.fromBytes(bytes);
    if (reader.sheetCount == 0) {
      throw FormatException('فایل Excel برگهٔ داده ندارد.');
    }

    final sheet = reader.sheet(0);
    final maps = sheet.toMaps();
    final out = <({int rowIndex, Map<String, String> values})>[];

    var rowIndex = 2;
    for (final row in maps) {
      final values = <String, String>{};
      for (final entry in row.entries) {
        final key = entry.key.toString().trim();
        if (key.isEmpty) continue;
        final text = _cellToString(entry.value);
        if (text.isNotEmpty) {
          values[key] = text;
        }
      }
      if (values.isNotEmpty) {
        out.add((rowIndex: rowIndex, values: values));
      }
      rowIndex++;
    }

    log('xls dart reader | sheet=${sheet.name} | rows=${out.length}', name: _logName);
    return out;
  }

  static String _cellToString(dynamic value) {
    if (value == null) return '';
    if (value is double) {
      if (value == value.roundToDouble()) {
        return value.toInt().toString();
      }
      return value.toString();
    }
    if (value is int) return value.toString();
    if (value is DateTime) {
      final h = value.hour;
      final m = value.minute;
      final base =
          '${value.year}/${value.month.toString().padLeft(2, '0')}/${value.day.toString().padLeft(2, '0')}';
      if (h == 0 && m == 0) return base;
      return '$base , ${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
    }
    return value.toString().trim();
  }
}
