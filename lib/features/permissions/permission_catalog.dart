/// کاتالوگ دسترسی‌ها — مشترک اپ و دسکتاپ
class PermissionNode {
  final String? key;
  final String label;
  final List<PermissionNode> children;

  const PermissionNode({
    this.key,
    required this.label,
    this.children = const [],
  });

  bool get isLeaf => key != null;
}

class PermissionCatalog {
  static const _lead = [
    'super_admin',
    'raees_etehadiye',
    'modir_ejraei',
  ];
  static const _leadAdm = [
    'super_admin',
    'raees_etehadiye',
    'modir_ejraei',
    'omoor_edari_1',
  ];
  static const _office = [
    'super_admin',
    'raees_etehadiye',
    'heyat_modire',
    'modir_ejraei',
    'omoor_edari_1',
    'omoor_edari_2',
    'omoor_edari_3',
  ];
  static const _staff = [
    'super_admin',
    'raees_etehadiye',
    'heyat_modire',
    'modir_ejraei',
    'omoor_edari_1',
    'omoor_edari_2',
    'omoor_edari_3',
    'masool_shakayat',
    'hesabdari',
    'bazrasi_1',
    'bazrasi_2',
    'karshenas_2',
    'bazrasi_karshenas_1',
    'bazrasi_karshenas_2',
  ];
  static const _reports = [
    'super_admin',
    'raees_etehadiye',
    'heyat_modire',
    'modir_ejraei',
    'omoor_edari_1',
    'omoor_edari_2',
    'omoor_edari_3',
    'masool_shakayat',
  ];
  static const _bazrasi = [
    'super_admin',
    'raees_etehadiye',
    'heyat_modire',
    'modir_ejraei',
    'omoor_edari_1',
    'bazrasi_1',
    'bazrasi_2',
    'bazrasi_karshenas_1',
    'bazrasi_karshenas_2',
  ];
  static const _shekayat = [
    'super_admin',
    'raees_etehadiye',
    'heyat_modire',
    'modir_ejraei',
    'omoor_edari_1',
    'omoor_edari_2',
    'omoor_edari_3',
    'masool_shakayat',
    'karshenas_1',
    'karshenas_2',
    'bazrasi_karshenas_1',
    'bazrasi_karshenas_2',
  ];
  static const _inspectors = [
    'super_admin',
    'modir_ejraei',
    'bazrasi_1',
    'bazrasi_2',
    'bazrasi_karshenas_1',
    'bazrasi_karshenas_2',
  ];

  static List<String> get allKeys {
    final keys = <String>[];
    void walk(List<PermissionNode> nodes) {
      for (final n in nodes) {
        if (n.key != null) keys.add(n.key!);
        walk(n.children);
      }
    }

    walk(permissionTree);
    return keys;
  }

