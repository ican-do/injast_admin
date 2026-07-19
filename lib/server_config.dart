const String _kHardDefaultApiProtocol = 'http';
const String _kHardDefaultApiIp = '194.5.175.180';
const String _kHardDefaultApiPort = '8080';
const String _kHardDefaultAdminApiPort = '4000';

const String kDefaultApiProtocol =
    String.fromEnvironment('API_PROTOCOL', defaultValue: _kHardDefaultApiProtocol);
const String kDefaultApiIp =
    String.fromEnvironment('API_IP', defaultValue: _kHardDefaultApiIp);
const String kDefaultApiPort =
    String.fromEnvironment('API_PORT', defaultValue: _kHardDefaultApiPort);
const String kDefaultAdminApiPort =
    String.fromEnvironment('ADMIN_API_PORT', defaultValue: _kHardDefaultAdminApiPort);

String get serverApiBaseUrl => '$kDefaultApiProtocol://$kDefaultApiIp:$kDefaultApiPort';

/// سرویس ادمین (قوانین، درخواست‌ها، مزایا) روی پورت جدا
String get adminApiBaseUrl =>
    '$kDefaultApiProtocol://$kDefaultApiIp:$kDefaultAdminApiPort';

String getApiUrl(String endpoint) {
  final clean = endpoint.startsWith('/') ? endpoint.substring(1) : endpoint;
  return '$serverApiBaseUrl/$clean';
}

String getAdminApiUrl(String endpoint) {
  final clean = endpoint.startsWith('/') ? endpoint.substring(1) : endpoint;
  return '$adminApiBaseUrl/$clean';
}
