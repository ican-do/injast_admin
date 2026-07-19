import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:injast_admin/server_config.dart';

/// مدل نرخ‌نامه
class RateSheet {
  final int? id;
  final String codeCo;
  final String title;
  final String? category;
  final String unit;
  final String price; // تغییر به String برای پشتیبانی از متن
  final String currency;
  final String? source;
  final int? updatedBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  RateSheet({
    this.id,
    required this.codeCo,
    required this.title,
    this.category,
    required this.unit,
    required this.price,
    this.currency = 'تومان',
    this.source,
    this.updatedBy,
    this.createdAt,
    this.updatedAt,
  });

  factory RateSheet.fromJson(Map<String, dynamic> json) {
    return RateSheet(
      id: json['id'],
      codeCo: json['code_co']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      category: json['category']?.toString(),
      unit: json['unit']?.toString() ?? '',
      price: json['price']?.toString() ?? '0', // نگه‌داری به صورت string
      currency: json['currency']?.toString() ?? 'تومان',
      source: json['source']?.toString(),
      updatedBy: json['updated_by'],
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'code_co': codeCo,
      'title': title,
      'category': category,
      'unit': unit,
      'price': price,
      'currency': currency,
      'source': source,
      if (updatedBy != null) 'updated_by': updatedBy,
    };
  }
}

/// پاسخ لیست نرخ‌ها با pagination
class RateSheetListResponse {
  final List<RateSheet> data;
  final RateSheetPagination pagination;

  RateSheetListResponse({
    required this.data,
    required this.pagination,
  });

  factory RateSheetListResponse.fromJson(Map<String, dynamic> json) {
    return RateSheetListResponse(
      data: (json['data'] as List<dynamic>?)
              ?.map((e) => RateSheet.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      pagination: RateSheetPagination.fromJson(json['pagination'] ?? {}),
    );
  }
}

class RateSheetPagination {
  final int total;
  final int page;
  final int limit;
  final int totalPages;

  RateSheetPagination({
    required this.total,
    required this.page,
    required this.limit,
    required this.totalPages,
  });

  factory RateSheetPagination.fromJson(Map<String, dynamic> json) {
    return RateSheetPagination(
      total: json['total'] ?? 0,
      page: json['page'] ?? 1,
      limit: json['limit'] ?? 50,
      totalPages: json['totalPages'] ?? 1,
    );
  }
}

/// دریافت لیست نرخ‌ها با جستجو، فیلتر و pagination
Future<RateSheetListResponse> getRateSheetList({
  required String codeCo,
  String? search,
  String? category,
  String sortBy = 'updated_at',
  String sortOrder = 'DESC',
  int page = 1,
  int limit = 50,
}) async {
  try {
    final uri = Uri.parse(getApiUrl('rate-sheets/list/$codeCo'))
        .replace(queryParameters: {
      if (search != null && search.isNotEmpty) 'search': search,
      if (category != null && category.isNotEmpty) 'category': category,
      'sort_by': sortBy,
      'sort_order': sortOrder,
      'page': page.toString(),
      'limit': limit.toString(),
    });

    final response = await http.get(uri);

    if (response.statusCode == 200) {
      final jsonData = jsonDecode(response.body) as Map<String, dynamic>;
      return RateSheetListResponse.fromJson(jsonData);
    } else {
      throw Exception('Failed to load rate sheets: ${response.statusCode}');
    }
  } catch (e) {
    print('Error getting rate sheet list: $e');
    rethrow;
  }
}

/// دریافت یک نرخ خاص
Future<RateSheet> getRateSheet(int id) async {
  try {
    final uri = Uri.parse(getApiUrl('rate-sheets/$id'));
    final response = await http.get(uri);

    if (response.statusCode == 200) {
      final jsonData = jsonDecode(response.body) as Map<String, dynamic>;
      if (jsonData['success'] == true && jsonData['data'] != null) {
        return RateSheet.fromJson(jsonData['data'] as Map<String, dynamic>);
      } else {
        throw Exception('Invalid response format');
      }
    } else {
      throw Exception('Failed to load rate sheet: ${response.statusCode}');
    }
  } catch (e) {
    print('Error getting rate sheet: $e');
    rethrow;
  }
}

/// ایجاد نرخ جدید
Future<Map<String, dynamic>> createRateSheet({
  required String codeCo,
  required String title,
  String? category,
  required String unit,
  required String price, // تغییر به String
  String currency = 'تومان',
  String? source,
  int? updatedBy,
}) async {
  try {
    final uri = Uri.parse(getApiUrl('rate-sheets/create'));
    // اطمینان از اینکه price همیشه به صورت string ارسال شود
    // استفاده از یک prefix برای جلوگیری از تبدیل به عدد در JavaScript
    final priceString = price.toString();

    // ساخت JSON به صورت دستی برای اطمینان از string بودن price
    final jsonBody = {
      'code_co': codeCo,
      'title': title,
      'category': category,
      'unit': unit,
      'price': priceString, // همیشه به صورت string
      'currency': currency,
      'source': source,
      'updated_by': updatedBy,
    };

    // لاگ برای دیباگ
    print(
        '📤 Sending price to backend: $priceString (type: ${priceString.runtimeType})');

    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(jsonBody),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      final errorBody = jsonDecode(response.body);
      throw Exception(errorBody['error'] ??
          'Failed to create rate sheet: ${response.statusCode}');
    }
  } catch (e) {
    print('Error creating rate sheet: $e');
    rethrow;
  }
}

/// به‌روزرسانی نرخ
Future<Map<String, dynamic>> updateRateSheet({
  required int id,
  String? title,
  String? category,
  String? unit,
  String? price, // تغییر به String
  String? currency,
  String? source,
  int? updatedBy,
}) async {
  try {
    final uri = Uri.parse(getApiUrl('rate-sheets/$id'));
    // اطمینان از اینکه price همیشه به صورت string ارسال شود
    final priceString = price != null ? price.toString() : null;
    final response = await http.put(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        if (title != null) 'title': title,
        if (category != null) 'category': category,
        if (unit != null) 'unit': unit,
        if (priceString != null) 'price': priceString, // همیشه به صورت string
        if (currency != null) 'currency': currency,
        if (source != null) 'source': source,
        if (updatedBy != null) 'updated_by': updatedBy,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      final errorBody = jsonDecode(response.body);
      throw Exception(errorBody['error'] ??
          'Failed to update rate sheet: ${response.statusCode}');
    }
  } catch (e) {
    print('Error updating rate sheet: $e');
    rethrow;
  }
}

/// حذف نرخ
Future<Map<String, dynamic>> deleteRateSheet(int id) async {
  try {
    final uri = Uri.parse(getApiUrl('rate-sheets/$id'));
    final response = await http.delete(uri);

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      final errorBody = jsonDecode(response.body);
      throw Exception(errorBody['error'] ??
          'Failed to delete rate sheet: ${response.statusCode}');
    }
  } catch (e) {
    print('Error deleting rate sheet: $e');
    rethrow;
  }
}

/// دریافت دسته‌بندی‌های موجود
Future<List<String>> getRateSheetCategories(String codeCo) async {
  try {
    final uri =
        Uri.parse(getApiUrl('rate-sheets/categories/$codeCo'));
    final response = await http.get(uri);

    if (response.statusCode == 200) {
      final jsonData = jsonDecode(response.body) as List<dynamic>;
      return jsonData.map((e) => e.toString()).toList();
    } else {
      throw Exception('Failed to load categories: ${response.statusCode}');
    }
  } catch (e) {
    print('Error getting categories: $e');
    rethrow;
  }
}
