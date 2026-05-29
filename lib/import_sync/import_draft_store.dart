import 'package:injast_admin/import_sync/import_models.dart';
import 'package:injast_admin/local_cache/parvande_local_db.dart';
import 'package:injast_admin/local_cache/parvande_local_repository.dart';
import 'package:injast_admin/local_cache/sync_status.dart';

export 'package:injast_admin/local_cache/parvande_local_repository.dart'
    show UpsertResult;
export 'package:injast_admin/local_cache/parvande_local_db.dart'
    show ParvandeSyncCounts;

/// ذخیرهٔ محلی پرونده‌های یک اتحادیه (SQLite + وضعیت همگام‌سازی).
class ImportDraftStore {
  ImportDraftStore(this.codeCo);

  final String codeCo;
  final _repo = ParvandeLocalRepository.instance;

  /// همهٔ پرونده‌های اتحادیه در حافظه.
  Future<List<ImportDraftRecord>> read(
          {SyncStatusFilter filter = SyncStatusFilter.all}) =>
      _repo.readRecords(codeCo, filter: filter);

  /// فقط پرونده‌هایی که باید به سرور ارسال شوند (local + dirty).
  Future<List<ImportDraftRecord>> readPendingForSync() =>
      _repo.readPendingForSync(codeCo);

  Future<ParvandeSyncCounts> syncCounts() => _repo.counts(codeCo);

  Future<void> save(List<ImportDraftRecord> records) =>
      _repo.saveAllRecords(codeCo, records);

  Future<UpsertResult> upsert(
    ImportDraftRecord record, {
    bool downloadImages = true,
    bool fastMode = false,
  }) =>
      _repo.upsertFromImportRecord(
        codeCo: codeCo,
        record: record,
        downloadImages: downloadImages,
        fastMode: fastMode,
      );

  Future<void> updateAfterEdit(ImportDraftRecord record) =>
      _repo.updatePayloadAfterEdit(codeCo: codeCo, record: record);

  Future<void> markSynced(String clientTempId) =>
      _repo.markSynced(codeCo, clientTempId);

  Future<void> markSyncedBatch(Iterable<String> clientTempIds) =>
      _repo.markSyncedBatch(codeCo, clientTempIds);

  Future<void> clear() => _repo.clearUnion(codeCo);

  Future<void> clearCompletely() => _repo.clearUnionCompletely(codeCo);

  Future<void> deleteRecord(String clientTempId) =>
      _repo.deleteRecord(codeCo, clientTempId);
}
