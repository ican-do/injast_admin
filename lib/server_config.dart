import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;

const String publicWebOrigin = 'http://injast-web.ir';

const String kDefaultApiProtocol =
    String.fromEnvironment('API_PROTOCOL', defaultValue: 'http');
const String kDefaultApiIp =
    String.fromEnvironment('API_IP', defaultValue: '194.5.175.180');
const String kDefaultApiPort =
    String.fromEnvironment('API_PORT', defaultValue: '8080');
const String kDefaultAdminApiPort =
    String.fromEnvironment('ADMIN_API_PORT', defaultValue: '4000');

/// آدرس مستقیم Node — ویندوز/دسکتاپ همیشه همین را می‌زند
String get nativeApiBaseUrl =>
    '$kDefaultApiProtocol://$kDefaultApiIp:$kDefaultApiPort';

/// مبدأ فایل‌های استاتیک (`/pic_injast`) — بدون پیشوند `/api`
String get mediaOrigin => (!kIsWeb || kDebugMode)
    ? nativeApiBaseUrl
    : publicWebOrigin;

String get serverApiBaseUrl => (!kIsWeb || kDebugMode)
    ? nativeApiBaseUrl
    : '$publicWebOrigin/api';

/// سرویس ادمین (قوانین، درخواست‌ها، مزایا) — روی IIS معمولاً `/api2`
String get adminApiBaseUrl => (!kIsWeb || kDebugMode)
    ? '$kDefaultApiProtocol://$kDefaultApiIp:$kDefaultAdminApiPort'
    : '$publicWebOrigin/api2';

String getApiUrl(String endpoint) {
  final clean = endpoint.startsWith('/') ? endpoint.substring(1) : endpoint;
  return '$serverApiBaseUrl/$clean';
}

String getAdminApiUrl(String endpoint) {
  final clean = endpoint.startsWith('/') ? endpoint.substring(1) : endpoint;
  return '$adminApiBaseUrl/$clean';
}
