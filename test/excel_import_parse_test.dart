import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:injast_admin/file_management/excel_import/excel_import_columns.dart';
import 'package:injast_admin/file_management/excel_import/excel_import_parser.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('parses sample asnaf xls with expected headers', () async {
    final path =
        'file import/پروانه های ایرانیان اصناف میوه و تره بار.xls';
    final bytes = File(path).readAsBytesSync();
    expect(detectWorkbookFormat(bytes), ExcelWorkbookFormat.xlsBiff8);

    // ignore: avoid_print
    print('cwd=${Directory.current.path} venv=${File('tool/xls_venv/bin/python3').existsSync()}');

    final rows = await parseWorkbookBytes(bytes);
    expect(rows.length, greaterThan(900));

    final withShenase = rows
        .where((r) => (r.values[ExcelImportColumns.shenase] ?? '').trim().isNotEmpty)
        .length;
    expect(withShenase, greaterThan(900), reason: 'python/xlrd باید کد صنفی را بخواند');

    final keys = rows.first.values.keys.toSet();
    expect(keys.contains(ExcelImportColumns.shenase), isTrue);
    expect(keys.contains(ExcelImportColumns.address), isTrue);
    expect(keys.contains(ExcelImportColumns.issueDate), isTrue);

    final shenase = rows.first.values[ExcelImportColumns.shenase];
    expect(shenase, isNotEmpty);
    expect(shenase, isNot(contains('E')));
  });
}
