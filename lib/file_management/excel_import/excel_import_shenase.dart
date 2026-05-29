/// نرمال‌سازی «کد صنفی» — حفظ صفر ابتدایی (۱۰ رقم).
class ExcelImportShenase {
  ExcelImportShenase._();

  static const shenaseLength = 10;

  static String normalize(String raw) {
    var t = raw.trim().replaceAll(',', '');
    if (t.isEmpty) return '';

    if (RegExp(r'^\d+\.0$').hasMatch(t)) {
      t = t.substring(0, t.length - 2);
    }

    if (RegExp(r'^\d+$').hasMatch(t)) {
      return t.length >= shenaseLength ? t : t.padLeft(shenaseLength, '0');
    }

    final asNum = double.tryParse(t);
    if (asNum != null && asNum == asNum.roundToDouble()) {
      final digits = asNum.toInt().toString();
      return digits.length >= shenaseLength
          ? digits
          : digits.padLeft(shenaseLength, '0');
    }

    return t.replaceAll(RegExp(r'\.0$'), '');
  }
}
