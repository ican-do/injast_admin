import 'dart:convert';
import 'dart:developer' show log;

import 'package:injast_admin/injast_http.dart' as http;
import 'package:injast_admin/import_sync/import_models.dart';
import 'package:injast_admin/server_config.dart';

class ImportSyncApi {
  ImportSyncApi._();
  static final ImportSyncApi instance = ImportSyncApi._();

  Future<ImportSessionResponse> startSession({
    required String codeCo,
    required int totalRecords,
    /// اگر true باشد، در finalize فقط فیلد money با تطبیق shenase_store + code_co به‌روز می‌شود.
    bool debtSyncOnly = false,
  }) async {
    final uri = Uri.parse(getApiUrl('insert/import/session/start'));
    final res = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'code_co': codeCo,
        'total_records': totalRecords,
        if (debtSyncOnly) 'debt_sync_only': true,
      }),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('خطا در شروع سشن انتقال (${res.statusCode})');
    }
    final body = jsonDecode(res.body);
    if (body is! Map<String, dynamic>) {
      throw Exception('پاسخ نامعتبر از سرور در شروع سشن');
    }
    return ImportSessionResponse.fromJson(body);
  }

  Future<void> uploadBatch({
    required String sessionId,
    required int chunkIndex,
    required int totalChunks,
    required List<ImportDraftRecord> records,
  }) async {
    await _uploadBatchAdaptive(
      sessionId: sessionId,
      chunkIndex: chunkIndex,
      totalChunks: totalChunks,
      records: records,
      depth: 0,
    );
  }

  Future<void> _uploadBatchAdaptive({
    required String sessionId,
    required int chunkIndex,
    required int totalChunks,
    required List<ImportDraftRecord> records,
    required int depth,
  }) async {
    if (records.isEmpty) return;
    final uri = Uri.parse(getApiUrl('insert/import/session/batch'));
    final bodyRecords = records.map((e) => e.toImportSessionRecordJson()).toList();
    var sumDocsArray = 0;
    for (final m in bodyRecords) {
      final id = m['client_temp_id']?.toString() ?? '';
      final docs = m['docs'];
      final n = docs is List ? docs.length : 0;
      sumDocsArray += n;
      final p = m['payload'];
      final jl = (p is Map && p['_docs_json'] != null) ? p['_docs_json'].toString().length : 0;
      log(
        'stage=3_http_batch | chunk=$chunkIndex/$totalChunks depth=$depth | parvaneh=$id | '
        'docs_array_len=$n | _docs_json_chars=$jl',
        name: 'asnaf_import_docs',
      );
    }
    log(
      'stage=3_http_batch_summary | chunk=$chunkIndex | records=${bodyRecords.length} | '
      'sum_docs_array=$sumDocsArray',
      name: 'asnaf_import_docs',
    );
    final res = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'session_id': sessionId,
        'chunk_index': chunkIndex,
        'total_chunks': totalChunks,
        'records': bodyRecords,
      }),
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      log(
        'stage=3_http_batch_post_ok | chunk=$chunkIndex | status=${res.statusCode}',
        name: 'asnaf_import_docs',
      );
      return;
    }

    // 413: درخواست خیلی بزرگ است؛ به‌صورت خودکار batch را نصف می‌کنیم و دوباره می‌فرستیم.
    if (res.statusCode == 413 && records.length > 1 && depth < 8) {
      final mid = records.length ~/ 2;
      final left = records.sublist(0, mid);
      final right = records.sublist(mid);
      await _uploadBatchAdaptive(
        sessionId: sessionId,
        chunkIndex: chunkIndex,
        totalChunks: totalChunks,
        records: left,
        depth: depth + 1,
      );
      await _uploadBatchAdaptive(
        sessionId: sessionId,
        chunkIndex: chunkIndex,
        totalChunks: totalChunks,
        records: right,
        depth: depth + 1,
      );
      return;
    }
    throw Exception('خطا در ارسال دسته اطلاعات (${res.statusCode})');
  }

  Future<ImportFinalizeResult> finalizeSession(
    String sessionId, {
    bool verboseLog = false,
  }) async {
    final uri = Uri.parse(getApiUrl('insert/import/session/finalize'));
    final res = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'session_id': sessionId}),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      if (verboseLog) {
        log(
          'finalize HTTP ${res.statusCode} | body=${res.body}',
          name: 'csv_import_test',
        );
      }
      throw Exception('خطا در نهایی‌سازی انتقال (${res.statusCode})');
    }
    final body = jsonDecode(res.body);
    if (body is! Map<String, dynamic>) {
      throw Exception('پاسخ نامعتبر از سرور در نهایی‌سازی');
    }
    if (verboseLog) {
      log('finalize raw response: $body', name: 'csv_import_test');
    }
    final result = ImportFinalizeResult.fromJson(body);
    if (verboseLog) {
      log(
        'finalize parsed | success=${result.success} inserted=${result.inserted} '
        'skipped=${result.skipped} failed=${result.failed} errors=${result.errors}',
        name: 'csv_import_test',
      );
    }
    return result;
  }

  Future<void> markParvandeImport(String codeCo) async {
    final code = codeCo.trim();
    if (code.isEmpty) return;
    try {
      await http.post(
        Uri.parse(getApiUrl('insert/import/mark-updated')),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'code_co': code}),
      );
    } catch (_) {}
  }
}
