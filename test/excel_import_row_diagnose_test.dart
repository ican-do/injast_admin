import 'dart:io';

import 'package:excel2003/excel2003.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:injast_admin/file_management/excel_import/excel_import_columns.dart';
import 'package:injast_admin/file_management/excel_import/excel_import_parser.dart';

void main() {
  test('diagnose rows 24-35 in sample xls/csv', () async {
    const xlsPath = 'file import/پروانه های ایرانیان اصناف میوه و تره بار.xls';
    const csvPath = 'file import/پروانه های ایرانیان اصناف میوه و تره بار.csv';
    final xlsBytes = File(xlsPath).readAsBytesSync();
    final csvBytes = File(csvPath).readAsBytesSync();
    final reader = XlsReader.fromBytes(xlsBytes);
    final dartRows = await parseImportFileBytes(csvBytes, fileName: csvPath);
    final shenaseCount = dartRows
        .where((r) => (r.values[ExcelImportColumns.shenase] ?? '').isNotEmpty)
        .length;
    // ignore: avoid_print
    print('csv parse rows=${dartRows.length} shenase=$shenaseCount');
    final sheet = reader.sheet(0);

    final maps = sheet.toMaps();
    expect(maps.length, greaterThan(30));

    final buf = StringBuffer();
    buf.writeln('firstRow=${sheet.firstRow} lastRow=${sheet.lastRow}');
    for (var i = 23; i < 32 && i < maps.length; i++) {
      final m = maps[i];
      buf.writeln(
        'map[$i] shenase=${m['کد صنفی']} addr=${m['آدرس']} date=${m['تاریخ صدور']}',
      );
    }

    for (var r = 24; r <= 30; r++) {
      final cells = <String>[];
      for (var c = 0; c < 10; c++) {
        final v = sheet.cell(r, c);
        if (v != null) cells.add('c$c=$v');
      }
      buf.writeln('direct row $r: ${cells.join(' | ')}');
    }

    for (final row in dartRows.where((r) => r.rowIndex >= 24 && r.rowIndex <= 35)) {
      buf.writeln(
        'parsed[${row.rowIndex}] shenase=${row.values[ExcelImportColumns.shenase]} '
        'addr=${row.values[ExcelImportColumns.address]}',
      );
    }

    var emptyShenase = 0;
    var goodShenase = 0;
    for (var r = sheet.firstRow + 1; r < sheet.lastRow; r++) {
      final v = sheet.cell(r, 1);
      if (v != null && v.toString().trim().isNotEmpty) {
        goodShenase++;
      } else {
        emptyShenase++;
      }
    }
    buf.writeln('direct goodShenase=$goodShenase empty=$emptyShenase');

    var parsedEmpty = 0;
    for (final row in dartRows) {
      if ((row.values[ExcelImportColumns.shenase] ?? '').isEmpty) {
        parsedEmpty++;
      }
    }
    buf.writeln('parsed emptyShenase=$parsedEmpty / ${dartRows.length}');

    // ignore: avoid_print
    print(buf.toString());

    final map24 = maps[24];
    expect(
      map24['کد صنفی']?.toString().trim(),
      isNotEmpty,
      reason: buf.toString(),
    );
  });
}
