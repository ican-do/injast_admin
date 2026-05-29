class ExcelParsedRow {
  const ExcelParsedRow({
    required this.rowIndex,
    required this.values,
  });

  final int rowIndex;
  final Map<String, String> values;
}
