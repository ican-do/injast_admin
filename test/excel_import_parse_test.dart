import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:injast_admin/file_management/excel_import/excel_import_columns.dart';
import 'package:injast_admin/file_management/excel_import/excel_import_parser.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('parses sample asnaf csv with expected headers', () async {
    const path = 'file import/پروانه های ایرانیان اصناف میوه و تره بار.csv';
    final bytes = File(path).readAsBytesSync();
    expect(detectImportFormat(bytes, fileName: path), ImportFileFormat.csv);

    final rows = await parseImportFileBytes(bytes, fileName: path);
    expect(rows.length, greaterThan(900));

    final withShenase = rows
        .where((r) => (r.values[ExcelImportColumns.shenase] ?? '').trim().isNotEmpty)
        .length;
    expect(withShenase, greaterThan(900), reason: 'کد صنفی باید از CSV خوانده شود');

    final keys = rows.first.values.keys.toSet();
    expect(keys.contains(ExcelImportColumns.shenase), isTrue);
    expect(keys.contains(ExcelImportColumns.address), isTrue);
    expect(keys.contains(ExcelImportColumns.issueDate), isTrue);

    final shenase = rows.first.values[ExcelImportColumns.shenase];
    expect(shenase, isNotEmpty);
    expect(shenase, isNot(contains('E')));
  });
}
