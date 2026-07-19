import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:injast_admin/server_config.dart';

/// مدل پرسنل
class Personnel {
  final int? id;
  final String codeCo;
  final String fullName;
  final String roleTitle;
  final String category;
  final String? bio;
  final String? phone;
  final String? email;
  final String? photoUrl;
  final bool isActive;
  final int displayOrder;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Personnel({
    this.id,
    required this.codeCo,
    required this.fullName,
    required this.roleTitle,
    required this.category,
    this.bio,
    this.phone,
    this.email,
    this.photoUrl,
    this.isActive = true,
    this.displayOrder = 0,
    this.createdAt,
    this.updatedAt,
  });

  factory Personnel.fromJson(Map<String, dynamic> json) {
    return Personnel(
      id: json['id'],
      codeCo: json['code_co']?.toString() ?? '',
      fullName: json['full_name']?.toString() ?? '',
      roleTitle: json['role_title']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      bio: json['bio']?.toString(),
      phone: json['phone']?.toString(),
      email: json['email']?.toString(),
      photoUrl: json['photo_url']?.toString(),
      isActive: json['is_active'] == 1 || json['is_active'] == true,
      displayOrder: json['display_order'] ?? 0,
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
      'full_name': fullName,
      'role_title': roleTitle,
      'category': category,
      'bio': bio,
      'phone': phone,
      'email': email,
      'photo_url': photoUrl,
      'is_active': isActive,
      'display_order': displayOrder,
    };
  }
}

/// دریافت لیست پرسنل
Future<List<Personnel>> getPersonnelList({
  required String codeCo,
  String? category,
  bool? isActive,
}) async {
  try {
    final uri = Uri.parse(getApiUrl('personnel/list/$codeCo'))
        .replace(queryParameters: {
      if (category != null) 'category': category,
      if (isActive != null) 'is_active': isActive.toString(),
    });

    final response = await http.get(uri);

    if (response.statusCode == 200) {
      final jsonData = jsonDecode(response.body) as List<dynamic>;
      return jsonData.map((e) => Personnel.fromJson(e as Map<String, dynamic>)).toList();
    } else {
      throw Exception('Failed to load personnel: ${response.statusCode}');
    }
  } catch (e) {
    print('Error getting personnel list: $e');
    rethrow;
  }
}

/// دریافت یک پرسنل خاص
Future<Personnel> getPersonnel(int id) async {
  try {
    final uri = Uri.parse(getApiUrl('personnel/$id'));
    final response = await http.get(uri);

    if (response.statusCode == 200) {
      final jsonData = jsonDecode(response.body) as Map<String, dynamic>;
      return Personnel.fromJson(jsonData);
    } else {
      throw Exception('Failed to load personnel: ${response.statusCode}');
    }
  } catch (e) {
    print('Error getting personnel: $e');
    rethrow;
  }
}

/// ایجاد پرسنل جدید
Future<Map<String, dynamic>> createPersonnel({
  required String codeCo,
  required String fullName,
  required String roleTitle,
  required String category,
  String? bio,
  String? phone,
  String? email,
  String? photoUrl,
  bool isActive = true,
  int displayOrder = 0,
  int? idUser,
}) async {
  try {
    final uri = Uri.parse(getApiUrl('personnel/create'));
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'code_co': codeCo,
        'full_name': fullName,
        'role_title': roleTitle,
        'category': category,
        'bio': bio,
        'phone': phone,
        'email': email,
        'photo_url': photoUrl,
        'is_active': isActive,
        'display_order': displayOrder,
        'id_user': idUser,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('Failed to create personnel: ${response.statusCode}');
    }
  } catch (e) {
    print('Error creating personnel: $e');
    rethrow;
  }
}

/// به‌روزرسانی پرسنل
Future<Map<String, dynamic>> updatePersonnel({
  required int id,
  required String fullName,
  required String roleTitle,
  required String category,
  String? bio,
  String? phone,
  String? email,
  String? photoUrl,
  bool isActive = true,
  int displayOrder = 0,
}) async {
  try {
    final uri = Uri.parse(getApiUrl('personnel/$id'));
    final response = await http.put(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'full_name': fullName,
        'role_title': roleTitle,
        'category': category,
        'bio': bio,
        'phone': phone,
        'email': email,
        'photo_url': photoUrl,
        'is_active': isActive,
        'display_order': displayOrder,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('Failed to update personnel: ${response.statusCode}');
    }
  } catch (e) {
    print('Error updating personnel: $e');
    rethrow;
  }
}

/// حذف پرسنل
Future<Map<String, dynamic>> deletePersonnel(int id) async {
  try {
    final uri = Uri.parse(getApiUrl('personnel/$id'));
    final response = await http.delete(uri);

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('Failed to delete personnel: ${response.statusCode}');
    }
  } catch (e) {
    print('Error deleting personnel: $e');
    rethrow;
  }
}

/// دریافت دسته‌بندی‌های موجود
Future<List<String>> getPersonnelCategories(String codeCo) async {
  try {
    final uri = Uri.parse(getApiUrl('personnel/categories/$codeCo'));
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

