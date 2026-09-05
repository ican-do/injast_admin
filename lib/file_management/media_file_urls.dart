import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:injast_admin/injast_http.dart' as http;
import 'package:injast_admin/server_config.dart';

/// نوع محتوای پروانه
enum ParvanehContentKind { html, pdf, image }

/// ساخت URL فایل‌های رسانه‌ای
class MediaFileUrls {
  MediaFileUrls._();

  static String get mediaHost => mediaOrigin;

  /// تصویر دلخواه واحد صنفی (p1..p4)
  static String storeImageUrl({
    required String codeCo,
    required String idParvandeh,
    required int index,
  }) {
    return '$mediaOrigin/pic_injast/store/${codeCo}_${idParvandeh}p$index.jpg';
  }

  /// URL قابل نمایش برای image_profile / licence_file / link_doc و …
  static String? resolveImageUrl(String? raw) {
    final urls = mediaUrlCandidates(raw);
    return urls.isEmpty ? null : urls.first;
  }

  /// چند URL محتمل برای یک فایل روی سرور یا CDN اصناف
  static List<String> mediaUrlCandidates(String? raw) {
    final urls = <String>[];
    void add(String? u) {
      if (u == null || u.isEmpty) return;
      if (!urls.contains(u)) urls.add(u);
    }

    final t = raw?.trim() ?? '';
    if (t.isEmpty || t.toLowerCase() == 'null') return urls;

    var normalized = t.replaceAll('\\', '/');
    if (normalized.startsWith('http://') || normalized.startsWith('https://')) {
      add(normalized.replaceAll(' ', '%20'));
      return urls;
    }

    if (normalized.startsWith('/pic_injast/') ||
        normalized.startsWith('pic_injast/')) {
      final path = normalized.startsWith('/') ? normalized : '/$normalized';
      add('$serverApiBaseUrl$path'.replaceAll(' ', '%20'));
      add('$mediaHost$path'.replaceAll(' ', '%20'));
      return urls;
    }

    if (normalized.startsWith('apinovin.iranianasnaf.ir')) {
      normalized = normalized.replaceFirst(RegExp(r'^/+'), '');
      add('https://$normalized'.replaceAll(' ', '%20'));
      return urls;
    }

    final rel = normalized.replaceFirst(RegExp(r'^/+'), '');
    add('https://apinovin.iranianasnaf.ir/$rel'.replaceAll(' ', '%20'));
    add('$serverApiBaseUrl/$rel'.replaceAll(' ', '%20'));
    return urls;
  }

  /// چند URL محتمل برای تصویر پروفایل (سرور + CDN اصناف)
  static List<String> profileImageCandidates(String? raw) {
    return mediaUrlCandidates(raw);
  }

  /// آیا فایل روی سرور موجود است؟ (HEAD و در صورت نیاز GET کوتاه)
  static Future<bool> urlExists(String url) async {
    try {
      final uri = Uri.parse(url);
      final head = await http.head(uri).timeout(const Duration(seconds: 10));
      if (head.statusCode >= 200 && head.statusCode < 300) return true;
      if (head.statusCode == 405 || head.statusCode == 404) {
        final get = await http.get(uri).timeout(const Duration(seconds: 12));
        return get.statusCode >= 200 &&
            get.statusCode < 300 &&
            get.bodyBytes.length > 80 &&
            (bytesLookLikeImage(get.bodyBytes) ||
                bytesLookLikePdf(get.bodyBytes));
      }
    } catch (_) {}
    return false;
  }

  static Future<bool> storeImageExists({
    required String codeCo,
    required String idParvandeh,
    required int index,
  }) {
    return urlExists(
        storeImageUrl(codeCo: codeCo, idParvandeh: idParvandeh, index: index));
  }

