import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint, kDebugMode, kIsWeb;
import 'package:injast_admin/api_http.dart';
import 'package:injast_admin/server_config.dart';

/// انتخاب کانال API قبل از بالا آمدن برنامه:
/// - وب لوکال/دیباگ: مستقیم IP:8080
/// - وب روی دامنه: مسیر نسبی `/api` اگر پروکسی IIS سالم باشد
/// - دسکتاپ: اول HTTPS دامنه (`/api/health`)، در غیر این صورت IP:8080
Future<void> initApiTransport() async {
  if (!kIsWeb) {
    final publicOk = await _publicHttpsResponds();
    if (publicOk) {
      webApiChannel = WebApiChannel.nativePublicHttps;
      useSameOriginApiOnWeb = false;
      debugPrint('apiTransport: دسکتاپ — HTTPS دامنه $publicWebOrigin/api');
      return;
    }
    webApiChannel = WebApiChannel.nativeDirect;
    useSameOriginApiOnWeb = false;
    debugPrint('apiTransport: دسکتاپ — اتصال مستقیم $nativeApiBaseUrl');
    return;
  }

  final host = Uri.base.host.toLowerCase();
  final isLocal = host.isEmpty ||
      host == 'localhost' ||
      host == '127.0.0.1' ||
      host == '::1';

  if (isLocal || kDebugMode) {
    webApiChannel = WebApiChannel.localDirect;
    useSameOriginApiOnWeb = false;
    debugPrint('apiTransport: لوکال/دیباگ — اتصال مستقیم $serverApiBaseUrl');
    return;
  }

  final proxyOk = await _proxyResponds();
  if (proxyOk) {
    webApiChannel = WebApiChannel.sameOrigin;
    useSameOriginApiOnWeb = true;
    debugPrint('apiTransport: دامنهٔ واقعی — پروکسی /api فعال است');
    return;
  }

  // روی HTTPS اتصال مستقیم به http://IP:8080 ممکن نیست؛ مرورگر آن را
  // به‌عنوان mixed content می‌بندد. پس مسیر نسبی باقی می‌ماند.
  if (Uri.base.scheme == 'https') {
    webApiChannel = WebApiChannel.sameOrigin;
    useSameOriginApiOnWeb = true;
    debugPrint('apiTransport: /api/health پاسخ نداد — روی HTTPS مسیر نسبی حفظ شد');
    return;
  }

  webApiChannel = WebApiChannel.publicDirect;
  useSameOriginApiOnWeb = false;
  debugPrint('apiTransport: دامنهٔ واقعی — /api/health پاسخ نداد؛ اتصال مستقیم API');
}

Future<bool> _proxyResponds() async {
  try {
    final res = await apiHttp
        .get(Uri.parse('/api/health'))
        .timeout(const Duration(seconds: 4));
    if (res.statusCode != 200) return false;
    final body = json.decode(res.body);
    return body is Map && body['ok'] == true;
  } catch (_) {
    return false;
  }
}

Future<bool> _publicHttpsResponds() async {
  try {
    final res = await apiHttp
        .get(Uri.parse('$publicWebOrigin/api/health'))
        .timeout(const Duration(seconds: 4));
    if (res.statusCode != 200) return false;
    final body = json.decode(res.body);
    return body is Map && body['ok'] == true;
  } catch (_) {
    return false;
  }
}
