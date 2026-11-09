import 'package:injast_admin/features/shekayat/compat/permissions.dart';

/// دسترسی‌های ماژول پرونده (هم‌راستا با injast_v3 Permissions)
class ParvandePermissions {
  ParvandePermissions._();

  static bool canEditParvande({String? role, bool isSuperAdmin = false}) {
    if (isSuperAdmin) return true;
    if (Permissions.currentUserRole.isNotEmpty) {
      return Permissions.canEditParvande();
    }
    final r = (role ?? '').trim().toLowerCase();
    return r == 'super_admin' ||
        r == 'modir_ejraei' ||
        r == 'omoor_edari_1' ||
        r == 'omoor_edari_2';
  }
}
