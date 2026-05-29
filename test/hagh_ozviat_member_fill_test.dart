import 'package:flutter_test/flutter_test.dart';
import 'package:injast_admin/file_management/hagh_ozviat_columns.dart';
import 'package:injast_admin/file_management/excel_import/excel_import_shenase.dart';
import 'package:injast_admin/file_management/hagh_ozviat_member_fill.dart';

void main() {
  test('block fill: new melli starts new member kod', () {
    final raw = [
      (
        rowIndex: 2,
        values: {
          'کد صنفی': '0158702107',
          'کدملی': '1170411738',
          'وضعیت': 'تایید شده',
        },
      ),
      (rowIndex: 3, values: {'وضعیت': 'در انتظار پرداخت'}),
      (
        rowIndex: 4,
        values: {
          'کد صنفی': '1403791838',
          'کدملی': '4840109354',
        },
      ),
      (rowIndex: 5, values: {'سال': '1405'}),
    ];

    final filled = HaghOzviatMemberFill.forwardFillMerged(raw);
    expect(
      ExcelImportShenase.normalize(
        HaghOzviatColumns.readShenase(filled[1].values) ?? '',
      ),
      '0158702107',
    );
    expect(
      ExcelImportShenase.normalize(
        HaghOzviatColumns.readShenase(filled[3].values) ?? '',
      ),
      '1403791838',
    );
  });
}
