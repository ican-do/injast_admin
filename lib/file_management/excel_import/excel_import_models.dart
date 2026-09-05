import 'package:injast_admin/file_management/excel_import/csv_header_mapper.dart';

class ExcelParsedRow {
  const ExcelParsedRow({
    required this.rowIndex,
    required this.values,
  });

  final int rowIndex;
  final Map<String, String> values;
}

class ImportParseResult {
  const ImportParseResult({
    required this.rawHeaders,
    required this.headerMatch,
    required this.rows,
  });

  final List<String> rawHeaders;
  final CsvHeaderMatchReport headerMatch;
  final List<ExcelParsedRow> rows;
}
