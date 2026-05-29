/// نرمال‌سازی برچسب‌های CSV برای فیلدهای پرونده (مطابق فرم ویرایش).
class CsvImportLabels {
  CsvImportLabels._();

  static String normalizeEducation(String? raw) {
    final t = _clean(raw);
    if (t.isEmpty) return '';
    const known = {
      'بی سواد',
      'خواندن ونوشتن',
      'پنجم ابتدایی',
      'سیکل',
      'دیپلم',
      'دیپلم ردی',
      'فوق دیپلم',
      'لیسانس',
      'فوق لیسانس',
      'دکتری',
      'دکتری عمومی',
      'ابتدایی',
    };
    if (known.contains(t)) return t;
    if (t.contains('فوق') && t.contains('لیسانس')) return 'فوق لیسانس';
    if (t.contains('لیسانس')) return 'لیسانس';
    if (t.contains('دیپلم')) return 'دیپلم';
    if (t.contains('سیکل')) return 'سیکل';
    return t;
  }

  static String normalizeOwnership(String? raw) {
    final t = _clean(raw);
    if (t.isEmpty) return '';
    const known = {
      'مالک',
      'استیجاری',
      'دائم',
      'صلح نامه',
      'هبه',
      'قرارداد شراکت',
      'مبایعه نامه',
    };
    if (known.contains(t)) return t;
    if (t.contains('مالک')) return 'مالک';
    if (t.contains('استیجار')) return 'استیجاری';
    return t;
  }

  static String normalizeReligion(String? raw) {
    var t = _clean(raw);
    if (t.isEmpty) return '';
    t = t.replaceAll('_', ' ').replaceAll('-', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    if (t == 'اسلام سایر' || t == 'اسلام_سایر') return 'سایر';
    if (t.contains('شیعه')) return 'اسلام - شیعه';
    if (t.contains('سنی')) return 'اسلام - سنی';
    if (t == 'اسلام' || t.startsWith('اسلام')) return 'اسلام - شیعه';
    if (t.contains('مسیحی')) return 'مسیحی';
    return t;
  }

  static String _clean(String? raw) {
    return (raw ?? '')
        .replaceAll('\u200c', '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
