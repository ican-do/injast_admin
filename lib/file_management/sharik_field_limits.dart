import 'package:injast_admin/file_management/jalali_date_util.dart';

/// محدودیت طول فیلدها مطابق schema دیتابیس tbl_sharik
class SharikFieldLimits {
  SharikFieldLimits._();

  static const nameMax = 30;
  static const familyMax = 30;
  static const codeMeliMax = 10;
  static const mobMax = 11;
  static const telMax = 11;
  static const shenasnameMax = 10;
  static const tavalodMax = 4;
  static const sadereMax = 30;
  static const namePedarMax = 30;
  static const captionMax = 100;
  static const dateMax = 20;
  static const typeFardMax = 50;

  /// سال تولد — در DB فقط ۴ رقم (مثلاً 1405)
  static String tavalodForDb(String raw) {
    final t = raw.trim();
    if (t.isEmpty || t == 'null') return '';
    final j = JalaliDateUtil.parse(t);
    if (j != null) return j.year.toString();
    if (RegExp(r'^\d{4}$').hasMatch(t)) return t;
    final year = int.tryParse(t.split('/').first);
    if (year != null && year >= 1200 && year <= 1500) return year.toString();
    return t.length > tavalodMax ? t.substring(0, tavalodMax) : t;
  }

  static String displayTavalod(String? raw) {
    final y = tavalodForDb(raw ?? '');
    return y;
  }

  static String? validate(Map<String, String> fields) {
    String check(String key, String label, int max, {bool required = false}) {
      final v = fields[key]?.trim() ?? '';
      if (required && v.isEmpty) return '$label الزامی است.';
      if (v.length > max) return '$label حداکثر $max کاراکتر مجاز است.';
      return '';
    }

    final checks = [
      check('name_sharik', 'نام', nameMax, required: true),
      check('family_sharik', 'نام خانوادگی', familyMax),
      check('mob_sharik', 'موبایل', mobMax, required: true),
      check('code_meli_sharik', 'کد ملی', codeMeliMax),
      check('tel_sharik', 'تلفن', telMax),
      check('num_shenasname_sharik', 'شماره شناسنامه', shenasnameMax),
      check('name_pedar_sharik', 'نام پدر', namePedarMax),
      check('sadere_sharik', 'صادره', sadereMax),
      check('caption_sharik', 'توضیحات', captionMax),
      check('type_fard', 'نوع فرد', typeFardMax),
      check('date_sodor_sharik', 'تاریخ صدور', dateMax),
      check('date_exp_sharik', 'تاریخ انقضا', dateMax),
    ];

    for (final c in checks) {
      if (c.isNotEmpty) return c;
    }

    final tavalod = fields['tavalod_sharik']?.trim() ?? '';
    if (tavalod.isNotEmpty) {
      final y = tavalodForDb(tavalod);
      if (y.length > tavalodMax) {
        return 'سال تولد باید ۴ رقم شمسی باشد (مثلاً 1370).';
      }
      if (!RegExp(r'^\d{4}$').hasMatch(y)) {
        return 'سال تولد نامعتبر است.';
      }
    }

    final mob = fields['mob_sharik']?.trim() ?? '';
    if (mob.isNotEmpty && !RegExp(r'^\d{10,11}$').hasMatch(mob)) {
      return 'شماره موبایل باید ۱۰ یا ۱۱ رقم باشد.';
    }

    final meli = fields['code_meli_sharik']?.trim() ?? '';
    if (meli.isNotEmpty && !RegExp(r'^\d{10}$').hasMatch(meli)) {
      return 'کد ملی باید دقیقاً ۱۰ رقم باشد.';
    }

    return null;
  }

  static Map<String, String> normalizeForApi(Map<String, String> fields) {
    return {
      ...fields,
      'tavalod_sharik': tavalodForDb(fields['tavalod_sharik'] ?? ''),
    };
  }
}
