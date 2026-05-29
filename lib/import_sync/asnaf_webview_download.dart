import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:http/http.dart' as http;
import 'package:injast_admin/import_sync/asnaf_jwt_policy.dart';

/// دانلود فایل (CSV/Excel و …) از لینک‌های داخل WebView اصناف.
class AsnafWebViewDownload {
  AsnafWebViewDownload._();

  static final _fileExt = RegExp(r'\.(csv|xls|xlsx|zip)(\?|#|$)', caseSensitive: false);

  static bool looksLikeFileUrl(String url, {String? mimeType}) {
    final u = url.toLowerCase();
    if (_fileExt.hasMatch(u)) return true;
    if (u.contains('/export') || u.contains('download')) return true;
    final m = mimeType?.toLowerCase() ?? '';
    if (m.contains('csv') ||
        m.contains('spreadsheet') ||
        m.contains('excel') ||
        m.contains('octet-stream') ||
        m.contains('ms-excel')) {
      return true;
    }
    return false;
  }

  static String resolveFilename({
    required String url,
    String? suggestedFilename,
    String? contentDisposition,
    String? mimeType,
  }) {
    final suggested = suggestedFilename?.trim();
    if (suggested != null && suggested.isNotEmpty) {
      return _sanitizeFilename(suggested);
    }
    final cd = contentDisposition;
    if (cd != null && cd.isNotEmpty) {
      final star = RegExp(r"filename\*=UTF-8''([^;\s]+)", caseSensitive: false)
          .firstMatch(cd);
      if (star != null) {
        return _sanitizeFilename(Uri.decodeComponent(star.group(1)!));
      }
      final plain =
          RegExp(r'filename="?([^";\n]+)"?', caseSensitive: false).firstMatch(cd);
      if (plain != null) {
        return _sanitizeFilename(plain.group(1)!.trim());
      }
    }
    try {
      final path = Uri.parse(url).pathSegments;
      if (path.isNotEmpty) {
        final last = path.last.trim();
        if (last.isNotEmpty && last.contains('.')) {
          return _sanitizeFilename(last);
        }
      }
    } catch (_) {}
    if (mimeType != null && mimeType.toLowerCase().contains('csv')) {
      return 'export_${DateTime.now().millisecondsSinceEpoch}.csv';
    }
    return 'download_${DateTime.now().millisecondsSinceEpoch}.bin';
  }

  static String _sanitizeFilename(String name) {
    return name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
  }

  static List<String> _extensionsForFilename(String name) {
    final dot = name.lastIndexOf('.');
    if (dot > 0 && dot < name.length - 1) {
      return [name.substring(dot + 1).toLowerCase()];
    }
    return ['csv', 'xls', 'xlsx', 'zip'];
  }

  /// دانلود با کوکی WebView + JWT؛ مسیر ذخیره از دیالوگ کاربر.
  static Future<String?> saveFromUrl({
    required WebUri url,
    String? mimeType,
    String? suggestedFilename,
    String? contentDisposition,
    String? jwtToken,
  }) async {
    if (kIsWeb) return null;

    final cookieManager = CookieManager.instance();
    final cookies = await cookieManager.getCookies(url: url);
    final cookieHeader =
        cookies.map((c) => '${c.name}=${c.value}').join('; ');

    final headers = <String, String>{
      'Accept': '*/*',
      'Accept-Language': 'fa-IR,fa;q=0.9',
      'User-Agent': AsnafJwtPolicy.browserUserAgent,
      'Origin': 'https://iranianasnaf.ir',
      'Referer': 'https://iranianasnaf.ir/panel/',
      if (cookieHeader.isNotEmpty) 'Cookie': cookieHeader,
    };
    final token = jwtToken?.trim() ?? '';
    if (token.isNotEmpty) {
      headers['Authorization'] = 'JWT $token';
    }

    final res = await http
        .get(url, headers: headers)
        .timeout(const Duration(minutes: 3));

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('دانلود ناموفق (${res.statusCode})');
    }

    final filename = resolveFilename(
      url: url.toString(),
      suggestedFilename: suggestedFilename,
      contentDisposition: contentDisposition,
      mimeType: mimeType,
    );

    final savePath = await FilePicker.saveFile(
      dialogTitle: 'ذخیره فایل',
      fileName: filename,
      type: FileType.custom,
      allowedExtensions: _extensionsForFilename(filename),
      bytes: res.bodyBytes,
    );

    if (savePath == null || savePath.isEmpty) return null;
    if (res.bodyBytes.isNotEmpty) {
      final f = File(savePath);
      if (!await f.exists() || await f.length() == 0) {
        await f.writeAsBytes(res.bodyBytes, flush: true);
      }
    }
    return savePath;
  }
}