  static const List<PermissionNode> permissionTree = [
    PermissionNode(label: 'منوی اصلی', children: [
      PermissionNode(key: 'manage_members', label: 'اعضاء اتحادیه'),
      PermissionNode(key: 'manage_raste', label: 'معرفی رسته'),
      PermissionNode(key: 'create_parvande', label: 'ثبت پرونده جدید'),
      PermissionNode(key: 'bazrasi_menu', label: 'بازرسی (منو)'),
      PermissionNode(key: 'shekayat_menu', label: 'شکایات (منو)'),
      PermissionNode(key: 'view_reports', label: 'آمار و گزارشات'),
      PermissionNode(key: 'commission_menu', label: 'صورت جلسه کمیسیون‌ها'),
      PermissionNode(key: 'manage_settings', label: 'تنظیمات'),
      PermissionNode(key: 'view_calendar', label: 'تقویم من'),
    ]),
    PermissionNode(label: 'صفحه اصلی', children: [
      PermissionNode(key: 'home_count_raste', label: 'تعداد رسته'),
      PermissionNode(key: 'home_count_parvande', label: 'تعداد پرونده / کل اعضا'),
      PermissionNode(key: 'home_count_users', label: 'تعداد کاربر فعال'),
      PermissionNode(key: 'home_count_update', label: 'وضعیت بروزرسانی'),
      PermissionNode(key: 'home_stat_debt_total', label: 'جمع بدهی (پنل بالا)'),
      PermissionNode(key: 'home_stat_new_month', label: 'اعضای جدید ماه'),
      PermissionNode(key: 'home_stat_inspections_month', label: 'بازرسی ماه'),
      PermissionNode(key: 'home_stat_expiring_month', label: 'انقضای ماه'),
      PermissionNode(key: 'home_slide_members', label: 'اسلاید آمار اعضا'),
      PermissionNode(key: 'home_slide_bazrasi_week', label: 'اسلاید بازرسی هفته'),
      PermissionNode(key: 'home_slide_shekayat', label: 'اسلاید شکایات'),
      PermissionNode(key: 'home_slide_debt', label: 'اسلاید بدهی حق عضویت'),
      PermissionNode(key: 'home_slide_raste', label: 'اسلاید رسته‌ها'),
    ]),
    PermissionNode(label: 'فاز ۲', children: [
      PermissionNode(key: 'view_personnel_names', label: 'اسامی پرسنل'),
      PermissionNode(key: 'manage_rate_sheets', label: 'مدیریت نرخ‌نامه'),
      PermissionNode(key: 'view_rules', label: 'قوانین و مقررات'),
      PermissionNode(key: 'view_member_requests', label: 'درخواست اعضا'),
      PermissionNode(key: 'view_benefits', label: 'مزایا و خدمات'),
      PermissionNode(key: 'view_news', label: 'اخبار'),
      PermissionNode(key: 'view_education', label: 'آموزش'),
      PermissionNode(key: 'view_cooperative', label: 'تعاونی'),
      PermissionNode(key: 'access_moshavere', label: 'مشاوره'),
      PermissionNode(key: 'view_announcements', label: 'اطلاعیه‌ها'),
      PermissionNode(key: 'view_survey', label: 'نظرسنجی'),
    ]),
    PermissionNode(label: 'شکایات', children: [
      PermissionNode(key: 'create_shekayat', label: 'ثبت شکایات'),
      PermissionNode(key: 'manage_shekayat', label: 'مدیریت شکایات'),
      PermissionNode(key: 'send_shekayat_link', label: 'ارسال لینک دعوت'),
    ]),
    PermissionNode(label: 'مدیریت شکایات (جزئیات)', children: [
      PermissionNode(key: 'shek_form', label: 'فرم شکایات'),
      PermissionNode(key: 'shek_subjects', label: 'موضوع شکایات'),
      PermissionNode(key: 'shek_documents', label: 'مدارک و مستندات'),
      PermissionNode(key: 'shek_unit_link', label: 'اتصال واحد'),
      PermissionNode(key: 'shek_followups', label: 'پیگیری‌ها'),
      PermissionNode(key: 'shek_expertise', label: 'کارشناسی'),
      PermissionNode(key: 'shek_commission', label: 'کمیسیون شکایات'),
      PermissionNode(key: 'shek_edit_result', label: 'ویرایش و نتیجه‌گیری'),
      PermissionNode(key: 'shek_delete_case', label: 'حذف پرونده شکایت'),
      PermissionNode(key: 'shek_reports', label: 'گزارشات شکایات'),
    ]),
    PermissionNode(label: 'کمیسیون‌ها', children: [
      PermissionNode(key: 'commission_manage', label: 'ثبت و مدیریت صورتجلسه'),
      PermissionNode(key: 'commission_reports', label: 'گزارشات جلسات'),
    ]),
    PermissionNode(label: 'بازرسی', children: [
      PermissionNode(key: 'create_bazrasi', label: 'ثبت'),
      PermissionNode(key: 'view_bazrasi_history', label: 'سوابق'),
      PermissionNode(key: 'view_inspection_archive', label: 'آرشیو بازرسی‌ها'),
      PermissionNode(key: 'manage_bazrasi_forms', label: 'فرم‌ساز بازرسی'),
      PermissionNode(key: 'view_reinspect_inbox', label: 'پرونده‌های محول‌شده'),
      PermissionNode(key: 'view_pasini_visits', label: 'بازدید پسینی'),
      PermissionNode(key: 'assign_pasini_cases', label: 'اختصاص پرونده پسینی'),
      PermissionNode(key: 'view_license_expiry', label: 'پروانه‌های نزدیک انقضا'),
      PermissionNode(key: 'set_inspection_outcome', label: 'ثبت وضعیت نهایی فرم'),
    ]),
    PermissionNode(label: 'اعضاء اتحادیه (عملیات پرونده)', children: [
      PermissionNode(key: 'member_create_parvande', label: '+ پرونده جدید'),
      PermissionNode(key: 'member_delete_trash', label: 'سطل زباله'),
      PermissionNode(key: 'member_shekayat', label: 'شکایات'),
      PermissionNode(key: 'member_bazrasi', label: 'بازرسی'),
      PermissionNode(key: 'member_bazrasi_history', label: 'سوابق بازرسی'),
      PermissionNode(key: 'view_additional_info', label: 'اطلاعات تکمیلی'),
      PermissionNode(key: 'view_shareek', label: 'شریک'),
      PermissionNode(key: 'view_documents', label: 'مدارک'),
      PermissionNode(key: 'view_parvande', label: 'پروانه'),
      PermissionNode(key: 'view_images', label: 'تصاویر'),
      PermissionNode(key: 'edit_parvande', label: 'ویرایش'),
      PermissionNode(key: 'delete_parvande', label: 'حذف'),
      PermissionNode(key: 'view_membership_fee', label: 'حق عضویت'),
    ]),
    PermissionNode(label: 'تنظیمات (زیرمنو)', children: [
      PermissionNode(key: 'manage_users', label: 'مدیریت کاربران / سطح دسترسی'),
      PermissionNode(key: 'insert_base_data', label: 'ورود اطلاعات پایه'),
      PermissionNode(key: 'manage_personnel', label: 'تنظیم اسامی پرسنل'),
      PermissionNode(key: 'manage_union_settings', label: 'تنظیمات اتحادیه'),
      PermissionNode(key: 'data_backup', label: 'بکاپ و مدیریت اطلاعات'),
      PermissionNode(key: 'asnaf_site', label: 'سایت ایرانی اصناف'),
      PermissionNode(key: 'manage_portal', label: 'درگاه دیجیتال وب'),
    ]),
  ];

