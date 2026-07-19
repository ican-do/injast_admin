import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:injast_admin/features/shekayat/compat/shekayat_basic.dart';
import 'package:injast_admin/server_config.dart';

Future<void> select_person_co_val(String codeco) async {
  list_user_select = [];
  final response = await http.get(
    Uri.parse(getApiUrl('select/select_person_co/$codeco')),
  );
  if (response.statusCode != 200) return;
  try {
    final decoded = jsonDecode(response.body);
    if (decoded is List) {
      list_user_select = decoded;
    }
  } catch (_) {
    list_user_select = [];
  }
}

Future<void> select_parvande_val(dynamic val) async {
  list_parvande_basic = [];
  final encoded = Uri.encodeComponent(val.toString().trim());
  final uri = Uri.parse(getApiUrl('select/select_parvande/$encoded/$code_co'));
  final response = await http.get(uri);
  if (response.statusCode != 200) return;
  try {
    final decoded = jsonDecode(response.body);
    if (decoded is List) {
      list_parvande_basic = decoded;
    }
  } catch (_) {
    list_parvande_basic = [];
  }
}
