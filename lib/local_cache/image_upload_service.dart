import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:injast_admin/file_management/store_image_service.dart';
import 'package:injast_admin/local_cache/local_image_store.dart';
import 'package:injast_admin/local_cache/parvande_local_db.dart';
import 'package:injast_admin/local_cache/server_media_paths.dart';
import 'package:injast_admin/server_config.dart';
import 'package:path/path.dart' as p;

/// آپلود فایل فیزیکی محلی به سرور؛ بدون دانلود از اصناف یا هر URL خارجی.
class ImageUploadService {
  ImageUploadService._();
  static final ImageUploadService instance = ImageUploadService._();

  final _localImages = LocalImageStore.instance;
  final _storeImages = StoreImageService.instance;

  Future<String> uploadLocalFile({
    required String codeCo,
    required String idParvandeh,
    required String fieldKey,
    required String localPath,
    void Function(String step)? onStep,
  }) async {
    final file = File(localPath);
    if (!await file.exists()) {
      throw Exception('فایل محلی یافت نشد: $fieldKey ($localPath)');
    }

    final ext = p.extension(localPath).toLowerCase();
    final filename =
        '${idParvandeh}_${fieldKey.replaceAll(':', '_')}${ext.isNotEmpty ? ext : '.jpg'}';

    onStep?.call('آپلود $fieldKey از دیسک…');
    final uri = Uri.parse(getApiUrl('upload/image'));
    final request = http.MultipartRequest('POST', uri)
      ..fields['path'] = 'parvande/$codeCo'
      ..fields['filename'] = filename
      ..files.add(await http.MultipartFile.fromPath('image', localPath));

    final streamed = await request.send().timeout(const Duration(minutes: 3));
    final res = await http.Response.fromStream(streamed);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('آپلود $fieldKey ناموفق (${res.statusCode}): ${res.body}');
    }

    final body = jsonDecode(res.body);
    if (body is! Map) {
      throw Exception('پاسخ نامعتبر از سرور برای $fieldKey');
    }
    final filePath = body['filePath']?.toString().trim() ?? '';
    if (filePath.isEmpty) {
      throw Exception('مسیر فایل از سرور برای $fieldKey خالی است');
    }

    await ParvandeLocalDb.instance.updateMediaLocal(
      codeCo,
      idParvandeh,
      fieldKey,
      serverUrl: filePath,
      downloadStatus: 'uploaded',
    );
    onStep?.call('✓ $fieldKey → $filePath');
    return filePath;
  }

  /// آپلود فقط فایل‌های فیزیکی موجود؛ URL اصناف از payload حذف می‌شود.
  Future<Map<String, String>> applyServerUrlsToPayload({
    required String codeCo,
    required String idParvandeh,
    required Map<String, String> payload,
    void Function(String step)? onStep,
  }) async {
    final out = Map<String, String>.from(payload);
    final assets = await ParvandeLocalDb.instance.listMedia(codeCo, idParvandeh);
    final diskFiles = await _localImages.listLocalFilesOnDisk(
      codeCo: codeCo,
      idParvandeh: idParvandeh,
    );

    Future<String?> serverPathForField(String fieldKey, String localPath) async {
      final asset = assets.where((a) => a.fieldKey == fieldKey).firstOrNull;
      var serverPath = asset?.serverUrl?.trim();
      if (serverPath != null && serverPath.isNotEmpty && ServerMediaPaths.isServerPath(serverPath)) {
        onStep?.call('↷ $fieldKey از قبل روی سرور');
        return serverPath;
      }
      return uploadLocalFile(
        codeCo: codeCo,
        idParvandeh: idParvandeh,
        fieldKey: fieldKey,
        localPath: localPath,
        onStep: onStep,
      );
    }

    for (final key in ServerMediaPaths.parvandeImageFields) {
      final localPath = diskFiles[key] ??
          await _localImages.resolveLocalPath(
            codeCo: codeCo,
            idParvandeh: idParvandeh,
            fieldKey: key,
          );
      if (localPath == null) {
        if (ServerMediaPaths.isExternalUrl(out[key])) {
          onStep?.call('⊘ $key — فایل محلی نیست؛ لینک اصناف حذف شد');
          out[key] = '';
        }
        continue;
      }
      final serverPath = await serverPathForField(key, localPath);
      if (serverPath != null && serverPath.isNotEmpty) {
        out[key] = serverPath;
      }
    }

    for (var i = 1; i <= StoreImageService.slotCount; i++) {
      final key = _storeImages.fieldKeyForSlot(i);
      final localPath = diskFiles[key] ??
          await _localImages.resolveLocalPath(
            codeCo: codeCo,
            idParvandeh: idParvandeh,
            fieldKey: key,
          );
      if (localPath == null) continue;
      onStep?.call('آپلود تصویر واحد p$i…');
      await _storeImages.uploadToServer(
        codeCo: codeCo,
        idParvandeh: idParvandeh,
        index: i,
        localPath: localPath,
      );
    }

    final docsRaw = out['_docs_json'];
    if (docsRaw != null && docsRaw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(docsRaw);
        if (decoded is List) {
          for (var i = 0; i < decoded.length; i++) {
            final e = decoded[i];
            if (e is! Map) continue;
            final idDoc = e['id_doc']?.toString().trim() ?? '';
            final keys = <String>{'doc:$i', if (idDoc.isNotEmpty) 'doc_$idDoc'};
            String? fieldKey;
            String? localPath;
            for (final k in keys) {
              if (diskFiles.containsKey(k)) {
                fieldKey = k;
                localPath = diskFiles[k];
                break;
              }
            }
            fieldKey ??= 'doc:$i';
            localPath ??= await _localImages.resolveLocalPath(
              codeCo: codeCo,
              idParvandeh: idParvandeh,
              fieldKey: fieldKey,
            );
            if (localPath == null) {
              if (ServerMediaPaths.isExternalUrl(e['link_doc']?.toString())) {
                e['link_doc'] = '';
              }
              continue;
            }
            final serverPath = await serverPathForField(fieldKey, localPath);
            if (serverPath != null && serverPath.isNotEmpty) {
              e['link_doc'] = serverPath;
            }
          }
          out['_docs_json'] = jsonEncode(decoded);
        }
      } catch (_) {}
    }

    ServerMediaPaths.sanitizeParvandeImageFields(out);
    out['_docs_json'] = ServerMediaPaths.sanitizeDocsJson(out['_docs_json']);

    return out;
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull {
    final it = iterator;
    if (it.moveNext()) return it.current;
    return null;
  }
}
