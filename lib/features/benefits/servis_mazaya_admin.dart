import 'dart:convert';

import 'package:injast_admin/injast_http.dart' as http;

import 'package:injast_admin/features/benefits/mazaya.dart';
import 'package:injast_admin/server_config.dart';
String get _baseUrl => adminApiBaseUrl;

class ServisMazayaAdmin {
  ServisMazayaAdmin._();

   static const Duration _timeout = Duration(seconds: 15);

  static Future<List<DasteMazaya>> gereftanDasteha({
    String? codeCo,
    bool activeOnly = false,
  }) async {
    final params = <String, String>{};
    if (codeCo != null && codeCo.isNotEmpty) {
      params['code_co'] = codeCo;
    }
    if (activeOnly) {
      params['active_only'] = '1';
    }
    final uri = Uri.parse('$_baseUrl/admin/benefits/categories')
        .replace(queryParameters: params.isEmpty ? null : params);
    final response = await http.get(uri).timeout(_timeout);
    final body = jsonDecode(utf8.decode(response.bodyBytes));
    if (response.statusCode == 200 && body['success'] == true) {
      final List list = body['data'] ?? [];
      return list.map((e) => DasteMazaya.fromJson(e)).toList();
    }
    return [];
  }

  static Future<bool> sakhtDaste({
    required String codeCo,
    required String title,
    String? description,
    bool isActive = true,
  }) async {
    final response = await http
        .post(
          Uri.parse('$_baseUrl/admin/benefits/categories'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'code_co': codeCo,
            'name_cat': title,
            'description': description,
            'act_cat': isActive ? 1 : 0,
          }),
        )
        .timeout(_timeout);
    final body = jsonDecode(utf8.decode(response.bodyBytes));
    return response.statusCode == 201 && body['success'] == true;
  }

  static Future<bool> virayeshDaste(
    int idCat, {
    String? title,
    String? description,
    bool? isActive,
  }) async {
    final payload = <String, dynamic>{};
    if (title != null) payload['name_cat'] = title;
    if (description != null) payload['description'] = description;
    if (isActive != null) payload['act_cat'] = isActive ? 1 : 0;
    final response = await http
        .put(
          Uri.parse('$_baseUrl/admin/benefits/categories/$idCat'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(payload),
        )
        .timeout(_timeout);
    final body = jsonDecode(utf8.decode(response.bodyBytes));
    return response.statusCode == 200 && body['success'] == true;
  }

  static Future<bool> hazfDaste(int idCat) async {
    final response = await http
        .delete(Uri.parse('$_baseUrl/admin/benefits/categories/$idCat'))
        .timeout(_timeout);
    final body = jsonDecode(utf8.decode(response.bodyBytes));
    return response.statusCode == 200 && body['success'] == true;
  }

  static Future<List<MazayaItem>> gereftanMazaya({
    String? codeCo,
    int? categoryId,
    bool activeOnly = false,
  }) async {
    final params = <String, String>{};
    if (codeCo != null && codeCo.isNotEmpty) params['code_co'] = codeCo;
    if (categoryId != null) params['id_cat'] = '$categoryId';
    if (activeOnly) params['active_only'] = '1';
    final uri = Uri.parse('$_baseUrl/admin/benefits')
        .replace(queryParameters: params.isEmpty ? null : params);
    final response = await http.get(uri).timeout(_timeout);
    final body = jsonDecode(utf8.decode(response.bodyBytes));
    if (response.statusCode == 200 && body['success'] == true) {
      final List list = body['data'] ?? [];
      return list.map((e) => MazayaItem.fromJson(e)).toList();
    }
    return [];
  }

  static Future<int?> sakhtMazaya({
    required String codeCo,
    required int categoryId,
    required String title,
    required String fullDesc,
    String? shortDesc,
    String? iconName,
    bool isActive = true,
  }) async {
    final response = await http
        .post(
          Uri.parse('$_baseUrl/admin/benefits'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'code_co': codeCo,
            'id_cat': categoryId,
            'title': title,
            'short_desc': shortDesc,
            'full_desc': fullDesc,
            'icon_name': iconName,
            'act_benefit': isActive ? 1 : 0,
          }),
        )
        .timeout(_timeout);
    final body = jsonDecode(utf8.decode(response.bodyBytes));
    if (response.statusCode == 201 && body['success'] == true) {
      return body['data']?['id_benefit'];
    }
    return null;
  }

  static Future<bool> virayeshMazaya(
    int idBenefit, {
    int? categoryId,
    String? title,
    String? shortDesc,
    String? fullDesc,
    String? iconName,
    bool? isActive,
  }) async {
    final payload = <String, dynamic>{};
    if (categoryId != null) payload['id_cat'] = categoryId;
    if (title != null) payload['title'] = title;
    if (shortDesc != null) payload['short_desc'] = shortDesc;
    if (fullDesc != null) payload['full_desc'] = fullDesc;
    if (iconName != null) payload['icon_name'] = iconName;
    if (isActive != null) payload['act_benefit'] = isActive ? 1 : 0;
    final response = await http
        .put(
          Uri.parse('$_baseUrl/admin/benefits/$idBenefit'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(payload),
        )
        .timeout(_timeout);
    final body = jsonDecode(utf8.decode(response.bodyBytes));
    return response.statusCode == 200 && body['success'] == true;
  }

  static Future<bool> hazfMazaya(int idBenefit) async {
    final response = await http
        .delete(Uri.parse('$_baseUrl/admin/benefits/$idBenefit'))
        .timeout(_timeout);
    final body = jsonDecode(utf8.decode(response.bodyBytes));
    return response.statusCode == 200 && body['success'] == true;
  }

  static Future<List<StepMazaya>> gereftanMarhale(int idBenefit) async {
    final response = await http
        .get(Uri.parse('$_baseUrl/admin/benefits/$idBenefit/steps'))
        .timeout(_timeout);
    final body = jsonDecode(utf8.decode(response.bodyBytes));
    if (response.statusCode == 200 && body['success'] == true) {
      final List list = body['data'] ?? [];
      return list.map((e) => StepMazaya.fromJson(e)).toList();
    }
    return [];
  }

  static Future<bool> sakhtMarhale({
    required int idBenefit,
    required int stepNumber,
    required String title,
    String? description,
  }) async {
    final response = await http
        .post(
          Uri.parse('$_baseUrl/admin/benefits/$idBenefit/steps'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'step_number': stepNumber,
            'step_title': title,
            'step_desc': description,
          }),
        )
        .timeout(_timeout);
    final body = jsonDecode(utf8.decode(response.bodyBytes));
    return response.statusCode == 201 && body['success'] == true;
  }

  static Future<bool> virayeshMarhale(
    int idStep, {
    int? stepNumber,
    String? title,
    String? description,
  }) async {
    final payload = <String, dynamic>{};
    if (stepNumber != null) payload['step_number'] = stepNumber;
    if (title != null) payload['step_title'] = title;
    if (description != null) payload['step_desc'] = description;
    final response = await http
        .put(
          Uri.parse('$_baseUrl/admin/benefits/steps/$idStep'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(payload),
        )
        .timeout(_timeout);
    final body = jsonDecode(utf8.decode(response.bodyBytes));
    return response.statusCode == 200 && body['success'] == true;
  }

  static Future<bool> hazfMarhale(int idStep) async {
    final response = await http
        .delete(Uri.parse('$_baseUrl/admin/benefits/steps/$idStep'))
        .timeout(_timeout);
    final body = jsonDecode(utf8.decode(response.bodyBytes));
    return response.statusCode == 200 && body['success'] == true;
  }
}