  static const List<MapEntry<String, String>> roleOptions = [
    MapEntry('raees_etehadiye', 'رئیس اتحادیه'),
    MapEntry('heyat_modire', 'هیئت مدیره'),
    MapEntry('modir_ejraei', 'مدیر اجرایی'),
    MapEntry('omoor_edari_1', 'امور اداری 1'),
    MapEntry('omoor_edari_2', 'امور اداری 2'),
    MapEntry('omoor_edari_3', 'امور اداری 3'),
    MapEntry('masool_shakayat', 'مسئول شکایات'),
    MapEntry('hesabdari', 'حسابدار'),
    MapEntry('bazrasi_1', 'بازرس 1'),
    MapEntry('bazrasi_2', 'بازرس 2'),
    MapEntry('karshenas_1', 'کارشناس 1'),
    MapEntry('karshenas_2', 'کارشناس 2'),
    MapEntry('bazrasi_karshenas_1', 'بازرس-کارشناس 1'),
    MapEntry('bazrasi_karshenas_2', 'بازرس-کارشناس 2'),
    MapEntry('moshaver', 'مشاور'),
    MapEntry('masool_taavoni', 'مسئول تعاونی'),
  ];

  static String roleLabel(String role) {
    final r = role.trim().toLowerCase();
    for (final e in roleOptions) {
      if (e.key == r) return e.value;
    }
    if (r == 'super_admin') return 'سوپرادمین';
    return role;
  }

