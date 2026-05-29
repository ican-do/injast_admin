import 'dart:io';

import 'package:injast_admin/file_management/store_image_logger.dart';
import 'package:http/http.dart' as http;
import 'package:injast_admin/file_management/media_file_urls.dart';
import 'package:injast_admin/local_cache/local_cache_paths.dart';
import 'package:injast_admin/local_cache/local_image_store.dart';
import 'package:injast_admin/local_cache/parvande_local_db.dart';
import 'package:injast_admin/server_config.dart';
import 'package:path/path.dart' as p;

/// مدیریت ۴ تصویر دلخواه واحد صنفی (store/p1..p4)
class StoreImageService {
  StoreImageService._();
  static final StoreImageService instance = StoreImageService._();

  static const slotCount = 4;

  String fieldKeyForSlot(int index) => 'store:p$index';

  String serverFilename(String codeCo, String idParvandeh, int index) =>
      '${codeCo}_${idParvandeh}p$index';

  String remoteUrl(String codeCo, String idParvandeh, int index) =>
      MediaFileUrls.storeImageUrl(
        codeCo: codeCo,
        idParvandeh: idParvandeh,
        index: index,
      );

  Future<String?> localPath(String codeCo, String idParvandeh, int index) {
    return LocalImageStore.instance.resolveLocalPath(
      codeCo: codeCo,
      idParvandeh: idParvandeh,
      fieldKey: fieldKeyForSlot(index),
    );
  }

  Future<void> saveLocalCopy({
    required String codeCo,
    required String idParvandeh,
    required int index,
    required String sourcePath,
  }) async {
    final file = File(sourcePath);
    if (!await file.exists()) return;
    final bytes = await file.readAsBytes();
    final ext = p.extension(sourcePath).isEmpty ? '.jpg' : p.extension(sourcePath);
    final dirPath = await LocalCachePaths.parvandeMediaDir(codeCo, idParvandeh);
    if (dirPath == null) return;
    final dir = Directory(dirPath);
    if (!await dir.exists()) await dir.create(recursive: true);
    final safeKey = fieldKeyForSlot(index).replaceAll(RegExp(r'[^\w.-]'), '_');
    final dest = File(p.join(dir.path, '$safeKey$ext'));
    await dest.writeAsBytes(bytes);

    try {
      await ParvandeLocalDb.instance.upsertMediaAsset(
        codeCo: codeCo,
        idParvandeh: idParvandeh,
        fieldKey: fieldKeyForSlot(index),
        remoteUrl: remoteUrl(codeCo, idParvandeh, index),
        localPath: dest.path,
        downloadStatus: 'local',
      );
    } catch (e) {
      logStoreImage('saveLocalCopy db skip: $e');
    }
  }

  Future<String?> uploadToServer({
    required String codeCo,
    required String idParvandeh,
    required int index,
    required String localPath,
  }) async {
    final uri = Uri.parse(getApiUrl('upload/image'));
    logStoreImage('upload POST $uri file=$localPath');

    final request = http.MultipartRequest('POST', uri)
      ..fields['path'] = 'store'
      ..fields['filename'] = serverFilename(codeCo, idParvandeh, index)
      ..files.add(await http.MultipartFile.fromPath('image', localPath));

    final streamed = await request.send().timeout(const Duration(seconds: 90));
    final res = await http.Response.fromStream(streamed);
    logStoreImage('upload status=${res.statusCode} body=${res.body}');

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('آپلود تصویر $index ناموفق (${res.statusCode}): ${res.body}');
    }

    try {
      await ParvandeLocalDb.instance.upsertMediaAsset(
        codeCo: codeCo,
        idParvandeh: idParvandeh,
        fieldKey: fieldKeyForSlot(index),
        remoteUrl: remoteUrl(codeCo, idParvandeh, index),
        localPath: localPath,
        downloadStatus: 'uploaded',
      );
    } catch (e) {
      logStoreImage('upload db skip: $e');
    }
    return remoteUrl(codeCo, idParvandeh, index);
  }
}
