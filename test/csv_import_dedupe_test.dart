import 'package:flutter_test/flutter_test.dart';
import 'package:injast_admin/file_management/excel_import/csv_import_dedupe.dart';
import 'package:injast_admin/file_management/excel_import/excel_import_columns.dart';
import 'package:injast_admin/file_management/excel_import/excel_import_models.dart';

ExcelParsedRow _row({
  required int index,
  required String shenase,
  required String status,
  required String issueDate,
}) {
  return ExcelParsedRow(
    rowIndex: index,
    values: {
      ExcelImportColumns.shenase: shenase,
      ExcelImportColumns.status: status,
      ExcelImportColumns.issueDate: issueDate,
    },
  );
}

void main() {
  test('sorts by shenase so same codes are adjacent', () {
    final result = CsvImportDedupe.apply([
      _row(index: 1, shenase: '2', status: 'منقضی شده', issueDate: '1400/01/01'),
      _row(index: 2, shenase: '1', status: 'فعال/صادر شده', issueDate: '1399/01/01'),
      _row(index: 3, shenase: '2', status: 'فعال/صادر شده', issueDate: '1401/01/01'),
    ]);

    expect(
      result.kept.map((r) => r.values[ExcelImportColumns.shenase]?.trim()),
      ['1', '2'],
    );
    expect(result.removedCount, 1);
  });

  test('case1: keeps فعال/صادر شده and drops others', () {
    final result = CsvImportDedupe.apply([
      _row(index: 1, shenase: '100', status: 'ابطال', issueDate: '1402/01/01'),
      _row(
        index: 2,
        shenase: '100',
        status: 'فعال/صادر شده',
        issueDate: '1400/01/01',
      ),
      _row(index: 3, shenase: '100', status: 'منقضی شده', issueDate: '1401/01/01'),
    ]);

    expect(result.kept, hasLength(1));
    expect(result.kept.single.rowIndex, 2);
    expect(result.removedCount, 2);
  });

  test('case1: among multiple فعال picks latest issue date (jalali→gregorian)', () {
    final result = CsvImportDedupe.apply([
      _row(
        index: 1,
        shenase: '100',
        status: 'فعال/صادر شده',
        issueDate: '1398/12/29',
      ),
      _row(
        index: 2,
        shenase: '100',
        status: 'فعال/صادر شده',
        issueDate: '1400/01/02',
      ),
    ]);

    expect(result.kept.single.rowIndex, 2);
  });

  test('case2: drops ابطال/ابطال متقاضی when other statuses exist', () {
    final result = CsvImportDedupe.apply([
      _row(index: 1, shenase: '200', status: 'ابطال', issueDate: '1402/06/01'),
      _row(
        index: 2,
        shenase: '200',
        status: 'ابطال متقاضی',
        issueDate: '1402/07/01',
      ),
      _row(index: 3, shenase: '200', status: 'منقضی شده', issueDate: '1399/01/01'),
      _row(index: 4, shenase: '200', status: 'تعلیق', issueDate: '1401/05/01'),
    ]);

    expect(result.kept, hasLength(1));
    expect(result.kept.single.rowIndex, 4); // latest among non-revoked
    expect(result.removedCount, 3);
  });

  test('case3: all revoked keeps latest issue date', () {
    final result = CsvImportDedupe.apply([
      _row(index: 1, shenase: '300', status: 'ابطال', issueDate: '1395/01/01'),
      _row(
        index: 2,
        shenase: '300',
        status: 'ابطال متقاضی',
        issueDate: '1401/12/01',
      ),
      _row(index: 3, shenase: '300', status: 'ابطال', issueDate: '1400/06/15'),
    ]);

    expect(result.kept, hasLength(1));
    expect(result.kept.single.rowIndex, 2);
    expect(result.removedCount, 2);
  });

  test('different shenase codes are all kept', () {
    final result = CsvImportDedupe.apply([
      _row(index: 1, shenase: '1', status: 'فعال/صادر شده', issueDate: '1400/01/01'),
      _row(index: 2, shenase: '2', status: 'ابطال', issueDate: '1400/01/01'),
    ]);

    expect(result.kept, hasLength(2));
    expect(result.removedCount, 0);
  });
}
