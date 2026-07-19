/// جایگزینی سبک persian_number_utility
extension PersianNumberString on String {
  String toPersianDigit() {
    const en = '0123456789';
    const fa = '۰۱۲۳۴۵۶۷۸۹';
    final buf = StringBuffer();
    for (var i = 0; i < length; i++) {
      final ch = this[i];
      final idx = en.indexOf(ch);
      buf.write(idx >= 0 ? fa[idx] : ch);
    }
    return buf.toString();
  }

  String seRagham() {
    final digits = replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return this;
    final buf = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buf.write(',');
      buf.write(digits[i]);
    }
    return buf.toString();
  }
}
