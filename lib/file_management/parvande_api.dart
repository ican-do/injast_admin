import 'dart:convert';

import 'package:http/http.dart' as http;
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
}

/// helperهای کوچک برای کار راحت‌تر با ردیف‌های پرونده
extension ParvandeRow on Map<String, dynamic> {
  String s(String key) => this[key]?.toString().trim() ?? '';
  bool get isTrash => s('act_parvande') == '2';
  bool get isActive => !isTrash;
  String get idParvandeh => s('id_parvandeh');
  String get fullName =>
      ('${s('name_admin')} ${s('family_admin')}').replaceAll(RegExp(r'\s+'), ' ').trim();
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
}
