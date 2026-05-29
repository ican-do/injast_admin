import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:injast_admin/file_management/hagh_ozviat_csv_parser.dart';
import 'package:injast_admin/file_management/hagh_ozviat_row_parser.dart';

void main() {
  test('parse user debt csv export', () async {
    const path =
        'file import/بدهی‌های صنفی-2026-05-28 202702.811584-11011777.csv';
    final file = File(path);
    if (!await file.exists()) return;

    final bytes = await file.readAsBytes();
    final raw = HaghOzviatCsvParser.parseBytes(bytes);
    final analysis = HaghOzviatRowParser.analyzeRawRows(
      fileName: path,
      raw: raw,
      importSource: 'csv',
      applyMergedCellFill: false,
    );

    expect(raw.length, greaterThan(3500));
    expect(analysis.rowsWithExplicitShenase, greaterThan(3500));
    expect(analysis.uniqueMembers, greaterThan(1100));
    expect(analysis.skippedEmptyShenase, 0);
  });
}
