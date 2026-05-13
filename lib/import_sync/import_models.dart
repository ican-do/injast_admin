import 'dart:convert';

class ImportDraftRecord {
  ImportDraftRecord({
    required this.clientTempId,
    required this.payload,
  });

  final String clientTempId;
  final Map<String, String> payload;

  /// بدنهٔ ساده برای ذخیرهٔ محلی.
  Map<String, dynamic> toJson() => {
        'client_temp_id': clientTempId,
        'payload': payload,
      };

  /// بدنهٔ ارسال به `/insert/import/session/batch`: علاوه بر payload، آرایهٔ `docs` را جدا می‌فرستد
  /// تا سرور بدون وابستگی به پارس مجدد رشتهٔ `_docs_json`، همان سناریوی processdoc را اجرا کند
  /// (طبق ASNAF_BOT_OPERATION_FLOW: ابتدا پرونده، سپس مستندات همان پرونده).
  Map<String, dynamic> toImportSessionRecordJson() {
    final docsList = <Map<String, dynamic>>[];
    final raw = payload['_docs_json'];
    if (raw != null && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          for (final e in decoded) {
            if (e is Map) {
              docsList.add(Map<String, dynamic>.from(e));
            }
          }
        }
      } catch (_) {}
    }
    return {
      'client_temp_id': clientTempId,
      'payload': payload,
      'docs': docsList,
    };
  }

  /// تعداد ردیف‌های آرایهٔ داخل `_docs_json` (برای لاگ؛ بدون تضمین معتبر بودن JSON).
  int persistedDocsCount() {
    final raw = payload['_docs_json'];
    if (raw == null || raw.trim().isEmpty) return 0;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) return decoded.length;
    } catch (_) {}
    return 0;
  }

  factory ImportDraftRecord.fromJson(Map<String, dynamic> json) {
    final rawPayload = (json['payload'] as Map?) ?? const {};
    return ImportDraftRecord(
      clientTempId: json['client_temp_id']?.toString() ?? '',
      payload: rawPayload.map((k, v) => MapEntry(k.toString(), v?.toString() ?? '')),
    );
  }
}

class ImportSessionResponse {
  ImportSessionResponse({
    required this.sessionId,
  });

  final String sessionId;

  factory ImportSessionResponse.fromJson(Map<String, dynamic> json) {
    return ImportSessionResponse(sessionId: json['session_id']?.toString() ?? '');
  }
}

/// پاسخ `POST .../insert/import/session/finalize` (برای نمایش به کاربر و لاگ).
class ImportFinalizeResult {
  ImportFinalizeResult({
    required this.success,
    required this.inserted,
    required this.skipped,
    required this.failed,
    required this.docsInserted,
    required this.docsRowAttempts,
    this.errors = const [],
  });

  final bool success;
  final int inserted;
  final int skipped;
  final int failed;
  final int docsInserted;
  final int docsRowAttempts;
  final List<dynamic> errors;

  factory ImportFinalizeResult.fromJson(Map<String, dynamic> json) {
    final err = json['errors'];
    return ImportFinalizeResult(
      success: json['success'] == true,
      inserted: int.tryParse('${json['inserted'] ?? 0}') ?? 0,
      skipped: int.tryParse('${json['skipped'] ?? 0}') ?? 0,
      failed: int.tryParse('${json['failed'] ?? 0}') ?? 0,
      docsInserted: int.tryParse('${json['docs_inserted'] ?? 0}') ?? 0,
      docsRowAttempts: int.tryParse('${json['docs_row_attempts'] ?? 0}') ?? 0,
      errors: err is List ? List<dynamic>.from(err) : const [],
    );
  }
}