  static const Map<String, List<String>> _permissionRoles = {
    'access_moshavere': ['super_admin', 'raees_etehadiye', 'modir_ejraei', 'moshaver', 'masool_taavoni'],
    'asnaf_site': _lead,
    'assign_pasini_cases': ['super_admin', 'modir_ejraei'],
    'bazrasi_menu': _bazrasi,
    'commission_manage': [
      'super_admin',
      'raees_etehadiye',
      'heyat_modire',
      'modir_ejraei',
      'omoor_edari_1',
      'omoor_edari_2',
      'omoor_edari_3',
      'masool_shakayat',
      'bazrasi_1',
      'bazrasi_2',
      'bazrasi_karshenas_1',
      'bazrasi_karshenas_2',
    ],
    'commission_menu': [
      'super_admin',
      'raees_etehadiye',
      'heyat_modire',
      'modir_ejraei',
      'omoor_edari_1',
      'omoor_edari_2',
      'omoor_edari_3',
      'masool_shakayat',
      'bazrasi_1',
      'bazrasi_2',
      'bazrasi_karshenas_1',
      'bazrasi_karshenas_2',
    ],
    'commission_reports': _reports,
    'create_bazrasi': _bazrasi,
    'create_parvande': [
      'super_admin',
      'raees_etehadiye',
      'heyat_modire',
      'modir_ejraei',
      'omoor_edari_1',
      'omoor_edari_2',
      'omoor_edari_3',
      'bazrasi_1',
      'bazrasi_2',
      'bazrasi_karshenas_1',
      'bazrasi_karshenas_2',
    ],
    'create_request': _office,
    'create_shekayat': [
      'super_admin',
      'modir_ejraei',
      'omoor_edari_1',
      'omoor_edari_2',
      'omoor_edari_3',
      'masool_shakayat',
    ],
    'data_backup': ['super_admin', 'raees_etehadiye'],
    'delete_parvande': ['super_admin', 'modir_ejraei'],
    'edit_parvande': ['super_admin', 'modir_ejraei', 'omoor_edari_1', 'omoor_edari_2'],
    'home_count_parvande': _staff,
    'home_count_raste': _staff,
    'home_count_update': _staff,
    'home_count_users': _staff,
    'home_slide_bazrasi_week': _bazrasi,
    'home_slide_debt': [..._reports, 'hesabdari'],
    'home_slide_members': _staff,
    'home_slide_raste': _staff,
    'home_slide_shekayat': _shekayat,
    'home_stat_debt_total': [..._reports, 'hesabdari'],
    'home_stat_expiring_month': _inspectors,
    'home_stat_inspections_month': _bazrasi,
    'home_stat_new_month': _staff,
    'insert_base_data': ['super_admin', 'raees_etehadiye'],
    'karshenas_icon': ['karshenas_1', 'karshenas_2'],
    'manage_bazrasi_forms': _lead,
    'manage_members': _staff,
    'manage_organizations': _office,
    'manage_personnel': _lead,
    'manage_portal': _lead,
    'manage_raste': _staff,
    'manage_rate_sheets': _lead,
    'manage_request_types': _office,
    'manage_requests': _office,
    'manage_settings': ['super_admin', 'raees_etehadiye'],
    'manage_shekayat': _shekayat,
    'manage_union_settings': _lead,
    'manage_users': ['super_admin', 'raees_etehadiye'],
    'member_bazrasi': _bazrasi,
    'member_bazrasi_history': [
      'super_admin',
      'raees_etehadiye',
      'heyat_modire',
      'modir_ejraei',
      'omoor_edari_1',
      'omoor_edari_2',
      'omoor_edari_3',
      'masool_shakayat',
      'bazrasi_1',
      'bazrasi_2',
      'bazrasi_karshenas_1',
      'bazrasi_karshenas_2',
    ],
    'member_create_parvande': [
      'super_admin',
      'raees_etehadiye',
      'heyat_modire',
      'modir_ejraei',
      'omoor_edari_1',
      'omoor_edari_2',
      'omoor_edari_3',
      'bazrasi_1',
      'bazrasi_2',
      'bazrasi_karshenas_1',
      'bazrasi_karshenas_2',
    ],
    'member_delete_trash': [
      'super_admin',
      'raees_etehadiye',
      'heyat_modire',
      'modir_ejraei',
      'omoor_edari_1',
      'omoor_edari_2',
      'omoor_edari_3',
      'hesabdari',
    ],
    'member_shekayat': _shekayat,
    'moshaver_icon': ['moshaver'],
    'send_shekayat_link': [
      'super_admin',
      'raees_etehadiye',
      'heyat_modire',
      'modir_ejraei',
      'omoor_edari_1',
      'omoor_edari_2',
      'omoor_edari_3',
      'masool_shakayat',
    ],
    'set_inspection_outcome': _leadAdm,
    'shek_commission': [
      'super_admin',
      'modir_ejraei',
      'omoor_edari_1',
      'omoor_edari_2',
      'omoor_edari_3',
      'masool_shakayat',
    ],
    'shek_delete_case': [
      'super_admin',
      'modir_ejraei',
      'omoor_edari_1',
      'omoor_edari_2',
      'omoor_edari_3',
      'masool_shakayat',
    ],
    'shek_documents': _shekayat,
    'shek_edit_result': [
      'super_admin',
      'modir_ejraei',
      'omoor_edari_1',
      'omoor_edari_2',
      'omoor_edari_3',
      'masool_shakayat',
    ],
    'shek_expertise': _shekayat,
    'shek_followups': [
      'super_admin',
      'raees_etehadiye',
      'heyat_modire',
      'modir_ejraei',
      'omoor_edari_1',
      'omoor_edari_2',
      'omoor_edari_3',
      'masool_shakayat',
    ],
    'shek_form': _shekayat,
    'shek_reports': _reports,
    'shek_subjects': [
      'super_admin',
      'modir_ejraei',
      'omoor_edari_1',
      'omoor_edari_2',
      'omoor_edari_3',
      'masool_shakayat',
    ],
    'shek_unit_link': [
      'super_admin',
      'modir_ejraei',
      'omoor_edari_1',
      'omoor_edari_2',
      'omoor_edari_3',
      'masool_shakayat',
    ],
    'shekayat_menu': _shekayat,
    'view_additional_info': _staff,
    'view_announcements': _lead,
    'view_bazrasi_history': [
      'super_admin',
      'raees_etehadiye',
      'heyat_modire',
      'modir_ejraei',
      'omoor_edari_1',
      'omoor_edari_2',
      'omoor_edari_3',
      'masool_shakayat',
      'bazrasi_1',
      'bazrasi_2',
      'bazrasi_karshenas_1',
      'bazrasi_karshenas_2',
    ],
    'view_benefits': _lead,
    'view_calendar': [
      'super_admin',
      'raees_etehadiye',
      'heyat_modire',
      'modir_ejraei',
      'omoor_edari_1',
      'omoor_edari_2',
      'omoor_edari_3',
      'masool_shakayat',
      'hesabdari',
      'bazrasi_1',
      'bazrasi_2',
      'bazrasi_karshenas_1',
      'bazrasi_karshenas_2',
    ],
    'view_cooperative': ['super_admin', 'raees_etehadiye', 'modir_ejraei', 'masool_taavoni'],
    'view_documents': [
      'super_admin',
      'raees_etehadiye',
      'heyat_modire',
      'modir_ejraei',
      'omoor_edari_1',
      'omoor_edari_2',
      'omoor_edari_3',
      'masool_shakayat',
    ],
    'view_education': _lead,
    'view_images': [
      'super_admin',
      'raees_etehadiye',
      'heyat_modire',
      'modir_ejraei',
      'omoor_edari_1',
      'omoor_edari_2',
      'omoor_edari_3',
      'masool_shakayat',
      'bazrasi_1',
      'bazrasi_2',
      'bazrasi_karshenas_1',
      'bazrasi_karshenas_2',
    ],
    'view_inspection_archive': _bazrasi,
    'view_license_expiry': _inspectors,
    'view_member_requests': _office,
    'view_membership_fee': [
      'super_admin',
      'raees_etehadiye',
      'heyat_modire',
      'modir_ejraei',
      'omoor_edari_1',
      'omoor_edari_2',
      'omoor_edari_3',
      'hesabdari',
      'bazrasi_1',
      'bazrasi_2',
      'bazrasi_karshenas_1',
      'bazrasi_karshenas_2',
    ],
    'view_news': _lead,
    'view_parvande': [
      'super_admin',
      'raees_etehadiye',
      'heyat_modire',
      'modir_ejraei',
      'omoor_edari_1',
      'omoor_edari_2',
      'omoor_edari_3',
      'masool_shakayat',
      'bazrasi_1',
      'bazrasi_karshenas_1',
    ],
    'view_pasini_visits': _bazrasi,
    'view_personnel_names': _lead,
    'view_price_list': _lead,
    'view_reinspect_inbox': _bazrasi,
    'view_reports': _reports,
    'view_rules': _lead,
    'view_shareek': _staff,
    'view_shekayat_history': _shekayat,
    'view_survey': _lead,
  };

