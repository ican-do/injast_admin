/// ستون‌های فایل XLS مطالبات صنفی (حق عضویت).
class HaghOzviatColumns {
  HaghOzviatColumns._();

  static const shenase = 'کد صنفی';
  static const onvan = 'عنوان';
  static const mablagh = 'مبلغ(ریال)';
  static const sal = 'سال';
  static const tarikhIjad = 'تاریخ ایجاد';
  static const noeEblagh = 'نوع ابلاغ';
  static const vaziyat = 'وضعیت';
  static const radeSanfi = 'رده صنفی';
  static const onvanRaste = 'عنوان رسته';
  static const codeMeli = 'کدملی';

  static const required = [shenase, onvan, mablagh, sal, vaziyat];

  static const _melliAliases = [
    codeMeli,
    'کد ملی',
    'کد ملی صاحب صنف',
    'کدملی صاحب صنف',
  ];

  static const _shenaseAliases = [
    shenase,
    'شناسه صنفی',
    'کد صنفی ',
    'کد صنف',
  ];

  static List<String> missingIn(List<String> headers) {
    final normalized = headers.map(_normKey).toSet();
    final hasShenase = _shenaseAliases.any((a) => normalized.contains(_normKey(a))) ||
        normalized.any((h) => h.contains('کدصنفی') || h.contains('شناسهصنفی'));
    final missing = <String>[];
    if (!hasShenase) missing.add(shenase);
    for (final col in required) {
      if (col == shenase) continue;
      if (!headers.map((e) => e.trim()).contains(col)) {
        missing.add(col);
      }
    }
    return missing;
  }

  static String normKey(String key) => _normKey(key);

  static String? readShenase(
    Map<String, String> values, {
    String? preferredColumn,
  }) {
    if (preferredColumn != null && preferredColumn.isNotEmpty) {
      final t = values[preferredColumn]?.trim();
      if (t != null && t.isNotEmpty) return t;
    }
    for (final key in _shenaseAliases) {
      final t = values[key]?.trim();
      if (t != null && t.isNotEmpty) return t;
    }
    for (final e in values.entries) {
      final nk = _normKey(e.key);
      if (nk.contains('کدملی')) continue;
      if (nk.contains('کدصنفی') ||
          nk == 'شناسهصنفی' ||
          (nk.contains('شناسه') && nk.contains('صنف'))) {
        final t = e.value.trim();
        if (t.isNotEmpty) return t;
      }
    }
    return null;
  }

  /// کد ملی ۱۰ رقمی (برای تفکیک اعضا وقتی «کد صنفی» ادغام شده است).
  static String readMelli(Map<String, String> values) {
    for (final key in _melliAliases) {
      final t = values[key]?.trim();
      if (t != null && t.isNotEmpty) return normalizeMelli(t);
    }
    for (final e in values.entries) {
      final nk = _normKey(e.key);
      if (nk.contains('کدملی') || nk == 'کدملی') {
        final t = e.value.trim();
        if (t.isNotEmpty) return normalizeMelli(t);
      }
    }
    return '';
  }

  static String normalizeMelli(String raw) {
    var t = raw.trim().replaceAll(',', '');
    if (t.isEmpty) return '';
    if (RegExp(r'^\d+\.0$').hasMatch(t)) {
      t = t.substring(0, t.length - 2);
    }
    final asNum = double.tryParse(t);
    if (asNum != null && asNum == asNum.roundToDouble()) {
      t = asNum.toInt().toString();
    }
    if (RegExp(r'^\d+$').hasMatch(t)) {
      return t.length >= 10 ? t : t.padLeft(10, '0');
    }
    return t.split('.').first;
  }

  static String read(Map<String, String> values, String canonical) {
    final direct = values[canonical]?.trim();
    if (direct != null && direct.isNotEmpty) return direct;
    return '';
  }

  static String _normKey(String key) =>
      key.trim().replaceAll(RegExp(r'\s+'), '').toLowerCase();
}
