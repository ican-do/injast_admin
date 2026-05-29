import 'package:shamsi_date/shamsi_date.dart';

/// تبدیل و فرمت تاریخ شمسی برای فرم‌ها
class JalaliDateUtil {
  JalaliDateUtil._();

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

  static Jalali? parse(String? raw) {
    final t = raw?.trim() ?? '';
    if (t.isEmpty || t == 'null') return null;
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

  static DateTime? parseToGregorian(String? raw) => parse(raw)?.toDateTime();

  /// تاریخ سرور (میلادی یا شمسی) → نمایش شمسی YYYY/MM/DD
  static String serverToDisplay(String? raw) {
    final t = raw?.trim() ?? '';
    if (t.isEmpty || t == 'null') return '';

    if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(t)) {
      final parts = t.split('-');
      final y = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      final d = int.tryParse(parts[2]);
      if (y != null && m != null && d != null) {
        return formatFromDateTime(DateTime(y, m, d));
      }
    }

    final j = parse(t);
    if (j != null) {
      return '${j.year}/${j.month.toString().padLeft(2, '0')}/${j.day.toString().padLeft(2, '0')}';
    }

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
    final t = display?.trim() ?? '';
    if (t.isEmpty) return '';

    if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(t)) return t;

    final j = parse(t);
    if (j == null) return t;
    final g = j.toGregorian();
    return formatGregorian(DateTime(g.year, g.month, g.day));
  }
}
