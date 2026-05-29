import 'package:flutter_test/flutter_test.dart';
import 'package:injast_admin/file_management/excel_import/excel_import_shenase.dart';

void main() {
  test('preserves leading zero from csv text', () {
    expect(ExcelImportShenase.normalize('0431350066'), '0431350066');
    expect(ExcelImportShenase.normalize('0113858809'), '0113858809');
  });

  test('pads numeric form without leading zero', () {
    expect(ExcelImportShenase.normalize('431350066'), '0431350066');
    expect(ExcelImportShenase.normalize('113858809'), '0113858809');
  });
}
