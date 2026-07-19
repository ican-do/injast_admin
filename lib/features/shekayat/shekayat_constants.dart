import 'package:flutter/material.dart';

/// رنگ اصلی سامانه شکایات (مطابق ماکاپ)
class ShekayatTheme {
  static const Color primary = Color(0xFF008CA7);
  static const Color primaryDark = Color(0xFF006B80);
  static const Color accentGreen = Color(0xFF4CAF50);
  static const Color accentYellow = Color(0xFFFFC107);
  static const Color accentOrange = Color(0xFFFF9800);
  static const Color accentRed = Color(0xFFE53935);
  static const Color accentCyan = Color(0xFF00BCD4);
  static const Color accentPurple = Color(0xFF7B1FA2);
  static const Color cardBg = Color(0xFFF5F5F5);
}

class ShekayatConstants {
  static const List<Map<String, String>> types = [
    {'value': '1', 'label': 'شکایت مشتری از واحد صنفی'},
    {'value': '2', 'label': 'شکایت واحد صنفی از مشتری'},
    {'value': '3', 'label': 'شکایت واحد صنفی از واحد صنفی (همکار از همکار)'},
  ];

  static const List<String> statusTabs = [
    'ثبت اولیه',
    'در حال بررسی',
    'ارجاع به کارشناس',
    'کارشناسی',
    'کارشناسی مجدد',
    'جلسه کمیسیون',
    'ارجاع به مرجع بالاتر',
    'مختومه',
  ];

  static const List<String> statuses = [
    'ثبت اولیه',
    'در حال بررسی',
    'ارجاع به کارشناس',
    'کارشناسی',
    'کارشناسی مجدد',
    'جلسه کمیسیون',
    'ارجاع به مرجع بالاتر',
    'مختومه',
  ];

  static const List<String> statusFilters = [
    'همه',
    'بررسی',
    'کارشناسی',
    'کارشناسی مجدد',
  ];

  static const List<String> sources = [
    'اتحادیه',
    'اتاق اصناف',
    'بخشداری',
    'اداره صمت',
    'اماکن',
    'سامانه 124',
    'سامانه سیمبا',
  ];

  static const List<String> results = [
    'رضایت طرفین',
    'توافق',
    'عدم توافق',
    'عدم پیگیری شاکی',
    'ارجاع به مرجع بالاتر',
    'مختومه',
  ];

  static const int maxComplainantDocs = 5;
  static const int maxExpertDocs = 3;
  static const int maxOfficerDocs = 3;

  static String typeLabel(String? v) {
    return types.firstWhere(
      (e) => e['value'] == v,
      orElse: () => types.first,
    )['label']!;
  }

  static Color statusColor(String status) {
    if (status.contains('مختومه')) return Colors.green.shade700;
    if (status.contains('کارشناس')) return Colors.blue.shade700;
    if (status.contains('کمیسیون')) return Colors.purple.shade700;
    if (status.contains('بررسی')) return Colors.orange.shade700;
    return ShekayatTheme.primary;
  }

  static Color resultColor(String? result) {
    final r = result?.trim() ?? '';
    if (r.isEmpty) return Colors.grey.shade600;
    if (r.contains('رضایت') || r.contains('توافق')) return const Color(0xFF2E7D32);
    if (r.contains('عدم توافق')) return const Color(0xFFC62828);
    if (r.contains('عدم پیگیری')) return const Color(0xFFEF6C00);
    if (r.contains('ارجاع')) return const Color(0xFF6A1B9A);
    if (r.contains('مختومه')) return const Color(0xFF00695C);
    return ShekayatTheme.primaryDark;
  }

  static IconData resultIcon(String? result) {
    final r = result?.trim() ?? '';
    if (r.contains('رضایت') || r.contains('توافق')) return Icons.check_circle;
    if (r.contains('عدم توافق')) return Icons.cancel;
    if (r.contains('عدم پیگیری')) return Icons.pause_circle;
    if (r.isNotEmpty) return Icons.gavel;
    return Icons.help_outline;
  }
}
