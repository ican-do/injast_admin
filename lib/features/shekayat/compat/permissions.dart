import 'package:injast_admin/features/permissions/permission_catalog.dart';
import 'package:injast_admin/features/permissions/user_permissions_api.dart';
import 'package:injast_admin/features/shekayat/compat/shekayat_basic.dart';

/// مدیریت دسترسی‌ها — هم‌راستا با injast_v3
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
    return r == 'karshenas' ||
        r == 'karshenas_1' ||
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

  static void applyCustomProfile(Set<String> permissions) {
    _hasCustomProfile = true;
    _enabled = Set<String>.from(permissions);
  }

  static void resetToRoleTemplate() {
    _hasCustomProfile = false;
    _enabled = PermissionCatalog.templateForRole(currentUserRole);
  }

  static bool _has(String key) {
    if (_hasCustomProfile) return _enabled.contains(key);
    return PermissionCatalog.roleHasPermission(currentUserRole, key);
  }

  static bool canManageMembers() => _has('manage_members');
  static bool canManageRaste() => _has('manage_raste');
  static bool canCreateParvande() => _has('create_parvande');
  static bool canBazrasiMenu() => _has('bazrasi_menu');
  static bool canShekayatMenu() => _has('shekayat_menu');
  static bool canViewReports() => _has('view_reports');
  static bool canCommissionMenu() => _has('commission_menu');
  static bool canManageCommission() => _has('commission_manage');
  static bool canCommissionReports() => _has('commission_reports');
  static bool canManageSettings() => _has('manage_settings');
  static bool canViewCalendar() => _has('view_calendar');
  static bool canManageUnionSettings() => _has('manage_union_settings');
  static bool canManageBazrasiForms() => _has('manage_bazrasi_forms');
  static bool canDataBackup() => _has('data_backup');
  static bool canAsnafSite() => _has('asnaf_site');
  static bool canManagePortal() => _has('manage_portal');

  static bool canHomeCountRaste() => _has('home_count_raste');
  static bool canHomeCountParvande() => _has('home_count_parvande');
  static bool canHomeCountUsers() => _has('home_count_users');
  static bool canHomeCountUpdate() => _has('home_count_update');
  static bool canHomeStatDebtTotal() => _has('home_stat_debt_total');
  static bool canHomeStatNewMonth() => _has('home_stat_new_month');
  static bool canHomeStatInspectionsMonth() => _has('home_stat_inspections_month');
  static bool canHomeStatExpiringMonth() => _has('home_stat_expiring_month');
  static bool canHomeSlideMembers() => _has('home_slide_members');
  static bool canHomeSlideBazrasiWeek() => _has('home_slide_bazrasi_week');
  static bool canHomeSlideShekayat() => _has('home_slide_shekayat');
  static bool canHomeSlideDebt() => _has('home_slide_debt');
  static bool canHomeSlideRaste() => _has('home_slide_raste');

  static bool canViewPersonnelNames() => _has('view_personnel_names');
  static bool canManagePersonnel() => _has('manage_personnel');
  static bool canManageRateSheets() => _has('manage_rate_sheets');
  static bool canViewRulesAndRegulations() => _has('view_rules');
  static bool canViewMemberRequests() => _has('view_member_requests');
  static bool canManageRequestTypes() => _has('manage_request_types');
  static bool canManageOrganizations() => _has('manage_organizations');
  static bool canManageRequests() => _has('manage_requests');
  static bool canViewBenefitsAndServices() => _has('view_benefits');
  static bool canViewNews() => _has('view_news');
  static bool canViewEducation() => _has('view_education');
  static bool canViewCooperative() => _has('view_cooperative');
  static bool canAccessMoshavere() => _has('access_moshavere');
  static bool canViewAnnouncements() => _has('view_announcements');
  static bool canViewSurvey() => _has('view_survey');
  static bool canViewPriceList() => _has('view_price_list');
  static bool canCreateRequest() => _has('create_request');

  static bool canManageUsers() => _has('manage_users');
  static bool canInsertBaseData() => _has('insert_base_data');

  static bool canCreateShekayat() => _has('create_shekayat');
  static bool canManageShekayat() => _has('manage_shekayat');
  static bool canSendShekayatLink() => _has('send_shekayat_link');
  static bool canViewShekayatHistory() => _has('manage_shekayat');

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

  static bool canCreateBazrasi() => _has('create_bazrasi');
  static bool canViewBazrasiHistory() => _has('view_bazrasi_history');
  static bool canViewInspectionArchive() => _has('view_inspection_archive');
  static bool canViewReinspectInbox() => _has('view_reinspect_inbox');
  static bool canViewPasiniVisits() => _has('view_pasini_visits');
  static bool canSetInspectionOutcome() => _has('set_inspection_outcome');
  static bool canAssignPasiniCases() => _has('assign_pasini_cases');
  static bool canLicenseExpiryReport() => _has('view_license_expiry');

  static bool canMemberCreateParvande() => _has('member_create_parvande');
  static bool canMemberDeleteTrash() => _has('member_delete_trash');
  static bool canMemberShekayat() => _has('member_shekayat');
  static bool canMemberBazrasi() => _has('member_bazrasi');
  static bool canMemberBazrasiHistory() => _has('member_bazrasi_history');
  static bool canViewAdditionalInfo() => _has('view_additional_info');
  static bool canViewShareek() => _has('view_shareek');
  static bool canViewDocuments() => _has('view_documents');
  static bool canViewParvande() => _has('view_parvande');
  static bool canViewImages() => _has('view_images');
  static bool canEditParvande() => _has('edit_parvande');
  static bool canDeleteParvande() => _has('delete_parvande');
  static bool canViewMembershipFee() => _has('view_membership_fee');

  static bool canOpenSettingsMenu() =>
      canManageSettings() ||
      canInsertBaseData() ||
      canManageUsers() ||
      canManageUnionSettings() ||
      canManageBazrasiForms() ||
      canDataBackup();

  static bool canViewMembers() => canManageMembers();
}
