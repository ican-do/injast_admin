import 'dart:convert';

import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:injast_admin/import_sync/asnaf_api_throttle.dart';
import 'package:injast_admin/import_sync/asnaf_jwt_policy.dart';

/// درخواست GET به API اصناف از داخل WebView (همان کوکی/سشن مرورگر داخلی).
class AsnafWebViewApi {
  AsnafWebViewApi(this._controller);

  final InAppWebViewController _controller;

  Future<dynamic> getJson(String url, String token) async {
    await AsnafApiThrottle.instance.waitTurn();
    // باید در همان JavaScript world صفحهٔ پنل اجرا شود؛ وگرنه fetch به apinovin → Load failed (CORS).
    final result = await _controller.callAsyncJavaScript(
      functionBody: r'''
        const headers = {
          'Accept': 'application/json, text/plain, */*',
          'Accept-Language': 'fa-IR,fa;q=0.9,en;q=0.8',
        };
        if (token) headers['Authorization'] = 'JWT ' + token;
        const res = await fetch(apiUrl, {
          method: 'GET',
          credentials: 'include',
          headers,
        });
        return { status: res.status, body: await res.text() };
      ''',
      arguments: {
        'apiUrl': url,
        'token': token,
      },
      contentWorld: ContentWorld.PAGE,
    );
    if (result == null || result.error != null) {
      throw Exception(
        'WebView fetch failed: ${result?.error?.toString() ?? 'no result'}',
      );
    }
    final value = result.value;
    if (value is! Map) {
      throw Exception('WebView fetch unexpected result: $value');
    }
    final status = _toInt(value['status']);
    final body = value['body']?.toString() ?? '';
    if (status >= 200 && status < 300) {
      return jsonDecode(body);
    }
    if (status == 401 || status == 403) {
      throw AsnafApiAuthException(status, url);
    }
    throw Exception('API error $status for $url');
  }

  static int _toInt(dynamic v) => int.tryParse(v?.toString() ?? '') ?? 0;
}
