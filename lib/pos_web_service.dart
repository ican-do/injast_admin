import 'dart:async';
import 'dart:convert';

import 'package:injast_admin/api_token.dart';
import 'package:injast_admin/import_sync/asnaf_recovery_store.dart';
import 'package:injast_admin/injast_http.dart' as http;
import 'package:injast_admin/local_cache/offline_session_store.dart';
import 'package:injast_admin/server_config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

const _kDeviceUuid = 'pos_web_device_uuid_v1';
const _kPosQrType = 'POS_ACTIVATION';

class PosWebService {
  PosWebService._();
  static final PosWebService instance = PosWebService._();

  final _uuid = const Uuid();
  String? _deviceUuid;
  Map<String, dynamic>? _sessionUser;
  Map<String, dynamic>? _unionInfo;
  Map<String, dynamic>? _memberStats;
  Timer? _pollTimer;

  String? get deviceUuid => _deviceUuid;
  Map<String, dynamic>? get sessionUser => _sessionUser;
  Map<String, dynamic>? get unionInfo => _unionInfo;
  Map<String, dynamic>? get memberStats => _memberStats;
  bool get isLoggedIn => _sessionUser != null;

  String get qrPayloadJson => jsonEncode({
        'type': _kPosQrType,
        'uuid': _deviceUuid,
        'v': 1,
      });

  Future<void> ensureDeviceUuid() async {
    if (_deviceUuid != null && _deviceUuid!.isNotEmpty) return;
    final p = await SharedPreferences.getInstance();
    var u = p.getString(_kDeviceUuid);
    if (u == null || u.isEmpty) {
      u = _uuid.v4();
      await p.setString(_kDeviceUuid, u);
    }
    _deviceUuid = u;
  }

  Future<void> startPolling({
    required void Function() onTick,
    Duration interval = const Duration(seconds: 4),
  }) async {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(interval, (_) => onTick());
  }

  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  /// یک بار وضعیت را می‌پرسد؛ اگر هر کاربری با همین `mac_id` ثبت شده باشد، کاربر/اتحادیه را بارگذاری می‌کند.
  Future<void> pollOnce() async {
    final uuid = _deviceUuid;
    if (uuid == null || uuid.isEmpty) return;

    try {
      final checkUri =
          Uri.parse(getApiUrl('pos/check-pos-status/${Uri.encodeComponent(uuid)}'));
      final checkRes = await http.get(checkUri);
      if (checkRes.statusCode != 200) return;

      final body = jsonDecode(checkRes.body);
      if (body is! Map<String, dynamic>) return;
      if (body['status'] != 'success') return;
      if (body['active'] != true) return;

      await _issueSessionToken();

      Map<String, dynamic>? row;
      final fromCheck = body['user'];
      if (fromCheck is Map<String, dynamic>) {
        row = fromCheck;
      } else if (fromCheck is Map) {
        row = Map<String, dynamic>.from(fromCheck);
      }
      if (row == null) {
        final userUri =
            Uri.parse(getApiUrl('select/select_user/${Uri.encodeComponent(uuid)}'));
        final userRes = await http.get(userUri);
        if (userRes.statusCode != 200) return;
        final list = jsonDecode(userRes.body);
        if (list is! List || list.isEmpty) return;
        final first = list.first;
        if (first is Map<String, dynamic>) {
          row = first;
        } else if (first is Map) {
          row = Map<String, dynamic>.from(first);
        }
      }
      if (row == null) return;

      final wasLoggedIn = _sessionUser != null;
      _sessionUser = row;

      // پس از ورود موفق با QR، توکن قدیمی اصناف پاک می‌شود تا IP/سشن قبلی دوباره استفاده نشود.
      if (!wasLoggedIn && _sessionUser != null) {
        await AsnafRecoveryStore().clearJwt();
      }

      await _loadUnionInfo();
      await _loadMemberStats();
      if (_sessionUser != null) {
        await OfflineSessionStore().saveSession(
          user: _sessionUser!,
          unionInfo: _unionInfo,
        );
      }
    } catch (_) {
      // اگر سرور موقتاً در دسترس نبود، فقط تلاش بعدی انجام شود.
      return;
    }
  }

