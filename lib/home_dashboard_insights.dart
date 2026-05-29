import 'dart:async';
import 'dart:convert';

import 'package:injast_admin/file_management/parvande_api.dart';
import 'package:injast_admin/file_management/parvande_bazrasi_api.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomeDashboardInsights {
  const HomeDashboardInsights({
    required this.totalMembers,
    required this.activeMembers,
    required this.inactiveMembers,
    required this.totalDebt,
    required this.debtorMembers,
    required this.newMembersThisMonth,
    required this.inspectionsThisMonth,
    required this.expiringThisMonth,
    required this.withLocationCount,
  });

  final int totalMembers;
  final int activeMembers;
  final int inactiveMembers;
  final double totalDebt;
  final int debtorMembers;
  final int newMembersThisMonth;
  final int? inspectionsThisMonth;
  final int expiringThisMonth;
  final int withLocationCount;

  Map<String, dynamic> toJson() => {
        'totalMembers': totalMembers,
        'activeMembers': activeMembers,
        'inactiveMembers': inactiveMembers,
        'totalDebt': totalDebt,
        'debtorMembers': debtorMembers,
        'newMembersThisMonth': newMembersThisMonth,
        'inspectionsThisMonth': inspectionsThisMonth,
        'expiringThisMonth': expiringThisMonth,
        'withLocationCount': withLocationCount,
      };

  factory HomeDashboardInsights.fromJson(Map<String, dynamic> json) {
    return HomeDashboardInsights(
      totalMembers: (json['totalMembers'] as num?)?.toInt() ?? 0,
      activeMembers: (json['activeMembers'] as num?)?.toInt() ?? 0,
      inactiveMembers: (json['inactiveMembers'] as num?)?.toInt() ?? 0,
      totalDebt: (json['totalDebt'] as num?)?.toDouble() ?? 0,
      debtorMembers: (json['debtorMembers'] as num?)?.toInt() ?? 0,
      newMembersThisMonth: (json['newMembersThisMonth'] as num?)?.toInt() ?? 0,
      inspectionsThisMonth: (json['inspectionsThisMonth'] as num?)?.toInt(),
      expiringThisMonth: (json['expiringThisMonth'] as num?)?.toInt() ?? 0,
      withLocationCount: (json['withLocationCount'] as num?)?.toInt() ?? 0,
    );
  }

  factory HomeDashboardInsights.fallback({
    required Map<String, dynamic>? memberStats,
  }) {
    final total = int.tryParse('${memberStats?['total_members'] ?? 0}') ?? 0;
    final active = int.tryParse('${memberStats?['active_members'] ?? 0}') ?? 0;
    final inactive =
        int.tryParse('${memberStats?['inactive_members'] ?? 0}') ?? 0;
    return HomeDashboardInsights(
      totalMembers: total,
      activeMembers: active,
      inactiveMembers: inactive,
      totalDebt: 0,
      debtorMembers: 0,
      newMembersThisMonth: 0,
      inspectionsThisMonth: null,
      expiringThisMonth: 0,
      withLocationCount: 0,
    );
  }
}

class HomeDashboardInsightsLoader {
  HomeDashboardInsightsLoader._();

  static const _cacheAge = Duration(minutes: 20);
  static const _storagePrefix = 'home_dashboard_insights_v2_';
  static final _cache = <String, ({DateTime at, HomeDashboardInsights data})>{};

