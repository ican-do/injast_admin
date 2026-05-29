import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// ذخیرهٔ محلی سوابق بازرسی برای حالت آفلاین
class BazrasiLocalStore {
  BazrasiLocalStore(this.codeCo);

  final String codeCo;
  static const _uuid = Uuid();

  String get _recordsKey => 'bazrasi_local_v1_$codeCo';
  String _deletedKey(String idParvandeh) => 'bazrasi_del_v1_${codeCo}_$idParvandeh';

  Future<List<Map<String, dynamic>>> readForParvande(String idParvandeh) async {
    final all = await _readAll();
    return all
        .where((e) => e['id_parvandeh']?.toString() == idParvandeh)
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<List<Map<String, dynamic>>> mergeWithServer(
    String idParvandeh,
    List<Map<String, dynamic>> serverRows,
  ) async {
    final deletedIds = await _deletedServerIds(idParvandeh);
    final merged = serverRows
        .where((r) => !deletedIds.contains(r['id_bazrasi']?.toString()))
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    for (final l in await readForParvande(idParvandeh)) {
      if (l['_deleted'] == true) continue;
      final dup = merged.any((r) {
        if (r['id_bazrasi']?.toString() == l['id_bazrasi']?.toString()) return true;
        return r['shenase_bazrasi']?.toString() == l['shenase_bazrasi']?.toString() &&
            r['date_sodor']?.toString() == l['date_sodor']?.toString();
      });
      if (dup) continue;
      merged.add(l);
    }
    return merged;
  }

  Future<void> addPending(Map<String, dynamic> record) async {
    final all = await _readAll();
    all.add({
      ...record,
      '_local_only': true,
      '_pending': true,
    });
    await _writeAll(all);
  }

  /// رکورد آنلاین ثبت‌شده — برای نمایش فوری تا fetch بعدی
  Future<void> addCached(Map<String, dynamic> record) async {
    final all = await _readAll();
    all.removeWhere((e) =>
        e['shenase_bazrasi']?.toString() == record['shenase_bazrasi']?.toString() &&
        e['date_sodor']?.toString() == record['date_sodor']?.toString());
    all.add({
      ...record,
      '_local_only': false,
      '_pending': false,
    });
    await _writeAll(all);
  }

  Future<void> markDeleted(String idParvandeh, String idBazrasi, {required bool isLocalOnly}) async {
    if (isLocalOnly) {
      final all = await _readAll();
      all.removeWhere((e) => e['id_bazrasi']?.toString() == idBazrasi);
      await _writeAll(all);
      return;
    }
    final ids = await _deletedServerIds(idParvandeh);
    ids.add(idBazrasi);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_deletedKey(idParvandeh), jsonEncode(ids.toList()));
  }

  Future<void> updateLocal(String idParvandeh, String idBazrasi, Map<String, dynamic> patch) async {
    final all = await _readAll();
    final idx = all.indexWhere((e) => e['id_bazrasi']?.toString() == idBazrasi);
    if (idx >= 0) {
      all[idx] = {...all[idx], ...patch, '_pending': true};
    } else {
      all.add({
        ...patch,
        'id_parvandeh': idParvandeh,
        'id_bazrasi': idBazrasi,
        '_pending': true,
        '_local_only': true,
      });
    }
    await _writeAll(all);
  }

  String newLocalId() => 'local_${_uuid.v4()}';

  Future<List<Map<String, dynamic>>> _readAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_recordsKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _writeAll(List<Map<String, dynamic>> rows) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_recordsKey, jsonEncode(rows));
  }

  Future<Set<String>> _deletedServerIds(String idParvandeh) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_deletedKey(idParvandeh));
    if (raw == null) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return {};
      return decoded.map((e) => e.toString()).toSet();
    } catch (_) {
      return {};
    }
  }
}
