import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:injast_admin/file_management/media_file_urls.dart';
import 'package:injast_admin/file_management/address_geocoding_service.dart';
import 'package:injast_admin/file_management/parvande_api.dart';
import 'package:injast_admin/file_management/province_geo_fence.dart';
import 'package:injast_admin/import_sync/asnaf_bot_client.dart';
import 'package:injast_admin/import_sync/import_draft_store.dart';
import 'package:injast_admin/import_sync/import_models.dart';
import 'package:injast_admin/local_cache/local_cache_paths.dart';
import 'package:injast_admin/local_cache/local_image_store.dart';

enum DataExportSource { server, local }

class DataStatsSnapshot {
  const DataStatsSnapshot({
    required this.totalCases,
    required this.activeCases,
    required this.trashedCases,
    required this.documentsCount,
    required this.withLocationCount,
    required this.debtorCount,
    required this.profileImageCount,
    required this.mediaFilesOnDisk,
    this.syncedCount = 0,
    this.pendingSyncCount = 0,
    this.generatedAt,
    this.fromCache = false,
  });

  final int totalCases;
  final int activeCases;
  final int trashedCases;
  final int documentsCount;
  final int withLocationCount;
  final int debtorCount;
  final int profileImageCount;
  final int mediaFilesOnDisk;
  final int syncedCount;
  final int pendingSyncCount;
  final DateTime? generatedAt;
  final bool fromCache;

  Map<String, dynamic> toJson() => {
        'total_cases': totalCases,
        'active_cases': activeCases,
        'trashed_cases': trashedCases,
        'documents_count': documentsCount,
        'with_location_count': withLocationCount,
        'debtor_count': debtorCount,
        'profile_image_count': profileImageCount,
        'media_files_on_disk': mediaFilesOnDisk,
        'synced_count': syncedCount,
        'pending_sync_count': pendingSyncCount,
        'generated_at': generatedAt?.toIso8601String(),
      };

  factory DataStatsSnapshot.fromJson(Map<String, dynamic> json,
      {bool fromCache = false}) {
    int n(String key) => int.tryParse('${json[key] ?? 0}') ?? 0;
    final generatedRaw = json['generated_at']?.toString().trim();
    return DataStatsSnapshot(
      totalCases: n('total_cases'),
      activeCases: n('active_cases'),
      trashedCases: n('trashed_cases'),
      documentsCount: n('documents_count'),
      withLocationCount: n('with_location_count'),
      debtorCount: n('debtor_count'),
      profileImageCount: n('profile_image_count'),
      mediaFilesOnDisk: n('media_files_on_disk'),
      syncedCount: n('synced_count'),
      pendingSyncCount: n('pending_sync_count'),
      generatedAt: generatedRaw == null || generatedRaw.isEmpty
          ? null
          : DateTime.tryParse(generatedRaw),
      fromCache: fromCache,
    );
  }
}

class DataBackupOverview {
  const DataBackupOverview({
    required this.server,
    required this.local,
    this.cacheDirectory,
  });

  final DataStatsSnapshot server;
  final DataStatsSnapshot local;
  final String? cacheDirectory;
}

class DataExportResult {
  const DataExportResult({
    required this.label,
    required this.mainPath,
    required this.recordCount,
    required this.source,
  });

  final String label;
  final String mainPath;
  final int recordCount;
  final DataExportSource source;
}

class BackupPreparation {
  const BackupPreparation({
    required this.totalCount,
    required this.totalPages,
  });

  final int totalCount;
  final int totalPages;
}

class BackupProgress {
  const BackupProgress({
    required this.stage,
    required this.message,
    this.current = 0,
    this.total = 0,
  });

  final String stage;
  final String message;
  final int current;
  final int total;

  double? get fraction {
    if (total <= 0) return null;
    return (current / total).clamp(0, 1);
  }
}

class BackupResult {
  const BackupResult({
    required this.recordsCount,
    required this.documentsCount,
    required this.storeImagesDownloaded,
  });

  final int recordsCount;
  final int documentsCount;
  final int storeImagesDownloaded;
}

