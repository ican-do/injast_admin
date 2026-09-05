import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:injast_admin/injast_http.dart' as http;
import 'package:injast_admin/local_cache/sync_status.dart';
import 'package:injast_admin/server_config.dart';

/// لایهٔ API برای ماژول مدیریت پرونده‌ها (در فاز اول فقط ۳ endpoint)
class ParvandeApi {
  ParvandeApi._();
  static final ParvandeApi instance = ParvandeApi._();

  /// لیست تمام پرونده‌های یک code_co (شامل فعال و سطل زباله)
  Future<List<Map<String, dynamic>>> fetchAll(String codeCo) async {
    final uri = Uri.parse(
      // هم‌راستا با پروژه قدیم: endpoint بدون فیلتر اجباری مختصات
      getApiUrl('select/select_parvande/0/${Uri.encodeComponent(codeCo)}'),
    );
    final res = await http.get(uri);
    if (res.statusCode != 200) {
      throw Exception('خطا در دریافت لیست پرونده‌ها (${res.statusCode})');
    }
    final body = jsonDecode(res.body);
    if (body is! List) return const [];
    return body.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  /// دادهٔ نقشه بازرسی با پشتیبانی از RBAC و فیلتر محدودهٔ فعلی نقشه.
  Future<List<Map<String, dynamic>>> fetchInspectionMapData({
    required String codeCo,
    Map<String, dynamic>? userContext,
    LatLngBounds? bounds,
  }) async {
    final query = <String, String>{};
    final code = userContext?['code_co']?.toString().trim() ?? '';
    final state = userContext?['state_user']?.toString().trim() ?? '';
    final city = userContext?['city_user']?.toString().trim() ?? '';
    final typeUser2 = [
      userContext?['type_user_2']?.toString().trim() ?? '',
      userContext?['type_user']?.toString().trim() ?? '',
    ].firstWhere((e) => e.isNotEmpty, orElse: () => '');

    if (code.isNotEmpty) query['user_code_co'] = code;
    if (state.isNotEmpty) query['user_state'] = state;
    if (city.isNotEmpty) query['user_city'] = city;
    if (typeUser2.isNotEmpty) query['user_type_user_2'] = typeUser2;

    if (bounds != null) {
      query['min_lat'] = bounds.south.toString();
      query['max_lat'] = bounds.north.toString();
      query['min_lng'] = bounds.west.toString();
      query['max_lng'] = bounds.east.toString();
    }

    final uri = Uri.parse(
      getApiUrl('select/select_parvande_full/${Uri.encodeComponent(codeCo)}'),
    ).replace(queryParameters: query.isEmpty ? null : query);
    final res = await http.get(uri).timeout(const Duration(seconds: 90));
    if (res.statusCode != 200) {
      throw Exception('خطا در دریافت داده‌های نقشه بازرسی (${res.statusCode})');
    }
    final body = jsonDecode(res.body);
    if (body is! List) return const [];
    return body.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  /// مدارک پرونده از tbl_doc_parvande
  Future<List<Map<String, dynamic>>> fetchDocuments(
    String codeCo,
    String idParvandeh,
  ) async {
    final uri = Uri.parse(
      getApiUrl(
        'select/select_doc_parvande/${Uri.encodeComponent(codeCo)}/${Uri.encodeComponent(idParvandeh)}',
      ),
    );
    final res = await http.get(uri).timeout(const Duration(seconds: 60));
    if (res.statusCode != 200) {
      throw Exception('خطا در دریافت مدارک (${res.statusCode})');
    }
    final body = jsonDecode(res.body);
    if (body is! List) return const [];
    return body.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  /// تغییر وضعیت پرونده: 1 = فعال، 2 = سطل زباله
  Future<void> setActParvande(String idParvandeh, int act) async {
    final uri = Uri.parse(
      getApiUrl(
        'update/update_act_parvande/${Uri.encodeComponent(idParvandeh)}/$act',
      ),
    );
    final res = await http.get(uri);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('خطا در تغییر وضعیت پرونده (${res.statusCode})');
    }
  }

  /// حذف دائم پرونده
  Future<void> deleteForever(String idParvandeh) async {
    final uri = Uri.parse(
      getApiUrl('delete/delete_parvande/${Uri.encodeComponent(idParvandeh)}'),
    );
    final res = await http.get(uri);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('خطا در حذف دائم پرونده (${res.statusCode})');
    }
  }

  /// اطلاعات آخرین ویرایش‌کنندهٔ لوکیشن
  Future<ParvandeLocationEditor?> fetchLocationEditor(
      String idParvandeh) async {
    final uri = Uri.parse(
      getApiUrl(
          'select/select_parvande_location_editor/${Uri.encodeComponent(idParvandeh)}'),
    );
    final res = await http.get(uri);
    if (res.statusCode != 200) return null;

    final body = jsonDecode(res.body);
    if (body is! List || body.isEmpty) return null;
    final row = body.first;
    if (row is! Map) return null;
    return ParvandeLocationEditor.fromJson(Map<String, dynamic>.from(row));
  }

  /// بروزرسانی مختصات واحد صنفی
  Future<void> updateStoreLocation({
    required String idParvandeh,
    required String lat,
    required String lng,
    String? idUser,
    bool keepEditLocation = false,
  }) async {
    var uri = Uri.parse(
      getApiUrl(
        'update/update_store_location/${Uri.encodeComponent(idParvandeh)}/${Uri.encodeComponent(lat)}/${Uri.encodeComponent(lng)}',
      ),
    );

    final query = <String, String>{};
    if (keepEditLocation) query['keep_edit_location'] = '1';
    if (idUser != null && idUser.trim().isNotEmpty) {
      query['id_user'] = idUser.trim();
    }
    if (query.isNotEmpty) uri = uri.replace(queryParameters: query);

    final res = await http.get(uri);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('خطا در ذخیره لوکیشن (${res.statusCode})');
    }
  }

