import 'package:injast_admin/features/permissions/permission_catalog.dart';
import 'package:injast_admin/features/permissions/user_permissions_api.dart';
import 'package:injast_admin/features/shekayat/compat/shekayat_basic.dart';

/// مدیریت دسترسی‌های شکایت — هم‌راستا با injast_v3
class Permissions {
  static bool _hasCustomProfile = false;
  static Set<String> _enabled = {};

  static String get currentUserRole {
    if (list_user.isEmpty) return '';
    return list_user.first['type_user']?.toString() ?? '';
  }

  static String get currentUserId {
    if (list_user.isEmpty) return '';
    return list_user.first['id_user']?.toString() ?? '';
  }

  static bool isComplaintExpertRole() {
    final r = currentUserRole.trim().toLowerCase();
    return r == 'karshenas_1' ||
        r == 'karshenas_2' ||
        r == 'bazrasi_karshenas_1' ||
        r == 'bazrasi_karshenas_2';
  }

  static bool canShekManageExpertise() =>
      canShekExpertise() && !isComplaintExpertRole();

  static Future<void> loadForCurrentUser() async {
    if (list_user.isEmpty) {
      _hasCustomProfile = false;
      _enabled = {};
      return;
    }
    final idUser = list_user.first['id_user']?.toString() ?? '';
    if (idUser.isEmpty) return;

    final data = await UserPermissionsApi.fetch(idUser);
    if (data != null && data.exists) {
      _hasCustomProfile = true;
      _enabled = PermissionCatalog.normalizeSavedPermissions(
        Set<String>.from(data.permissions),
      );
    } else {
      _hasCustomProfile = false;
      _enabled = PermissionCatalog.templateForRole(currentUserRole);
    }
  }

  static bool _has(String key) {
    if (_hasCustomProfile) return _enabled.contains(key);
    if (_enabled.isEmpty && currentUserRole.isNotEmpty) {
      return PermissionCatalog.roleHasPermission(currentUserRole, key);
    }
    if (_enabled.isEmpty) {
      // بدون نقش مشخص: دسترسی کامل برای ادمین تا دکمه‌ها دیده شوند
      return true;
    }
    return _enabled.contains(key);
  }

  static bool canShekForm() => _has('shek_form');
  static bool canShekSubjects() => _has('shek_subjects');
  static bool canShekDocuments() => _has('shek_documents');
  static bool canShekUnitLink() => _has('shek_unit_link');
  static bool canShekFollowups() => _has('shek_followups');
  static bool canShekExpertise() => _has('shek_expertise');
  static bool canShekCommission() => _has('shek_commission');
  static bool canShekEditResult() => _has('shek_edit_result');
  static bool canShekDeleteCase() => _has('shek_delete_case');
  static bool canShekReports() => _has('shek_reports');
}
