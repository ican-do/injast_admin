import 'package:injast_admin/import_sync/import_draft_store.dart';
import 'package:injast_admin/local_cache/sync_status.dart';

/// بارگذاری لیست پرونده‌ها از حافظهٔ محلی (SQLite) برای UI مدیریت پرونده در حالت آفلاین.
class ParvandeCacheListService {
  ParvandeCacheListService._();
  static final ParvandeCacheListService instance = ParvandeCacheListService._();

  Future<List<Map<String, dynamic>>> fetchAllFromCache(String codeCo) async {
    final store = ImportDraftStore(codeCo);
    final records = await store.read(filter: SyncStatusFilter.all);
    return records.map((r) => Map<String, dynamic>.from(r.payload)).toList();
  }

  Future<int> countInCache(String codeCo) async {
    final store = ImportDraftStore(codeCo);
    final c = await store.syncCounts();
    return c.total;
  }

  /// ادغام وضعیت `_sync_status` حافظهٔ محلی روی لیست دریافتی از سرور.
  Future<List<Map<String, dynamic>>> mergeSyncStatusFromCache(
    String codeCo,
    List<Map<String, dynamic>> rows,
  ) async {
    final store = ImportDraftStore(codeCo);
    final records = await store.read(filter: SyncStatusFilter.all);
    final byId = <String, String>{
      for (final r in records)
        r.clientTempId: (r.payload['_sync_status'] ?? 'local').toString(),
    };
    return rows.map((row) {
      final id = row['id_parvandeh']?.toString().trim() ?? '';
      if (id.isEmpty || !byId.containsKey(id)) return row;
      final copy = Map<String, dynamic>.from(row);
      copy['_sync_status'] = byId[id];
      return copy;
    }).toList();
  }
}