  Future<void> _loadUnionInfo() async {
    final codeCo = _sessionUser?['code_co']?.toString().trim();
    if (codeCo == null || codeCo.isEmpty) {
      _unionInfo = null;
      return;
    }
    try {
      final coUri = Uri.parse(getApiUrl('select/select_co/${Uri.encodeComponent(codeCo)}'));
      final coRes = await http.get(coUri);
      if (coRes.statusCode != 200) return;
      final body = jsonDecode(coRes.body);
      if (body is List && body.isNotEmpty) {
        final first = body.first;
        if (first is Map<String, dynamic>) {
          _unionInfo = first;
        } else if (first is Map) {
          _unionInfo = Map<String, dynamic>.from(first);
        }
      }
    } catch (_) {}
  }

  Future<void> _loadMemberStats() async {
    final codeCo = _sessionUser?['code_co']?.toString().trim();
    if (codeCo == null || codeCo.isEmpty) {
      _memberStats = null;
      return;
    }
    try {
      final uri = Uri.parse(getApiUrl('select/count_members/${Uri.encodeComponent(codeCo)}'));
      final res = await http.get(uri);
      if (res.statusCode != 200) return;
      final body = jsonDecode(res.body);
      if (body is Map<String, dynamic> && body['success'] == true) {
        final total = int.tryParse('${body['total_members'] ?? 0}') ?? 0;
        final active = int.tryParse('${body['active_members'] ?? 0}') ?? 0;
        final inactive = (total - active) < 0 ? 0 : (total - active);
        _memberStats = {
          'total_members': total,
          'active_members': active,
          'inactive_members': inactive,
          'last_parvande_import': body['last_parvande_import'],
        };
      }
    } catch (_) {}
  }

  /// خروج: قطع اتصال روی سرور و ساخت UUID جدید برای دور بعدی اسکن.
  Future<void> logout() async {
    final uuid = _deviceUuid;
    if (uuid != null && uuid.isNotEmpty) {
      try {
        await http
            .post(
              Uri.parse(getApiUrl('pos/unbind-by-device')),
              headers: {'Content-Type': 'application/json; charset=utf-8'},
              body: jsonEncode({'mac_id': uuid}),
            )
            .timeout(const Duration(seconds: 8));
      } catch (_) {}
    }
    await ApiToken.clear();
    _sessionUser = null;
    _unionInfo = null;
    _memberStats = null;
    final p = await SharedPreferences.getInstance();
    // پاک‌سازی داده‌های حساس/موقت مرتبط با بازیابی اسناف در زمان خروج کاربر.
    await p.remove('asnaf_jwt_hidden_v1');
    await p.remove('asnaf_recovery_state_v1');
    await p.remove('import_sync_draft_records_v1');
    final next = _uuid.v4();
    await p.setString(_kDeviceUuid, next);
    _deviceUuid = next;
  }

  Future<void> _issueSessionToken() async {
    final uuid = _deviceUuid;
    if (uuid == null || uuid.isEmpty) return;
    try {
      final res = await http.post(
        Uri.parse(getApiUrl('pos/session')),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
        body: jsonEncode({'mac_id': uuid}),
      );
      if (res.statusCode != 200) return;
      final body = jsonDecode(res.body);
      if (body is! Map) return;
      final token = body['token']?.toString() ?? '';
      if (token.isEmpty) return;
      final expRaw = body['expires_at'];
      final expiresAt = expRaw is int
          ? expRaw
          : int.tryParse(expRaw?.toString() ?? '') ?? 0;
      await ApiToken.save(token, expiresAt: expiresAt);
    } catch (_) {}
  }

  void clearSessionUserOnly() {
    _sessionUser = null;
  }

  /// بارگذاری نشست ذخیره‌شده برای ورود آفلاین (بدون تماس با سرور).
  Future<bool> restoreOfflineSession() async {
    final saved = await OfflineSessionStore().readSession();
    final user = saved.user;
    if (user == null || (user['code_co']?.toString().trim().isEmpty ?? true)) {
      return false;
    }
    _sessionUser = user;
    _unionInfo = saved.unionInfo;
    _memberStats = null;
    return true;
  }
}
