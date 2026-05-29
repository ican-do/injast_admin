import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:injast_admin/file_management/excel_import/excel_import_columns.dart';
import 'package:injast_admin/file_management/excel_import/excel_import_parser.dart';

void main() {
  const samplePath =
      'file import/پروانه های ایرانیان اصناف میوه و تره بار.csv';

  test('csv sample parses 934 rows with shenase', () async {
    final bytes = File(samplePath).readAsBytesSync();
    final format = detectImportFormat(bytes, fileName: 'sample.csv');
    expect(format, ImportFileFormat.csv);

    final rows = await parseImportFileBytes(bytes, fileName: 'sample.csv');
    expect(rows.length, 934);

    final withShenase = rows
        .where(
          (r) =>
              (r.values[ExcelImportColumns.shenase] ?? '').trim().isNotEmpty,
        )
        .length;
    expect(withShenase, 933);

    final first = rows.first.values;
    expect(first[ExcelImportColumns.shenase], '0431350066');
    expect(first[ExcelImportColumns.firstName], 'فضل الله');
    expect(
      first[ExcelImportColumns.address],
      contains('میدان میوه'),
    );
  });
}
