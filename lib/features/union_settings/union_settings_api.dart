import 'dart:convert';

import 'package:image_picker/image_picker.dart';
import 'package:injast_admin/injast_http.dart' as http;
import 'package:injast_admin/server_config.dart';

class UnionSettingsApi {
  UnionSettingsApi._();
  static final instance = UnionSettingsApi._();

  Future<Map<String, dynamic>> fetch(String codeCo) async {
    final res = await http.get(
      Uri.parse(getApiUrl('union-settings/${Uri.encodeComponent(codeCo)}')),
    );
    return _data(res, 'خطا در دریافت تنظیمات اتحادیه');
  }

  Future<Map<String, dynamic>> save(String codeCo, Map<String, dynamic> body) async {
    final res = await http.put(
      Uri.parse(getApiUrl('union-settings/${Uri.encodeComponent(codeCo)}')),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    return _data(res, 'خطا در ذخیره تنظیمات اتحادیه');
  }

  Future<String> uploadLogo(String codeCo, XFile file) async {
    final name = file.name.toLowerCase();
    final path = file.path.toLowerCase();
    final ok = name.endsWith('.png') ||
        name.endsWith('.jpg') ||
        name.endsWith('.jpeg') ||
        path.endsWith('.png') ||
        path.endsWith('.jpg') ||
        path.endsWith('.jpeg') ||
        !name.contains('.');
    if (!ok) {
      throw Exception('فقط فایل PNG یا JPG مجاز است');
    }
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final uri = Uri.parse(getApiUrl('upload/image'));
    final bytes = await file.readAsBytes();
    if (bytes.length > 2 * 1024 * 1024) {
      throw Exception('حجم لوگو حداکثر ۲ مگابایت باشد');
    }
    final request = http.MultipartRequest('POST', uri)
      ..fields['path'] = 'union'
      ..fields['filename'] = 'logo_${codeCo}_$stamp'
      ..files.add(http.MultipartFile.fromBytes(
        'image',
        bytes,
        filename: name.contains('.') ? file.name : 'logo.jpg',
      ));
    final streamed = await http.send(request).timeout(const Duration(seconds: 60));
    final res = await http.Response.fromStream(streamed);
    final body = jsonDecode(res.body);
    if (res.statusCode != 200 || body is! Map || body['success'] == false) {
      throw Exception(body is Map ? (body['message'] ?? 'آپلود لوگو ناموفق بود') : 'آپلود لوگو ناموفق بود');
    }
    final filePath = body['filePath']?.toString().trim() ?? '';
    if (filePath.isEmpty) throw Exception('مسیر لوگو از سرور خالی است');
    return filePath;
  }

  Map<String, dynamic> _data(http.Response res, String fallback) {
    final body = jsonDecode(res.body);
    if (body is! Map) throw Exception(fallback);
    final map = Map<String, dynamic>.from(body);
    if (res.statusCode != 200 || map['success'] == false) {
      throw Exception(map['message']?.toString() ?? fallback);
    }
    final data = map['data'];
    if (data is Map) return Map<String, dynamic>.from(data);
    return map;
  }
}
