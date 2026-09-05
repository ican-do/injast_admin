import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:injast_admin/injast_http.dart' as http;
import 'package:injast_admin/server_config.dart';

/// API بازرسی پرونده
class ParvandeBazrasiApi {
  ParvandeBazrasiApi._();
  static final ParvandeBazrasiApi instance = ParvandeBazrasiApi._();

  static const _timeout = Duration(seconds: 120);

  Future<List<Map<String, dynamic>>> fetchByParvande(
    String idParvandeh, {
    bool silent = false,
  }) async {
    final uri = Uri.parse(
      getApiUrl('select/select_bazrasi/${Uri.encodeComponent(idParvandeh)}'),
    );
    if (!silent) logBazrasiDebug('GET $uri');
    final res = await http.get(uri).timeout(_timeout);
    if (!silent) {
      logBazrasiDebug('select status=${res.statusCode} len=${res.body.length}');
    }
    if (res.statusCode != 200) {
      throw Exception('خطا در دریافت سوابق بازرسی (${res.statusCode})');
    }
    final bodyText = res.body.trim();
    if (bodyText.isEmpty) return const [];
    if (bodyText.startsWith('<')) {
      throw Exception('پاسخ سرور HTML است (احتمالاً timeout یا خطای سرور)');
    }
    final body = jsonDecode(bodyText);
    if (body is! List) return const [];
    return body
        .map((e) => _normalizeRow(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> insert({
    required String codeCo,
    required String codeBazrasi,
    required String idParvandeh,
    required String shenaseBazrasi,
    required String dateSodor,
    required String vaziyatBazrasi,
    required String dayBazrasi,
    required String captionBazrasi,
    required String dateAmaken,
    required String numAmaken,
    required String dateEjrayi,
    required String numEjrayi,
    required String idUser,
    required String typeTakhalof,
  }) async {
    final parts = [
      _seg(codeCo),
      codeBazrasi.trim().isEmpty ? '0' : codeBazrasi,
      _seg(idParvandeh),
      _seg(shenaseBazrasi),
      _seg(dateSodor),
      _seg(vaziyatBazrasi),
      _seg(dayBazrasi),
      _seg(captionBazrasi),
      _seg(dateAmaken),
      _seg(numAmaken),
      _seg(dateEjrayi),
      _seg(numEjrayi),
      '1',
      _seg(idUser),
      _seg(typeTakhalof),
    ];
    final uri =
        Uri.parse(getApiUrl('insert/insert_bazrasi/${parts.join('/')}'));
    logBazrasiDebug('GET $uri');
    final res = await http.get(uri).timeout(_timeout);
    logBazrasiDebug('insert status=${res.statusCode} body=${res.body.trim()}');
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('خطا در ثبت بازرسی (${res.statusCode})');
    }
    final body = res.body.trim().toLowerCase();
    if (body.contains('error') || body.contains('fail')) {
      throw Exception('سرور ثبت بازرسی را رد کرد: ${res.body.trim()}');
    }
  }

  Future<void> delete(String idBazrasi) async {
    final uri = Uri.parse(
      getApiUrl('delete/delete_bazrasi/${Uri.encodeComponent(idBazrasi)}'),
    );
    final res = await http.get(uri).timeout(_timeout);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('خطا در حذف بازرسی (${res.statusCode})');
    }
  }

  Future<void> updateFull({
    required String idBazrasi,
    required String dateAmaken,
    required String numAmaken,
    required String dateEjrayi,
    required String numEjrayi,
    required String lastResult,
    required String dateTahod,
    required String modatTahod,
    required String noeTahod,
    required String dateAdamPelamp,
    required String numAdamPelamp,
    required String datePelamp,
    required String numPelamp,
    required String dateFekPelamp,
    required String numFekPelamp,
    required String tozihat,
  }) async {
    final parts = [
      _seg(idBazrasi),
      _seg(dateAmaken),
      _seg(numAmaken),
      _seg(dateEjrayi),
      _seg(numEjrayi),
      _seg(lastResult),
      _seg(dateTahod),
      _seg(modatTahod),
      _seg(noeTahod),
      _seg(dateAdamPelamp),
      _seg(numAdamPelamp),
      _seg(datePelamp),
      _seg(numPelamp),
      _seg(dateFekPelamp),
      _seg(numFekPelamp),
      _seg(tozihat),
    ];
    final uri = Uri.parse(
        getApiUrl('update/update_tbl_bazrasi_full/${parts.join('/')}'));
    final res = await http.get(uri).timeout(_timeout);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('خطا در ویرایش بازرسی (${res.statusCode})');
    }
  }

  Map<String, dynamic> _normalizeRow(Map<String, dynamic> row) {
    return row.map((k, v) => MapEntry(k, v?.toString() ?? ''));
  }

  String _seg(String? value) {
    final t = value?.trim() ?? '';
    return t.isEmpty ? '0' : Uri.encodeComponent(t);
  }
}

void logBazrasiDebug(String message) {
  debugPrint('[Bazrasi] $message');
}