class GeocodeRecoveryStats {
  const GeocodeRecoveryStats({
    required this.totalCases,
    required this.withLocation,
    required this.withoutLocation,
    required this.validInProvince,
    required this.invalidOutOfProvince,
  });

  final int totalCases;
  final int withLocation;
  final int withoutLocation;
  final int validInProvince;
  final int invalidOutOfProvince;
}

enum GeocodeRecoveryMode { all, testFive, problematicOnly }

class GeocodeRecoveryResult {
  const GeocodeRecoveryResult({
    required this.attempted,
    required this.updated,
    required this.failed,
    required this.skippedOutOfProvince,
    required this.previewRows,
  });

  final int attempted;
  final int updated;
  final int failed;
  final int skippedOutOfProvince;
  final List<Map<String, dynamic>> previewRows;
}

class UnionPurgeResult {
  const UnionPurgeResult({
    required this.serverDeleteAttempted,
    required this.serverDeleteSucceeded,
    required this.serverDeleteFailed,
    required this.localCleared,
    this.sampleErrors = const [],
  });

  final int serverDeleteAttempted;
  final int serverDeleteSucceeded;
  final int serverDeleteFailed;
  final bool localCleared;
  final List<String> sampleErrors;

  bool get hasServerFailures => serverDeleteFailed > 0;
}

class UnionPurgePreview {
  const UnionPurgePreview({
    required this.serverParvandeCount,
    required this.localParvandeCount,
    required this.localDocumentsCount,
    required this.localMediaFilesCount,
  });

  final int serverParvandeCount;
  final int localParvandeCount;
  final int localDocumentsCount;
  final int localMediaFilesCount;
}

class DataBackupService {
  DataBackupService(this.codeCo);

  final String codeCo;

  static const _serverStatsCacheAge = Duration(minutes: 20);
  static const _serverStatsCachePrefix = 'data_backup_server_stats_v1_';
  static const _serverFetchConcurrency = 12;
  static const _serverDeleteConcurrency = 8;
  static const _mediaSyncConcurrency = 6;
  static const _maxPurgeErrorSamples = 12;

  final _parvandeApi = ParvandeApi.instance;
  final _images = LocalImageStore.instance;
  final _addressGeocoder = AddressGeocodingService.instance;

  ImportDraftStore get _store => ImportDraftStore(codeCo);

  Future<DataBackupOverview> loadOverview({
    bool forceRefresh = false,
    void Function(BackupProgress progress)? onProgress,
  }) async {
    onProgress?.call(const BackupProgress(
        stage: 'local', message: 'در حال محاسبه آمار محلی...'));
    final local = await _loadLocalSnapshot();
    onProgress?.call(const BackupProgress(
        stage: 'server', message: 'در حال دریافت آمار سرور...'));
    final server = await _loadServerSnapshot(
      forceRefresh: forceRefresh,
      onProgress: onProgress,
    );
    return DataBackupOverview(
      server: server,
      local: local,
      cacheDirectory: await LocalCachePaths.unionCacheDir(codeCo),
    );
  }

  Future<GeocodeRecoveryStats> loadGeocodeRecoveryStats() async {
    final rows = await _parvandeApi.fetchAll(codeCo);
    var withLocation = 0;
    var validInProvince = 0;
    var invalidOutOfProvince = 0;
    for (final row in rows) {
      final hasLoc = _hasLocation(row);
      if (hasLoc) withLocation += 1;
      if (_isLocationInsideProvince(row)) {
        validInProvince += 1;
      } else if (hasLoc) {
        invalidOutOfProvince += 1;
      }
    }
    return GeocodeRecoveryStats(
      totalCases: rows.length,
      withLocation: withLocation,
      withoutLocation: rows.length - withLocation,
      validInProvince: validInProvince,
      invalidOutOfProvince: invalidOutOfProvince,
    );
  }

