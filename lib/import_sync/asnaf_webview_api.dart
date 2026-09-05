import 'dart:convert';

import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:injast_admin/import_sync/asnaf_api_throttle.dart';
import 'package:injast_admin/import_sync/asnaf_jwt_policy.dart';
import 'package:injast_admin/import_sync/asnaf_op_log.dart';

/// درخواست GET به API اصناف از داخل WebView.
///
/// پنل Angular با XHR به apinovin و هدر JWT (بدون cookie credentials) ۲۰۰ می‌گیرد.
/// `withCredentials: true` روی WKWebView همان درخواست را CORS/status=0 می‌کند.
class AsnafWebViewApi {
  AsnafWebViewApi(this._controller);

  final InAppWebViewController _controller;

  static const networkHookSource = r'''
(function() {
  if (window.__asnafHooked) return;
  window.__asnafHooked = true;
  window.__asnafNet = [];
  function rec(kind, url, status, body, headerNames) {
    try {
      var u = String(url || '');
      var keep = status >= 200 && status < 300 && /parvaneh|\/docs|apinovin|raste|token/i.test(u);
      window.__asnafNet.push({
        kind: kind,
        url: u,
        status: status,
        t: Date.now(),
        headers: headerNames || [],
        body: keep ? String(body || '').slice(0, 1500000) : ''
      });
      if (window.__asnafNet.length > 80) window.__asnafNet.shift();
      if (/parvaneh|\/docs|apinovin|raste|token/i.test(u)) {
        console.log('[AsnafNet] ' + kind + ' ' + status + ' ' + u + ' hdr=' + (headerNames || []).join(','));
      }
    } catch (e) {}
  }
  var ofetch = window.fetch;
  if (typeof ofetch === 'function') {
    window.fetch = function(input, init) {
      var url = (typeof input === 'string') ? input : (input && input.url);
      return ofetch.apply(this, arguments).then(function(res) {
        rec('fetch', url, res.status, '', []);
        return res;
      });
    };
  }
  var open = XMLHttpRequest.prototype.open;
  var send = XMLHttpRequest.prototype.send;
  var setHeader = XMLHttpRequest.prototype.setRequestHeader;
  XMLHttpRequest.prototype.open = function(method, url) {
    this.__asnafUrl = url;
    this.__asnafHdr = [];
    return open.apply(this, arguments);
  };
  XMLHttpRequest.prototype.setRequestHeader = function(k, v) {
    this.__asnafHdr = this.__asnafHdr || [];
    this.__asnafHdr.push(String(k));
    return setHeader.apply(this, arguments);
  };
  XMLHttpRequest.prototype.send = function() {
    var xhr = this;
    xhr.addEventListener('loadend', function() {
      rec('xhr', xhr.__asnafUrl, xhr.status, xhr.responseText, xhr.__asnafHdr);
    });
    return send.apply(this, arguments);
  };
})();
''';

  Future<String> collectCookieHeader() async {
    final mgr = CookieManager.instance();
    final map = <String, String>{};
    try {
      final all = await mgr.getAllCookies();
      final names = <String>[];
      for (final c in all) {
        final domain = (c.domain ?? '').toLowerCase();
        if (domain.contains('iranianasnaf') || domain.contains('apinovin')) {
          map[c.name] = c.value;
          names.add('${c.name}@${c.domain ?? ''}');
        }
      }
      AsnafOpLog.line(
        AsnafOpLog.api,
        'allCookies n=${all.length} asnaf=${map.length} | ${names.join(', ')}',
      );
    } catch (e) {
      AsnafOpLog.line(AsnafOpLog.api, 'getAllCookies خطا: $e');
    }
    return map.entries.map((e) => '${e.key}=${e.value}').join('; ');
  }

  Future<dynamic> getJson(String url, String token) async {
    await AsnafApiThrottle.instance.waitTurn();

    final cached = await _capturedBodyFor(url);
    if (cached != null) {
      AsnafOpLog.line(
        AsnafOpLog.api,
        'استفاده از پاسخ ذخیره‌شده پنل | ${AsnafOpLog.shortUrl(url)} len=${cached.length}',
      );
      return jsonDecode(cached);
    }

    final candidates = _candidateUrls(url);
    AsnafOpLog.line(
      AsnafOpLog.api,
      'کاندیدها n=${candidates.length} | ${candidates.map(AsnafOpLog.shortUrl).join(' , ')}',
    );

    Object? lastError;
    for (final candidate in candidates) {
      for (var attempt = 1; attempt <= 6; attempt++) {
        try {
          final value = await _pageXhrGet(candidate, token);
          final status = _toInt(value['status']);
          final body = value['body']?.toString() ?? '';
          final err = value['error']?.toString() ?? '';
          AsnafOpLog.line(
            AsnafOpLog.api,
            'XHR-page ${AsnafOpLog.shortUrl(candidate)} | status=$status '
            'via=${value['via']} body_len=${body.length} err=$err attempt=$attempt',
          );
          if (status >= 200 && status < 300 && body.isNotEmpty) {
            return jsonDecode(body);
          }
          if (status == 401 || status == 403) {
            lastError = AsnafApiAuthException(status, candidate, fromWebView: true);
            break;
          }
          lastError = Exception('API error $status for $candidate');
          if (status == 429 && attempt < 6) {
            AsnafOpLog.line(
              AsnafOpLog.api,
              '429 محدودیت نرخ — صبر و تلاش دوباره attempt=$attempt '
              '${AsnafOpLog.shortUrl(candidate)}',
            );
            await AsnafApiThrottle.instance.backoff429(attempt);
            continue;
          }
          final retryable = status == 0 ||
              err == 'timeout' ||
              err == 'xhr_error' ||
              err == 'xhr_timeout';
          if (retryable && attempt < 6) {
            AsnafOpLog.line(
              AsnafOpLog.api,
              'تلاش دوباره لیست/جزئیات بعد از $err | attempt=$attempt',
            );
            await AsnafApiThrottle.instance.backoffNetworkError(
              attempt.clamp(1, 3),
            );
            continue;
          }
          break;
        } catch (e) {
          lastError = e;
          AsnafOpLog.line(
            AsnafOpLog.api,
            'XHR-page exception ${AsnafOpLog.shortUrl(candidate)} | $e',
          );
          if (attempt < 6) {
            await AsnafApiThrottle.instance.backoffNetworkError(
              attempt.clamp(1, 3),
            );
            continue;
          }
        }
      }
      if (lastError is AsnafApiAuthException) break;
    }
    if (lastError is AsnafApiAuthException) throw lastError;
    throw lastError ?? Exception('WebView XHR failed for $url');
  }

