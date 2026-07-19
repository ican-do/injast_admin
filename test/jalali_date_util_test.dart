import 'package:flutter_test/flutter_test.dart';
import 'package:injast_admin/file_management/jalali_date_util.dart';

void main() {
  test('normalizeJalaliDisplay keeps shamsi year (no +1)', () {
    expect(
      JalaliDateUtil.normalizeJalaliDisplay('1408/12/02 , 00:00'),
      '1408/12/02',
    );
  });

  test('toPathSafeJalali uses dashes without year shift', () {
    expect(
      JalaliDateUtil.toPathSafeJalali('1408/12/02 , 00:00'),
      '1408-12-02',
    );
  });

  test('serverToDisplay does not reconvert jalali dash dates', () {
    expect(JalaliDateUtil.serverToDisplay('1408-12-02'), '1408/12/02');
    expect(JalaliDateUtil.serverToDisplay('1408/12/02'), '1408/12/02');
  });

  test('serverToDisplay converts real gregorian', () {
    expect(JalaliDateUtil.serverToDisplay('2030-02-20'), '1408/12/02');
  });

  test('displayToServer converts jalali dash form', () {
    expect(JalaliDateUtil.displayToServer('1408-12-02'), '2030-02-20');
    expect(JalaliDateUtil.displayToServer('1408/12/02'), '2030-02-20');
  });

  test('serverToDisplay strips ISO time and shows date only', () {
    expect(
      JalaliDateUtil.serverToDisplay('1405-05-28T07:52:45.000Z'),
      '1405/05/28',
    );
    expect(
      JalaliDateUtil.serverToPersianDisplay('1405-05-28T07:52:45.000Z'),
      '۱۴۰۵/۰۵/۲۸',
    );
    expect(
      JalaliDateUtil.serverToPersianDisplay('۱۴۰۵-۰۵-۲۸- T ۰۷:۵۲:۴۵. ۰۰۰z'),
      '۱۴۰۵/۰۵/۲۸',
    );
  });
}
