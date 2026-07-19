import 'package:injast_admin/features/shekayat/compat/class_controler.dart';
import 'package:injast_admin/features/shekayat/shekayat_api.dart';
import 'package:injast_admin/features/shekayat/shekayat_constants.dart';
import 'package:shamsi_date/shamsi_date.dart';

class ShekayatReportFilters {
  DateTime? startDate;
  DateTime? endDate;
  String? status;
  String? type;
  String? source;
  String? category;
  String? result;
  String? linkedUnit; // همه | متصل | بدون اتصال

  bool get hasActive =>
      startDate != null ||
      endDate != null ||
      (status != null && status!.isNotEmpty && status != 'همه') ||
      (type != null && type!.isNotEmpty && type != 'همه') ||
      (source != null && source!.isNotEmpty && source != 'همه') ||
      (category != null && category!.isNotEmpty && category != 'همه') ||
      (result != null && result!.isNotEmpty && result != 'همه') ||
      (linkedUnit != null && linkedUnit!.isNotEmpty && linkedUnit != 'همه');
}

class ShekayatReportDate {
  static const _monthNames = {
    'فروردین': 1,
    'اردیبهشت': 2,
    'خرداد': 3,
    'تیر': 4,
    'مرداد': 5,
    'شهریور': 6,
    'مهر': 7,
    'آبان': 8,
    'آذر': 9,
    'دی': 10,
    'بهمن': 11,
    'اسفند': 12,
  };

  static String toEnDigits(String input) {
    const fa = '۰۱۲۳۴۵۶۷۸۹';
    const ar = '٠١٢٣٤٥٦٧٨٩';
    var out = input;
    for (var i = 0; i < 10; i++) {
      out = out.replaceAll(fa[i], '$i').replaceAll(ar[i], '$i');
    }
    return out;
  }

  static DateTime? parse(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final text = toEnDigits(raw.trim());

    final slash = RegExp(r'(\d{4})[/-](\d{1,2})[/-](\d{1,2})');
    final slashMatch = slash.firstMatch(text);
    if (slashMatch != null) {
      return _jalaliToDateTime(
        int.parse(slashMatch.group(1)!),
        int.parse(slashMatch.group(2)!),
        int.parse(slashMatch.group(3)!),
      );
    }

    final dash = RegExp(r'(\d{4})-(\d{1,2})-(\d{1,2})');
    final dashMatch = dash.firstMatch(text);
    if (dashMatch != null) {
      final y = int.parse(dashMatch.group(1)!);
      final m = int.parse(dashMatch.group(2)!);
      final d = int.parse(dashMatch.group(3)!);
      if (y > 1300) {
        return _jalaliToDateTime(y, m, d);
      }
      return DateTime(y, m, d);
    }

    final persian = RegExp(r'(\d{1,2})\s+(\S+)\s+(\d{4})');
    final persianMatch = persian.firstMatch(text);
    if (persianMatch != null) {
      final day = int.parse(persianMatch.group(1)!);
      final monthName = persianMatch.group(2)!;
      final year = int.parse(persianMatch.group(3)!);
      final month = _monthNames[monthName];
      if (month != null) return _jalaliToDateTime(year, month, day);
    }

    if (text.startsWith('SK')) {
      final ts = int.tryParse(text.substring(2));
      if (ts != null && ts > 1000000000000) {
        return DateTime.fromMillisecondsSinceEpoch(ts);
      }
    }
    return null;
  }

  static DateTime? _jalaliToDateTime(int y, int m, int d) {
    try {
      final g = Jalali(y, m, d).toGregorian();
      return DateTime(g.year, g.month, g.day);
    } catch (_) {
      return null;
    }
  }

  static String monthKey(String? raw) {
    final dt = parse(raw);
    if (dt == null) return 'نامشخص';
    final j = Gregorian(dt.year, dt.month, dt.day).toJalali();
    return '${j.year}/${j.month.toString().padLeft(2, '0')}';
  }

  static String monthLabel(String key) {
    if (key == 'نامشخص') return key;
    final parts = key.split('/');
    if (parts.length != 2) return key;
    const names = [
      '', 'فروردین', 'اردیبهشت', 'خرداد', 'تیر', 'مرداد', 'شهریور',
      'مهر', 'آبان', 'آذر', 'دی', 'بهمن', 'اسفند',
    ];
    final m = int.tryParse(parts[1]) ?? 0;
    return '${names[m]} ${parts[0]}';
  }
}

class ShekayatReportService {
  static Future<List<dynamic>> loadAll(String codeCo) async {
    return ShekayatApi.listComplaints(codeCo);
  }

  static Future<List<dynamic>> loadCategories(String codeCo) async {
    return ShekayatApi.getCategories(codeCo);
  }

  static List<dynamic> applyFilters(List<dynamic> items, ShekayatReportFilters f) {
    return items.where((item) {
      final map = item as Map;
      if (f.status != null && f.status!.isNotEmpty && f.status != 'همه') {
        if ((map['status_shekayat']?.toString() ?? '') != f.status) return false;
      }
      if (f.type != null && f.type!.isNotEmpty && f.type != 'همه') {
        if ((map['type_shekayat']?.toString() ?? '') != f.type) return false;
      }
      if (f.source != null && f.source!.isNotEmpty && f.source != 'همه') {
        if ((map['source_shekayat']?.toString() ?? '') != f.source) return false;
      }
      if (f.category != null && f.category!.isNotEmpty && f.category != 'همه') {
        final cat = map['category_name']?.toString() ?? 'بدون موضوع';
        if (cat != f.category) return false;
      }
      if (f.result != null && f.result!.isNotEmpty && f.result != 'همه') {
        final res = map['result_shekayat']?.toString() ?? 'بدون نتیجه';
        if (res != f.result) return false;
      }
      if (f.linkedUnit != null && f.linkedUnit!.isNotEmpty && f.linkedUnit != 'همه') {
        final id = map['id_store']?.toString() ?? '0';
        final linked = id != '0' && id.isNotEmpty;
        if (f.linkedUnit == 'متصل' && !linked) return false;
        if (f.linkedUnit == 'بدون اتصال' && linked) return false;
      }
      if (f.startDate != null || f.endDate != null) {
        final dt = ShekayatReportDate.parse(map['date_shekayat']?.toString());
        if (dt == null) return false;
        if (f.startDate != null) {
          final s = DateTime(f.startDate!.year, f.startDate!.month, f.startDate!.day);
          if (dt.isBefore(s)) return false;
        }
        if (f.endDate != null) {
          final e = DateTime(f.endDate!.year, f.endDate!.month, f.endDate!.day, 23, 59, 59);
          if (dt.isAfter(e)) return false;
        }
      }
      return true;
    }).toList();
  }