  /// لیست رسته‌های اتحادیه
  Future<List<String>> fetchRasteNames(String codeCo) async {
    final uri = Uri.parse(
        getApiUrl('select/select_raste/${Uri.encodeComponent(codeCo)}'));
    final res = await http.get(uri).timeout(const Duration(seconds: 60));
    if (res.statusCode != 200) {
      throw Exception('خطا در دریافت رسته‌ها (${res.statusCode})');
    }
    final body = jsonDecode(res.body);
    if (body is! List) return const [];
    final names = body
        .map((e) => (e as Map)['name_raste']?.toString().trim() ?? '')
        .where((n) => n.isNotEmpty)
        .toSet()
        .toList();
    names.sort();
    return names;
  }

  /// بروزرسانی پرونده — همان updateParvandeh سرور
  Future<ParvandeUpdateResult> updateParvandeh(
    Map<String, dynamic> parvande, {
    Map<String, String>? overrides,
    bool verboseLog = false,
  }) async {
    return _updateParvandeOnServer(
      parvande,
      overrides: overrides,
      verboseLog: verboseLog,
    );
  }

  /// بروزرسانی سریع: موبایل، تلفن، بدهی
  Future<void> quickUpdateParvandeh({
    required Map<String, dynamic> parvande,
    required String mobAdmin,
    required String telAdmin,
    required String money,
  }) async {
    await updateParvandeh(
      parvande,
      overrides: {
        'mob_admin': mobAdmin.trim(),
        'tel_admin': telAdmin.trim(),
        'money': money.trim().isEmpty ? '0' : money.trim(),
      },
    );
  }

  Future<void> updateParvandeAddressAndLocation({
    required Map<String, dynamic> parvande,
    required String address,
    required String lat,
    required String lng,
    String? idUser,
    bool keepEditLocation = false,
  }) async {
    await _updateParvandeOnServer(
      parvande,
      address: address,
      lat: lat,
      lng: lng,
    );
    await updateStoreLocation(
      idParvandeh: parvande.idParvandeh,
      lat: lat,
      lng: lng,
      idUser: idUser,
      keepEditLocation: keepEditLocation,
    );
  }

  /// بروزرسانی فقط آدرس در سرور (مختصات قبلی حفظ می‌شود)
  Future<void> updateParvandeAddressOnly({
    required Map<String, dynamic> parvande,
    required String address,
  }) async {
    await _updateParvandeOnServer(
      parvande,
      address: address,
      lat: parvande.lat,
      lng: parvande.lng,
    );
  }

