import 'dart:convert';

import 'package:injast_admin/injast_http.dart' as http;
import 'package:injast_admin/file_management/hagh_ozviat_member_index.dart';
import 'package:injast_admin/file_management/hagh_ozviat_models.dart';
import 'package:injast_admin/file_management/excel_import/excel_import_shenase.dart';
import 'package:injast_admin/server_config.dart';

class HaghOzviatApi {
  HaghOzviatApi._();
  static final HaghOzviatApi instance = HaghOzviatApi._();

  Future<List<HaghOzviatRow>> fetchForMember({
    required String codeCo,
    required String shenaseStore,
  }) async {
    final uri = Uri.parse(
      getApiUrl(
        'select/select_hagh_ozviat/${Uri.encodeComponent(codeCo)}/${Uri.encodeComponent(shenaseStore)}',
      ),
    );
    final res = await http.get(uri).timeout(const Duration(seconds: 60));
    if (res.statusCode == 404) return const [];
    if (res.statusCode != 200) {
      throw Exception('خطا در دریافت حق عضویت (${res.statusCode})');
    }
    final body = jsonDecode(res.body);
    if (body is! List) return const [];
    return body
        .whereType<Map>()
        .map((e) {
          final m = Map<String, dynamic>.from(e);
          if ((m['shenase_store']?.toString().trim() ?? '').isEmpty) {
            m['shenase_store'] = shenaseStore;
          }
          return HaghOzviatRow.fromServerJson(m);
        })
        .where((r) => r.shenaseStore.isNotEmpty)
        .toList();
  }

  /// همهٔ ردیف‌های حق عضویت یک اتحادیه (برای گزارش‌گیری).
  Future<List<HaghOzviatRow>> fetchAllRows(String codeCo) async {
    final uri = Uri.parse(
      getApiUrl(
        'select/select_hagh_ozviat_all/${Uri.encodeComponent(codeCo)}',
      ),
    );
    final res = await http.get(uri).timeout(const Duration(seconds: 180));
    if (res.statusCode == 404) return const [];
    if (res.statusCode != 200) {
      throw Exception('خطا در دریافت گزارش حق عضویت (${res.statusCode})');
    }
    final body = jsonDecode(res.body);
    if (body is! List) return const [];
    return body
        .whereType<Map>()
        .map((e) => HaghOzviatRow.fromServerJson(Map<String, dynamic>.from(e)))
        .where((r) => r.shenaseStore.isNotEmpty)
        .toList();
  }

  /// همهٔ ردیف‌ها: ابتدا bulk؛ در صورت نبود endpoint، از index + API تک‌عضو.
  Future<List<HaghOzviatRow>> fetchAllRowsResolved(
    String codeCo, {
    void Function(int done, int total, String? shenase)? onProgress,
  }) async {
    final bulk = await fetchAllRows(codeCo);
    if (bulk.isNotEmpty) return bulk;

    final index = await fetchIndex(codeCo);
    if (index.isEmpty) return const [];

    final keys = index.entries
        .where((e) => e.value.hasRecords)
        .map((e) => e.key)
        .toList();
    if (keys.isEmpty) return const [];

    const batchSize = 10;
    final all = <HaghOzviatRow>[];
    for (var i = 0; i < keys.length; i += batchSize) {
      final batch = keys.skip(i).take(batchSize).toList();
      final parts = await Future.wait(
        batch.map(
          (k) => fetchForMember(codeCo: codeCo, shenaseStore: k),
        ),
      );
      for (final part in parts) {
        all.addAll(part);
      }
      onProgress?.call(
        (i + batch.length).clamp(0, keys.length),
        keys.length,
        batch.isEmpty ? null : batch.last,
      );
    }
    return all;
  }

  /// خلاصهٔ حق عضویت همهٔ اعضای یک اتحادیه (برای کارت‌های پرونده).
  Future<Map<String, HaghOzviatMemberIndex>> fetchIndex(String codeCo) async {
    final uri = Uri.parse(
      getApiUrl(
        'select/select_hagh_ozviat_index/${Uri.encodeComponent(codeCo)}',
      ),
    );
    final res = await http.get(uri).timeout(const Duration(seconds: 120));
    if (res.statusCode == 404) return const {};
    if (res.statusCode != 200) {
      return const {};
    }
    final body = jsonDecode(res.body);
    if (body is! List) return const {};

    final map = <String, HaghOzviatMemberIndex>{};
    for (final item in body) {
      if (item is! Map) continue;
      final idx = HaghOzviatMemberIndex.fromJson(
        Map<String, dynamic>.from(item),
      );
      final key = ExcelImportShenase.normalize(idx.shenaseStore);
      if (key.isEmpty) continue;
      map[key] = idx;
    }
    return map;
  }

  Future<HaghOzviatMemberSummary> fetchSummary({
    required String codeCo,
    required String shenaseStore,
  }) async {
    final rows = await fetchForMember(codeCo: codeCo, shenaseStore: shenaseStore);
    var pending = 0;
    var confirmed = 0;
    for (final r in rows) {
      if (r.isPending) pending += r.mablaghRial;
      if (r.isConfirmed) confirmed += r.mablaghRial;
    }
    return HaghOzviatMemberSummary(
      rows: rows,
      pendingRial: pending,
      confirmedRial: confirmed,
    );
  }