  static bool roleHasPermission(String role, String key) {
    final r = role.trim().toLowerCase();
    if (r == 'super_admin') return true;
    final allowed = _permissionRoles[key];
    if (allowed == null) return false;
    return allowed.contains(r);
  }

  static Set<String> templateForRole(String role) {
    final r = role.trim().toLowerCase();
    if (r == 'super_admin') return Set<String>.from(allKeys);
    return allKeys.where((k) => roleHasPermission(r, k)).toSet();
  }

  static Set<String> normalizeSavedPermissions(Set<String> keys) {
    final out = keys.where((k) => allKeys.contains(k)).toSet();
    if (out.contains('create_parvande')) out.add('member_create_parvande');
    if (out.contains('delete_parvande')) out.add('member_delete_trash');
    if (out.contains('create_bazrasi')) {
      out.add('member_bazrasi');
      out.add('bazrasi_menu');
    }
    if (out.contains('view_bazrasi_history')) {
      out.add('member_bazrasi_history');
      out.add('bazrasi_menu');
    }
    if (out.contains('create_shekayat') ||
        out.contains('manage_shekayat') ||
        out.contains('view_shekayat_history')) {
      out.add('member_shekayat');
      out.add('shekayat_menu');
    }
    if (out.contains('manage_shekayat')) {
      out.addAll([
        'shek_form',
        'shek_subjects',
        'shek_documents',
        'shek_unit_link',
        'shek_followups',
        'shek_expertise',
        'shek_commission',
        'shek_edit_result',
        'shek_delete_case',
        'shek_reports',
      ].where(allKeys.contains));
    }
    if (out.contains('manage_settings')) {
      out.addAll([
        'manage_users',
        'insert_base_data',
        'manage_union_settings',
        'manage_bazrasi_forms',
      ].where(allKeys.contains));
    }
    if (out.contains('view_personnel_names')) out.add('manage_personnel');
    if (out.contains('view_member_requests')) {
      out.addAll([
        'manage_request_types',
        'manage_organizations',
        'manage_requests',
        'create_request',
      ]);
    }
    if (out.contains('manage_rate_sheets')) out.add('view_price_list');
    if (out.contains('commission_menu')) {
      out.addAll(['commission_manage', 'commission_reports'].where(allKeys.contains));
    }
    if (out.contains('view_reports')) {
      out.addAll([
        'commission_reports',
        'home_slide_members',
        'home_slide_debt',
        'home_slide_raste',
        'home_count_raste',
        'home_count_parvande',
        'home_count_users',
        'home_count_update',
        'home_stat_debt_total',
        'home_stat_new_month',
      ].where(allKeys.contains));
    }
    if (out.contains('bazrasi_menu') || out.contains('create_bazrasi')) {
      out.addAll([
        'view_pasini_visits',
        'view_reinspect_inbox',
        'view_inspection_archive',
        'home_slide_bazrasi_week',
        'home_stat_inspections_month',
      ].where(allKeys.contains));
    }
    if (out.contains('shekayat_menu') || out.contains('manage_shekayat')) {
      out.add('home_slide_shekayat');
    }
    if (out.contains('view_license_expiry') || out.contains('bazrasi_menu')) {
      out.add('home_stat_expiring_month');
    }
    return out.where(allKeys.contains).toSet();
  }
}
