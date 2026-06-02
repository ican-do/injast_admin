import 'package:flutter_test/flutter_test.dart';
import 'package:injast_admin/file_management/hagh_ozviat_models.dart';
import 'package:injast_admin/reports/hagh_ozviat_report_engine.dart';
import 'package:shamsi_date/shamsi_date.dart';

HaghOzviatRow _row({
  required String shenase,
  required String sal,
  required int amount,
  required String vaziyat,
}) {
  return HaghOzviatRow(
    shenaseStore: shenase,
    onvan: 'حق $sal',
    mablaghRial: amount,
    sal: sal,
    tarikhIjad: '$sal/06/15 , 10:00',
    noeEblagh: 'سیستمی',
    vaziyat: vaziyat,
    radeSanfi: 'رده ۱',
    onvanRaste: 'پوشاک',
  );
}

void main() {
  test('yearsWithPendingDebt lists only years with open debt', () {
    final years = HaghOzviatReportEngine.yearsWithPendingDebt([
      _row(shenase: '001', sal: '1404', amount: 1000, vaziyat: 'در انتظار پرداخت'),
      _row(shenase: '002', sal: '1403', amount: 2000, vaziyat: 'تایید شده'),
      _row(shenase: '003', sal: '1404', amount: 500, vaziyat: 'در انتظار پرداخت'),
    ]);

    expect(years.length, 1);
    expect(years.first.sal, '1404');
    expect(years.first.pendingRial, 1500);
    expect(years.first.debtorCount, 2);
  });

  test('filters rows by vaziyat and jalali date range', () {
    final rows = [
      HaghOzviatRow(
        shenaseStore: '001',
        onvan: 'حق 1404',
        mablaghRial: 1000,
        sal: '1404',
        tarikhIjad: '1404/06/15 , 10:00',
        noeEblagh: 'سیستمی',
        vaziyat: 'در انتظار پرداخت',
        radeSanfi: 'رده ۱',
        onvanRaste: 'پوشاک',
      ),
      HaghOzviatRow(
        shenaseStore: '002',
        onvan: 'حق 1403',
        mablaghRial: 2000,
        sal: '1403',
        tarikhIjad: '1403/01/01 , 08:00',
        noeEblagh: 'سیستمی',
        vaziyat: 'تایید شده',
        radeSanfi: 'رده ۲',
        onvanRaste: 'مواد غذایی',
      ),
    ];

    final snap = HaghOzviatReportEngine.fromRows(
      allRows: rows,
      filters: HaghOzviatReportFilters(
        vaziyat: 'در انتظار پرداخت',
        dateFrom: Jalali(1404, 1, 1),
        dateTo: Jalali(1404, 12, 29),
      ),
    );

    expect(snap.rowCount, 1);
    expect(snap.totalPendingRial, 1000);
    expect(snap.debtorMembers, 1);
  });

  test('sal filter recalculates totals for selected year', () {
    final snap = HaghOzviatReportEngine.fromRows(
      allRows: [
        _row(shenase: '001', sal: '1404', amount: 1000, vaziyat: 'در انتظار پرداخت'),
        _row(shenase: '002', sal: '1403', amount: 9000, vaziyat: 'در انتظار پرداخت'),
      ],
      filters: const HaghOzviatReportFilters(sal: '1404'),
    );

    expect(snap.totalPendingRial, 1000);
    expect(snap.debtorMembers, 1);
  });
}