  /// URLهای دانلود پروانه — فقط سرور 194.5.175.180 (بدون apinovin)
  static List<String> parvanehDownloadUrls(String? raw) {
    final path = _serverPathWithSlash(raw);
    if (path == null) return const [];

    final urls = <String>{};
    void addPath(String p) {
      urls.add('$serverApiBaseUrl$p');
      urls.add('$mediaHost$p');
    }

    addPath(path);

    if (path.toLowerCase().endsWith('.jpg') ||
        path.toLowerCase().endsWith('.jpeg')) {
      final pdf =
          path.replaceAll(RegExp(r'\.jpe?g$', caseSensitive: false), '.pdf');
      final html =
          path.replaceAll(RegExp(r'\.jpe?g$', caseSensitive: false), '.html');
      addPath(pdf);
      addPath(html);
    }

    final list = urls.toList();
    list.sort((a, b) {
      int score(String u) {
        var s = 0;
        if (u.contains(':8080')) s += 5;
        if (u.toLowerCase().endsWith('.jpg')) s += 3;
        if (u.toLowerCase().endsWith('.html')) s += 2;
        if (u.toLowerCase().endsWith('.pdf')) s += 1;
        return s;
      }

      return score(b).compareTo(score(a));
    });
    return list;
  }

  /// @deprecated — از parvanehDownloadUrls استفاده کنید
  static List<String> parvanehUrlCandidates(String? raw) =>
      parvanehDownloadUrls(raw);

  static String? parvanehLocalBaseName(String? raw) {
    final path = _serverPathWithSlash(raw);
    if (path == null) return null;
    final fileName = path.split('/').last;
    if (fileName.isEmpty) return null;
    return fileName.replaceAll(
        RegExp(r'\.(jpe?g|pdf|html)$', caseSensitive: false), '');
  }

  /// baseUrl برای بارگذاری CSS/تصاویر نسبی داخل HTML پروانه
  static String baseUrlForParvanehFetch(String fetchUrl) {
    final uri = Uri.tryParse(fetchUrl);
    if (uri == null) return '$mediaHost/';
    return '${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}/';
  }

  /// دانلود پروانه — HTML / PDF / تصویر
  static Future<
      ({
        List<int> bytes,
        String url,
        String baseName,
        ParvanehContentKind kind,
      })?> fetchParvanehContent(
    String? raw, {
    void Function(String message)? onAttempt,
  }) async {
    final baseName = parvanehLocalBaseName(raw);
    if (baseName == null || baseName.isEmpty) return null;

    for (final url in parvanehDownloadUrls(raw)) {
      if (url.contains('apinovin.iranianasnaf.ir')) continue;

      onAttempt?.call('GET $url');
      logParvanehDebug('GET $url');
      try {
        final res =
            await http.get(Uri.parse(url)).timeout(const Duration(seconds: 90));
        onAttempt
            ?.call('پاسخ ${res.statusCode} (${res.bodyBytes.length} بایت)');
        logParvanehDebug(
            '  status=${res.statusCode} bytes=${res.bodyBytes.length}');
        if (res.statusCode < 200 ||
            res.statusCode >= 300 ||
            res.bodyBytes.isEmpty) {
          continue;
        }

        if (bytesLookLikeParvanehHtml(res.bodyBytes)) {
          onAttempt?.call('تشخیص: HTML پروانه');
          logParvanehDebug('  kind=html (license template)');
          return (
            bytes: res.bodyBytes,
            url: url,
            baseName: baseName,
            kind: ParvanehContentKind.html
          );
        }
        if (bytesLookLikePdf(res.bodyBytes)) {
          onAttempt?.call('تشخیص: PDF');
          return (
            bytes: res.bodyBytes,
            url: url,
            baseName: baseName,
            kind: ParvanehContentKind.pdf
          );
        }
        if (bytesLookLikeImage(res.bodyBytes)) {
          onAttempt?.call('تشخیص: تصویر');
          return (
            bytes: res.bodyBytes,
            url: url,
            baseName: baseName,
            kind: ParvanehContentKind.image
          );
        }
        if (bytesLookLikeHtml(res.bodyBytes)) {
          onAttempt?.call('رد شد: HTML نامعتبر');
          continue;
        }
      } catch (e) {
        onAttempt?.call('خطا: $e');
        logParvanehDebug('  error: $e');
      }
    }
    return null;
  }