  static Map<String, int> countByField(List<dynamic> items, String field, {String Function(dynamic)? label}) {
    final map = <String, int>{};
    for (final item in items) {
      final m = item as Map;
      var key = m[field]?.toString().trim();
      if (key == null || key.isEmpty) key = 'نامشخص';
      if (label != null) key = label(m[field]);
      map[key] = (map[key] ?? 0) + 1;
    }
    return map;
  }

  static Map<String, int> countByStatus(List<dynamic> items) =>
      countByField(items, 'status_shekayat');

  static Map<String, int> countByType(List<dynamic> items) {
    return countByField(items, 'type_shekayat', label: (v) => ShekayatConstants.typeLabel(v?.toString()));
  }

  static Map<String, int> countBySource(List<dynamic> items) =>
      countByField(items, 'source_shekayat');

  static Map<String, int> countByCategory(List<dynamic> items) {
    final map = <String, int>{};
    for (final item in items) {
      final m = item as Map;
      final names = m['category_names'];
      if (names is List && names.isNotEmpty) {
        for (final n in names) {
          final key = n?.toString().trim();
          if (key != null && key.isNotEmpty) map[key] = (map[key] ?? 0) + 1;
        }
        continue;
      }
      final single = m['category_name']?.toString().trim();
      final key = (single == null || single.isEmpty) ? 'بدون موضوع' : single;
      map[key] = (map[key] ?? 0) + 1;
    }
    return map;
  }

  static Map<String, int> countByResult(List<dynamic> items) {
    return countByField(items, 'result_shekayat', label: (v) {
      final s = v?.toString().trim();
      return (s == null || s.isEmpty) ? 'بدون نتیجه' : s;
    });
  }

  static Map<String, int> countByMonth(List<dynamic> items) {
    final map = <String, int>{};
    for (final item in items) {
      final key = ShekayatReportDate.monthKey((item as Map)['date_shekayat']?.toString());
      map[key] = (map[key] ?? 0) + 1;
    }
    final keys = map.keys.toList()
      ..sort((a, b) {
        if (a == 'نامشخص') return 1;
        if (b == 'نامشخص') return -1;
        return a.compareTo(b);
      });
    return {for (final k in keys) k: map[k]!};
  }

  static Map<String, int> countByExpert(List<dynamic> items) {
    return countByField(items, 'last_expert_name', label: (v) {
      final s = v?.toString().trim();
      return (s == null || s.isEmpty) ? 'بدون کارشناس' : s;
    });
  }

  static Map<String, int> countByUnit(List<dynamic> items) {
    final map = <String, int>{};
    for (final item in items) {
      final m = item as Map;
      final id = m['id_store']?.toString() ?? '0';
      if (id == '0' || id.isEmpty) continue;
      final name = m['linked_parvandeh_name']?.toString().trim().isNotEmpty == true
          ? m['linked_parvandeh_name'].toString()
          : (m['name_store']?.toString().trim().isNotEmpty == true
              ? m['name_store'].toString()
              : 'واحد $id');
      map[name] = (map[name] ?? 0) + 1;
    }
    final sorted = map.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return Map.fromEntries(sorted.take(15));
  }

  static Map<String, dynamic> summaryStats(List<dynamic> items) {
    final total = items.length;
    var closed = 0;
    var withExpert = 0;
    var withUnit = 0;
    var withDocs = 0;
    double totalDamage = 0;
    var damageCount = 0;

    for (final item in items) {
      final m = item as Map;
      final status = m['status_shekayat']?.toString() ?? '';
      if (status.contains('مختومه')) closed++;
      if ((m['last_expert_name']?.toString().trim().isNotEmpty ?? false)) withExpert++;
      final id = m['id_store']?.toString() ?? '0';
      if (id != '0' && id.isNotEmpty) withUnit++;
      final counts = m['attachment_counts'];
      if (counts is Map) {
        final sum = (counts['complainant'] ?? 0) + (counts['expert'] ?? 0) + (counts['officer'] ?? 0);
        if (sum > 0) withDocs++;
      }
      final dmg = double.tryParse(m['last_damage']?.toString().replaceAll(',', '') ?? '');
      if (dmg != null && dmg > 0) {
        totalDamage += dmg;
        damageCount++;
      }
    }

    return {
      'total': total,
      'open': total - closed,
      'closed': closed,
      'closure_rate': total > 0 ? (closed / total * 100) : 0.0,
      'with_expert': withExpert,
      'with_unit': withUnit,
      'with_docs': withDocs,
      'avg_damage': damageCount > 0 ? totalDamage / damageCount : 0.0,
      'total_damage': totalDamage,
    };
  }

  static String formatFilterDate(DateTime? d) =>
      d == null ? '' : convert_date_persian2(d);
}
