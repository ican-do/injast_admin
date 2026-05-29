import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:injast_admin/file_management/excel_import/excel_import_columns.dart';
import 'package:injast_admin/file_management/excel_import/xls_python_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('python bridge reads full sample xls', () async {
    final path =
        'file import/پروانه های ایرانیان اصناف میوه و تره بار.xls';
    final bytes = File(path).readAsBytesSync();
    final rows = await XlsPythonBridge.parse(bytes);
    expect(rows.length, greaterThan(900));
    final withShenase = rows
        .where((r) => (r.values[ExcelImportColumns.shenase] ?? '').trim().isNotEmpty)
        .length;
    expect(withShenase, greaterThan(900));
  });
}
