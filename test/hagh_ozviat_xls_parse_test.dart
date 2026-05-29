import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:injast_admin/file_management/hagh_ozviat_xls_parser.dart';

void main() {
  test('parse sample membership xls without python', () async {
    final path = 'file import/مطالبات صنفی پوشاک.xls';
    final file = File(path);
    if (!await file.exists()) {
      return;
    }
    final analysis = await HaghOzviatXlsParser.analyze(
      fileName: path,
      bytes: await file.readAsBytes(),
    );
    expect(analysis.uniqueMembers, greaterThan(1000));
    expect(analysis.totalRows, greaterThan(5000));
  });
}
