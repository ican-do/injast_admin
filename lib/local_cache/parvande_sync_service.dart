import 'package:injast_admin/import_sync/import_models.dart';
import 'package:injast_admin/local_cache/image_upload_service.dart';
import 'package:injast_admin/local_cache/parvande_local_repository.dart';

/// آماده‌سازی رکورد برای ارسال: فقط فایل‌های فیزیکی محلی آپلود می‌شوند؛ بدون تماس با اصناف.
class ParvandeSyncService {
  ParvandeSyncService._();
  static final ParvandeSyncService instance = ParvandeSyncService._();

  final _uploader = ImageUploadService.instance;

  Future<ImportDraftRecord> prepareRecordForServer({
    required String codeCo,
    required ImportDraftRecord record,
    void Function(String step)? onStep,
  }) async {
    final id = record.clientTempId;
    onStep?.call('آپلود فایل‌های محلی id=$id (بدون دانلود از اصناف)…');
    final payloadWithUrls = await _uploader.applyServerUrlsToPayload(
      codeCo: codeCo,
      idParvandeh: id,
      payload: Map<String, String>.from(record.payload),
      onStep: onStep,
    );
    return ImportDraftRecord(
      clientTempId: record.clientTempId,
      payload: payloadWithUrls,
    );
  }

  Future<List<ImportDraftRecord>> prepareBatchForServer({
    required String codeCo,
    required List<ImportDraftRecord> records,
  }) async {
    final out = <ImportDraftRecord>[];
    for (final r in records) {
      out.add(await prepareRecordForServer(codeCo: codeCo, record: r));
    }
    return out;
  }

  Future<void> markRecordsSynced(String codeCo, Iterable<ImportDraftRecord> records) async {
    await ParvandeLocalRepository.instance.markSyncedBatch(
      codeCo,
      records.map((e) => e.clientTempId),
    );
  }
}
