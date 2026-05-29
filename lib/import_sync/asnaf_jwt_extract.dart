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
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw.toString());
      if (decoded is! Map) return null;
      final token = decoded['token']?.toString().trim() ?? '';
      if (token.isEmpty) return null;
      if (AsnafJwtPolicy.isExpired(token)) return null;
      return token;
    } catch (_) {
      return null;
    }
  }
}
