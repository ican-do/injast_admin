import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:injast_admin/server_config.dart';

String _segment(Object value) => Uri.encodeComponent(value.toString().trim());

bool _isSuccessful(http.Response response) =>
    response.statusCode >= 200 && response.statusCode < 300;

Future<List<Map<String, dynamic>>> getRasteList(String codeCo) async {
  final response = await http.get(
    Uri.parse(getApiUrl('select/select_raste/${_segment(codeCo)}')),
  );
  if (!_isSuccessful(response)) {
    throw Exception('دریافت فهرست رسته‌ها ناموفق بود (${response.statusCode})');
  }

  final decoded = jsonDecode(response.body);
  final List<dynamic> rows;
  if (decoded is List<dynamic>) {
    rows = decoded;
  } else if (decoded is Map<String, dynamic> && decoded['data'] is List) {
    rows = decoded['data'] as List<dynamic>;
  } else {
    throw const FormatException('ساختار پاسخ فهرست رسته‌ها معتبر نیست');
  }
  return rows
      .whereType<Map>()
      .map((row) => Map<String, dynamic>.from(row))
      .toList();
}

Future<bool> createRaste({
  required String codeCo,
  required String name,
  required String code,
  required String type,
  required String idUser,
}) async {
  final datetime = DateTime.now().toIso8601String();
  final path = [
    'insert',
    'insert_raste',
    codeCo,
    name,
    code,
    type,
    idUser,
    '1',
    datetime,
  ].map(_segment).join('/');
  return _isSuccessful(await http.get(Uri.parse(getApiUrl(path))));
}

Future<bool> updateRaste({
  required String idRaste,
  required String name,
  required String code,
  required String type,
}) async {
  final path = [
    'update',
    'UPDATE_raste',
    name,
    code,
    type,
    idRaste,
  ].map(_segment).join('/');
  return _isSuccessful(await http.get(Uri.parse(getApiUrl(path))));
}

Future<bool> deleteRaste(String idRaste) async {
  final response = await http.get(
    Uri.parse(getApiUrl('delete/delete_raste/${_segment(idRaste)}')),
  );
  return _isSuccessful(response);
}
