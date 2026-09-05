import 'package:http/http.dart' as http;
import 'package:injast_admin/api_token.dart';
import 'package:injast_admin/server_config.dart';

/// کلاینت HTTP برنامه — توکن نشست را روی درخواست‌های سرور خودمان می‌گذارد.
class _ApiClient extends http.BaseClient {
  final http.Client _inner = http.Client();

  bool _isOwnServer(Uri url) {
    if (!url.hasAuthority) return true;
    final host = url.host.toLowerCase();
    if (host == kDefaultApiIp) return true;
    if (host == 'injast-web.ir' || host == 'www.injast-web.ir') return true;
    return false;
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    final token = ApiToken.value;
    if (token.isNotEmpty && _isOwnServer(request.url)) {
      request.headers.putIfAbsent('Authorization', () => 'Bearer $token');
    }
    return _inner.send(request);
  }
}

final http.Client apiHttp = _ApiClient();
