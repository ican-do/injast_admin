import 'dart:convert';
import 'package:http/http.dart' as http;

import 'package:injast_admin/features/laws/dade_ghavanin.dart';
import 'package:injast_admin/features/requests/dade_darkhast.dart';
import 'package:injast_admin/server_config.dart';
String get _baseUrl => adminApiBaseUrl;

class ServisApiAdmin {
   static const Duration _timeout = Duration(seconds: 15);

  // ============================================
  // API های مربوط به قوانین (برای اتحادیه)
  // ============================================

  // ثبت قانون جدید
  static Future<PasokhGhavanin> sakhtGhavanin(DadeGhavanin law) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/admin/laws/create'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(law.toCreateJson()),
          )
          .timeout(_timeout);

      final String responseString = utf8.decode(response.bodyBytes);
      final Map<String, dynamic> responseBody = jsonDecode(responseString);

      return PasokhGhavanin.fromJson(responseBody);
    } catch (e) {
      String payamKhata = 'خطا در ارتباط با سرور';
      if (e.toString().contains('TimeoutException') ||
          e.toString().contains('timeout')) {
        payamKhata = 'زمان اتصال به سرور به پایان رسید';
      } else if (e.toString().contains('SocketException') ||
          e.toString().contains('Failed host lookup')) {
        payamKhata = 'عدم دسترسی به سرور. لطفاً اتصال اینترنت را بررسی کنید';
      }

      return PasokhGhavanin(success: false, message: payamKhata);
    }
  }

  // ویرایش قانون
  static Future<PasokhGhavanin> virayeshGhavanin(
    int idLaw,
    DadeGhavanin law,
  ) async {
    try {
      final response = await http
          .put(
            Uri.parse('$_baseUrl/admin/laws/$idLaw'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(law.toUpdateJson()),
          )
          .timeout(_timeout);

      final String responseString = utf8.decode(response.bodyBytes);
      final Map<String, dynamic> responseBody = jsonDecode(responseString);

      return PasokhGhavanin.fromJson(responseBody);
    } catch (e) {
      String payamKhata = 'خطا در ارتباط با سرور';
      if (e.toString().contains('TimeoutException') ||
          e.toString().contains('timeout')) {
        payamKhata = 'زمان اتصال به سرور به پایان رسید';
      } else if (e.toString().contains('SocketException') ||
          e.toString().contains('Failed host lookup')) {
        payamKhata = 'عدم دسترسی به سرور. لطفاً اتصال اینترنت را بررسی کنید';
      }

      return PasokhGhavanin(success: false, message: payamKhata);
    }
  }

  // حذف قانون
  static Future<PasokhGhavanin> hazfGhavanin(int idLaw) async {
    try {
      final response = await http
          .delete(
            Uri.parse('$_baseUrl/admin/laws/$idLaw'),
            headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
          )
          .timeout(_timeout);

      final String responseString = utf8.decode(response.bodyBytes);
      if (responseString.trim().isEmpty) {
        return PasokhGhavanin(
          success: response.statusCode >= 200 && response.statusCode < 300,
          message: response.statusCode >= 200 && response.statusCode < 300
              ? 'قانون با موفقیت حذف شد.'
              : 'حذف قانون ناموفق بود',
        );
      }

      final Map<String, dynamic> responseBody = jsonDecode(responseString);
      final parsed = PasokhGhavanin.fromJson(responseBody);
      if (parsed.success) return parsed;
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return PasokhGhavanin(
          success: true,
          message: parsed.message ?? 'قانون با موفقیت حذف شد.',
        );
      }
      return parsed;
    } catch (e) {
      String payamKhata = 'خطا در ارتباط با سرور';
      if (e.toString().contains('TimeoutException') ||
          e.toString().contains('timeout')) {
        payamKhata = 'زمان اتصال به سرور به پایان رسید';
      } else if (e.toString().contains('SocketException') ||
          e.toString().contains('Failed host lookup')) {
        payamKhata = 'عدم دسترسی به سرور. لطفاً اتصال اینترنت را بررسی کنید';
      }

      return PasokhGhavanin(success: false, message: payamKhata);
    }
  }

  // تغییر وضعیت فعال/غیرفعال قانون
  static Future<PasokhGhavanin> taghireVaziyatGhavanin({
    required int idLaw,
    required bool isActive,
  }) async {
    try {
      final response = await http
          .put(
            Uri.parse('$_baseUrl/admin/laws/$idLaw'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'is_active': isActive ? 1 : 0}),
          )
          .timeout(_timeout);

      final String responseString = utf8.decode(response.bodyBytes);
      final Map<String, dynamic> responseBody = jsonDecode(responseString);

      return PasokhGhavanin.fromJson(responseBody);
    } catch (e) {
      String payamKhata = 'خطا در ارتباط با سرور';
      if (e.toString().contains('TimeoutException') ||
          e.toString().contains('timeout')) {
        payamKhata = 'زمان اتصال به سرور به پایان رسید';
      } else if (e.toString().contains('SocketException') ||
          e.toString().contains('Failed host lookup')) {
        payamKhata = 'عدم دسترسی به سرور. لطفاً اتصال اینترنت را بررسی کنید';
      }

      return PasokhGhavanin(success: false, message: payamKhata);
    }
  }

  // دریافت لیست قوانین (برای پنل اتحادیه - شامل غیرفعال‌ها)
  static Future<DadeGhavaninList?> gereftanListeGhavaninAdmin({
    String? codeCo,
    String? categoryLaw,
    String? search,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final Map<String, String> queryParams = {
        'page': page.toString(),
        'limit': limit.toString(),
      };
      if (codeCo != null && codeCo.isNotEmpty) {
        queryParams['code_co'] = codeCo;
      }
      if (categoryLaw != null && categoryLaw.isNotEmpty) {
        queryParams['category_law'] = categoryLaw;
      }
      if (search != null && search.isNotEmpty) {
        queryParams['search'] = search;
      }

      final uri = Uri.parse(
        '$_baseUrl/admin/laws',
      ).replace(queryParameters: queryParams);
      final response = await http.get(uri).timeout(_timeout);

      final String responseString = utf8.decode(response.bodyBytes);
      final Map<String, dynamic> responseBody = jsonDecode(responseString);

      if (response.statusCode == 200 && responseBody['success'] == true) {
        return DadeGhavaninList.fromJson(responseBody);
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  // دریافت جزئیات یک قانون (برای پنل اتحادیه)
  static Future<DadeGhavanin?> gereftanGhavaninAdmin(int idLaw) async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/admin/laws/$idLaw'))
          .timeout(_timeout);

      final String responseString = utf8.decode(response.bodyBytes);
      final Map<String, dynamic> responseBody = jsonDecode(responseString);

      if (response.statusCode == 200 && responseBody['success'] == true) {
        return DadeGhavanin.fromJson(responseBody['data']);
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  // دریافت دسته‌بندی‌ها (برای پنل اتحادیه)
  static Future<List<DadeCategory>?> gereftanCategoriesAdmin({
    String? codeCo,
  }) async {
    try {
      final Map<String, String> queryParams = {};
      if (codeCo != null && codeCo.isNotEmpty) {
        queryParams['code_co'] = codeCo;
      }

      final uri = Uri.parse(
        '$_baseUrl/admin/laws/categories',
      ).replace(queryParameters: queryParams);
      final response = await http.get(uri).timeout(_timeout);

      final String responseString = utf8.decode(response.bodyBytes);
      final Map<String, dynamic> responseBody = jsonDecode(responseString);

      if (response.statusCode == 200 && responseBody['success'] == true) {
        final List<dynamic> categoriesList = responseBody['data'] ?? [];
        return categoriesList
            .map((item) => DadeCategory.fromJson(item))
            .toList();
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  // ============================================
  // API های مربوط به درخواست‌ها (برای اتحادیه)
  // ============================================

  // دریافت لیست درخواست‌ها
  static Future<DadeDarkhastList?> gereftanListeDarkhastAdmin({
    String? codeCo,
    String? typeRequest,
    String? statusRequest,
    String? search,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final Map<String, String> queryParams = {
        'page': page.toString(),
        'limit': limit.toString(),
      };
      if (codeCo != null && codeCo.isNotEmpty) {
        queryParams['code_co'] = codeCo;
      }
      if (typeRequest != null && typeRequest.isNotEmpty) {
        queryParams['type_request'] = typeRequest;
      }
      if (statusRequest != null && statusRequest.isNotEmpty) {
        queryParams['status_request'] = statusRequest;
      }
      if (search != null && search.isNotEmpty) {
        queryParams['search'] = search;
      }

      final uri = Uri.parse(
        '$_baseUrl/admin/requests',
      ).replace(queryParameters: queryParams);
      final response = await http.get(uri).timeout(_timeout);

      final String responseString = utf8.decode(response.bodyBytes);
      final Map<String, dynamic> responseBody = jsonDecode(responseString);

      if (response.statusCode == 200 && responseBody['success'] == true) {
        return DadeDarkhastList.fromJson(responseBody);
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  // دریافت جزئیات یک درخواست
  static Future<DadeDarkhastDetails?> gereftanDarkhastAdmin(
    int idRequest,
  ) async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/admin/requests/$idRequest'))
          .timeout(_timeout);

      final String responseString = utf8.decode(response.bodyBytes);
      final Map<String, dynamic> responseBody = jsonDecode(responseString);

      if (response.statusCode == 200 && responseBody['success'] == true) {
        return DadeDarkhastDetails.fromJson(responseBody['data']);
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  // تغییر وضعیت درخواست
  static Future<PasokhGhavanin> taghireVaziyatDarkhast(
    int idRequest,
    String statusRequest,
    String? descriptionStatus,
    int idUser,
  ) async {
    try {
      final response = await http
          .put(
            Uri.parse('$_baseUrl/admin/requests/$idRequest/status'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'status_request': statusRequest,
              'description_status': descriptionStatus,
              'id_user': idUser,
            }),
          )
          .timeout(_timeout);

      final String responseString = utf8.decode(response.bodyBytes);
      final Map<String, dynamic> responseBody = jsonDecode(responseString);

      return PasokhGhavanin.fromJson(responseBody);
    } catch (e) {
      String payamKhata = 'خطا در ارتباط با سرور';
      if (e.toString().contains('TimeoutException') ||
          e.toString().contains('timeout')) {
        payamKhata = 'زمان اتصال به سرور به پایان رسید';
      } else if (e.toString().contains('SocketException') ||
          e.toString().contains('Failed host lookup')) {
        payamKhata = 'عدم دسترسی به سرور. لطفاً اتصال اینترنت را بررسی کنید';
      }

      return PasokhGhavanin(success: false, message: payamKhata);
    }
  }

  // ============================================
  // API های مدیریت نوع درخواست‌ها
  // ============================================

  // ثبت نوع درخواست جدید
  static Future<PasokhGhavanin> sakhtRequestType(
      DadeRequestType type, int idUser) async {
    try {
      final typeData = type.toCreateJson();
      typeData['id_user'] = idUser;

      final response = await http
          .post(
            Uri.parse('$_baseUrl/admin/request-types/create'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(typeData),
          )
          .timeout(_timeout);

      final String responseString = utf8.decode(response.bodyBytes);
      final Map<String, dynamic> responseBody = jsonDecode(responseString);

      return PasokhGhavanin.fromJson(responseBody);
    } catch (e) {
      return PasokhGhavanin(success: false, message: 'خطا در ارتباط با سرور');
    }
  }

  // ویرایش نوع درخواست
  static Future<PasokhGhavanin> virayeshRequestType(
      int id, DadeRequestType type) async {
    try {
      final response = await http
          .put(
            Uri.parse('$_baseUrl/admin/request-types/$id'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(type.toCreateJson()),
          )
          .timeout(_timeout);

      final String responseString = utf8.decode(response.bodyBytes);
      final Map<String, dynamic> responseBody = jsonDecode(responseString);

      return PasokhGhavanin.fromJson(responseBody);
    } catch (e) {
      return PasokhGhavanin(success: false, message: 'خطا در ارتباط با سرور');
    }
  }

  // حذف نوع درخواست
  static Future<PasokhGhavanin> hazfRequestType(int id) async {
    try {
      final response = await http
          .delete(Uri.parse('$_baseUrl/admin/request-types/$id'))
          .timeout(_timeout);

      final String responseString = utf8.decode(response.bodyBytes);
      final Map<String, dynamic> responseBody = jsonDecode(responseString);

      return PasokhGhavanin.fromJson(responseBody);
    } catch (e) {
      return PasokhGhavanin(success: false, message: 'خطا در ارتباط با سرور');
    }
  }

  // دریافت لیست انواع درخواست‌ها
  static Future<List<DadeRequestType>?> gereftanRequestTypesAdmin(
      {String? codeCo}) async {
    try {
      final Map<String, String> queryParams = {};
      if (codeCo != null && codeCo.isNotEmpty) {
        queryParams['code_co'] = codeCo;
      }

      final uri = Uri.parse('$_baseUrl/admin/request-types')
          .replace(queryParameters: queryParams);
      final response = await http.get(uri).timeout(_timeout);

      final String responseString = utf8.decode(response.bodyBytes);
      final Map<String, dynamic> responseBody = jsonDecode(responseString);

      if (response.statusCode == 200 && responseBody['success'] == true) {
        final List<dynamic> typesList = responseBody['data'] ?? [];
        return typesList
            .map((item) => DadeRequestType.fromJson(item))
            .toList();
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  // ============================================
  // API های مدیریت ارگان‌های مقصد
  // ============================================

  // ثبت ارگان جدید
  static Future<PasokhGhavanin> sakhtOrganization(
      DadeOrganization org, int idUser) async {
    try {
      final orgData = org.toCreateJson();
      orgData['id_user'] = idUser;

      final response = await http
          .post(
            Uri.parse('$_baseUrl/admin/organizations/create'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(orgData),
          )
          .timeout(_timeout);

      final String responseString = utf8.decode(response.bodyBytes);
      final Map<String, dynamic> responseBody = jsonDecode(responseString);

      return PasokhGhavanin.fromJson(responseBody);
    } catch (e) {
      return PasokhGhavanin(success: false, message: 'خطا در ارتباط با سرور');
    }
  }

  // ویرایش ارگان
  static Future<PasokhGhavanin> virayeshOrganization(
      int id, DadeOrganization org) async {
    try {
      final response = await http
          .put(
            Uri.parse('$_baseUrl/admin/organizations/$id'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(org.toCreateJson()),
          )
          .timeout(_timeout);

      final String responseString = utf8.decode(response.bodyBytes);
      final Map<String, dynamic> responseBody = jsonDecode(responseString);

      return PasokhGhavanin.fromJson(responseBody);
    } catch (e) {
      return PasokhGhavanin(success: false, message: 'خطا در ارتباط با سرور');
    }
  }

  // حذف ارگان
  static Future<PasokhGhavanin> hazfOrganization(int id) async {
    try {
      final response = await http
          .delete(Uri.parse('$_baseUrl/admin/organizations/$id'))
          .timeout(_timeout);

      final String responseString = utf8.decode(response.bodyBytes);
      final Map<String, dynamic> responseBody = jsonDecode(responseString);

      return PasokhGhavanin.fromJson(responseBody);
    } catch (e) {
      return PasokhGhavanin(success: false, message: 'خطا در ارتباط با سرور');
    }
  }

  // دریافت لیست ارگان‌ها
  static Future<List<DadeOrganization>?> gereftanOrganizationsAdmin(
      {String? codeCo}) async {
    try {
      final Map<String, String> queryParams = {};
      if (codeCo != null && codeCo.isNotEmpty) {
        queryParams['code_co'] = codeCo;
      }

      final uri = Uri.parse('$_baseUrl/admin/organizations')
          .replace(queryParameters: queryParams);
      final response = await http.get(uri).timeout(_timeout);

      final String responseString = utf8.decode(response.bodyBytes);
      final Map<String, dynamic> responseBody = jsonDecode(responseString);

      if (response.statusCode == 200 && responseBody['success'] == true) {
        final List<dynamic> orgsList = responseBody['data'] ?? [];
        return orgsList
            .map((item) => DadeOrganization.fromJson(item))
            .toList();
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }
}
