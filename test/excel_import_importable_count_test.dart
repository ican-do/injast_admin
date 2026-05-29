import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:injast_admin/file_management/excel_import/excel_import_parser.dart';
import 'package:injast_admin/file_management/excel_import/excel_import_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('sample xls has hundreds of rows with shenase after python parse', () async {
    final path =
        'file import/پروانه های ایرانیان اصناف میوه و تره بار.xls';
    final bytes = File(path).readAsBytesSync();
    final rows = await parseWorkbookBytes(bytes);

    var withShenase = 0;
    for (final row in rows) {
      final s = row.values['کد صنفی']?.trim() ?? '';
      if (s.isNotEmpty) withShenase++;
    }

    expect(rows.length, greaterThan(900));
    expect(withShenase, greaterThan(900));

    final analysis = await ExcelImportService('test').analyze(
      fileName: path,
      fileBytes: bytes,
      rows: rows,
    );

    // بدون تکرار سرور، بیشتر ردیف‌ها باید قابل ثبت باشند
    expect(analysis.missingRequiredColumns, isEmpty);
    expect(analysis.importableCount, greaterThan(800));
  });
}
