import 'dart:developer' as developer;

import 'package:injast_admin/import_sync/asnaf_jwt_policy.dart';

/// لاگ تشخیصی عملیات صفحهٔ اصناف — بدون چاپ خود JWT.
class AsnafOpLog {
  AsnafOpLog._();

  static const login = 'LOGIN';
  static const token = 'TOKEN';
  static const web = 'WEB';
  static const latest = 'LATEST';
  static const full = 'FULL';
  static const test5 = 'TEST5';
  static const send = 'SEND';
  static const draft = 'DRAFT';
  static const offline = 'OFFLINE';
  static const download = 'DOWNLOAD';
  static const pause = 'CTRL';
  static const api = 'API';
  static const geo = 'GEO';
  static const record = 'RECORD';
  static const site = 'SITE';

  /// خط کامل با timestamp برای نمایش در UI (جدیدترین اول).
  static void Function(String entry)? uiSink;

  static void line(String op, String message, {Object? error}) {
    final now = DateTime.now();
    final ts =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
    final entry = '[$ts] [$op] $message';
    developer.log(
      '[$op] $message',
      name: 'AsnafSite',
      error: error,
    );
    uiSink?.call(entry);
  }

  static String jwtSafe(String? token) {
    final t = token?.trim() ?? '';
    if (t.isEmpty) return 'empty';
    final exp = AsnafJwtPolicy.expiryEpochSeconds(t);
    String expStr = 'no-exp';
    if (exp != null) {
      final dt = DateTime.fromMillisecondsSinceEpoch(exp * 1000, isUtc: true).toLocal();
      expStr =
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} '
          '${dt.month}/${dt.day}';
    }
    return 'len=${t.length} expired=${AsnafJwtPolicy.isExpired(t)} exp≈$expStr';
  }

  static String shortUrl(String url) {
    return url
        .replaceFirst('https://apinovin.iranianasnaf.ir', '')
        .replaceFirst('https://iranianasnaf.ir', '');
  }

  static String clip(String s, [int max = 160]) {
    final t = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (t.length <= max) return t;
    return '${t.substring(0, max)}…';
  }
}
