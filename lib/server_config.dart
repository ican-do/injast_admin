import 'package:flutter/foundation.dart' show kDebugMode;

const String publicWebOrigin = 'http://injast-web.ir';

const String kDefaultApiProtocol =
    String.fromEnvironment('API_PROTOCOL', defaultValue: 'http');
const String kDefaultApiIp =
    String.fromEnvironment('API_IP', defaultValue: '194.5.175.180');
const String kDefaultApiPort =
    String.fromEnvironment('API_PORT', defaultValue: '8080');
const String kDefaultAdminApiPort =
    String.fromEnvironment('ADMIN_API_PORT', defaultValue: '4000');

/// مبدأ فایل‌های استاتیک (`/pic_injast`) — بدون پیشوند `/api`
String get mediaOrigin => kDebugMode
    ? '$kDefaultApiProtocol://$kDefaultApiIp:$kDefaultApiPort'
    : publicWebOrigin;

String get serverApiBaseUrl => kDebugMode
    ? '$kDefaultApiProtocol://$kDefaultApiIp:$kDefaultApiPort'
    : '$publicWebOrigin/api';

/// سرویس ادمین (قوانین، درخواست‌ها، مزایا) — روی IIS معمولاً `/api2`
String get adminApiBaseUrl => kDebugMode
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
