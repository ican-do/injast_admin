import 'package:flutter_test/flutter_test.dart';
import 'package:injast_admin/file_management/excel_import/csv_import_labels.dart';
import 'package:injast_admin/file_management/excel_import/csv_parvande_dates.dart';

void main() {
  test('مدت دار → تاریخ انقضا +۵ سال', () {
    expect(
      CsvParvandeDates.computeExpServer(
        csvValidity: 'مدت دار',
        issueDateServer: '2020-03-25',
      ),
      '2025-03-25',
    );
  });

  test('normalize education and ownership', () {
    expect(CsvImportLabels.normalizeEducation('سیکل'), 'سیکل');
    expect(CsvImportLabels.normalizeOwnership('مالک'), 'مالک');
    expect(CsvImportLabels.normalizeReligion('اسلام-شیعه'), 'اسلام - شیعه');
  });
}