  static String? _serverPathWithSlash(String? raw) {
    final t = raw?.trim() ?? '';
    if (t.isEmpty || t.toLowerCase() == 'null') return null;
    var normalized = t.replaceAll('\\', '/');
    if (normalized.startsWith('http://') || normalized.startsWith('https://')) {
      final uri = Uri.tryParse(normalized);
      if (uri == null) return null;
      if (uri.host.contains('apinovin.iranianasnaf.ir')) return null;
      return uri.path.isEmpty ? null : uri.path;
    }
    if (normalized.startsWith('apinovin.iranianasnaf.ir')) return null;
    if (!normalized.startsWith('/')) normalized = '/$normalized';
    return normalized;
  }

  static String extensionForKind(ParvanehContentKind kind) {
    switch (kind) {
      case ParvanehContentKind.html:
        return '.html';
      case ParvanehContentKind.pdf:
        return '.pdf';
      case ParvanehContentKind.image:
        return '.jpg';
    }
  }
}

/// تشخیص PDF از روی محتوا
bool bytesLookLikePdf(List<int> bytes) {
  if (bytes.length < 4) return false;
  if (bytes[0] == 0x25 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x44 &&
      bytes[3] == 0x46) {
    return true;
  }
  final scan = bytes.length > 512 ? bytes.sublist(0, 512) : bytes;
  for (var i = 0; i < scan.length - 4; i++) {
    if (scan[i] == 0x25 &&
        scan[i + 1] == 0x50 &&
        scan[i + 2] == 0x44 &&
        scan[i + 3] == 0x46) {
      return true;
    }
  }
  return false;
}

bool bytesLookLikeHtml(List<int> bytes) {
  if (bytes.isEmpty) return false;
  final head = String.fromCharCodes(
    bytes.take(256).where(
        (b) => b == 0x09 || b == 0x0A || b == 0x0D || (b >= 0x20 && b <= 0x7E)),
  ).toLowerCase();
  return head.contains('<!doctype') ||
      head.contains('<html') ||
      head.contains('<link') ||
      head.contains('<div') ||
      head.contains('<style') ||
      head.contains('<script');
}

/// HTML قالب پروانه کسب (نه صفحه خطا)
bool bytesLookLikeParvanehHtml(List<int> bytes) {
  if (!bytesLookLikeHtml(bytes)) return false;
  try {
    final text = utf8.decode(bytes, allowMalformed: true);
    return text.contains('id="license"') ||
        text.contains("id='license'") ||
        text.contains('#license') ||
        text.contains('پروانه کسب') ||
        text.contains('parvaneh-kasb');
  } catch (_) {
    return false;
  }
}

bool bytesLookLikeImage(List<int> bytes) {
  if (bytes.length < 3) return false;
  if (bytes[0] == 0xFF && bytes[1] == 0xD8) return true;
  if (bytes[0] == 0x89 && bytes[1] == 0x50) return true;
  if (bytes[0] == 0x47 && bytes[1] == 0x49) return true;
  if (bytes.length >= 12 &&
      bytes[0] == 0x52 &&
      bytes[1] == 0x49 &&
      bytes[2] == 0x46 &&
      bytes[3] == 0x46 &&
      bytes[8] == 0x57 &&
      bytes[9] == 0x45 &&
      bytes[10] == 0x42 &&
      bytes[11] == 0x50) {
    return true;
  }
  if (bytes[0] == 0x42 && bytes[1] == 0x4D) return true;
  return false;
}

bool isValidParvanehBytes(List<int> bytes) {
  if (bytes.length < 80) return false;
  return bytesLookLikeParvanehHtml(bytes) ||
      bytesLookLikePdf(bytes) ||
      bytesLookLikeImage(bytes);
}

void logParvanehDebug(String message) {
  debugPrint('[Parvaneh] $message');
}
