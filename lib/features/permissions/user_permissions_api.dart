import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:injast_admin/server_config.dart';

class UserPermissionsData {
  final String idUser;
  final String baseRole;
  final Set<String> permissions;
  final bool exists;

  const UserPermissionsData({
    required this.idUser,
    required this.baseRole,
    required this.permissions,
    required this.exists,
  });
}

class UserPermissionsApi {
  /// دریافت پروفایل دسترسی کاربر از سرور
  static Future<UserPermissionsData?> fetch(String idUser) async {
    final url = getApiUrl('select/user_permissions/$idUser');
    final response = await http.get(Uri.parse(url));
    if (response.statusCode != 200) return null;

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (body['success'] != true) return null;

    if (body['exists'] != true || body['data'] == null) {
      return UserPermissionsData(
        idUser: idUser,
        baseRole: '',
        permissions: {},
        exists: false,
      );
    }

    final data = body['data'] as Map<String, dynamic>;
    final perms = (data['permissions'] as List<dynamic>? ?? [])
        .map((e) => e.toString())
        .toSet();

    return UserPermissionsData(
      idUser: data['id_user']?.toString() ?? idUser,
      baseRole: data['base_role']?.toString() ?? 'person_co',
      permissions: perms,
      exists: true,
    );
  }

  /// ذخیره پروفایل دسترسی
  static Future<bool> save({
    required String idUser,
    required String baseRole,
    required Set<String> permissions,
  }) async {
    final url = getApiUrl('update/user_permissions');
    final response = await http.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'id_user': idUser,
        'base_role': baseRole,
        'permissions': permissions.toList()..sort(),
      }),
    );
    if (response.statusCode != 200) return false;
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return body['success'] == true;
  }

  /// حذف پروفایل شخصی (بازگشت به الگوی نقش)
  static Future<bool> reset(String idUser) async {
    final url = getApiUrl('delete/user_permissions/$idUser');
    final response = await http.get(Uri.parse(url));
    if (response.statusCode != 200) return false;
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return body['success'] == true;
  }
}
