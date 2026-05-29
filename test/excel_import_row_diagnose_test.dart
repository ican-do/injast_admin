import 'dart:io';

import 'package:excel2003/excel2003.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:injast_admin/file_management/excel_import/excel_import_columns.dart';
import 'package:injast_admin/file_management/excel_import/excel_import_parser.dart';
import 'package:injast_admin/file_management/excel_import/excel_import_service.dart';

void main() {
  test('diagnose rows 24-35 in sample xls', () {
    final path =
        'file import/پروانه های ایرانیان اصناف میوه و تره بار.xls';
    final bytes = File(path).readAsBytesSync();
    final reader = XlsReader.fromBytes(bytes);
    // ignore: avoid_print
    print(
      'sst declared=${reader.sharedStringDeclared} parsed=${reader.sharedStringCount}',
    );
    final dartRows = await parseWorkbookBytes(bytes);
    final shenaseCount = dartRows
        .where((r) => (r.values[ExcelImportColumns.shenase] ?? '').isNotEmpty)
        .length;
    print('dart parse rows=${dartRows.length} shenase=$shenaseCount');
    final sheet = reader.sheet(0);

    final maps = sheet.toMaps();
    expect(maps.length, greaterThan(30));

    // Print for manual inspection in test failure output
    final buf = StringBuffer();
    buf.writeln('firstRow=${sheet.firstRow} lastRow=${sheet.lastRow}');
    for (var i = 23; i < 32 && i < maps.length; i++) {
      final m = maps[i];
      buf.writeln(
        'map[$i] shenase=${m['کد صنفی']} addr=${m['آدرس']} date=${m['تاریخ صدور']}',
      );
    }

    // Direct cell access for excel rows 24-30
    for (var r = 24; r <= 30; r++) {
      final cells = <String>[];
      for (var c = 0; c < 10; c++) {
        final v = sheet.cell(r, c);
        if (v != null) cells.add('c$c=$v');
      }
      buf.writeln('direct row $r: ${cells.join(' | ')}');
    }

    final parsed = parseWorkbookBytes(bytes);
    for (final row in parsed.where((r) => r.rowIndex >= 24 && r.rowIndex <= 35)) {
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
    for (final row in parsed) {
      if ((row.values[ExcelImportColumns.shenase] ?? '').isEmpty) {
        parsedEmpty++;
      }
    }
    buf.writeln('parsed emptyShenase=$parsedEmpty / ${parsed.length}');

    // ignore: avoid_print
    print(buf.toString());

    // Row 25 in file (1-based excel line 26) should have data in sample
    final map24 = maps[24]; // 0-based data row index 24 = excel row 26 if header at 0
    expect(
      map24['کد صنفی']?.toString().trim(),
      isNotEmpty,
      reason: buf.toString(),
    );
  });
}
