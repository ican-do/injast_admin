import 'dart:typed_data';

import 'package:injast_admin/file_management/hagh_ozviat_api.dart';
import 'package:injast_admin/file_management/hagh_ozviat_models.dart';
import 'package:injast_admin/file_management/hagh_ozviat_registry.dart';
import 'package:injast_admin/file_management/hagh_ozviat_file_parser.dart';
import 'package:injast_admin/file_management/parvande_api.dart';
import 'package:injast_admin/local_cache/parvande_cache_list_service.dart';

class HaghOzviatImportService {
  HaghOzviatImportService(this.codeCo);

  final String codeCo;
  final _api = HaghOzviatApi.instance;

  Future<HaghOzviatAnalysis> analyzeFile({
    required String fileName,
    required Uint8List bytes,
  }) async {
    final registry = await _loadRegistry();
    return HaghOzviatFileParser.analyze(
      fileName: fileName,
      bytes: bytes,
      registry: registry,
    );
  }

  Future<HaghOzviatRegistry> _loadRegistry() async {
    final merged = <Map<String, dynamic>>[];
    final seen = <String>{};

    void addRows(List<Map<String, dynamic>> rows) {
      for (final row in rows) {
        final id = row['id_parvandeh']?.toString().trim() ?? '';
        final key = id.isNotEmpty ? id : row['shenase_store']?.toString() ?? '';
        if (key.isNotEmpty && seen.contains(key)) continue;
        if (key.isNotEmpty) seen.add(key);
        merged.add(row);
      }
    }

    try {
      addRows(await ParvandeCacheListService.instance.fetchAllFromCache(codeCo));
    } catch (_) {}

    try {
      addRows(await ParvandeApi.instance.fetchAll(codeCo));
    } catch (_) {}

    return HaghOzviatRegistry.fromParvandeRows(merged);
  }

  Future<HaghOzviatSyncResult> runSync({
    required List<HaghOzviatRow> rows,
    void Function(HaghOzviatSyncProgress progress)? onProgress,
  }) =>
      _api.syncReplaceAll(
        codeCo: codeCo,
        rows: rows,
        onProgress: onProgress,
      );
}
