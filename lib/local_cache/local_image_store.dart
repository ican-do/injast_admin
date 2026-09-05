import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:injast_admin/injast_http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:injast_admin/import_sync/asnaf_api_throttle.dart';
import 'package:injast_admin/import_sync/asnaf_jwt_policy.dart';
import 'package:injast_admin/file_management/media_file_urls.dart';
import 'package:injast_admin/local_cache/local_cache_paths.dart';
import 'package:injast_admin/local_cache/parvande_local_db.dart';

/// دانلود و نگهداری فیزیکی تصاویر پرونده و اسناد.
class LocalImageStore {
  LocalImageStore._();
  static final LocalImageStore instance = LocalImageStore._();

  static const _parvandeImageFields = [
    'image_profile',
    'image_parvaneh',
    'licence_file'
  ];
  static const _asnafImageBase = 'https://apinovin.iranianasnaf.ir/';

  Future<Directory?> _unionDir(String codeCo) async {
    if (kIsWeb) return null;
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, 'asnaf_cache', codeCo));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  String normalizeRemoteUrl(String raw) {
    final candidates = MediaFileUrls.mediaUrlCandidates(raw);
    if (candidates.isNotEmpty) {
      return candidates.first;
    }
    var normalized = raw.trim().replaceAll('\\', '/');
    if (normalized.isEmpty || normalized.toLowerCase() == 'null') return '';
    if (normalized.startsWith('http://') || normalized.startsWith('https://')) {
      return normalized;
    }
    if (normalized.startsWith('apinovin.iranianasnaf.ir')) {
      return 'https://${normalized.replaceFirst(RegExp(r'^/+'), '')}';
    }
    normalized = normalized.replaceFirst(RegExp(r'^/+'), '');
    return '$_asnafImageBase$normalized';
  }

  String _extensionFromUrl(String url, {List<int>? bodyBytes}) {
    final path = Uri.tryParse(url)?.path ?? url;
    var ext = p.extension(path).toLowerCase();
    if (ext == '.jpeg') ext = '.jpg';
    const known = {'.png', '.jpg', '.webp', '.gif', '.pdf', '.bmp'};
    if (known.contains(ext)) return ext;

    if (bodyBytes != null && bodyBytes.length >= 4) {
      if (bodyBytes[0] == 0x25 &&
          bodyBytes[1] == 0x50 &&
          bodyBytes[2] == 0x44 &&
          bodyBytes[3] == 0x46) {
        return '.pdf';
      }
      if (bodyBytes[0] == 0x89 && bodyBytes[1] == 0x50) return '.png';
      if (bodyBytes[0] == 0xFF && bodyBytes[1] == 0xD8) return '.jpg';
    }
    return '.jpg';
  }

  Future<String?> downloadToFile({
    required String codeCo,
    required String idParvandeh,
    required String fieldKey,
    required String remoteUrl,
    bool fastMode = false,
  }) async {
    final url = normalizeRemoteUrl(remoteUrl);
    if (url.isEmpty || kIsWeb) return null;

    final union = await _unionDir(codeCo);
    if (union == null) return null;

    final parvDir = Directory(p.join(union.path, idParvandeh));
    if (!await parvDir.exists()) {
      await parvDir.create(recursive: true);
    }

    final safeKey = fieldKey.replaceAll(RegExp(r'[^\w.-]'), '_');

    try {
      if (!fastMode) {
        await AsnafApiThrottle.instance.waitTurn();
      }
      final res = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': AsnafJwtPolicy.browserUserAgent,
          'Referer': 'https://iranianasnaf.ir/panel/',
        },
      ).timeout(const Duration(seconds: 90));
      if (res.statusCode < 200 || res.statusCode >= 300) {
        await ParvandeLocalDb.instance.upsertMediaAsset(
          codeCo: codeCo,
          idParvandeh: idParvandeh,
          fieldKey: fieldKey,
          remoteUrl: remoteUrl,
          downloadStatus: 'failed',
        );
        return null;
      }
      if (!_isAcceptedDownload(
        bytes: res.bodyBytes,
        fieldKey: fieldKey,
        contentType: res.headers['content-type'],
      )) {
        await ParvandeLocalDb.instance.upsertMediaAsset(
          codeCo: codeCo,
          idParvandeh: idParvandeh,
          fieldKey: fieldKey,
          remoteUrl: remoteUrl,
          downloadStatus: 'failed',
        );
        return null;
      }
      final ext = _extensionFromUrl(url, bodyBytes: res.bodyBytes);
      final filePath = p.join(parvDir.path, '$safeKey$ext');
      final file = File(filePath);
      await file.writeAsBytes(res.bodyBytes);
      await ParvandeLocalDb.instance.upsertMediaAsset(
        codeCo: codeCo,
        idParvandeh: idParvandeh,
        fieldKey: fieldKey,
        remoteUrl: remoteUrl,
        localPath: filePath,
        downloadStatus: 'done',
      );
      return filePath;
    } catch (_) {
      await ParvandeLocalDb.instance.upsertMediaAsset(
        codeCo: codeCo,
        idParvandeh: idParvandeh,
        fieldKey: fieldKey,
        remoteUrl: remoteUrl,
        downloadStatus: 'failed',
      );
      return null;
    }
  }

  bool _isAcceptedDownload({
    required List<int> bytes,
    required String fieldKey,
    String? contentType,
  }) {
    if (bytes.isEmpty || bytes.length < 32) return false;
    final type = (contentType ?? '').toLowerCase();
    final looksImage = bytesLookLikeImage(bytes) || type.startsWith('image/');
    final looksPdf = bytesLookLikePdf(bytes) || type.contains('pdf');
    final looksHtml = bytesLookLikeParvanehHtml(bytes);
    final isBinaryAttachment =
        type.contains('octet-stream') || type.contains('application/');

    if (fieldKey == 'image_profile' || fieldKey.startsWith('store:')) {
      return looksImage;
    }
    if (fieldKey == 'image_parvaneh' || fieldKey == 'licence_file') {
      return looksImage || looksPdf || looksHtml || isBinaryAttachment;
    }
    if (fieldKey.startsWith('doc')) {
      return looksImage || looksPdf || isBinaryAttachment;
    }
    return looksImage || looksPdf || looksHtml || isBinaryAttachment;
  }

  /// دانلود فیلدهای تصویر پرونده + لینک‌های اسناد.
  Future<void> syncAllMediaForPayload({
    required String codeCo,
    required String idParvandeh,
    required Map<String, String> payload,
    bool fastMode = false,
  }) async {
    if (kIsWeb) return;

    Future<void> pause() async {
      if (fastMode) return;
      await AsnafApiThrottle.instance
          .randomBetweenSteps(minMs: 2000, maxMs: 5000);
    }

    for (final key in _parvandeImageFields) {
      final raw = payload[key]?.trim() ?? '';
      if (raw.isEmpty) continue;
      await downloadToFile(
        codeCo: codeCo,
        idParvandeh: idParvandeh,
        fieldKey: key,
        remoteUrl: raw,
        fastMode: fastMode,
      );
      await pause();
    }

    final docsRaw = payload['_docs_json'];
    if (docsRaw == null || docsRaw.trim().isEmpty) return;
    try {
      final decoded = jsonDecode(docsRaw);
      if (decoded is! List) return;
      for (var i = 0; i < decoded.length; i++) {
        final e = decoded[i];
        if (e is! Map) continue;
        final link = _docLinkFromDynamicMap(e);
        if (link.isEmpty) continue;
        final idDoc = e['id_doc']?.toString().trim() ?? '';
        final fieldKey = idDoc.isNotEmpty ? 'doc_$idDoc' : 'doc:$i';
        await downloadToFile(
          codeCo: codeCo,
          idParvandeh: idParvandeh,
          fieldKey: fieldKey,
          remoteUrl: link,
          fastMode: fastMode,
        );
        await pause();
      }
    } catch (_) {}
  }

  /// مسیر محلی برای نمایش؛ اگر فایل وجود نداشت null.
  Future<String?> localPathForField(
    String codeCo,
    String idParvandeh,
    String fieldKey,
  ) async {
    final assets =
        await ParvandeLocalDb.instance.listMedia(codeCo, idParvandeh);
    for (final a in assets) {
      if (a.fieldKey == fieldKey && a.localPath != null) {
        final f = File(a.localPath!);
        if (await f.exists()) return a.localPath;
      }
    }
    return null;
  }

  String _docLinkFromDynamicMap(Map e) {
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
      final value = e[key]?.toString().trim() ?? '';
      if (value.isNotEmpty && value.toLowerCase() != 'null') {
        return value;
      }
    }
    return '';
  }

  /// مسیر فایل فیزیکی روی دیسک — بدون هیچ درخواست شبکه.
  Future<String?> resolveLocalPath({
    required String codeCo,
    required String idParvandeh,
    required String fieldKey,
  }) async {
    final fromDb = await localPathForField(codeCo, idParvandeh, fieldKey);
    if (fromDb != null) return fromDb;

    if (kIsWeb) return null;
    final dirPath = await LocalCachePaths.parvandeMediaDir(codeCo, idParvandeh);
    if (dirPath == null) return null;
    final dir = Directory(dirPath);
    if (!await dir.exists()) return null;

    final safeKey = fieldKey.replaceAll(RegExp(r'[^\w.-]'), '_');
    await for (final entity in dir.list()) {
      if (entity is! File) continue;
      if (p.basenameWithoutExtension(entity.path) == safeKey) {
        return entity.path;
      }
    }
    return null;
  }

  /// همهٔ فایل‌های فیزیکی موجود برای یک پرونده (fieldKey → مسیر محلی).
  Future<Map<String, String>> listLocalFilesOnDisk({
    required String codeCo,
    required String idParvandeh,
  }) async {
    final out = <String, String>{};
    if (kIsWeb) return out;

    for (final key in _parvandeImageFields) {
      final path = await resolveLocalPath(
        codeCo: codeCo,
        idParvandeh: idParvandeh,
        fieldKey: key,
      );
      if (path != null) out[key] = path;
    }

    final dirPath = await LocalCachePaths.parvandeMediaDir(codeCo, idParvandeh);
    if (dirPath == null) return out;
    final dir = Directory(dirPath);
    if (!await dir.exists()) return out;

    await for (final entity in dir.list()) {
      if (entity is! File) continue;
      final stem = p.basenameWithoutExtension(entity.path);
      if (stem.startsWith('doc_')) {
        out[stem] = entity.path;
        if (RegExp(r'^doc_\d+$').hasMatch(stem)) {
          out[stem.replaceFirst('_', ':')] = entity.path;
        }
      }
      if (stem.startsWith('store_p')) {
        out[stem.replaceFirst('store_p', 'store:p')] = entity.path;
      }
    }
    return out;
  }
}
