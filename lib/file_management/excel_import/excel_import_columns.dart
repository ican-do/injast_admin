/// ستون‌های شناخته‌شده در فایل خروجی/ورودی اصناف (نمونه: پروانه‌های ایرانیان اصناف).
class ExcelImportColumns {
  ExcelImportColumns._();

  static const trackingNovin = 'کدرهگیری نوین';
  static const shenase = 'کد صنفی';
  static const firstName = 'نام';
  static const lastName = 'نام خانوادگی';
  static const nationalId = 'کدملی';
  static const postalCode = 'کدپستی';
  static const address = 'آدرس';
  static const issueDate = 'تاریخ صدور';
  static const validity = 'اعتبار';
  static const state = 'استان';
  static const city = 'شهر';
  static const raste = 'عنوان رسته';
  static const status = 'وضعیت';
  static const source = 'مبدا';
  static const unionName = 'نام اتحادیه (مرجع صادرکننده)';
  static const activityType = 'نوع فعالیت واحد صنفی';
  static const storeTitle = 'عنوان تابلو';
  static const normalType = 'نوع عادی/ایثارگری';
  static const personType = 'نوع شخص';
  static const companyName = 'نام شرکت';
  static const fatherName = 'نام پدر';
  static const gender = 'جنسیت';
  static const education = 'سطح تحصیلات';
  static const ownership = 'نوع مالکیت';
  static const birthDate = 'تاریخ تولد';
  static const religion = 'مذهب';

  /// حداقل ستون‌های لازم برای ثبت پرونده در سیستم.
  static const requiredForRegistration = [
    shenase,
    firstName,
    lastName,
    address,
    storeTitle,
    issueDate,
    state,
    city,
    raste,
    status,
  ];

  static const allKnown = [
    trackingNovin,
    shenase,
    firstName,
    lastName,
    nationalId,
    postalCode,
    address,
    issueDate,
    validity,
    state,
    city,
    raste,
    status,
    source,
    unionName,
    activityType,
    storeTitle,
    normalType,
    personType,
    companyName,
    fatherName,
    gender,
    education,
    ownership,
    birthDate,
    religion,
  ];

  static String normalizeHeader(String raw) {
    return raw
        .replaceAll('\uFEFF', '')
        .replaceAll('\u200c', '')
        .replaceAll('\u200f', '')
        .replaceAll('ي', 'ی')
        .replaceAll('ك', 'ک')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// تطبیق نام ستون فایل با نام استاندارد (حساس به فاصله/ی عربی نیست).
  static String? canonicalColumn(String header) {
    final h = normalizeHeader(header);
    if (h.isEmpty) return null;
    for (final known in allKnown) {
      if (normalizeHeader(known) == h) return known;
    }
    return null;
  }
}
