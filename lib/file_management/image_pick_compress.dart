import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:injast_admin/file_management/store_image_logger.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// انتخاب تصویر (موبایل + دسکتاپ) و فشرده‌سازی خودکار تا حداکثر ۵۰۰ کیلوبایت
class ImagePickCompress {
  ImagePickCompress._();

  static const int maxBytes = 500 * 1024;
  static final ImagePicker _picker = ImagePicker();

  static bool get isDesktop =>
      !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

  /// [useCamera] فقط روی موبایل معنا دارد؛ روی دسکتاپ همیشه فایل از دیسک.
  static Future<ImagePickResult?> pick({required bool useCamera}) async {
    logStoreImage('pick start desktop=$isDesktop camera=$useCamera');
    try {
      final sourcePath = useCamera && !isDesktop
          ? await _pickMobile(ImageSource.camera)
          : isDesktop
              ? await _pickDesktop()
              : await _pickMobile(ImageSource.gallery);
      if (sourcePath == null) {
        logStoreImage('pick cancelled (no file)');
        return null;
      }

      logStoreImage('picked path=$sourcePath');
      final rawSize = await File(sourcePath).length();
      logStoreImage('compress start size=$rawSize');
      final compressedPath = await _compressToTempFile(sourcePath);
      final outSize = await File(compressedPath).length();
      logStoreImage('compress done out=$compressedPath bytes=$outSize');
      return ImagePickResult(
        path: compressedPath,
        originalBytes: rawSize,
        compressedBytes: outSize,
        wasCompressed: outSize < rawSize || !sourcePath.toLowerCase().endsWith('.jpg'),
      );
    } on PlatformException catch (e) {
      logStoreImage('pick PlatformException: ${e.code} ${e.message}');
      rethrow;
    } catch (e, st) {
      logStoreImage('pick error: $e\n$st');
      rethrow;
    }
  }

  /// دسکتاپ: image_picker (file_selector) — همان روش injast_v3
  static Future<String?> _pickDesktop() async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    try {
      logStoreImage('image_picker gallery (desktop)…');
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 2400,
        maxHeight: 2400,
        imageQuality: 100,
      );
      logStoreImage('image_picker result: ${picked?.path ?? 'null'}');
      if (picked?.path != null) return picked!.path;
    } on MissingPluginException catch (e) {
      logStoreImage('image_picker unavailable: $e');
    }

    try {
      logStoreImage('file_picker fallback…');
      final result = await FilePicker.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: false,
      );
      if (result == null || result.files.isEmpty) {
        logStoreImage('file_picker cancelled');
        return null;
      }
      final path = result.files.single.path;
      logStoreImage('file_picker returned: $path');
      return path;
    } on MissingPluginException catch (e) {
      logStoreImage('file_picker unavailable: $e');
      throw MissingPluginException(
        'انتخاب فایل در دسترس نیست. اپ را کامل stop کنید و دوباره run کنید (flutter clean && flutter run -d macos).',
      );
    }
  }

  static Future<String?> _pickMobile(ImageSource source) async {
    logStoreImage('image_picker source=$source');
    final picked = await _picker.pickImage(source: source, imageQuality: 100);
    logStoreImage('image_picker result: ${picked?.path ?? 'null'}');
    return picked?.path;
  }

  static Future<String> _compressToTempFile(String sourcePath) async {
    final raw = await File(sourcePath).readAsBytes();
    final compressed = await compute(_compressIsolate, raw);
    final dir = await getTemporaryDirectory();
    final out = p.join(dir.path, 'injast_${DateTime.now().millisecondsSinceEpoch}.jpg');
    await File(out).writeAsBytes(compressed, flush: true);
    return out;
  }

  static Uint8List _compressIsolate(Uint8List raw) => compressBytes(raw);

  static Uint8List compressBytes(Uint8List raw, {int limit = maxBytes}) {
    final decoded = img.decodeImage(raw);
    if (decoded == null) {
      throw FormatException('فرمت تصویر پشتیبانی نمی‌شود.');
    }

    final base = img.bakeOrientation(decoded);
    var w = base.width;
    var h = base.height;
    var quality = 85;
    Uint8List best = raw;

    for (var pass = 0; pass < 28; pass++) {
      final resized = (w == base.width && h == base.height)
          ? base
          : img.copyResize(
              base,
              width: w,
              height: h,
              interpolation: img.Interpolation.linear,
            );
      final bytes = Uint8List.fromList(img.encodeJpg(resized, quality: quality));
      best = bytes;
      if (bytes.length <= limit) return bytes;

      if (quality > 32) {
        quality -= 7;
      } else if (w > 280 || h > 210) {
        w = (w * 0.82).round().clamp(240, base.width);
        h = (h * 0.82).round().clamp(180, base.height);
        quality = 72;
      } else if (quality > 18) {
        quality -= 4;
      } else {
        break;
      }
    }
    return best;
  }

  static String formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    final kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
    return '${(kb / 1024).toStringAsFixed(2)} MB';
  }
}

class ImagePickResult {
  const ImagePickResult({
    required this.path,
    required this.originalBytes,
    required this.compressedBytes,
    required this.wasCompressed,
  });

  final String path;
  final int originalBytes;
  final int compressedBytes;
  final bool wasCompressed;
}
