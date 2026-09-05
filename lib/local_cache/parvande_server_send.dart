import 'dart:developer' show log;

import 'package:injast_admin/import_sync/asnaf_op_log.dart';
import 'package:injast_admin/import_sync/import_models.dart';
import 'package:injast_admin/import_sync/import_sync_api.dart';
import 'package:injast_admin/local_cache/parvande_sync_service.dart';

/// پیشرفت ارسال پرونده‌ها به سرور (برای دیالوگ زنده).
class ParvandeServerSendProgress {
  const ParvandeServerSendProgress({
    required this.message,
    required this.done,
    required this.total,
    this.recordId,
    this.phase = 'prepare',
  });

  final String message;
  final int done;
  final int total;
  final String? recordId;
  final String phase;
}

class ParvandeServerSendResult {
  const ParvandeServerSendResult({
    required this.finalize,
    required this.sentRecords,
    required this.stoppedEarly,
  });

  final ImportFinalizeResult finalize;
  final int sentRecords;
  final bool stoppedEarly;
}

/// ارسال پرونده‌های محلی به سرور: آپلود تصاویر + import/session.
class ParvandeServerSend {
  ParvandeServerSend._();
  static final ParvandeServerSend instance = ParvandeServerSend._();

  static const defaultChunkSize = 25;

  final _syncApi = ImportSyncApi.instance;
  final _parvandeSync = ParvandeSyncService.instance;

  /// همهٔ پرونده‌های [records] را با تصاویر به سرور می‌فرستد.
  Future<ParvandeServerSendResult> sendAll({
    required String codeCo,
    required List<ImportDraftRecord> records,
    void Function(ParvandeServerSendProgress progress)? onProgress,
    bool Function()? shouldStop,
    int chunkSize = defaultChunkSize,
    /// برای ورود اکسل بدون تصویر — از آپلود/پاک‌سازی فایل محلی صرف‌نظر می‌شود.
    bool skipImagePreparation = false,
    bool verboseLog = false,
  }) async {
    if (records.isEmpty) {
      throw Exception('پرونده‌ای برای ارسال نیست.');
    }

    final debtOnlySession = records.every(
      (r) => (r.payload['_import_mode'] ?? '').toString().trim().toLowerCase() == 'debt_only',
    );

    AsnafOpLog.line(
      AsnafOpLog.send,
      'شروع | n=${records.length} debtOnly=$debtOnlySession codeCo=$codeCo skipImages=$skipImagePreparation',
    );
    onProgress?.call(
      ParvandeServerSendProgress(
        message: 'شروع نشست ارسال (${records.length} پرونده)…',
        done: 0,
        total: records.length,
        phase: 'session',
      ),
    );

    final session = await _syncApi.startSession(
      codeCo: codeCo,
      totalRecords: records.length,
      debtSyncOnly: debtOnlySession,
    );
    AsnafOpLog.line(AsnafOpLog.send, 'نشست ساخته شد | id=${session.sessionId}');
    if (verboseLog) {
      // ignore: avoid_print
      log(
        'session started | id=${session.sessionId} | records=${records.length} | codeCo=$codeCo',
        name: 'csv_import_test',
      );
    }

    final prepared = <ImportDraftRecord>[];
    final sentIds = <String>[];

    for (var i = 0; i < records.length; i++) {
      if (shouldStop?.call() == true) break;
      final r = records[i];
      final id = r.clientTempId;
      if (skipImagePreparation) {
        onProgress?.call(
          ParvandeServerSendProgress(
            message: 'آماده‌سازی ${i + 1}/${records.length} — id=$id',
            done: i,
            total: records.length,
            recordId: id,
            phase: 'prepare',
          ),
        );
        prepared.add(r);
      } else {
        onProgress?.call(
          ParvandeServerSendProgress(
            message: 'آماده‌سازی ${i + 1}/${records.length} — آپلود تصاویر id=$id',
            done: i,
            total: records.length,
            recordId: id,
            phase: 'images',
          ),
        );
        prepared.add(
          await _parvandeSync.prepareRecordForServer(
            codeCo: codeCo,
            record: r,
            onStep: (step) => onProgress?.call(
              ParvandeServerSendProgress(
                message: step,
                done: i,
                total: records.length,
                recordId: id,
                phase: 'images',
              ),
            ),
          ),
        );
      }
      sentIds.add(id);
    }

    if (prepared.isEmpty) {
      throw Exception('هیچ پرونده‌ای آماده نشد.');
    }

    final chunks = <List<ImportDraftRecord>>[];
    for (var i = 0; i < prepared.length; i += chunkSize) {
      final end = (i + chunkSize < prepared.length) ? i + chunkSize : prepared.length;
      chunks.add(prepared.sublist(i, end));
    }

    for (var i = 0; i < chunks.length; i++) {
      if (shouldStop?.call() == true) break;
      onProgress?.call(
        ParvandeServerSendProgress(
          message: 'ارسال دسته ${i + 1}/${chunks.length} (${chunks[i].length} پرونده)',
          done: (i * chunkSize).clamp(0, prepared.length),
          total: records.length,
          phase: 'batch',
        ),
      );
      AsnafOpLog.line(
        AsnafOpLog.send,
        'آپلود دسته ${i + 1}/${chunks.length} | n=${chunks[i].length}',
      );
      await _syncApi.uploadBatch(
        sessionId: session.sessionId,
        chunkIndex: i + 1,
        totalChunks: chunks.length,
        records: chunks[i],
      );
      if (verboseLog) {
        for (final r in chunks[i]) {
          final p = r.payload;
          log(
            'batch uploaded | id=${r.clientTempId} | shenase=${p['shenase_store']} | '
            'vaziyat=${p['vaziyat_store']}/${p['lbl_vaziyat_store']} | '
            'date_sodor=${p['date_sodor_store']} | lat=${p['lat_store']} lng=${p['long_store']}',
            name: 'csv_import_test',
          );
        }
      }
    }

    onProgress?.call(
      ParvandeServerSendProgress(
        message: 'نهایی‌سازی در سرور…',
        done: sentIds.length,
        total: records.length,
        phase: 'finalize',
      ),
    );

    AsnafOpLog.line(AsnafOpLog.send, 'نهایی‌سازی نشست ${session.sessionId}…');
    final fin = await _syncApi.finalizeSession(
      session.sessionId,
      verboseLog: verboseLog,
    );
    AsnafOpLog.line(
      AsnafOpLog.send,
      'نهایی شد | inserted=${fin.inserted} skipped=${fin.skipped} '
      'docs=${fin.docsInserted} failed=${fin.failed} sentIds=${sentIds.length}',
    );

    if (sentIds.isNotEmpty) {
      final sentSet = sentIds.toSet();
      await _parvandeSync.markRecordsSynced(
        codeCo,
        records.where((r) => sentSet.contains(r.clientTempId)),
      );
    }
    if (fin.inserted > 0 || sentIds.isNotEmpty) {
      await _syncApi.markParvandeImport(codeCo);
    }

    onProgress?.call(
      ParvandeServerSendProgress(
        message: 'ارسال انجام شد — ${fin.inserted} پرونده، ${fin.docsInserted} سند',
        done: sentIds.length,
        total: records.length,
        phase: 'done',
      ),
    );

    return ParvandeServerSendResult(
      finalize: fin,
      sentRecords: sentIds.length,
      stoppedEarly: shouldStop?.call() == true,
    );
  }
}
