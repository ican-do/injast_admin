import 'dart:convert';

import 'package:injast_admin/injast_http.dart' as http;
import 'package:injast_admin/server_config.dart';

class InspectionArchiveApi {
  InspectionArchiveApi._();
  static final instance = InspectionArchiveApi._();

  static const _timeout = Duration(seconds: 90);

  Future<Map<String, dynamic>> fetchArchive({
    required String codeCo,
    String q = '',
    String raste = '',
    String formId = '',
    String inspectorId = '',
    String from = '',
    String to = '',
  }) async {
    final query = <String, String>{
      if (q.trim().isNotEmpty) 'q': q.trim(),
      if (raste.trim().isNotEmpty) 'raste': raste.trim(),
      if (formId.trim().isNotEmpty) 'form_id': formId.trim(),
      if (inspectorId.trim().isNotEmpty) 'inspector_id': inspectorId.trim(),
      if (from.trim().isNotEmpty) 'from': from.trim(),
      if (to.trim().isNotEmpty) 'to': to.trim(),
    };
    final uri = Uri.parse(
      getApiUrl('bazrasi-forms/${Uri.encodeComponent(codeCo)}/archive'),
    ).replace(queryParameters: query.isEmpty ? null : query);
    final res = await http.get(uri).timeout(_timeout);
    return _data(res, 'خطا در دریافت آرشیو بازرسی');
  }

  Future<Map<String, dynamic>> fetchParvande({
    required String codeCo,
    required String idParvande,
  }) async {
    final uri = Uri.parse(
      getApiUrl(
        'bazrasi-forms/${Uri.encodeComponent(codeCo)}/archive/${Uri.encodeComponent(idParvande)}',
      ),
    );
    final res = await http.get(uri).timeout(_timeout);
    return _data(res, 'خطا در دریافت پرونده');
  }

  Future<List<Map<String, dynamic>>> fetchInspectors(String codeCo) async {
    final uri = Uri.parse(
      getApiUrl('bazrasi-forms/${Uri.encodeComponent(codeCo)}/inspectors'),
    );
    final res = await http.get(uri).timeout(_timeout);
    final raw = _raw(res, 'خطا در دریافت بازرسان');
    final data = raw['data'];
    if (data is! List) return const [];
    return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<Map<String, dynamic>> saveOutcome({
    required String codeCo,
    required String sourceKind,
    required String sourceId,
    required String status,
    required String statusDate,
    String idParvande = '',
    String formId = '',
    String formName = '',
    String authorityName = '',
    String reinspectInspectorId = '',
    String reinspectInspectorName = '',
    String reinspectDate = '',
  }) async {
    final uri = Uri.parse(
      getApiUrl('bazrasi-forms/${Uri.encodeComponent(codeCo)}/outcome'),
    );
    final res = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json; charset=utf-8'},
          body: jsonEncode({
            'source_kind': sourceKind,
            'source_id': sourceId,
            'status': status,
            'status_date': statusDate,
            'id_parvande': idParvande,
            'form_id': formId,
            'form_name': formName,
            'authority_name': authorityName,
            'reinspect_inspector_id': reinspectInspectorId,
            'reinspect_inspector_name': reinspectInspectorName,
            'reinspect_date': reinspectDate,
          }),
        )
        .timeout(_timeout);
    return _data(res, 'خطا در ثبت وضعیت نهایی');
  }

  Future<Map<String, dynamic>> fetchFill({
    required String codeCo,
    required String fillId,
  }) async {
    final uri = Uri.parse(
      getApiUrl(
        'bazrasi-forms/${Uri.encodeComponent(codeCo)}/fill/${Uri.encodeComponent(fillId)}',
      ),
    );
    final res = await http.get(uri).timeout(_timeout);
    return _data(res, 'خطا در دریافت فرم بازرسی');
  }

  Map<String, dynamic> _raw(http.Response res, String fallback) {
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('$fallback (${res.statusCode})');
    }
    final body = jsonDecode(res.body);
    if (body is! Map) throw Exception(fallback);
    if (body['success'] == false) {
      throw Exception(body['message']?.toString() ?? fallback);
    }
    return Map<String, dynamic>.from(body);
  }

  Map<String, dynamic> _data(http.Response res, String fallback) {
    final raw = _raw(res, fallback);
    final data = raw['data'];
    if (data is Map) return Map<String, dynamic>.from(data);
    return {};
  }
}

String publicBazrasiFillUrl(String token) {
  final t = token.trim();
  if (t.isEmpty) return '';
  return '$publicWebOrigin/bazrasi/#/BazrasiFill/$t';
}
