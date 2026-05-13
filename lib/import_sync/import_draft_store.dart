import 'dart:convert';
import 'dart:developer' show log;

import 'package:injast_admin/import_sync/import_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ImportDraftStore {
  static const _kDraftKey = 'import_sync_draft_records_v1';

  Future<void> save(List<ImportDraftRecord> records) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(records.map((e) => e.toJson()).toList());
    await prefs.setString(_kDraftKey, encoded);
    var totalDocRows = 0;
    for (final r in records) {
      final n = r.persistedDocsCount();
      totalDocRows += n;
      final jl = r.payload['_docs_json']?.length ?? 0;
      log(
        'stage=2_draft_local | parvaneh=${r.clientTempId} | parsed_list_len=$n | _docs_json_chars=$jl',
        name: 'asnaf_import_docs',
      );
    }
    log(
      'stage=2_draft_local_summary | records=${records.length} | total_parsed_doc_rows=$totalDocRows',
      name: 'asnaf_import_docs',
    );
  }

  /// خواندن پیش‌نویس از دیسک؛ لاگ `stage=2_draft_local_read` برای مقایسه با ذخیره.
  Future<List<ImportDraftRecord>> read() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kDraftKey);
    if (raw == null || raw.trim().isEmpty) return const [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    final list = decoded
        .whereType<Map>()
        .map((e) => ImportDraftRecord.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    var totalDocRows = 0;
    for (final r in list) {
      final n = r.persistedDocsCount();
      totalDocRows += n;
      log(
        'stage=2_draft_local_read | parvaneh=${r.clientTempId} | parsed_list_len=$n',
        name: 'asnaf_import_docs',
      );
    }
    if (list.isNotEmpty) {
      log(
        'stage=2_draft_local_read_summary | records=${list.length} | total_parsed_doc_rows=$totalDocRows',
        name: 'asnaf_import_docs',
      );
    }
    return list;
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kDraftKey);
  }
}
