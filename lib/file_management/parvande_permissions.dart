/// دسترسی‌های ماژول پرونده (هم‌راستا با injast_v3 Permissions)
class ParvandePermissions {
  ParvandePermissions._();

  static const _allowedKeys = {
    'super_admin',
    'modir_ejraei',
    'omoor_edari_1',
    'omoor_edari_2',
  };

  /// برچسب‌های فارسی معادل (وقتی type_user به‌صورت label ارسال شده)
  static const _allowedLabels = {
    'مدیرکل سیستم',
    'مدیر اجرایی',
    'امور اداری ۱',
    'امور اداری ۲',
  };

  static bool canEditParvande({String? role, bool isSuperAdmin = false}) {
    if (isSuperAdmin) return true;
    final r = role?.trim() ?? '';
    if (r.isEmpty) return false;
    if (_allowedKeys.contains(r.toLowerCase())) return true;
    return _allowedLabels.contains(r);
  }
}
