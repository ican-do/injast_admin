import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;

/// کانال ارتباط — توسط [initApiTransport] در شروع برنامه تعیین می‌شود.
enum WebApiChannel {
  /// دسکتاپ: اتصال مستقیم به IP:8080
  nativeDirect,

  /// دسکتاپ: دامنهٔ عمومی HTTPS (`/api` و `/api2`)
  nativePublicHttps,

  /// Chrome روی localhost یا flutter run دیباگ
  localDirect,

  /// سایت واقعی با پروکسی IIS (`/api`)
  sameOrigin,

  /// سایت واقعی ولی پروکسی /api آماده نیست — اتصال مستقیم به API
  publicDirect,
}

WebApiChannel webApiChannel = WebApiChannel.nativeDirect;

/// اگر true باشد درخواست‌های وب نسبی `/api` هستند.
bool useSameOriginApiOnWeb = false;

/// پیشوند مسیر پروکسی روی وب‌سرور (بدون / ابتدا و انتها)
String apiPathPrefix = 'api';

/// دامنهٔ عمومی وب — گواهی SSL صادر شده و روی HTTPS است
const String publicWebOrigin = 'https://injast-web.ir';

bool get sameOriginApiActive =>
    kIsWeb && webApiChannel == WebApiChannel.sameOrigin;

bool get nativePublicHttpsActive =>
    !kIsWeb && webApiChannel == WebApiChannel.nativePublicHttps;

String get _apiPrefix => apiPathPrefix.replaceAll(RegExp(r'^/+|/+$'), '');

String _relativePath(String prefix, String endpoint) {
  final p = prefix.replaceAll(RegExp(r'^/+|/+$'), '');
  return p.isEmpty ? '/$endpoint' : '/$p/$endpoint';
}

const String kDefaultApiProtocol =
    String.fromEnvironment('API_PROTOCOL', defaultValue: 'http');
const String kDefaultApiIp =
    String.fromEnvironment('API_IP', defaultValue: '194.5.175.180');
const String kDefaultApiPort =
    String.fromEnvironment('API_PORT', defaultValue: '8080');
const String kDefaultAdminApiPort =
    String.fromEnvironment('ADMIN_API_PORT', defaultValue: '4000');
const String kDefaultMemberApiPort =
    String.fromEnvironment('MEMBER_API_PORT', defaultValue: '4001');

/// آدرس IP سرور API (فقط دیباگ / fallback)
String get serverApiIp => kDefaultApiIp;

int get serverApiPort => int.tryParse(kDefaultApiPort) ?? 8080;

/// پروتکل اتصال مستقیم به IP — روی HTTP می‌ماند چون گواهی برای دامنه صادر
/// شده و روی آدرس IP اعتبار ندارد.
String get serverProtocol => kDefaultApiProtocol;

/// آدرس پایه وب‌اپ شکایات
String shekayatWebBaseUrl = '$publicWebOrigin/shekayat';

String getShekayatInviteUrl(String codeCo) =>
    '$shekayatWebBaseUrl/#/Complaint/$codeCo';

/// آدرس مستقیم Node API
String get nativeApiBaseUrl =>
    '$serverProtocol://$serverApiIp:$serverApiPort';

String get _publicApiBaseUrl =>
    _apiPrefix.isEmpty ? publicWebOrigin : '$publicWebOrigin/$_apiPrefix';

/// مبدأ فایل‌های استاتیک (`/pic_injast`) — بدون پیشوند `/api`
String get mediaOrigin {
  if (sameOriginApiActive) return publicWebOrigin;
  if (nativePublicHttpsActive) return publicWebOrigin;
  if (!kIsWeb || kDebugMode) return nativeApiBaseUrl;
  return publicWebOrigin;
}

String get staticFilesBaseUrl => mediaOrigin;

String get webMediaOrigin {
  if (sameOriginApiActive) return '';
  return mediaOrigin;
}

bool _isInternalApiHost(String host) {
  final h = host.toLowerCase();
  return h == serverApiIp ||
      h == 'injast-web.ir' ||
      h == 'www.injast-web.ir' ||
      h == 'localhost' ||
      h == '127.0.0.1';
}

/// URL کامل فایل‌های استاتیک (تصاویر آپلود شده در /pic_injast/...)
String getStaticFileUrl(String filePath) {
  if (filePath.isEmpty) return '';
  var path = filePath.trim();
  if (path.startsWith('http://') || path.startsWith('https://')) {
    final uri = Uri.tryParse(path);
    if (uri != null && _isInternalApiHost(uri.host)) {
      path = uri.path;
    } else {
      return path;
    }
  }
  final normalized = path.startsWith('/') ? path : '/$path';
  if (!kIsWeb) return '$mediaOrigin$normalized';
  if (sameOriginApiActive) return normalized;
  return '$mediaOrigin$normalized';
}

/// دریافت URL کامل سرور API
String get serverApiBaseUrl {
  if (sameOriginApiActive || nativePublicHttpsActive) return _publicApiBaseUrl;
  if (!kIsWeb || kDebugMode) return nativeApiBaseUrl;
  return _publicApiBaseUrl;
}

/// پیشوند آدرس سرور API
String get apiOrigin {
  if (sameOriginApiActive) return _apiPrefix.isEmpty ? '' : '/$_apiPrefix';
  return serverApiBaseUrl;
}

/// پیشوند آدرس فایل‌های استاتیک
String get staticOrigin {
  if (!kIsWeb) return staticFilesBaseUrl;
  return webMediaOrigin;
}

/// سرویس ادمین (قوانین، درخواست‌ها، مزایا) — پورت ۴۰۰۰ یا `/api2`
String get adminApiBaseUrl {
  if (sameOriginApiActive) return '/api2';
  if (nativePublicHttpsActive) return '$publicWebOrigin/api2';
  if (kIsWeb && !kDebugMode) return '$publicWebOrigin/api2';
  return '$serverProtocol://$serverApiIp:$kDefaultAdminApiPort';
}

/// API کمکی پورت ۴۰۰۱ — در وب/HTTPS: `/api3`
String get memberApiBaseUrl {
  if (sameOriginApiActive) return '/api3';
  if (nativePublicHttpsActive) return '$publicWebOrigin/api3';
  if (kIsWeb && !kDebugMode) return '$publicWebOrigin/api3';
  return '$serverProtocol://$serverApiIp:$kDefaultMemberApiPort';
}

String getApiUrl(String endpoint) {
  final clean = endpoint.startsWith('/') ? endpoint.substring(1) : endpoint;
  if (sameOriginApiActive) return _relativePath(apiPathPrefix, clean);
  if (nativePublicHttpsActive) return '$_publicApiBaseUrl/$clean';
  if (!kIsWeb) return '$nativeApiBaseUrl/$clean';
  return '$serverApiBaseUrl/$clean';
}

String getAdminApiUrl(String endpoint) {
  final clean = endpoint.startsWith('/') ? endpoint.substring(1) : endpoint;
  return '$adminApiBaseUrl/$clean';
}
