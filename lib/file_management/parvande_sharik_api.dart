import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:injast_admin/server_config.dart';

/// API شرکای پرونده
class ParvandeSharikApi {
  ParvandeSharikApi._();
  static final ParvandeSharikApi instance = ParvandeSharikApi._();

  static const _timeout = Duration(seconds: 120);

  Future<List<Map<String, dynamic>>> fetchByParvande(String idParvandeh) async {
    final uri = Uri.parse(getApiUrl('select/select_sharik/${Uri.encodeComponent(idParvandeh)}'));
    logSharikDebug('GET $uri');
    final res = await http.get(uri).timeout(_timeout);
    if (res.statusCode != 200) {
      throw Exception('خطا در دریافت شرکا (${res.statusCode})');
    }
    final body = jsonDecode(res.body.trim());
    if (body is! List) return const [];
    return body.map((e) => _normalize(Map<String, dynamic>.from(e as Map))).toList();
  }

  Future<void> insert({
    required String codeCo,
    required String idParvandeh,
    required String idUser,
    required Map<String, String> fields,
  }) async {
    final parts = [
      _seg(codeCo),
      _nullable(fields['name_sharik']),
      _seg(fields['family_sharik']),
      _nullable(fields['sex_sharik']),
      _nullable(fields['sadere_sharik']),
      _nullable(fields['tavalod_sharik']),
      _nullable(fields['name_pedar_sharik']),
      _nullable(fields['num_shenasname_sharik']),
      _seg(fields['code_meli_sharik']),
      _seg(fields['mob_sharik']),
      _nullable(fields['tel_sharik']),
      _nullable(fields['madrak_sharik']),
      _nullable(fields['din_sharik']),
      _nullable(fields['sarbazi_sharik']),
      _nullable(fields['taahol_sharik']),
      _nullable(fields['type_fard']),
      _nullable(fields['date_sodor_sharik']),
      _nullable(fields['date_exp_sharik']),
      _seg(idParvandeh),
      _nullable(fields['caption_sharik']),
      _seg(idUser),
      '1',
    ];
    final uri = Uri.parse(getApiUrl('insert/insert_sharik/${parts.join('/')}'));
    logSharikDebug('GET $uri');
    final res = await http.get(uri).timeout(_timeout);
    final body = res.body.trim();
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(
        body.isNotEmpty ? body : 'خطا در ثبت شریک (${res.statusCode})',
      );
    }
    if (body.toLowerCase().contains('error')) {
      throw Exception(body);
    }
  }

  Future<void> update({
    required String idSharik,
    required Map<String, String> fields,
  }) async {
    final parts = [
      _seg(idSharik),
      _nullable(fields['name_sharik']),
      _seg(fields['family_sharik']),
      _nullable(fields['sex_sharik']),
      _nullable(fields['sadere_sharik']),
      _nullable(fields['tavalod_sharik']),
      _nullable(fields['name_pedar_sharik']),
      _nullable(fields['num_shenasname_sharik']),
      _seg(fields['code_meli_sharik']),
      _seg(fields['mob_sharik']),
      _nullable(fields['tel_sharik']),
      _nullable(fields['madrak_sharik']),
      _nullable(fields['din_sharik']),
      _nullable(fields['sarbazi_sharik']),
      _nullable(fields['taahol_sharik']),
      _nullable(fields['type_fard']),
      _nullable(fields['date_sodor_sharik']),
      _nullable(fields['date_exp_sharik']),
      _nullable(fields['caption_sharik']),
    ];
    final uri = Uri.parse(getApiUrl('update/update_sharik/${parts.join('/')}'));
    logSharikDebug('GET $uri');
    final res = await http.get(uri).timeout(_timeout);
    final body = res.body.trim();
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(
        body.isNotEmpty ? body : 'خطا در ویرایش شریک (${res.statusCode})',
      );
    }
    if (body.toLowerCase().contains('error')) {
      throw Exception(body);
    }
  }

  Future<void> delete(String idSharik) async {
    final uri = Uri.parse(getApiUrl('delete/delete_sharik/${Uri.encodeComponent(idSharik)}'));
    final res = await http.get(uri).timeout(_timeout);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('خطا در حذف شریک (${res.statusCode})');
    }
  }

  Map<String, dynamic> _normalize(Map<String, dynamic> row) {
    return row.map((k, v) => MapEntry(k, v?.toString() ?? ''));
  }

  String _seg(String? value) {
    final t = value?.trim() ?? '';
    return t.isEmpty ? '0' : Uri.encodeComponent(t);
  }

  String _nullable(String? value) {
    final t = value?.trim() ?? '';
    return t.isEmpty ? 'null' : Uri.encodeComponent(t);
  }
}

void logSharikDebug(String message) {
  debugPrint('[Sharik] $message');
}
