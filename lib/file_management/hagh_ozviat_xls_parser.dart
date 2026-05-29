import 'dart:typed_data';

import 'package:injast_admin/file_management/excel_import/xls_python_bridge.dart';
import 'package:injast_admin/file_management/hagh_ozviat_models.dart';
import 'package:injast_admin/file_management/hagh_ozviat_registry.dart';
import 'package:injast_admin/file_management/hagh_ozviat_row_parser.dart';

/// @deprecated از [HaghOzviatFileParser] استفاده کنید.
class HaghOzviatXlsParser {
  static Future<HaghOzviatAnalysis> analyze({
    required String fileName,
    required Uint8List bytes,
    HaghOzviatRegistry? registry,
  }) async {
    final raw = await XlsPythonBridge.parseRawRows(bytes);
    return HaghOzviatRowParser.analyzeRawRows(
      fileName: fileName,
      raw: raw,
      registry: registry,
      importSource: 'xls',
      applyMergedCellFill: true,
    );
  }
}