  Future<ParvandeUpdateResult> _updateParvandeOnServer(
    Map<String, dynamic> p, {
    String? address,
    String? lat,
    String? lng,
    Map<String, String>? overrides,
    bool verboseLog = false,
  }) async {
    String v(String key) {
      final o = overrides?[key];
      if (o != null) return o;
      return p.s(key);
    }

    String seg(String key) => _pathParam(v(key));
    final moneyRaw = v('money');
    final money = moneyRaw.isEmpty ? '0' : _pathParam(moneyRaw);

    final parts = [
      seg('name_admin'),
      seg('family_admin'),
      seg('sex_admin'),
      seg('sadere_admin'),
      seg('tavalod_admin'),
      seg('name_pedar_admin'),
      seg('num_shenasname_admin'),
      seg('code_meli_admin'),
      seg('mob_admin'),
      seg('tel_admin'),
      seg('madrak_admin'),
      seg('din_admin'),
      seg('sarbazi_admin'),
      seg('taahol_admin'),
      seg('name_store'),
      seg('shenase_store'),
      seg('raste_store'),
      seg('masahat_store'),
      seg('type_melki_store'),
      _pathParam(address ?? v('address_store')),
      seg('code_posti_store'),
      seg('mantaghe_store'),
      _pathParam(lat ?? v('lat_store')),
      _pathParam(lng ?? v('long_store')),
      seg('state_store'),
      seg('city_store'),
      seg('date_sodor_store'),
      seg('date_exp_store'),
      seg('date_etebar_store'),
      seg('daraje_store'),
      seg('num_parvande_store'),
      seg('vaziyat_store'),
      seg('lbl_vaziyat_store'),
      seg('num_person_store'),
      seg('caption_parvande'),
      money,
      _pathParam(p.idParvandeh),
    ];

    final uri =
        Uri.parse(getApiUrl('update/update_parvandeh/${parts.join('/')}'));
    if (verboseLog) {
      debugPrint(
        '[csv_import_update] HTTP GET update_parvandeh | '
        'id=${p.idParvandeh} | shenase=${v('shenase_store')} | '
        'date_sodor=${v('date_sodor_store')} | '
        'vaziyat=${v('vaziyat_store')}/${v('lbl_vaziyat_store')} | '
        'date_exp=${v('date_exp_store')}',
      );
      debugPrint('[csv_import_update] URL: $uri');
    }
    final res = await http.get(uri).timeout(const Duration(seconds: 120));
    if (verboseLog) {
      debugPrint(
        '[csv_import_update] HTTP RESP ${res.statusCode} | '
        'body=${res.body.length > 200 ? '${res.body.substring(0, 200)}…' : res.body}',
      );
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(
        res.body.trim().isNotEmpty
            ? res.body.trim()
            : 'خطا در ذخیره پرونده (${res.statusCode})',
      );
    }
    final body = res.body.toLowerCase();
    if (body.contains('error') || body.contains('fail')) {
      throw Exception('خطا در ذخیره پرونده: ${res.body}');
    }
    return ParvandeUpdateResult(
      statusCode: res.statusCode,
      body: res.body.trim(),
      requestUri: uri.toString(),
    );
  }

  String _pathParam(String value) {
    // `/` در path باعث شکستن پارامترها می‌شود (تاریخ شمسی، آدرس، برچسب وضعیت).
    // `%2F` هم روی بعضی سرورهای جاوا قبول نمی‌شود — به `-` تبدیل می‌کنیم.
    final t = value.trim().replaceAll('/', '-');
    return t.isEmpty ? '0' : Uri.encodeComponent(t);
  }
}

class ParvandeUpdateResult {
  const ParvandeUpdateResult({
    required this.statusCode,
    required this.body,
    required this.requestUri,
  });

  final int statusCode;
  final String body;
  final String requestUri;
}

class ParvandeLocationEditor {
  const ParvandeLocationEditor({
    this.idUser,
    this.nameUser,
    this.familyUser,
    this.typeUser,
  });

  final String? idUser;
  final String? nameUser;
  final String? familyUser;
  final String? typeUser;

  factory ParvandeLocationEditor.fromJson(Map<String, dynamic> json) {
    return ParvandeLocationEditor(
      idUser: json['id_user']?.toString(),
      nameUser: json['name_user']?.toString(),
      familyUser: json['family_user']?.toString(),
      typeUser: json['type_user']?.toString(),
    );
  }

  String get displayName {
    if (idUser == '1000' ||
        (typeUser ?? '').trim().toLowerCase() == 'super_admin') {
      return 'سیستم';
    }
    final full = '${nameUser ?? ''} ${familyUser ?? ''}'.trim();
    return full.isEmpty ? '—' : full;
  }

