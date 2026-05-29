import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:injast_admin/file_management/hagh_ozviat_csv_parser.dart';
import 'package:injast_admin/file_management/hagh_ozviat_row_parser.dart';

void main() {
  test('parse utf-8 csv with persian headers', () {
    const csv = '\uFEFFکد صنفی,نام,نام خانوادگی,کدملی,عنوان,مبلغ(ریال),سال,وضعیت\n'
        '0158702107,حسن,احمدی,1170411738,حق عضویت 1403,12000000,1403,تایید شده\n'
        '1403791838,سمانه,رضایی,4840109354,حق عضویت 1404,18000000,1404,در انتظار پرداخت\n';
    final raw = HaghOzviatCsvParser.parseBytes(Uint8List.fromList(utf8.encode(csv)));
    expect(raw.length, 2);

    final analysis = HaghOzviatRowParser.analyzeRawRows(
      fileName: 'test.csv',
      raw: raw,
      importSource: 'csv',
      applyMergedCellFill: false,
    );
    expect(analysis.uniqueMembers, 2);
    expect(analysis.rowsWithExplicitShenase, 2);
  });

  test('parse sample xls via csv conversion when python available', () async {
    final path = 'file import/مطالبات صنفی پوشاک.xls';
    final file = File(path);
    if (!await file.exists()) return;

    final xlsBytes = await file.readAsBytes();
    final csvBytes = await _runPythonCsv(xlsBytes, path);
    if (csvBytes == null) return;

    final raw = HaghOzviatCsvParser.parseBytes(Uint8List.fromList(csvBytes));
    final analysis = HaghOzviatRowParser.analyzeRawRows(
      fileName: 'via-csv.xls',
      raw: raw,
      importSource: 'xls→csv',
      applyMergedCellFill: false,
    );
    expect(analysis.uniqueMembers, greaterThan(1000));
    expect(analysis.rowsWithExplicitShenase, greaterThan(1000));
  });
}

Future<List<int>?> _runPythonCsv(List<int> xlsBytes, String path) async {
  try {
    final result = await Process.run(
      'python3',
      ['scripts/xls_to_csv.py', path],
      workingDirectory:
          '/Users/mac/Documents/myperoject2/basic progect 2025/injasttt/injast_admin',
      environment: {
        'PYTHONPATH':
            '/Users/mac/Documents/myperoject2/basic progect 2025/injasttt/injast_admin/scripts/pydeps',
      },
    );
    if (result.exitCode != 0) return null;
    return (result.stdout as List<int>?) ?? [];
  } catch (_) {
    return null;
  }
}
