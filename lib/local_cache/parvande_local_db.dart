import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'package:injast_admin/local_cache/sync_status.dart';

/// ردیف پرونده در SQLite.
class ParvandeLocalRow {
  ParvandeLocalRow({
    required this.idParvandeh,
    required this.codeCo,
    required this.clientTempId,
    required this.payloadJson,
    required this.contentHash,
    required this.syncStatus,
    this.lastFetchedAt,
    this.lastSyncedAt,
  });

  final String idParvandeh;
  final String codeCo;
  final String clientTempId;
  final String payloadJson;
  final String contentHash;
  final ParvandeSyncStatus syncStatus;
  final int? lastFetchedAt;
  final int? lastSyncedAt;

  Map<String, dynamic> get payloadMap {
    try {
      final d = jsonDecode(payloadJson);
      if (d is Map) {
        return d.map((k, v) => MapEntry(k.toString(), v?.toString() ?? ''));
      }
    } catch (_) {}
    return {};
  }
}

class MediaAssetRow {
  MediaAssetRow({
    required this.id,
    required this.codeCo,
    required this.idParvandeh,
    required this.fieldKey,
    required this.remoteUrl,
    this.localPath,
    this.serverUrl,
    required this.downloadStatus,
  });

  final int id;
  final String codeCo;
  final String idParvandeh;
  final String fieldKey;
  final String remoteUrl;
  final String? localPath;
  final String? serverUrl;
  final String downloadStatus;
}

class ParvandeSyncCounts {
  const ParvandeSyncCounts({
    required this.total,
    required this.local,
    required this.synced,
    required this.dirty,
    required this.pendingSend,
  });

  final int total;
  final int local;
  final int synced;
  final int dirty;
  final int pendingSend;
}

class ParvandeLocalDb {
  ParvandeLocalDb._();
  static final ParvandeLocalDb instance = ParvandeLocalDb._();

  Database? _db;