  static Future<HomeDashboardInsights> load({
    required String codeCo,
    Map<String, dynamic>? memberStats,
  }) async {
    final now = DateTime.now();
    final cached = _cache[codeCo];
    if (cached != null && now.difference(cached.at) < _cacheAge) {
      return cached.data;
    }

    final stored = await _readStored(codeCo, now);
    if (stored != null) {
      _cache[codeCo] = (at: now, data: stored);
      return stored;
    }

    final rows = await ParvandeApi.instance.fetchAll(codeCo);
    final activeRows = rows.where((e) => !e.isTrash).toList();
    final total =
        int.tryParse('${memberStats?['total_members'] ?? activeRows.length}') ??
            activeRows.length;
    final active = int.tryParse(
            '${memberStats?['active_members'] ?? activeRows.length}') ??
        activeRows.length;
    final inactive =
        int.tryParse('${memberStats?['inactive_members'] ?? 0}') ?? 0;

    double totalDebt = 0;
    var debtorMembers = 0;
    var newMembersThisMonth = 0;
    var expiringThisMonth = 0;
    var withLocationCount = 0;

    for (final row in activeRows) {
      final money = _moneyValue(row.s('money'));
      totalDebt += money;
      if (money > 0) debtorMembers++;
      if (row.hasLocation) withLocationCount++;
      if (_isInCurrentMonth(
          _tryParseServerDate(row.s('date_sodor_store')), now)) {
        newMembersThisMonth++;
      }
      if (_isInCurrentMonth(
          _tryParseServerDate(row.s('date_exp_store')), now)) {
        expiringThisMonth++;
      }
    }

    final inspectionsThisMonth =
        await _countInspectionsThisMonth(activeRows, now: now);

    final data = HomeDashboardInsights(
      totalMembers: total,
      activeMembers: active,
      inactiveMembers: inactive,
      totalDebt: totalDebt,
      debtorMembers: debtorMembers,
      newMembersThisMonth: newMembersThisMonth,
      inspectionsThisMonth: inspectionsThisMonth,
      expiringThisMonth: expiringThisMonth,
      withLocationCount: withLocationCount,
    );
    _cache[codeCo] = (at: now, data: data);
    await _writeStored(codeCo, now, data);
    return data;
  }

  static Future<int> _countInspectionsThisMonth(
    List<Map<String, dynamic>> rows, {
    required DateTime now,
  }) async {
    final ids =
        rows.map((e) => e.idParvandeh).where((e) => e.isNotEmpty).toList();
    if (ids.isEmpty) return 0;

    const batchSize = 8;
    var total = 0;

    for (var i = 0; i < ids.length; i += batchSize) {
      final batch = ids.skip(i).take(batchSize).toList();
      final results = await Future.wait(
        batch.map((id) async {
          try {
            return await ParvandeBazrasiApi.instance
                .fetchByParvande(id, silent: true)
                .timeout(const Duration(seconds: 12),
                    onTimeout: () => const []);
          } catch (_) {
            return const <Map<String, dynamic>>[];
          }
        }),
      );
      for (final items in results) {
        for (final item in items) {
          if (_isInCurrentMonth(
              _tryParseServerDate(item['date_sodor']?.toString()), now)) {
            total++;
          }
        }
      }
    }

    return total;
  }

  static Future<HomeDashboardInsights?> _readStored(
    String codeCo,
    DateTime now,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_storagePrefix$codeCo');
    if (raw == null || raw.isEmpty) return null;
    try {
      final json = jsonDecode(raw);
      if (json is! Map<String, dynamic>) return null;
      final stamp = DateTime.tryParse(json['storedAt']?.toString() ?? '');
      final monthKey = json['monthKey']?.toString() ?? '';
      if (stamp == null ||
          now.difference(stamp) > _cacheAge ||
          monthKey != _monthKey(now)) {
        return null;
      }
      final payload = json['data'];
      if (payload is! Map<String, dynamic>) return null;
      return HomeDashboardInsights.fromJson(payload);
    } catch (_) {
      return null;
    }
  }

  static Future<void> _writeStored(
    String codeCo,
    DateTime now,
    HomeDashboardInsights data,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '$_storagePrefix$codeCo',
      jsonEncode({
        'storedAt': now.toIso8601String(),
        'monthKey': _monthKey(now),
        'data': data.toJson(),
      }),
    );
  }

  static String _monthKey(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}';

  static DateTime? _tryParseServerDate(String? raw) {
    final value = (raw ?? '').trim();
    if (value.isEmpty || value.toLowerCase() == 'null') return null;
    final normalized = value.replaceAll('/', '-').split(' ').first.trim();
    final parts = normalized.split('-');
    if (parts.length != 3) return null;
    final y = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final d = int.tryParse(parts[2]);
    if (y == null || m == null || d == null) return null;
    return DateTime(y, m, d);
  }

  static bool _isInCurrentMonth(DateTime? dt, DateTime now) =>
      dt != null && dt.year == now.year && dt.month == now.month;

  static double _moneyValue(String raw) {
    final normalized = raw.replaceAll(',', '').trim();
    if (normalized.isEmpty || normalized.toLowerCase() == 'null') return 0;
    return double.tryParse(normalized) ?? 0;
  }
}
