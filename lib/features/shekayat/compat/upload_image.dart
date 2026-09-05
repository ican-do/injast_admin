import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:injast_admin/injast_http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:injast_admin/server_config.dart';

Future<String?> uploadImageToServer(
  XFile imageFile,
  String path,
  String filename,
) async {
  try {
    final file = File(imageFile.path);
    if (!await file.exists()) return null;

    final fileSize = await file.length();
    if (fileSize > 10 * 1024 * 1024) {
      throw Exception('حجم فایل بیش از حد مجاز است (حداکثر 10 مگابایت)');
    }

    final request = http.MultipartRequest(
      'POST',
      Uri.parse(getApiUrl('upload/image')),
    );
    request.files.add(await http.MultipartFile.fromPath('image', file.path));
    request.fields['path'] = path;
    request.fields['filename'] = filename;

    final streamedResponse = await http.send(request).timeout(
      const Duration(seconds: 60),
      onTimeout: () => throw TimeoutException('زمان اتصال به سرور به پایان رسید.'),
    );
    final response = await http.Response.fromStream(streamedResponse).timeout(
      const Duration(seconds: 10),
      onTimeout: () =>
          throw TimeoutException('زمان دریافت پاسخ از سرور به پایان رسید.'),
    );

    if (response.statusCode == 200) {
      final responseData = json.decode(response.body);
      return responseData['filePath']?.toString();
    }
    return null;
  } on TimeoutException {
    rethrow;
  } on SocketException {
    throw Exception('عدم دسترسی به سرور. لطفاً اتصال اینترنت را بررسی کنید.');
  } catch (e) {
    if (e is Exception) rethrow;
    throw Exception('خطا در آپلود تصویر: $e');
  }
}

Future<String?> uploadFileToServer(
  String filePath,
  String path,
  String filename,
) async {
  try {
    final file = File(filePath);
    if (!await file.exists()) return null;

    final fileSize = await file.length();
    if (fileSize > 10 * 1024 * 1024) {
      throw Exception('حجم فایل بیش از حد مجاز است (حداکثر 10 مگابایت)');
    }

    final request = http.MultipartRequest(
      'POST',
      Uri.parse(getApiUrl('upload/image')),
    );
    request.files.add(await http.MultipartFile.fromPath('image', file.path));
    request.fields['path'] = path;
    request.fields['filename'] = filename;

    final streamedResponse = await http.send(request).timeout(
      const Duration(seconds: 60),
      onTimeout: () => throw TimeoutException('زمان اتصال به سرور به پایان رسید.'),
    );
    final response = await http.Response.fromStream(streamedResponse).timeout(
      const Duration(seconds: 10),
      onTimeout: () =>
          throw TimeoutException('زمان دریافت پاسخ از سرور به پایان رسید.'),
    );

    if (response.statusCode == 200) {
      final responseData = json.decode(response.body);
      return responseData['filePath']?.toString();
    }
    return null;
  } on TimeoutException {
    rethrow;
  } on SocketException {
    throw Exception('عدم دسترسی به سرور. لطفاً اتصال اینترنت را بررسی کنید.');
  } catch (e) {
    if (e is Exception) rethrow;
    throw Exception('خطا در آپلود فایل: $e');
  }
}
