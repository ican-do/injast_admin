import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:injast_admin/server_config.dart';

class ShekayatApi {
  static String _url(String path) => getApiUrl(path);

  static Future<Map<String, dynamic>> _get(String path) async {
    final res = await http.get(Uri.parse(_url(path)));
    if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
    return json.decode(res.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body) async {
    final res = await http.post(
      Uri.parse(_url(path)),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(body),
    );
    if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
    return json.decode(res.body) as Map<String, dynamic>;
  }

  static Future<List<dynamic>> listComplaints(
    String codeCo, {
    String? status,
    String? search,
    String? idExpert,
    String? type,
  }) async {
    final q = <String, String>{};
    if (status != null && status.isNotEmpty) q['status'] = status;
    if (search != null && search.isNotEmpty) q['search'] = search;
    if (idExpert != null) q['id_expert'] = idExpert;
    if (type != null) q['type_shekayat'] = type;
    final uri = Uri.parse(_url('shekayat/list/$codeCo')).replace(queryParameters: q.isEmpty ? null : q);
    final res = await http.get(uri);
    final body = json.decode(res.body) as Map<String, dynamic>;
    return body['data'] as List? ?? [];
  }

  static Future<Map<String, dynamic>?> getDetail(String codeShekayat) async {
    final body = await _get('shekayat/detail/$codeShekayat');
    return body['data'] as Map<String, dynamic>?;
  }

  static Future<Map<String, dynamic>> createComplaint(Map<String, dynamic> data) async {
    return _post('shekayat/create', data);
  }

  static Future<bool> updateComplaint(Map<String, dynamic> data) async {
    final body = await _post('shekayat/update', data);
    return body['success'] == true;
  }

  static Future<bool> deleteFull(String codeShekayat) async {
    final body = await _get('shekayat/delete_full/$codeShekayat');
    return body['success'] == true;
  }

  static Future<List<dynamic>> getCategories(String codeCo) async {
    final body = await _get('shekayat/categories/$codeCo');
    return body['data'] as List? ?? [];
  }

  static Future<bool> saveCategory(Map<String, dynamic> data) async {
    final body = await _post('shekayat/category/save', data);
    return body['success'] == true;
  }

  static Future<bool> assignCategory(String codeShekayat, int idCategory) async {
    return assignCategories(codeShekayat, [idCategory]);
  }

  static Future<bool> assignCategories(String codeShekayat, List<int> idCategories) async {
    final body = await _post('shekayat/assign_category', {
      'code_shekayat': codeShekayat,
      'id_categories': idCategories,
    });
    return body['success'] == true;
  }

  static Future<List<dynamic>> getComplaintCategories(String codeShekayat) async {
    final body = await _get('shekayat/complaint_categories/$codeShekayat');
    return body['data'] as List? ?? [];
  }

  static Future<List<dynamic>> getAttachments(String code, {String source = 'all'}) async {
    final body = await _get('shekayat/attachments/$code/$source');
    return body['data'] as List? ?? [];
  }

  static Future<bool> saveAttachment(Map<String, dynamic> data) async {
    final body = await _post('shekayat/attachment/save', data);
    return body['success'] == true;
  }

  static Future<Map<String, dynamic>> saveAttachmentResult(Map<String, dynamic> data) async {
    return _post('shekayat/attachment/save', data);
  }

  static Future<bool> deleteAttachment(dynamic id) async {
    final body = await _get('shekayat/attachment/delete/$id');
    return body['success'] == true;
  }

  static Future<List<dynamic>> getExperts(String code) async {
    final body = await _get('shekayat/experts/$code');
    return body['data'] as List? ?? [];
  }

  static Future<List<dynamic>> getExpertRecords(String code) async {
    final body = await _get('shekayat/expert_records/$code');
    return body['data'] as List? ?? [];
  }

  static Future<List<dynamic>> getExpertProfiles(String codeCo) async {
    final body = await _get('shekayat/expert_profiles/$codeCo');
    return body['data'] as List? ?? [];
  }

  static Future<bool> saveExpertProfile(Map<String, dynamic> data) async {
    final body = await _post('shekayat/expert_profile/save', data);
    return body['success'] == true;
  }

  static Future<bool> saveExpert(Map<String, dynamic> data) async {
    final body = await _post('shekayat/expert/save', data);
    return body['success'] == true;
  }

  static Future<Map<String, dynamic>> saveExpertRaw(Map<String, dynamic> data) async {
    return _post('shekayat/expert/save', data);
  }

  static Future<List<dynamic>> getOpinions(String code) async {
    final body = await _get('shekayat/opinions/$code');
    return body['data'] as List? ?? [];
  }

  static Future<bool> saveOpinion(Map<String, dynamic> data) async {
    final body = await _post('shekayat/opinion/save', data);
    return body['success'] == true;
  }

  static Future<List<dynamic>> getSessions(String code) async {
    final body = await _get('shekayat/sessions/$code');
    return body['data'] as List? ?? [];
  }

  static Future<bool> saveSession(Map<String, dynamic> data) async {
    final body = await _post('shekayat/session/save', data);
    return body['success'] == true;
  }

  static Future<List<dynamic>> getFollowups(String code) async {
    final body = await _get('shekayat/followups/$code');
    return body['data'] as List? ?? [];
  }

  static Future<bool> saveFollowup(Map<String, dynamic> data) async {
    final body = await _post('shekayat/followup/save', data);
    return body['success'] == true;
  }

  static Future<bool> deleteFollowup(int id) async {
    final body = await _get('shekayat/followup/delete/$id');
    return body['success'] == true;
  }

  static Future<bool> deleteSession(int id) async {
    final body = await _get('shekayat/session/delete/$id');
    return body['success'] == true;
  }

  static Future<bool> deleteCategory(int id) async {
    final res = await http.get(Uri.parse(_url('shekayat/category/delete/$id')));
    final body = json.decode(res.body) as Map<String, dynamic>;
    if (body['success'] != true) {
      throw Exception(body['message']?.toString() ?? 'خطا در حذف موضوع');
    }
    return true;
  }

  static Future<Map<String, dynamic>> getFormNote(String codeCo) async {
    final body = await _get('shekayat/form_note/$codeCo');
    return body['data'] as Map<String, dynamic>? ?? {};
  }

  static Future<bool> saveFormNote(String codeCo, String note) async {
    final body = await _post('shekayat/form_note/save', {'code_co': codeCo, 'form_note': note});
    return body['success'] == true;
  }

  static Future<List<dynamic>> getCalendarEvents(String codeCo) async {
    final body = await _get('shekayat/calendar/$codeCo');
    return body['data'] as List? ?? [];
  }

  static Future<bool> linkParvandeh(String codeShekayat, String idParvandeh) async {
    final body = await _post('shekayat/link_parvandeh', {
      'code_shekayat': codeShekayat,
      'id_parvandeh': idParvandeh,
    });
    return body['success'] == true;
  }

  static Future<List<dynamic>> reportByParvandeh(String codeCo) async {
    final body = await _get('shekayat/report_by_parvandeh/$codeCo');
    return body['data'] as List? ?? [];
  }
}
