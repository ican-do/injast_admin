import 'dart:convert';

import 'package:injast_admin/injast_http.dart' as http;
import 'package:injast_admin/server_config.dart';

class PlaceApi {
  PlaceApi._();

  static Future<List<String>> readStates() async {
    final response = await http.get(Uri.parse(getApiUrl('select/read_state')));
    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}');
    }
    final body = jsonDecode(utf8.decode(response.bodyBytes));
    if (body is! List) return [];
    return body
        .map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  static Future<List<String>> readCities(String state) async {
    final encoded = Uri.encodeComponent(state.trim());
    final response =
        await http.get(Uri.parse(getApiUrl('select/read_city/$encoded')));
    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}');
    }
    final body = jsonDecode(utf8.decode(response.bodyBytes));
    if (body is! List) return [];
    return body
        .map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }
}
