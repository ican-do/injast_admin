/// نگاشت وضعیت پرونده ↔ کد vaziyat_store
class ParvandeVaziyat {
  ParvandeVaziyat._();

  static const options = [
    'دردست اقدام',
    'فعال/صادر شده',
    'منقضی شده',
    'ابطال متقاضی',
    'ابطال',
    'فاقد اعتبار',
    'تعلیق',
  ];

  static const _labelToCode = {
    'دردست اقدام': '1',
    'فعال/صادر شده': '2',
    'منقضی شده': '3',
    'ابطال متقاضی': '6',
    'ابطال': '8',
    'فاقد اعتبار': '10',
    'فاقد پروانه(فاقد اعتبار)': '10',
    'تعلیق': '11',
  };

  static const _codeToLabel = {
    '1': 'دردست اقدام',
    '2': 'فعال/صادر شده',
    '3': 'منقضی شده',
    '6': 'ابطال متقاضی',
    '8': 'ابطال',
    '10': 'فاقد اعتبار',
    '11': 'تعلیق',
  };

  static String normalizeLabel(String? raw) {
    final t = raw?.trim() ?? '';
    if (t.isEmpty || t == 'null') return options.first;
    if (t == 'فاقد پروانه(فاقد اعتبار)') return 'فاقد اعتبار';
    // نسخهٔ path-safe که با خط تیره روی سرور ذخیره شده است.
    if (t == 'فعال-صادر شده') return 'فعال/صادر شده';
    if (options.contains(t)) return t;
    final fromCode = _codeToLabel[t];
    if (fromCode != null) return fromCode;
    return t;
  }

  static String codeForLabel(String label) =>
      _labelToCode[normalizeLabel(label)] ?? '1';

  static String labelForRow(Map<String, dynamic> p) {
    final lbl = p['lbl_vaziyat_store']?.toString().trim() ?? '';
    if (lbl.isNotEmpty && lbl != 'null') return normalizeLabel(lbl);
    final code = p['vaziyat_store']?.toString().trim() ?? '';
    return _codeToLabel[code] ?? normalizeLabel(lbl);
  }
}
