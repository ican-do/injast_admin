import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:injast_admin/import_sync/import_models.dart';
import 'package:injast_admin/local_cache/content_hash.dart';
import 'package:injast_admin/local_cache/local_cache_paths.dart';
import 'package:injast_admin/local_cache/local_image_store.dart';
import 'package:injast_admin/local_cache/parvande_local_db.dart';
import 'package:injast_admin/local_cache/sync_status.dart';

/// مخزن محلی پرونده‌های یک اتحادیه (SQLite + مهاجرت از SharedPreferences).
class ParvandeLocalRepository {
  ParvandeLocalRepository._();
  static final ParvandeLocalRepository instance = ParvandeLocalRepository._();

  static const _legacyDraftKey = 'import_sync_draft_records_v1';
  static const _legacyMigratedPrefix = 'asnaf_sqlite_migrated_v1_';

  final _db = ParvandeLocalDb.instance;
  final _images = LocalImageStore.instance;

  Future<void> ensureMigrated(String codeCo) async {
    if (kIsWeb) return;
    final prefs = await SharedPreferences.getInstance();
    final flag = '${_legacyMigratedPrefix}_$codeCo';
    if (prefs.getBool(flag) == true) return;

    final raw = prefs.getString(_legacyDraftKey);
    if (raw != null && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          for (final e in decoded) {
            if (e is! Map) continue;
            final record =
                ImportDraftRecord.fromJson(Map<String, dynamic>.from(e));
            final co = record.payload['code_co']?.trim() ?? '';
            if (co.isEmpty || co == codeCo) {
              await upsertFromImportRecord(codeCo: codeCo, record: record);
            }
          }
        }
      } catch (_) {}
    }
    await prefs.setBool(flag, true);
  }

  /// ذخیره یا بروزرسانی پرونده؛ در صورت تغییر محتوا پس از sync → dirty.
  Future<UpsertResult> upsertFromImportRecord({
    required String codeCo,
    required ImportDraftRecord record,
    bool downloadImages = true,
    bool fastMode = false,
  }) async {
    if (kIsWeb) {
      return _upsertWeb(codeCo, record);
    }

    final id = record.clientTempId.isNotEmpty
        ? record.clientTempId
        : (record.payload['id_parvandeh'] ?? '');
    if (id.isEmpty) return UpsertResult.skipped;

    final payload = Map<String, String>.from(record.payload);
    payload['code_co'] = codeCo;
    payload['id_parvandeh'] = id;

    final hash = computePayloadContentHash(payload);
    final now = DateTime.now().millisecondsSinceEpoch;
    final existing = await _db.getRow(codeCo, id);

    ParvandeSyncStatus newStatus;
    if (existing == null) {
      newStatus = ParvandeSyncStatus.local;
    } else if (existing.contentHash == hash) {
      newStatus = existing.syncStatus;
      if (newStatus == ParvandeSyncStatus.synced) {
        return UpsertResult.unchanged;
      }
    } else {
      newStatus = existing.syncStatus == ParvandeSyncStatus.synced
          ? ParvandeSyncStatus.dirty
          : ParvandeSyncStatus.local;
    }

    final row = ParvandeLocalRow(
      idParvandeh: id,
      codeCo: codeCo,
      clientTempId: record.clientTempId,
      payloadJson: jsonEncode(payload),
      contentHash: hash,
      syncStatus: newStatus,
      lastFetchedAt: now,
      lastSyncedAt: existing?.lastSyncedAt,
    );
    await _db.upsertParvande(row);

    if (downloadImages) {
      await _images.syncAllMediaForPayload(
        codeCo: codeCo,
        idParvandeh: id,
        payload: payload,
        fastMode: fastMode,
      );
    }

    return existing == null
        ? UpsertResult.inserted
        : (newStatus == ParvandeSyncStatus.dirty
            ? UpsertResult.updatedDirty
            : UpsertResult.updated);
  }

  Future<void> saveAllRecords(
      String codeCo, List<ImportDraftRecord> records) async {
    await ensureMigrated(codeCo);
    for (final r in records) {
      await upsertFromImportRecord(codeCo: codeCo, record: r);
    }
  }

  Future<List<ImportDraftRecord>> readRecords(
    String codeCo, {
    SyncStatusFilter filter = SyncStatusFilter.all,
  }) async {
    if (kIsWeb) {
      return _readLegacyWeb(codeCo, filter);
    }
    await ensureMigrated(codeCo);
    final rows = await _db.listParvande(codeCo, filter: filter);
    return rows.map(_toImportRecord).toList();
  }

  Future<List<ImportDraftRecord>> readPendingForSync(String codeCo) async {
    return readRecords(codeCo, filter: SyncStatusFilter.pendingSend);
  }

  Future<ParvandeSyncCounts> counts(String codeCo) async {
    if (kIsWeb) {
      final all = await _readLegacyWeb(codeCo, SyncStatusFilter.all);
      return ParvandeSyncCounts(
        total: all.length,
        local: all.length,
        synced: 0,
        dirty: 0,
        pendingSend: all.length,
      );
    }
    await ensureMigrated(codeCo);
    return _db.countByStatus(codeCo);
  }

  Future<void> markSynced(String codeCo, String idParvandeh) async {
    if (kIsWeb) {
      final all = await _readLegacyWeb(codeCo, SyncStatusFilter.all);
      final idx = all.indexWhere((e) => e.clientTempId == idParvandeh);
      if (idx < 0) return;
      final p = Map<String, String>.from(all[idx].payload);
      p['_sync_status'] = 'synced';
      all[idx] = ImportDraftRecord(clientTempId: idParvandeh, payload: p);
      await _saveLegacyWeb(codeCo, all);
      return;
    }
    await _db.updateSyncStatus(
      codeCo,
      idParvandeh,
      ParvandeSyncStatus.synced,
      lastSyncedAt: DateTime.now().millisecondsSinceEpoch,
    );
  }

  Future<void> markSyncedBatch(String codeCo, Iterable<String> ids) async {
    for (final id in ids) {
      await markSynced(codeCo, id);
    }
  }

  Future<void> updatePayloadAfterEdit({
    required String codeCo,
    required ImportDraftRecord record,
  }) async {
    if (kIsWeb) {
      final all = await _readLegacyWeb(codeCo, SyncStatusFilter.all);
      final idx = all.indexWhere((e) => e.clientTempId == record.clientTempId);
      final payload = Map<String, String>.from(record.payload);
      if (idx >= 0) {
        final wasSynced = all[idx].payload['_sync_status'] == 'synced';
        payload['_sync_status'] =
            wasSynced ? 'dirty' : (all[idx].payload['_sync_status'] ?? 'local');
        all[idx] = ImportDraftRecord(
            clientTempId: record.clientTempId, payload: payload);
      } else {
        payload['_sync_status'] = 'local';
        all.add(ImportDraftRecord(
            clientTempId: record.clientTempId, payload: payload));
      }
      await _saveLegacyWeb(codeCo, all);
      return;
    }

    final id = record.clientTempId;
    final existing = await _db.getRow(codeCo, id);
    final hash = computePayloadContentHash(record.payload);
    final status = existing?.syncStatus == ParvandeSyncStatus.synced
        ? ParvandeSyncStatus.dirty
        : (existing?.syncStatus ?? ParvandeSyncStatus.local);

    await _db.updatePayload(
      codeCo,
      id,
      jsonEncode(record.payload),
      hash,
      status,
    );
  }

  Future<void> deleteRecord(String codeCo, String idParvandeh) async {
    if (kIsWeb) {
      final all = await _readLegacyWeb(codeCo, SyncStatusFilter.all);
      all.removeWhere((e) => e.clientTempId == idParvandeh);
      await _saveLegacyWeb(codeCo, all);
      return;
    }
    await _db.deleteParvande(codeCo, idParvandeh);
    final dir = await LocalCachePaths.parvandeMediaDir(codeCo, idParvandeh);
    if (dir != null) {
      final d = Directory(dir);
      if (await d.exists()) {
        await d.delete(recursive: true);
      }
    }
  }

  Future<void> clearUnion(String codeCo) async {
    if (kIsWeb) {
      await _saveLegacyWeb(codeCo, []);
      return;
    }
    await _db.deleteAllForUnion(codeCo);
  }

  /// پاک‌سازی کامل کش یک اتحادیه: دیتابیس + فایل‌های فیزیکی روی دیسک.
  Future<void> clearUnionCompletely(String codeCo) async {
    await clearUnion(codeCo);
    if (kIsWeb) return;
    final dir = await LocalCachePaths.unionCacheDir(codeCo);
    if (dir == null) return;
    final d = Directory(dir);
    if (await d.exists()) {
      await d.delete(recursive: true);
    }
  }

  ImportDraftRecord _toImportRecord(ParvandeLocalRow row) {
    final map = Map<String, String>.from(row.payloadMap);
    map['_sync_status'] = row.syncStatus.storageValue;
    return ImportDraftRecord(
      clientTempId: row.clientTempId,
      payload: map,
    );
  }

  // --- Web fallback (SharedPreferences + sync_status در payload) ---

  Future<List<ImportDraftRecord>> _readLegacyWeb(
    String codeCo,
    SyncStatusFilter filter,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('${_legacyDraftKey}_$codeCo');
    if (raw == null) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      var list = decoded
          .whereType<Map>()
          .map((e) => ImportDraftRecord.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      list = list
          .where((r) => (r.payload['code_co'] ?? codeCo) == codeCo)
          .toList();
      return list.where((r) {
        final st = r.payload['_sync_status'] ?? 'local';
        switch (filter) {
          case SyncStatusFilter.all:
            return true;
          case SyncStatusFilter.pendingSend:
            return st == 'local' || st == 'dirty';
          case SyncStatusFilter.synced:
            return st == 'synced';
          case SyncStatusFilter.dirty:
            return st == 'dirty';
        }
      }).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveLegacyWeb(
      String codeCo, List<ImportDraftRecord> records) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '${_legacyDraftKey}_$codeCo',
      jsonEncode(records.map((e) => e.toJson()).toList()),
    );
  }

  Future<UpsertResult> _upsertWeb(
      String codeCo, ImportDraftRecord record) async {
    final all = await _readLegacyWeb(codeCo, SyncStatusFilter.all);
    final id = record.clientTempId;
    final hash = computePayloadContentHash(record.payload);
    final idx = all.indexWhere((e) => e.clientTempId == id);
    final payload = Map<String, String>.from(record.payload);
    payload['code_co'] = codeCo;
    payload['id_parvandeh'] = id;

    if (idx < 0) {
      payload['_sync_status'] = 'local';
      all.add(ImportDraftRecord(clientTempId: id, payload: payload));
      await _saveLegacyWeb(codeCo, all);
      return UpsertResult.inserted;
    }

    final old = all[idx];
    final oldHash = computePayloadContentHash(old.payload);
    if (oldHash == hash) {
      return UpsertResult.unchanged;
    }
    final wasSynced = old.payload['_sync_status'] == 'synced';
    payload['_sync_status'] =
        wasSynced ? 'dirty' : (old.payload['_sync_status'] ?? 'local');
    all[idx] = ImportDraftRecord(clientTempId: id, payload: payload);
    await _saveLegacyWeb(codeCo, all);
    return wasSynced ? UpsertResult.updatedDirty : UpsertResult.updated;
  }
}

enum UpsertResult {
  inserted,
  updated,
  updatedDirty,
  unchanged,
  skipped,
}
