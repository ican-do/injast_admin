import 'dart:async';

import 'package:injast_admin/injast_http.dart' as http;
import 'package:injast_admin/server_config.dart';

/// بررسی دسترسی به سرور اتحادیه (برای فعال‌سازی خودکار حالت آفلاین).
class NetworkReachability {
  NetworkReachability._();
  static final NetworkReachability instance = NetworkReachability._();

  static const _pingPath = 'health';
  static const _defaultTimeout = Duration(seconds: 4);

  bool? _lastResult;
  DateTime? _lastCheckedAt;

  bool? get lastKnownOnline => _lastResult;

  /// آیا سرور API در دسترس است؟
  Future<bool> isServerReachable({Duration timeout = _defaultTimeout}) async {
    try {
      final uri = Uri.parse(getApiUrl(_pingPath));
      final res = await http.get(uri).timeout(timeout);
      final ok = res.statusCode >= 200 && res.statusCode < 500;
      _lastResult = ok;
      _lastCheckedAt = DateTime.now();
      return ok;
    } catch (_) {
      _lastResult = false;
      _lastCheckedAt = DateTime.now();
      return false;
    }
  }

  /// اگر کمتر از [maxAge] از آخرین پینگ گذشته، همان نتیجهٔ کش‌شده را برمی‌گرداند.
  Future<bool> isServerReachableCached({
    Duration maxAge = const Duration(seconds: 25),
    Duration timeout = _defaultTimeout,
  }) async {
    if (_lastResult != null &&
        _lastCheckedAt != null &&
        DateTime.now().difference(_lastCheckedAt!) < maxAge) {
      return _lastResult!;
    }
    return isServerReachable(timeout: timeout);
  }
}