  Future<Database> _database() async {
    if (_db != null) return _db!;
    if (kIsWeb) {
      throw UnsupportedError('SQLite local cache is not available on web.');
    }
    final dbPath = p.join(await getDatabasesPath(), 'asnaf_parvande_cache_v1.db');
    _db = await openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE parvande (
            id_parvandeh TEXT NOT NULL,
            code_co TEXT NOT NULL,
            client_temp_id TEXT NOT NULL,
            payload_json TEXT NOT NULL,
            content_hash TEXT NOT NULL,
            sync_status TEXT NOT NULL,
            last_fetched_at INTEGER,
            last_synced_at INTEGER,
            PRIMARY KEY (code_co, id_parvandeh)
          )
        ''');
        await db.execute('''
          CREATE TABLE media_asset (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            code_co TEXT NOT NULL,
            id_parvandeh TEXT NOT NULL,
            field_key TEXT NOT NULL,
            remote_url TEXT NOT NULL,
            local_path TEXT,
            server_url TEXT,
            download_status TEXT NOT NULL,
            UNIQUE(code_co, id_parvandeh, field_key)
          )
        ''');
        await db.execute(
          'CREATE INDEX idx_parvande_sync ON parvande(code_co, sync_status)',
        );
      },
    );
    return _db!;
  }

  Future<ParvandeLocalRow?> getRow(String codeCo, String idParvandeh) async {
    final db = await _database();
    final rows = await db.query(
      'parvande',
      where: 'code_co = ? AND id_parvandeh = ?',
      whereArgs: [codeCo, idParvandeh],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _rowFromMap(rows.first);
  }

  Future<void> upsertParvande(ParvandeLocalRow row) async {
    final db = await _database();
    await db.insert(
      'parvande',
      {
        'id_parvandeh': row.idParvandeh,
        'code_co': row.codeCo,
        'client_temp_id': row.clientTempId,
        'payload_json': row.payloadJson,
        'content_hash': row.contentHash,
        'sync_status': row.syncStatus.storageValue,
        'last_fetched_at': row.lastFetchedAt,
        'last_synced_at': row.lastSyncedAt,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateSyncStatus(
    String codeCo,
    String idParvandeh,
    ParvandeSyncStatus status, {
    int? lastSyncedAt,
  }) async {
    final db = await _database();
    await db.update(
      'parvande',
      {
        'sync_status': status.storageValue,
        if (lastSyncedAt != null) 'last_synced_at': lastSyncedAt,
      },
      where: 'code_co = ? AND id_parvandeh = ?',
      whereArgs: [codeCo, idParvandeh],
    );
  }

  Future<void> updatePayload(
    String codeCo,
    String idParvandeh,
    String payloadJson,
    String contentHash,
    ParvandeSyncStatus syncStatus,
  ) async {
    final db = await _database();
    await db.update(
      'parvande',
      {
        'payload_json': payloadJson,
        'content_hash': contentHash,
        'sync_status': syncStatus.storageValue,
        'last_fetched_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'code_co = ? AND id_parvandeh = ?',
      whereArgs: [codeCo, idParvandeh],
    );
  }

  Future<List<ParvandeLocalRow>> listParvande(
    String codeCo, {
    SyncStatusFilter filter = SyncStatusFilter.all,
  }) async {
    final db = await _database();
    String? where;
    List<Object?>? args;
    switch (filter) {
      case SyncStatusFilter.all:
        where = 'code_co = ?';
        args = [codeCo];
      case SyncStatusFilter.pendingSend:
        where = "code_co = ? AND sync_status IN ('local', 'dirty')";
        args = [codeCo];
      case SyncStatusFilter.synced:
        where = "code_co = ? AND sync_status = 'synced'";
        args = [codeCo];
      case SyncStatusFilter.dirty:
        where = "code_co = ? AND sync_status = 'dirty'";
        args = [codeCo];
    }
    final rows = await db.query(
      'parvande',
      where: where,
      whereArgs: args,
      orderBy: 'last_fetched_at DESC',
    );
    return rows.map(_rowFromMap).toList();
  }

  Future<ParvandeSyncCounts> countByStatus(String codeCo) async {
    final db = await _database();
    final rows = await db.rawQuery(
      '''
      SELECT sync_status, COUNT(*) as c FROM parvande
      WHERE code_co = ?
      GROUP BY sync_status
      ''',
      [codeCo],
    );
    var local = 0, synced = 0, dirty = 0;
    for (final r in rows) {
      final st = ParvandeSyncStatusX.fromStorage(r['sync_status']?.toString());
      final c = (r['c'] as int?) ?? int.tryParse('${r['c']}') ?? 0;
      switch (st) {
        case ParvandeSyncStatus.local:
          local += c;
        case ParvandeSyncStatus.synced:
          synced += c;
        case ParvandeSyncStatus.dirty:
          dirty += c;
      }
    }
    final total = local + synced + dirty;
    return ParvandeSyncCounts(
      total: total,
      local: local,
      synced: synced,
      dirty: dirty,
      pendingSend: local + dirty,
    );
  }

  Future<void> deleteAllForUnion(String codeCo) async {
    final db = await _database();
    await db.delete('media_asset', where: 'code_co = ?', whereArgs: [codeCo]);
    await db.delete('parvande', where: 'code_co = ?', whereArgs: [codeCo]);
  }

  Future<void> deleteParvande(String codeCo, String idParvandeh) async {
    final db = await _database();
    await db.delete(
      'media_asset',
      where: 'code_co = ? AND id_parvandeh = ?',
      whereArgs: [codeCo, idParvandeh],
    );
    await db.delete(
      'parvande',
      where: 'code_co = ? AND id_parvandeh = ?',
      whereArgs: [codeCo, idParvandeh],
    );
  }

  Future<void> upsertMediaAsset({
    required String codeCo,
    required String idParvandeh,
    required String fieldKey,
    required String remoteUrl,
    String? localPath,
    String? serverUrl,
    required String downloadStatus,
  }) async {
    final db = await _database();
    await db.insert(
      'media_asset',
      {
        'code_co': codeCo,
        'id_parvandeh': idParvandeh,
        'field_key': fieldKey,
        'remote_url': remoteUrl,
        'local_path': localPath,
        'server_url': serverUrl,
        'download_status': downloadStatus,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<MediaAssetRow>> listMedia(String codeCo, String idParvandeh) async {
    final db = await _database();
    final rows = await db.query(
      'media_asset',
      where: 'code_co = ? AND id_parvandeh = ?',
      whereArgs: [codeCo, idParvandeh],
    );
    return rows
        .map(
          (m) => MediaAssetRow(
            id: m['id'] as int,
            codeCo: m['code_co'] as String,
            idParvandeh: m['id_parvandeh'] as String,
            fieldKey: m['field_key'] as String,
            remoteUrl: m['remote_url'] as String,
            localPath: m['local_path'] as String?,
            serverUrl: m['server_url'] as String?,
            downloadStatus: m['download_status'] as String,
          ),
        )
        .toList();
  }

  Future<void> updateMediaLocal(
    String codeCo,
    String idParvandeh,
    String fieldKey, {
    String? localPath,
    String? serverUrl,
    String? downloadStatus,
  }) async {
    final db = await _database();
    final data = <String, Object?>{};
    if (localPath != null) data['local_path'] = localPath;
    if (serverUrl != null) data['server_url'] = serverUrl;
    if (downloadStatus != null) data['download_status'] = downloadStatus;
    if (data.isEmpty) return;
    await db.update(
      'media_asset',
      data,
      where: 'code_co = ? AND id_parvandeh = ? AND field_key = ?',
      whereArgs: [codeCo, idParvandeh, fieldKey],
    );
  }

  ParvandeLocalRow _rowFromMap(Map<String, Object?> m) {
    return ParvandeLocalRow(
      idParvandeh: m['id_parvandeh'] as String,
      codeCo: m['code_co'] as String,
      clientTempId: m['client_temp_id'] as String,
      payloadJson: m['payload_json'] as String,
      contentHash: m['content_hash'] as String,
      syncStatus: ParvandeSyncStatusX.fromStorage(m['sync_status'] as String?),
      lastFetchedAt: m['last_fetched_at'] as int?,
      lastSyncedAt: m['last_synced_at'] as int?,
    );
  }
}
