import 'dart:convert';

/// سیاست JWT سایت اصناف: اعتبار، URLهای مجاز برای استخراج، پاک‌سازی.
class AsnafJwtPolicy {
  AsnafJwtPolicy._();

  /// User-Agent شبیه مرورگر پنل (کاهش ریسک تشخیص به‌عنوان کلاینت نامشخص).
  static const browserUserAgent =
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36';

  /// صفحاتی که نباید از آن‌ها توکن استخراج/ذخیره شود.
  static bool isPublicOrLoginUrl(String? url) {
    if (url == null || url.trim().isEmpty) return true;
    final u = url.toLowerCase();
    if (u.contains('/login') || u.contains('/auth/login')) return true;
    if (u.contains('panjarevahed.iranianasnaf.ir')) return true;
    final hostOnly = u.replaceAll(RegExp(r'#.*'), '').replaceAll(RegExp(r'/$'), '');
    if (hostOnly == 'https://iranianasnaf.ir' ||
        hostOnly == 'https://www.iranianasnaf.ir' ||
        hostOnly.endsWith('iranianasnaf.ir/fa')) {
      return true;
    }
    return false;
  }

  /// فقط پس از ورود واقعی به پنل (نه صفحهٔ login).
  static bool isAuthenticatedPanelUrl(String? url) {
    if (url == null || url.trim().isEmpty) return false;
    final u = url.toLowerCase();
    if (!u.contains('iranianasnaf.ir/panel')) return false;
    return !u.contains('/login') && !u.contains('/auth/login');
  }

  /// بررسی انقضای JWT (فیلد `exp` به ثانیه).
  static bool isExpired(String token) {
    final exp = expiryEpochSeconds(token);
    if (exp == null) return false;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return now >= exp - 30;
  }

  static int? expiryEpochSeconds(String token) {
    try {
      final parts = token.split('.');
      if (parts.length < 2) return null;
      var payload = parts[1];
      final pad = payload.length % 4;
      if (pad > 0) payload += '=' * (4 - pad);
      final decoded = utf8.decode(base64Url.decode(payload));
      final map = jsonDecode(decoded);
      if (map is! Map) return null;
      final exp = map['exp'];
      if (exp is int) return exp;
      return int.tryParse(exp?.toString() ?? '');
    } catch (_) {
      return null;
    }
  }
}

/// خطای احراز هویت / مسدودسازی API اصناف — بازیابی باید متوقف شود.
class AsnafApiAuthException implements Exception {
  AsnafApiAuthException(this.statusCode, this.url, {this.fromWebView = false});

  final int statusCode;
  final String url;
  final bool fromWebView;

  @override
  String toString() =>
      'Asnaf API auth/block ($statusCode${fromWebView ? ', webview' : ', http'}) for $url';
}
