import 'package:shamsi_date/shamsi_date.dart';

/// تبدیل و فرمت تاریخ شمسی برای فرم‌ها
class JalaliDateUtil {
  JalaliDateUtil._();

  /// بازهٔ سال شمسی متداول در داده‌های اصناف/اتحادیه.
  static bool isLikelyJalaliYear(int year) => year >= 1200 && year <= 1599;

  static String formatFromDateTime(DateTime dt) {
    final j = Gregorian(dt.year, dt.month, dt.day).toJalali();
    return '${j.year}/${j.month.toString().padLeft(2, '0')}/${j.day.toString().padLeft(2, '0')}';
  }

  static String formatYearFromDateTime(DateTime dt) {
    final j = Gregorian(dt.year, dt.month, dt.day).toJalali();
    return j.year.toString();
  }

  static String formatGregorian(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  static String _formatJalali(Jalali j) =>
      '${j.year}/${j.month.toString().padLeft(2, '0')}/${j.day.toString().padLeft(2, '0')}';

  static Jalali? parse(String? raw) {
    final t = _stripTime(raw);
    if (t.isEmpty) return null;
    final normalized = t.replaceAll('-', '/');
    final parts = normalized.split('/');
    if (parts.length != 3) return null;
    final y = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final d = int.tryParse(parts[2]);
    if (y == null || m == null || d == null) return null;
    try {
      return Jalali(y, m, d);
    } catch (_) {
      return null;
    }
  }

  static DateTime? parseToGregorian(String? raw) {
    final j = parse(raw);
    if (j == null) return null;
    final g = j.toGregorian();
    return DateTime(g.year, g.month, g.day);
  }

  /// تاریخ سرور (میلادی یا شمسی) → نمایش شمسی YYYY/MM/DD
  static String serverToDisplay(String? raw) {
    final t = _stripTime(raw);
    if (t.isEmpty) return '';

    final dashForm = t.replaceAll('/', '-');
    if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(dashForm)) {
      final parts = dashForm.split('-');
      final y = int.parse(parts[0]);
      final m = int.parse(parts[1]);
      final d = int.parse(parts[2]);
      // اگر سال در بازهٔ شمسی باشد، همان را نشان بده — تبدیل دوباره میلادی→شمسی نکن.
      if (isLikelyJalaliYear(y)) {
        return '$y/${m.toString().padLeft(2, '0')}/${d.toString().padLeft(2, '0')}';
      }
      return formatFromDateTime(DateTime(y, m, d));
    }

    final j = parse(t);
    if (j != null) return _formatJalali(j);

    // ISO کامل مثل 2026-07-19T07:52:45.000Z
    final dt = DateTime.tryParse(raw?.trim() ?? '');
    if (dt != null) return formatFromDateTime(dt.toLocal());

    return t;
  }

  /// سال تولد از سرور → نمایش سال شمسی
  static String serverToDisplayYear(String? raw) {
    final t = raw?.trim() ?? '';
    if (t.isEmpty || t == 'null') return '';
    if (RegExp(r'^\d{4}$').hasMatch(t)) return t;

    final display = serverToDisplay(t);
    if (display.isEmpty) return t;
    final j = parse(display);
    return j?.year.toString() ?? t;
  }

  /// نمایش شمسی → ارسال میلادی YYYY-MM-DD به سرور
  static String displayToServer(String? display) {
    final t = _stripTime(display);
    if (t.isEmpty) return '';

    final dashForm = t.replaceAll('/', '-');
    if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(dashForm)) {
      final y = int.parse(dashForm.substring(0, 4));
      // از قبل میلادی است
      if (!isLikelyJalaliYear(y)) return dashForm;
      // شمسی با خط تیره → میلادی
    }

    final j = parse(t);
    if (j == null) return t;
    final g = j.toGregorian();
    return formatGregorian(DateTime(g.year, g.month, g.day));
  }

  /// نرمال‌سازی متن تاریخ شمسی به `YYYY/MM/DD` (بدون تبدیل به میلادی).
  static String normalizeJalaliDisplay(String? raw) {
    final j = parse(raw);
    if (j == null) {
      final t = _stripTime(raw);
      return t;
    }
    return _formatJalali(j);
  }

  /// تاریخ شمسی مناسب Path API: `YYYY-MM-DD` (بدون `/` تا پارامتر URL نشکند).
  static String toPathSafeJalali(String? raw) {
    final display = normalizeJalaliDisplay(raw);
    if (display.isEmpty) return '';
    return display.replaceAll('/', '-');
  }

  /// تاریخ سرور → نمایش شمسی با ارقام فارسی (مثلاً ۱۴۰۵/۰۵/۰۸)
  static String serverToPersianDisplay(String? raw) {
    final display = serverToDisplay(raw);
    if (display.isEmpty) return '';
    return _toPersianDigits(display);
  }

  static String _toPersianDigits(String input) {
    const en = '0123456789';
    const fa = '۰۱۲۳۴۵۶۷۸۹';
    final buf = StringBuffer();
    for (var i = 0; i < input.length; i++) {
      final ch = input[i];
      final idx = en.indexOf(ch);
      buf.write(idx >= 0 ? fa[idx] : ch);
    }
    return buf.toString();
  }

  static String _stripTime(String? raw) {
    var t = raw?.trim() ?? '';
    if (t.isEmpty || t == 'null') return '';

    // ارقام فارسی/عربی → انگلیسی تا پارس درست کار کند
    t = _fromPersianDigits(t);

    // فاصله‌های اضافه دور جداکننده‌ها (مثلاً «1405-05-28- T 07:52»)
    t = t.replaceAll(RegExp(r'\s+'), '');

    // ISO: 1405-05-28T07:52:45.000Z یا 1405-05-28T07:52:45
    final tUpper = t.indexOf('T');
    final tLower = t.indexOf('t');
    final tSep = tUpper >= 0
        ? (tLower >= 0 ? (tUpper < tLower ? tUpper : tLower) : tUpper)
        : tLower;
    if (tSep > 0 && RegExp(r'^\d').hasMatch(t)) {
      t = t.substring(0, tSep);
    }

    // اگر بعد از تاریخ هنوز `-` اضافه مانده: 1405-05-28-
    t = t.replaceFirst(RegExp(r'[-/]+$'), '');

    final comma = t.indexOf(',');
    if (comma > 0) t = t.substring(0, comma).trim();
    final space = t.indexOf(' ');
    if (space > 0 && RegExp(r'^\d').hasMatch(t)) {
      t = t.substring(0, space).trim();
    }

    // فقط بخش تاریخ YYYY-MM-DD یا YYYY/MM/DD را نگه دار
    final m = RegExp(r'^(\d{4}[-/]\d{1,2}[-/]\d{1,2})').firstMatch(t);
    if (m != null) return m.group(1)!;

    return t;
  }

  static String _fromPersianDigits(String input) {
    const en = '0123456789';
    const fa = '۰۱۲۳۴۵۶۷۸۹';
    const ar = '٠١٢٣٤٥٦٧٨٩';
    final buf = StringBuffer();
    for (var i = 0; i < input.length; i++) {
      final ch = input[i];
      final fi = fa.indexOf(ch);
      if (fi >= 0) {
        buf.write(en[fi]);
        continue;
      }
      final ai = ar.indexOf(ch);
      if (ai >= 0) {
        buf.write(en[ai]);
        continue;
      }
      buf.write(ch);
    }
    return buf.toString();
  }
}