  Future<GeocodeRecoveryResult> recoverGeocodes({
    required GeocodeRecoveryMode mode,
    void Function(BackupProgress progress)? onProgress,
  }) async {
    final allRows = await _parvandeApi.fetchAll(codeCo);
    final rows = switch (mode) {
      GeocodeRecoveryMode.all => allRows,
      GeocodeRecoveryMode.testFive =>
        allRows.reversed.take(5).toList().reversed.toList(),
      GeocodeRecoveryMode.problematicOnly =>
        allRows.where((row) => !_isLocationInsideProvince(row)).toList(),
    };

    var updated = 0;
    var failed = 0;
    var skippedOutOfProvince = 0;

    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      final id = _id(row);
      onProgress?.call(
        BackupProgress(
          stage: 'recover_geocode',
          message: 'بازیابی مختصات ${i + 1} از ${rows.length} (پرونده $id)',
          current: i + 1,
          total: rows.length,
        ),
      );

      final state = _s(row, 'state_store');
      final city = _s(row, 'city_store');
      final address = _s(row, 'address_store');
      if (state.isEmpty || city.isEmpty || address.isEmpty) {
        failed += 1;
        continue;
      }

      final geo = await _addressGeocoder.resolve(
        address: address,
        state: state,
        city: city,
      );
      if (geo == null) {
        failed += 1;
        continue;
      }

      final lat = double.tryParse(geo.$1);
      final lng = double.tryParse(geo.$2);
      if (lat == null || lng == null) {
        failed += 1;
        continue;
      }
      if (!_isInsideProvince(state: state, lat: lat, lng: lng)) {
        skippedOutOfProvince += 1;
        continue;
      }

      try {
        await _parvandeApi.updateStoreLocation(
          idParvandeh: id,
          lat: geo.$1,
          lng: geo.$2,
          keepEditLocation: true,
        );
        updated += 1;
      } catch (_) {
        failed += 1;
      }
      await _addressGeocoder.pauseBetweenImports();
    }

