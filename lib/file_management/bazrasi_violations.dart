/// ۱۶ مورد تخلف بازرسی (همان فهرست manage_store / new_bazrasi)
const kBazrasiViolationItems = [
  'عدم نصب پروانه كسب در محل',
  'فروش فوق العاده بدون مجوز',
  'عدم صدور فاكتور',
  'منقضى شدن پروانه كسب',
  'عدم درج مشخصات قيمت',
  'فقدان کپسول آتش‌نشاني',
  'تغيير نشانى بدون مجوز',
  'عدم پرداخت حق عضويت',
  'عدم رعايت موارد انتظامى',
  'نداشتن پروانه كسب',
  'عدم تطابق نام واحد صنفى با پروانه يا فاكتور',
  'كارگر اتباع بدون مجوز',
  'فعاليت خارج از رسته صنفى در پروانه',
  'نام بيگانه يا غير فارسى در تابلو يا فاكتور',
  'تداخل صنفى',
  'عدم حضور متصدى / مباشر',
];

/// رشتهٔ type_takhalof برای API (با جداکننده -)
String encodeBazrasiTypeTakhalof(List<String> selected) {
  if (selected.isEmpty) return '0';
  final buf = StringBuffer();
  for (final item in selected) {
    buf.write('-$item');
  }
  return buf.toString();
}

/// شرح یادآور تقویم (مثل پروژهٔ قدیم)
String bazrasiReminderDescription({
  required String shenase,
  required String typeTakhalof,
}) =>
    '$shenase/$shenase/$typeTakhalof';
