import 'dart:convert';

import 'package:injast_admin/import_sync/asnaf_jwt_policy.dart';

/// استخراج JWT از WebView (localStorage، sessionStorage، persist:root).
class AsnafJwtExtract {
  AsnafJwtExtract._();

  static const extractJavaScript = r'''
(() => {
  function clean(v) {
    if (!v) return '';
    let s = String(v).trim();
    if (s.toLowerCase().startsWith('bearer ')) s = s.slice(7).trim();
    if (s.toLowerCase().startsWith('jwt ')) s = s.slice(4).trim();
    return s;
  }
  function looksJwt(s) {
    const p = s.split('.');
    return p.length === 3 && p[0].startsWith('eyJ') && s.length > 60;
  }
  const found = [];
  function push(v) {
    const c = clean(v);
    if (looksJwt(c)) found.push(c);
  }
  function scanStorage(st) {
    if (!st) return;
    const priority = ['token', 'access_token', 'access', 'jwt', 'authToken', 'Authorization', 'authorization'];
    for (const k of priority) push(st.getItem(k));
    for (let i = 0; i < st.length; i++) {
      const k = st.key(i);
      const v = st.getItem(k);
      if (!k || !v) continue;
      const lk = k.toLowerCase();
      if (lk.includes('token') || lk.includes('jwt') || lk.includes('auth')) push(v);
    }
  }
  scanStorage(window.localStorage);
  scanStorage(window.sessionStorage);
  try {
    const pr = window.localStorage && window.localStorage.getItem('persist:root');
    if (pr) {
      const re = /eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+/g;
      let m;
      while ((m = re.exec(pr)) !== null) push(m[0]);
    }
  } catch (_) {}
  const unique = [...new Set(found)];
  let best = '';
  let bestExp = -1;
  for (const t of unique) {
    try {
      const payload = t.split('.')[1];
      let b64 = payload;
      const pad = b64.length % 4;
      if (pad > 0) b64 += '='.repeat(4 - pad);
      const json = JSON.parse(atob(b64.replace(/-/g, '+').replace(/_/g, '/')));
      const exp = typeof json.exp === 'number' ? json.exp : 0;
      if (exp > bestExp) { bestExp = exp; best = t; }
    } catch (_) {
      if (!best) best = t;
    }
  }
  if (!best && unique.length) best = unique[0];
  return JSON.stringify({ token: best, count: unique.length });
})();
''';

  /// `raw` خروجی `evaluateJavascript`.
  static String? parseTokenFromJsResult(dynamic raw) {
    final d = diagnoseJsResult(raw);
    if (d.expired || d.token == null || d.token!.isEmpty) return null;
    return d.token;
  }

  /// برای لاگ تست: تعداد توکن، انقضا، خطای پارس — بدون خود JWT.
  static AsnafJwtExtractDiag diagnoseJsResult(dynamic raw) {
    if (raw == null) {
      return const AsnafJwtExtractDiag(foundCount: 0, note: 'js_null');
    }
    try {
      dynamic decoded = raw;
      if (raw is String) {
        decoded = jsonDecode(raw);
        if (decoded is String) {
          decoded = jsonDecode(decoded);
        }
      }
      if (decoded is! Map) {
        return AsnafJwtExtractDiag(
          foundCount: 0,
          note: 'js_not_map:${decoded.runtimeType}',
        );
      }
      final count = int.tryParse(decoded['count']?.toString() ?? '') ?? 0;
      final token = decoded['token']?.toString().trim() ?? '';
      if (token.isEmpty) {
        return AsnafJwtExtractDiag(foundCount: count, note: 'token_empty');
      }
      if (AsnafJwtPolicy.isExpired(token)) {
        return AsnafJwtExtractDiag(
          foundCount: count,
          token: token,
          expired: true,
          note: 'token_expired',
        );
      }
      return AsnafJwtExtractDiag(foundCount: count, token: token, note: 'ok');
    } catch (e) {
      return AsnafJwtExtractDiag(foundCount: 0, note: 'parse_error:$e');
    }
  }
}

class AsnafJwtExtractDiag {
  const AsnafJwtExtractDiag({
    required this.foundCount,
    this.token,
    this.expired = false,
    this.note = '',
  });

  final int foundCount;
  final String? token;
  final bool expired;
  final String note;
}
