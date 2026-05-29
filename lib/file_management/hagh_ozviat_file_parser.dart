import 'dart:typed_data';

import 'package:injast_admin/file_management/hagh_ozviat_csv_parser.dart';
import 'package:injast_admin/file_management/hagh_ozviat_models.dart';
import 'package:injast_admin/file_management/hagh_ozviat_registry.dart';
import 'package:injast_admin/file_management/hagh_ozviat_row_parser.dart';

/// ورود فایل حق عضویت — فقط CSV (UTF-8).
class HaghOzviatFileParser {
  HaghOzviatFileParser._();

  static Future<HaghOzviatAnalysis> analyze({
    required String fileName,
    required Uint8List bytes,
    HaghOzviatRegistry? registry,
  }) async {
    if (!fileName.toLowerCase().endsWith('.csv')) {
      throw Exception(
        'فقط فایل CSV پشتیبانی می‌شود.\n'
        'در Excel: Save As → CSV UTF-8',
      );
    }

    final raw = HaghOzviatCsvParser.parseBytes(bytes);
    return HaghOzviatRowParser.analyzeRawRows(
      fileName: fileName,
      raw: raw,
      registry: registry,
      importSource: 'csv',
      applyMergedCellFill: false,
    );
  }
}
