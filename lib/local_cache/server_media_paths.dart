import 'dart:convert';

/// تشخیص و پاک‌سازی مسیر/URL تصاویر برای ارسال به سرور (بدون وابستگی به اصناف).
class ServerMediaPaths {
  ServerMediaPaths._();

  static const parvandeImageFields = ['image_profile', 'image_parvaneh', 'licence_file'];

  /// مسیر ذخیره‌شده روی سرور خودمان.
  static bool isServerPath(String? raw) {
    final t = raw?.trim() ?? '';
    if (t.isEmpty) return false;
    return t.startsWith('/pic_injast/') ||
        t.startsWith('pic_injast/') ||
        t.contains('/pic_injast/');
  }

  /// لینک خارجی (اصناف، CDN، http…) — نباید در payload ارسالی به سرور بماند.
  static bool isExternalUrl(String? raw) {
    final t = raw?.trim() ?? '';
    if (t.isEmpty) return false;
    if (isServerPath(t)) return false;
    final lower = t.toLowerCase();
    return lower.startsWith('http://') ||
        lower.startsWith('https://') ||
        lower.contains('iranianasnaf.ir') ||
        lower.contains('apinovin');
  }

  /// فقط مسیر سرور را نگه می‌دارد؛ لینک اصناف و http خالی می‌شود.
  static void sanitizeParvandeImageFields(Map<String, String> payload) {
    for (final key in parvandeImageFields) {
      final v = payload[key]?.trim() ?? '';
      if (v.isEmpty) continue;
      if (!isServerPath(v)) {
        payload[key] = '';
      }
    }
  }

  /// link_doc در _docs_json: فقط مسیر سرور باقی بماند.
  static String sanitizeDocsJson(String? docsRaw) {
    if (docsRaw == null || docsRaw.trim().isEmpty) return docsRaw ?? '';
    try {
      final decoded = jsonDecode(docsRaw);
      if (decoded is! List) return docsRaw;
      for (final e in decoded) {
        if (e is! Map) continue;
        final link = e['link_doc']?.toString().trim() ?? '';
        if (link.isEmpty) continue;
        if (!isServerPath(link)) {
          e['link_doc'] = '';
        }
      }
      return jsonEncode(decoded);
    } catch (_) {
      return docsRaw;
    }
  }
}