  String get roleLabel => userRoleLabel(typeUser);
}

const _userRoleLabels = <String, String>{
  'person_co': 'پرسنل عادی',
  'bazras_co': 'بازرس',
  'admin_co': 'مدیر',
  'raees_etehadiye': 'رئیس اتحادیه',
  'moaven_modir': 'معاون مدیر',
  'heyat_modire': 'هیئت مدیره',
  'modir_ejraei': 'مدیر اجرایی',
  'omoor_edari_1': 'امور اداری ۱',
  'omoor_edari_2': 'امور اداری ۲',
  'omoor_edari_3': 'امور اداری ۳',
  'masool_shakayat': 'مسئول شکایات',
  'hesabdari': 'حسابداری',
  'bazrasi_1': 'بازرسی ۱',
  'bazrasi_2': 'بازرسی ۲',
  'karshenas': 'کارشناس',
  'karshenas_1': 'کارشناس ۱',
  'karshenas_2': 'کارشناس ۲',
  'bazrasi_karshenas_1': 'بازرس-کارشناس ۱',
  'bazrasi_karshenas_2': 'بازرس-کارشناس ۲',
  'moshaver': 'مشاور',
  'masool_taavoni': 'مسئول تعاونی',
  'sandoghdar': 'صندوقدار (وب)',
};

/// برچسب فارسی نقش کاربر بر اساس type_user
String userRoleLabel(String? typeUser) {
  final key = typeUser?.trim().toLowerCase() ?? '';
  if (key.isEmpty) return '—';
  if (key == 'super_admin') return 'مدیرکل سیستم';
  return _userRoleLabels[key] ?? typeUser!.trim();
}

/// helperهای کوچک برای کار راحت‌تر با ردیف‌های پرونده
extension ParvandeRow on Map<String, dynamic> {
  String s(String key) => this[key]?.toString().trim() ?? '';
  bool get isTrash => s('act_parvande') == '2';
  bool get isActive => !isTrash;
  String get idParvandeh => s('id_parvandeh');
  String get fullName => ('${s('name_admin')} ${s('family_admin')}')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  String get storeName => s('name_store');
  String get raste => s('raste_store');
  String get mob => s('mob_admin');
  String get codeMeli => s('code_meli_admin');
  String get codePosti => s('code_posti_store');
  String get shenase => s('shenase_store');
  String get numParvande => s('num_parvande_store');
  String get city => s('city_store');
  String get state => s('state_store');
  String get mantaghe => s('mantaghe_store');
  String get address => s('address_store');
  String get vaziyat => s('lbl_vaziyat_store');
  String get vaziyatCode => s('vaziyat_store');
  String get dateExp => s('date_exp_store');
  String get imageProfile => s('image_profile');
  String get imageProfileUrl {
    const imageBase = 'https://apinovin.iranianasnaf.ir/';
    final raw = imageProfile.trim();
    if (raw.isEmpty || raw.toLowerCase() == 'null') return '';

    String normalized = raw.replaceAll('\\', '/').replaceAll(' ', '%20');
    if (normalized.startsWith('http://') || normalized.startsWith('https://')) {
      return Uri.encodeFull(normalized);
    }
    if (normalized.startsWith('apinovin.iranianasnaf.ir')) {
      normalized = normalized.replaceFirst(RegExp(r'^/+'), '');
      return Uri.encodeFull('https://$normalized');
    }
    normalized = normalized.replaceFirst(RegExp(r'^/+'), '');
    return Uri.encodeFull('$imageBase$normalized');
  }

  String get lat => s('lat_store');
  String get lng => s('long_store');
  bool get hasLocation =>
      lat.isNotEmpty &&
      lng.isNotEmpty &&
      lat != '0' &&
      lng != '0' &&
      lat.toLowerCase() != 'null' &&
      lng.toLowerCase() != 'null';

  /// وضعیت همگام‌سازی در حافظهٔ محلی؛ null یعنی این پرونده فقط از سرور لود شده.
  ParvandeSyncStatus? get cacheSyncStatus {
    if (!containsKey('_sync_status')) return null;
    return ParvandeSyncStatusX.fromStorage(s('_sync_status'));
  }

  bool get isInLocalCache => cacheSyncStatus != null;

  bool get needsSyncSend {
    final st = cacheSyncStatus;
    return st == ParvandeSyncStatus.local || st == ParvandeSyncStatus.dirty;
  }
}