    return GeocodeRecoveryResult(
      attempted: rows.length,
      updated: updated,
      failed: failed,
      skippedOutOfProvince: skippedOutOfProvince,
      previewRows: mode == GeocodeRecoveryMode.testFive ? rows : const [],
    );
  }

  Future<BackupPreparation> prepareFullBackup() async {
    final rows = await _parvandeApi.fetchAll(codeCo);
    return BackupPreparation(totalCount: rows.length, totalPages: 1);
  }

  Future<void> clearLocalDataCompletely() async {
    await _store.clearCompletely();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_serverStatsCachePrefix$codeCo');
  }

  Future<UnionPurgePreview> loadUnionPurgePreview() async {
    final rows = await _parvandeApi.fetchAll(codeCo);
    final local = await _loadLocalSnapshot();
    return UnionPurgePreview(
      serverParvandeCount: rows.length,
      localParvandeCount: local.totalCases,
      localDocumentsCount: local.documentsCount,
      localMediaFilesCount: local.mediaFilesOnDisk,
    );
  }

  /// حذف دائم همهٔ پرونده‌های اتحادیه از سرور و سپس پاک‌سازی کامل کش محلی.
  Future<UnionPurgeResult> purgeUnionCompletely({
    void Function(BackupProgress progress)? onProgress,
  }) async {
    onProgress?.call(const BackupProgress(
      stage: 'server_list',
      message: 'در حال دریافت لیست پرونده‌های سرور…',
    ));
    final rows = await _parvandeApi.fetchAll(codeCo);
    final ids = rows
        .map(_id)
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();

    var serverSucceeded = 0;
    var serverFailed = 0;
    final errors = <String>[];

    if (ids.isNotEmpty) {
      var done = 0;
      await _mapWithConcurrency<String, bool>(
        ids,
        concurrency: _serverDeleteConcurrency,
        task: (id, index) async {
          try {
            await _parvandeApi.deleteForever(id);
            return true;
          } catch (e) {
            if (errors.length < _maxPurgeErrorSamples) {
              errors.add('پرونده $id: $e');
            }
            return false;
          }
        },
        onItemDone: (index, ok) {
          done += 1;
          if (ok) {
            serverSucceeded += 1;
          } else {
            serverFailed += 1;
          }
          onProgress?.call(
            BackupProgress(
              stage: 'server_delete',
              message: 'حذف از سرور $done از ${ids.length}',
              current: done,
              total: ids.length,
            ),
          );
        },
      );
    } else {
      onProgress?.call(const BackupProgress(
        stage: 'server_delete',
        message: 'پرونده‌ای روی سرور برای حذف یافت نشد.',
      ));
    }

    onProgress?.call(const BackupProgress(
      stage: 'local_clear',
      message: 'پاک‌سازی کامل حافظهٔ محلی و فایل‌ها…',
    ));
    await clearLocalDataCompletely();

    return UnionPurgeResult(
      serverDeleteAttempted: ids.length,
      serverDeleteSucceeded: serverSucceeded,
      serverDeleteFailed: serverFailed,
      localCleared: true,
      sampleErrors: errors,
    );
  }

  Future<BackupResult> runFullServerBackup({
    void Function(BackupProgress progress)? onProgress,
  }) async {
    final prep = await prepareFullBackup();
    onProgress?.call(
      BackupProgress(
        stage: 'collect',
        message: 'دریافت کامل اطلاعات از سرور اصلی سیستم...',
        current: 0,
        total: prep.totalCount,
      ),
    );
    final records = await _fetchServerRecordsForBackup(onProgress: onProgress);

    onProgress?.call(
        const BackupProgress(stage: 'clear', message: 'پاک‌سازی کش قبلی...'));
    await _store.clearCompletely();

    var docsTotal = 0;
    final syncedIds = <String>[];
    for (var i = 0; i < records.length; i++) {
      final record = records[i];
      docsTotal += record.persistedDocsCount();
      onProgress?.call(
        BackupProgress(
          stage: 'write_payload',
          message: 'ذخیره اطلاعات پرونده ${i + 1} از ${records.length}',
          current: i + 1,
          total: records.length,
        ),
      );
      await _store.upsert(
        record,
        downloadImages: false,
        fastMode: true,
      );
      syncedIds.add(record.clientTempId);
    }
    await _store.markSyncedBatch(syncedIds);

    var mediaDone = 0;
    final mediaResults = await _mapWithConcurrency<ImportDraftRecord, int>(
      records,
      concurrency: _mediaSyncConcurrency,
      task: (record, index) async {
        final id = record.clientTempId;
        try {
          await _images.syncAllMediaForPayload(
            codeCo: codeCo,
            idParvandeh: id,
            payload: record.payload,
            fastMode: true,
          );
          return await _syncStoreImagesForRecord(id);
        } catch (_) {
          return 0;
        } finally {
          mediaDone += 1;
          onProgress?.call(
            BackupProgress(
              stage: 'download_media',
              message: 'دریافت فایل‌های محلی $mediaDone از ${records.length}',
              current: mediaDone,
              total: records.length,
            ),
          );
        }
      },
    );
    final storeImagesDownloaded =
        mediaResults.fold<int>(0, (sum, value) => sum + value);

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_serverStatsCachePrefix$codeCo');

    return BackupResult(
      recordsCount: records.length,
      documentsCount: docsTotal,
      storeImagesDownloaded: storeImagesDownloaded,
    );
  }

  Future<List<ImportDraftRecord>> _fetchServerRecordsForBackup({
    void Function(BackupProgress progress)? onProgress,
  }) async {
    final rows = await _parvandeApi.fetchAll(codeCo);
    var completed = 0;
    final out =
        await _mapWithConcurrency<Map<String, dynamic>, ImportDraftRecord?>(
      rows,
      concurrency: _serverFetchConcurrency,
      task: (row, index) async {
        final id = _id(row);
        if (id.isEmpty) return null;
        List<Map<String, dynamic>> docs = const [];
        try {
          final rawDocs = await _parvandeApi.fetchDocuments(codeCo, id);
          docs = rawDocs.map(_normalizeServerDocRow).toList();
        } catch (_) {}
        final payload = row.map(
          (key, value) => MapEntry(key.toString(), value?.toString() ?? ''),
        );
        payload['code_co'] = codeCo;
        payload['id_parvandeh'] = id;
        payload['_docs_json'] = jsonEncode(docs);
        return ImportDraftRecord(clientTempId: id, payload: payload);
      },
      onItemDone: (_, __) {
        completed += 1;
        onProgress?.call(
          BackupProgress(
            stage: 'fetch_docs',
            message: 'دریافت پرونده و اسناد $completed از ${rows.length}',
            current: completed,
            total: rows.length,
          ),
        );
      },
    );
    return out.whereType<ImportDraftRecord>().toList();
  }

  Future<DataExportResult?> exportJson(DataExportSource source) async {
    final records = await _collectExportRecords(source);
    final filePath = await _pickSavePath(
      suggestedName: _suggestedFileName(
          prefix: 'backup_${source.name}', extension: 'json'),
      extensions: const ['json'],
    );
    if (filePath == null) return null;
    final payload = {
      'code_co': codeCo,
      'source': source.name,
      'generated_at': DateTime.now().toIso8601String(),
      'records_count': records.length,
      'records': records,
    };
    await File(filePath).writeAsString(
      const JsonEncoder.withIndent('  ').convert(payload),
      flush: true,
    );
    return DataExportResult(
      label: 'JSON',
      mainPath: filePath,
      recordCount: records.length,
      source: source,
    );
  }

  Future<DataExportResult?> exportCsv(DataExportSource source) async {
    final records = await _collectExportRecords(source);
    final mainPath = await _pickSavePath(
      suggestedName:
          _suggestedFileName(prefix: 'backup_${source.name}', extension: 'csv'),
      extensions: const ['csv'],
    );
    if (mainPath == null) return null;

    await File(mainPath).writeAsString(
      _utf8Bom + _csvFromMaps(records),
      flush: true,
    );

    return DataExportResult(
      label: 'CSV',
      mainPath: mainPath,
      recordCount: records.length,
      source: source,
    );
  }

  Future<DataExportResult?> exportExcel(DataExportSource source) async {
    final records = await _collectExportRecords(source);
    final filePath = await _pickSavePath(
      suggestedName:
          _suggestedFileName(prefix: 'backup_${source.name}', extension: 'xls'),
      extensions: const ['xls'],
    );
    if (filePath == null) return null;
    final xml = _spreadsheetXml(
      records: records,
    );
    await File(filePath).writeAsString(xml, flush: true);
    return DataExportResult(
      label: 'Excel',
      mainPath: filePath,
      recordCount: records.length,
      source: source,
    );
  }

  Future<DataStatsSnapshot> _loadLocalSnapshot() async {
    final counts = await _store.syncCounts();
    final records = await _store.read();
    var active = 0;
    var trash = 0;
    var docs = 0;
    var withLocation = 0;
    var debtors = 0;
    var profileImages = 0;
    var mediaFiles = 0;

    for (final record in records) {
      final row = Map<String, dynamic>.from(record.payload);
      if (_isTrash(row)) {
        trash += 1;
      } else {
        active += 1;
      }
      docs += record.persistedDocsCount();
      if (_hasLocation(row)) withLocation += 1;
      if (_debtValue(row) > 0) debtors += 1;
      final diskFiles = await _images.listLocalFilesOnDisk(
        codeCo: codeCo,
        idParvandeh: _id(row),
      );
      mediaFiles += diskFiles.values.toSet().length;
      if (diskFiles.containsKey('image_profile')) {
        profileImages += 1;
      }
    }

    return DataStatsSnapshot(
      totalCases: records.length,
      activeCases: active,
      trashedCases: trash,
      documentsCount: docs,
      withLocationCount: withLocation,
      debtorCount: debtors,
      profileImageCount: profileImages,
      mediaFilesOnDisk: mediaFiles,
      syncedCount: counts.synced,
      pendingSyncCount: counts.pendingSend,
      generatedAt: DateTime.now(),
    );
  }

  Future<DataStatsSnapshot> _loadServerSnapshot({
    required bool forceRefresh,
    void Function(BackupProgress progress)? onProgress,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = '$_serverStatsCachePrefix$codeCo';
    if (!forceRefresh) {
      final raw = prefs.getString(cacheKey);
      if (raw != null && raw.trim().isNotEmpty) {
        try {
          final decoded = jsonDecode(raw);
          if (decoded is Map) {
            final generatedRaw = decoded['generated_at']?.toString();
            final generatedAt =
                generatedRaw == null ? null : DateTime.tryParse(generatedRaw);
            final fresh = generatedAt != null &&
                DateTime.now().difference(generatedAt) <= _serverStatsCacheAge;
            if (fresh) {
              return DataStatsSnapshot.fromJson(
                Map<String, dynamic>.from(decoded),
                fromCache: true,
              );
            }
          }
        } catch (_) {}
      }
    }

    final rows = await _parvandeApi.fetchAll(codeCo);
    var active = 0;
    var trash = 0;
    var withLocation = 0;
    var debtors = 0;
    for (final row in rows) {
      if (_isTrash(row)) {
        trash += 1;
      } else {
        active += 1;
      }
      if (_hasLocation(row)) withLocation += 1;
      if (_debtValue(row) > 0) debtors += 1;
    }

    var completed = 0;
    final docCounts = await _mapWithConcurrency<Map<String, dynamic>, int>(
      rows,
      concurrency: _serverFetchConcurrency,
      task: (row, index) async {
        final id = _id(row);
        if (id.isEmpty) return 0;
        try {
          final docs = await _parvandeApi.fetchDocuments(codeCo, id);
          return docs.length;
        } catch (_) {
          return 0;
        }
      },
      onItemDone: (_, __) {
        completed += 1;
        onProgress?.call(
          BackupProgress(
            stage: 'server_docs',
            message: 'شمارش اسناد سرور $completed از ${rows.length}',
            current: completed,
            total: rows.length,
          ),
        );
      },
    );
    final docsCount = docCounts.fold<int>(0, (sum, value) => sum + value);

    final snapshot = DataStatsSnapshot(
      totalCases: rows.length,
      activeCases: active,
      trashedCases: trash,
      documentsCount: docsCount,
      withLocationCount: withLocation,
      debtorCount: debtors,
      profileImageCount:
          rows.where((e) => _s(e, 'image_profile').isNotEmpty).length,
      mediaFilesOnDisk: 0,
      generatedAt: DateTime.now(),
    );
    await prefs.setString(cacheKey, jsonEncode(snapshot.toJson()));
    return snapshot;
  }

  Future<List<Map<String, dynamic>>> _collectExportRecords(
      DataExportSource source) async {
    switch (source) {
      case DataExportSource.local:
        final local = await _store.read();
        return local
            .map((e) =>
                _prepareExportRecord(Map<String, dynamic>.from(e.payload)))
            .toList();
      case DataExportSource.server:
        final rows = await _parvandeApi.fetchAll(codeCo);
        return rows.map(_prepareExportRecord).toList();
    }
  }

  Map<String, dynamic> _prepareExportRecord(Map<String, dynamic> row) {
    final out = <String, dynamic>{};
    for (final entry in row.entries) {
      final key = entry.key.toString();
      if (key == '_docs_json' || key == '_sync_status' || key.startsWith('_')) {
        continue;
      }
      out[key] = entry.value;
    }
    return out;
  }

  Map<String, dynamic> _normalizeServerDocRow(Map<String, dynamic> row) {
    final out = Map<String, dynamic>.from(row);
    final link = _docLinkFromRow(row);
    if (link.isNotEmpty) {
      out['link_doc'] = link;
    }
    return out;
  }

  String _docLinkFromRow(Map<String, dynamic> row) {
    const keys = [
      'link_doc',
      'file_url',
      'url',
      'link',
      'download_url',
      'href',
      'file_doc',
      'file',
      'file_path',
      'path_doc',
      'path',
      'src',
    ];
    for (final key in keys) {
      final value = row[key]?.toString().trim() ?? '';
      if (value.isNotEmpty && value.toLowerCase() != 'null') {
        return value;
      }
    }
    return '';
  }

  Future<int> _syncStoreImagesForRecord(String idParvandeh) async {
    final results = await Future.wait(
      List.generate(4, (offset) {
        final index = offset + 1;
        return _images.downloadToFile(
          codeCo: codeCo,
          idParvandeh: idParvandeh,
          fieldKey: 'store:p$index',
          remoteUrl: MediaFileUrls.storeImageUrl(
            codeCo: codeCo,
            idParvandeh: idParvandeh,
            index: index,
          ),
          fastMode: true,
        );
      }),
    );
    return results.whereType<String>().length;
  }

  Future<String?> _pickSavePath({
    required String suggestedName,
    required List<String> extensions,
  }) async {
    if (kIsWeb) {
      throw UnsupportedError('ذخیره فایل روی وب در این نسخه فعال نیست.');
    }
    try {
      final path = await FilePicker.saveFile(
        dialogTitle: 'ذخیره فایل خروجی',
        fileName: suggestedName,
        type: FileType.custom,
        allowedExtensions: extensions,
      );
      if (path != null && path.trim().isNotEmpty) {
        return _ensureExtension(path.trim(), extensions);
      }
    } on MissingPluginException {
      throw Exception('پنجره انتخاب مسیر فایل در این دستگاه در دسترس نیست.');
    } on PlatformException {
      throw Exception('انتخاب مسیر ذخیره فایل توسط سیستم لغو یا پشتیبانی نشد.');
    }
    return null;
  }

  String _suggestedFileName({
    required String prefix,
    required String extension,
  }) {
    final now = DateTime.now();
    final stamp =
        '${now.year.toString().padLeft(4, '0')}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
    return '${prefix}_${codeCo}_$stamp.$extension';
  }

  String _ensureExtension(String path, List<String> extensions) {
    if (extensions.isEmpty) return path;
    final ext = extensions.first.trim().toLowerCase().replaceFirst('.', '');
    if (ext.isEmpty) return path;
    if (path.toLowerCase().endsWith('.$ext')) return path;
    return '$path.$ext';
  }

  String _csvFromMaps(List<Map<String, dynamic>> rows) {
    if (rows.isEmpty) return '';
    final columns = _collectColumns(rows);
    final buffer = StringBuffer()..writeln(columns.map(_csvCell).join(','));
    for (final row in rows) {
      buffer.writeln(
          columns.map((key) => _csvCell(_stringify(row[key]))).join(','));
    }
    return buffer.toString();
  }

  List<String> _collectColumns(List<Map<String, dynamic>> rows) {
    const preferred = [
      'id_parvandeh',
      'code_co',
      'num_parvande_store',
      'name_store',
      'name_admin',
      'family_admin',
      'mob_admin',
      'code_meli_admin',
      'raste_store',
      'city_store',
      'state_store',
      'address_store',
      'money',
      'vaziyat_store',
      'lbl_vaziyat_store',
      'date_sodor_store',
      'date_exp_store',
      'image_profile',
    ];
    final set = <String>{};
    for (final row in rows) {
      set.addAll(row.keys.map((e) => e.toString()));
    }
    final remaining = set.where((e) => !preferred.contains(e)).toList()..sort();
    return [...preferred.where(set.contains), ...remaining];
  }

  String _csvCell(String raw) {
    final escaped = raw.replaceAll('"', '""');
    if (escaped.contains(',') ||
        escaped.contains('"') ||
        escaped.contains('\n')) {
      return '"$escaped"';
    }
    return escaped;
  }

  String _spreadsheetXml({
    required List<Map<String, dynamic>> records,
  }) {
    final recordColumns = _collectColumns(records);
    final buffer = StringBuffer()
      ..writeln('<?xml version="1.0" encoding="UTF-8"?>')
      ..writeln('<?mso-application progid="Excel.Sheet"?>')
      ..writeln(
          '<Workbook xmlns="urn:schemas-microsoft-com:office:spreadsheet"')
      ..writeln(' xmlns:o="urn:schemas-microsoft-com:office:office"')
      ..writeln(' xmlns:x="urn:schemas-microsoft-com:office:excel"')
      ..writeln(' xmlns:ss="urn:schemas-microsoft-com:office:spreadsheet">')
      ..writeln(_worksheetXml(
          name: 'Parvande', columns: recordColumns, rows: records))
      ..writeln('</Workbook>');
    return buffer.toString();
  }

  String _worksheetXml({
    required String name,
    required List<String> columns,
    required List<Map<String, dynamic>> rows,
  }) {
    final safeName = name.length > 28 ? name.substring(0, 28) : name;
    final buffer = StringBuffer()
      ..writeln('<Worksheet ss:Name="${_xml(safeName)}">')
      ..writeln('<Table>');
    if (columns.isNotEmpty) {
      buffer.writeln('<Row>');
      for (final column in columns) {
        buffer.writeln(
            '<Cell><Data ss:Type="String">${_xml(column)}</Data></Cell>');
      }
      buffer.writeln('</Row>');
      for (final row in rows) {
        buffer.writeln('<Row>');
        for (final column in columns) {
          buffer.writeln(
            '<Cell><Data ss:Type="String">${_xml(_stringify(row[column]))}</Data></Cell>',
          );
        }
        buffer.writeln('</Row>');
      }
    }
    buffer
      ..writeln('</Table>')
      ..writeln('</Worksheet>');
    return buffer.toString();
  }

  String _xml(String input) {
    return input
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }

  String _stringify(dynamic value) {
    if (value == null) return '';
    if (value is String) return value;
    if (value is Map || value is List) return jsonEncode(value);
    return value.toString();
  }

  String _s(Map<String, dynamic> row, String key) =>
      row[key]?.toString().trim() ?? '';

  String _id(Map<String, dynamic> row) => _s(row, 'id_parvandeh');

  bool _isTrash(Map<String, dynamic> row) => _s(row, 'act_parvande') == '2';

  bool _hasLocation(Map<String, dynamic> row) {
    final lat = _s(row, 'lat_store');
    final lng = _s(row, 'long_store');
    if (lat.isEmpty || lng.isEmpty) return false;
    if (lat == '0' || lng == '0') return false;
    if (lat.toLowerCase() == 'null' || lng.toLowerCase() == 'null') {
      return false;
    }
    return true;
  }

  bool _isLocationInsideProvince(Map<String, dynamic> row) {
    if (!_hasLocation(row)) return false;
    final lat = double.tryParse(_s(row, 'lat_store'));
    final lng = double.tryParse(_s(row, 'long_store'));
    if (lat == null || lng == null) return false;
    return _isInsideProvince(
      state: _s(row, 'state_store'),
      lat: lat,
      lng: lng,
    );
  }

  bool _isInsideProvince({
    required String state,
    required double lat,
    required double lng,
  }) {
    final fence = ProvinceGeoFence.fromState(state);
    if (fence == null) return true;
    return fence.contains(lat, lng);
  }

  double _debtValue(Map<String, dynamic> row) {
    final parsed = AsnafBotClient.parseDebtAmount(row['money']);
    return parsed ?? 0;
  }

  Future<List<R>> _mapWithConcurrency<T, R>(
    List<T> items, {
    required int concurrency,
    required Future<R> Function(T item, int index) task,
    void Function(int index, R result)? onItemDone,
  }) async {
    if (items.isEmpty) return const [];
    final limit = math.max(1, math.min(concurrency, items.length));
    final results = List<R?>.filled(items.length, null);
    var nextIndex = 0;

    Future<void> worker() async {
      while (true) {
        final current = nextIndex;
        if (current >= items.length) return;
        nextIndex += 1;
        final result = await task(items[current], current);
        results[current] = result;
        onItemDone?.call(current, result);
      }
    }

    await Future.wait(List.generate(limit, (_) => worker()));
    return results.cast<R>();
  }
}

const _utf8Bom = '\uFEFF';
