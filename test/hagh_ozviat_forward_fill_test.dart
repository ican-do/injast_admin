import 'package:flutter_test/flutter_test.dart';
import 'package:injast_admin/file_management/hagh_ozviat_columns.dart';
import 'package:injast_admin/file_management/excel_import/excel_import_shenase.dart';

/// شبیه‌سازی منطق forward-fill برای سلول‌های ادغام‌شده در export اصناف.
void main() {
  test('forward-fill shenase from previous row', () {
    final raw = [
      {'کد صنفی': '0158702107', 'وضعیت': 'تایید شده'},
      {'کد صنفی': '', 'وضعیت': 'در انتظار پرداخت'},
      {'کد صنفی': '', 'وضعیت': 'تایید شده'},
      {'کد صنفی': '1403791838', 'وضعیت': 'تایید شده'},
      {'کد صنفی': '', 'وضعیت': 'در انتظار پرداخت'},
    ];

    String? last;
    var filled = 0;
    final accepted = <String>[];

    for (final v in raw) {
      var shenaseRaw = HaghOzviatColumns.readShenase(v);
      if ((shenaseRaw == null || shenaseRaw.isEmpty) && last != null) {
        shenaseRaw = last;
        filled += 1;
      }
      final shenase = ExcelImportShenase.normalize(shenaseRaw ?? '');
      if (shenase.isEmpty) continue;
      last = shenase;
      accepted.add(shenase);
    }

    expect(filled, 3);
    expect(accepted.length, 5);
    expect(accepted.where((s) => s == '0158702107').length, 3);
  });
}