  List<String> _candidateUrls(String url) {
    final out = <String>[];
    void add(String u) {
      final t = u.trim();
      if (t.isEmpty || out.contains(t)) return;
      out.add(t);
    }

    add(url);
    try {
      final parsed = Uri.parse(url);
      if (parsed.host.contains('apinovin') || parsed.host.isEmpty) {
        final page = parsed.queryParameters['page'] ?? '1';
        final path = parsed.path;
        if (path.endsWith('/parvaneh/') || path == '/parvaneh/') {
          add('https://apinovin.iranianasnaf.ir/parvaneh/?page=$page&management=True');
        }
      }
    } catch (_) {}
    return out;
  }

  Future<String?> _capturedBodyFor(String url) async {
    final urlJson = jsonEncode(url);
    try {
      final raw = await _controller.evaluateJavascript(
        source: '''
(function() {
  function abs(u) {
    try { return new URL(u, location.href); } catch (e) { return null; }
  }
  var want = abs($urlJson);
  if (!want) return JSON.stringify({body: ''});
  var list = window.__asnafNet || [];
  for (var i = list.length - 1; i >= 0; i--) {
    var x = list[i];
    if (x.status != 200 || !x.body) continue;
    var got = abs(x.url);
    if (!got || got.pathname !== want.pathname) continue;
    function qMatch(key) {
      var a = want.searchParams.get(key);
      var b = got.searchParams.get(key);
      if (!a && !b) return true;
      return a === b;
    }
    if (!qMatch('page') || !qMatch('parvaneh') || !qMatch('user')) continue;
    return JSON.stringify({body: x.body});
  }
  return JSON.stringify({body: ''});
})();
''',
        contentWorld: ContentWorld.PAGE,
      );
      if (raw == null) return null;
      var decoded = jsonDecode(raw.toString());
      if (decoded is String) {
        try {
          decoded = jsonDecode(decoded);
        } catch (_) {}
      }
      if (decoded is! Map) return null;
      final text = decoded['body']?.toString() ?? '';
      if (text.isEmpty) return null;
      return text;
    } catch (e) {
      AsnafOpLog.line(AsnafOpLog.api, 'خواندن body ذخیره‌شده خطا: $e');
      return null;
    }
  }

  /// XHR داخل همان JS پنل (evaluateJavascript)، نه callAsyncJavaScript.
  Future<Map<String, dynamic>> _pageXhrGet(String url, String token) async {
    final urlJson = jsonEncode(url);
    final tokenJson = jsonEncode(token);
    final started = await _controller.evaluateJavascript(
      source: '''
(function() {
  var url = $urlJson;
  var token = $tokenJson;
  window.__asnafJobs = window.__asnafJobs || {};
  var id = 'j' + Date.now() + '_' + Math.random().toString(16).slice(2);
  window.__asnafJobs[id] = { done: false };
  var xhr = new XMLHttpRequest();
  xhr.open('GET', url, true);
  xhr.withCredentials = false;
  if (token) xhr.setRequestHeader('Authorization', 'JWT ' + token);
  xhr.setRequestHeader('Accept', 'application/json, text/plain, */*');
  xhr.timeout = 28000;
  xhr.onload = function() {
    window.__asnafJobs[id] = {
      done: true, status: xhr.status, body: xhr.responseText || '', via: 'xhr-page'
    };
  };
  xhr.ontimeout = function() {
    window.__asnafJobs[id] = {
      done: true, status: 0, error: 'xhr_timeout', body: '', via: 'xhr-page'
    };
  };
  xhr.onerror = function() {
    window.__asnafJobs[id] = {
      done: true, status: 0, error: 'xhr_error', body: '', via: 'xhr-page'
    };
  };
  xhr.send();
  return id;
})();
''',
      contentWorld: ContentWorld.PAGE,
    );
    var id = started?.toString() ?? '';
    id = id.replaceAll('"', '');
    if (id.isEmpty || id == 'null') {
      return {'status': 0, 'error': 'job_id_empty', 'via': 'xhr-page'};
    }

    for (var i = 0; i < 300; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      final raw = await _controller.evaluateJavascript(
        source: 'JSON.stringify(window.__asnafJobs[${jsonEncode(id)}] || {done:false})',
        contentWorld: ContentWorld.PAGE,
      );
      if (raw == null) continue;
      var decoded = jsonDecode(raw.toString());
      if (decoded is String) {
        try {
          decoded = jsonDecode(decoded);
        } catch (_) {}
      }
      if (decoded is! Map) continue;
      if (decoded['done'] == true) {
        return Map<String, dynamic>.from(decoded);
      }
    }
    return {'status': 0, 'error': 'timeout', 'via': 'xhr-page'};
  }

  static int _toInt(dynamic v) => int.tryParse(v?.toString() ?? '') ?? 0;
}