  Future<HaghOzviatSyncResult> syncReplaceAll({
    required String codeCo,
    required List<HaghOzviatRow> rows,
    void Function(HaghOzviatSyncProgress progress)? onProgress,
  }) async {
    if (rows.isEmpty) {
      return const HaghOzviatSyncResult(
        membersReplaced: 0,
        rowsInserted: 0,
        errors: [],
      );
    }

    final byMember = <String, List<HaghOzviatRow>>{};
    for (final r in rows) {
      byMember.putIfAbsent(r.shenaseStore, () => []).add(r);
    }

    final memberEntries = byMember.entries.toList();
    var membersReplaced = 0;
    var rowsInserted = 0;
    final errors = <String>[];
    final totalMembers = memberEntries.length;
    const membersPerRequest = 40;

    for (var i = 0; i < totalMembers; i += membersPerRequest) {
      final slice = memberEntries.skip(i).take(membersPerRequest).toList();
      final records = <HaghOzviatRow>[
        for (final e in slice) ...e.value,
      ];
      final done = (i + slice.length).clamp(1, totalMembers);
      onProgress?.call(
        HaghOzviatSyncProgress(
          message: 'اعضا $done از $totalMembers…',
          current: done,
          total: totalMembers,
        ),
      );

      try {
        final part = await _postSyncBatch(
          codeCo: codeCo,
          records: records,
        );
        membersReplaced += part.membersReplaced;
        rowsInserted += part.rowsInserted;
        errors.addAll(part.errors);
      } catch (e) {
        errors.add('دسته از عضو ${slice.first.key}: ${_friendlyError(e)}');
      }
    }

    return HaghOzviatSyncResult(
      membersReplaced: membersReplaced,
      rowsInserted: rowsInserted,
      errors: errors,
    );
  }

  Future<HaghOzviatSyncResult> _postSyncBatch({
    required String codeCo,
    required List<HaghOzviatRow> records,
  }) async {
    final uri = Uri.parse(getApiUrl('insert/hagh_ozviat/sync'));
    final body = jsonEncode({
      'code_co': codeCo,
      'records': records.map((e) => e.toSyncJson()).toList(),
    });

    http.Response? res;
    Object? lastError;
    for (var attempt = 0; attempt < 6; attempt++) {
      try {
        res = await http
            .post(
              uri,
              headers: {
                'Content-Type': 'application/json',
                'Content-Length': utf8.encode(body).length.toString(),
              },
              body: body,
            )
            .timeout(const Duration(minutes: 2));
        if (res.statusCode != 429 &&
            !res.body.contains('تعداد درخواست‌ها بیش از حد مجاز است')) {
          break;
        }
        lastError = Exception(_parseHttpError(res.statusCode, res.body));
      } catch (e) {
        lastError = e;
        final s = e.toString();
        if (!s.contains('429') && !s.contains('حد مجاز')) rethrow;
      }
      await Future<void>.delayed(Duration(seconds: 2 + attempt * 2));
    }
    if (res == null) {
      throw lastError ?? Exception('خطا در همگام‌سازی حق عضویت');
    }

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(_parseHttpError(res.statusCode, res.body));
    }

    final decoded = jsonDecode(res.body);
    if (decoded is! Map) {
      throw Exception('پاسخ نامعتبر از سرور');
    }
    if (decoded['ok'] == false) {
      throw Exception(decoded['error']?.toString() ?? 'همگام‌سازی ناموفق');
    }

    final errList = decoded['errors'];
    final errors = <String>[];
    if (errList is List) {
      for (final e in errList) {
        final t = e?.toString().trim() ?? '';
        if (t.isNotEmpty) errors.add(t);
      }
    }

    return HaghOzviatSyncResult(
      membersReplaced: _toInt(decoded['members_replaced']),
      rowsInserted: _toInt(decoded['rows_inserted']),
      errors: errors,
    );
  }

  static int _toInt(dynamic v) => int.tryParse(v?.toString() ?? '') ?? 0;

  static String _friendlyError(Object e) {
    final s = e.toString();
    if (s.contains('PayloadTooLarge') || s.contains('entity too large')) {
      return 'حجم درخواست برای سرور زیاد است — app_dd.js را به‌روز و Node را ری‌استارت کنید.';
    }
    if (s.length > 280) return '${s.substring(0, 280)}…';
    return s;
  }

  static String _parseHttpError(int status, String body) {
    final t = body.trim();
    if (t.contains('PayloadTooLargeError') || t.contains('entity too large')) {
      return 'PayloadTooLarge: فایل C:\\api_new\\new_backend\\api\\app_dd.js را '
          'از پروژه کپی کنید (JSON_BODY_LIMIT=100mb) و node start.js را دوباره بزنید.';
    }
    if (t.startsWith('<!DOCTYPE') || t.startsWith('<html')) {
      return 'خطای سرور ($status). API حق عضویت deploy نشده یا جدول ساخته نشده.';
    }
    if (t.isNotEmpty) return t.length > 400 ? '${t.substring(0, 400)}…' : t;
    return 'خطا در همگام‌سازی حق عضویت ($status)';
  }
}
