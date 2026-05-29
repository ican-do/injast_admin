import 'package:injast_admin/import_sync/import_models.dart';
import 'package:injast_admin/local_cache/parvande_server_send.dart';

/// ارسال یک پرونده از حافظهٔ محلی به سرور (همان مسیر batch، تک‌رکوردی).
class ParvandeSingleSync {
  ParvandeSingleSync._();

  static Future<ImportFinalizeResult> sendOne({
    required String codeCo,
    required ImportDraftRecord record,
    void Function(String message)? onProgress,
  }) async {
    final result = await ParvandeServerSend.instance.sendAll(
      codeCo: codeCo,
      records: [record],
      chunkSize: 1,
      onProgress: (p) => onProgress?.call(p.message),
    );
    return result.finalize;
  }
}
