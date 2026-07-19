import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:injast_admin/server_config.dart';

/// مدل خبر
class News {
  final int? id;
  final String codeCo;
  final String title;
  final String content;
  final String? imageUrl;
  final String? publishLink;
  final bool isActive;
  final int? idUser;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  News({
    this.id,
    required this.codeCo,
    required this.title,
    required this.content,
    this.imageUrl,
    this.publishLink,
    this.isActive = true,
    this.idUser,
    this.createdAt,
    this.updatedAt,
  });

  factory News.fromJson(Map<String, dynamic> json) {
    return News(
      id: json['id'],
      codeCo: json['code_co']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      imageUrl: json['image_url']?.toString(),
      publishLink: json['publish_link']?.toString(),
      isActive: json['is_active'] == 1 || json['is_active'] == true,
      idUser: json['id_user'],
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
      'content': content,
      'image_url': imageUrl,
      'publish_link': publishLink,
      'is_active': isActive,
      if (idUser != null) 'id_user': idUser,
    };
  }
}

/// دریافت لیست اخبار
Future<List<News>> getNewsList({
  required String codeCo,
  String? search,
  bool? isActive,
}) async {
  try {
    final uri = Uri.parse(getApiUrl('news/list/$codeCo'))
        .replace(queryParameters: {
      if (search != null && search.isNotEmpty) 'search': search,
      if (isActive != null) 'is_active': isActive.toString(),
    });

    final response = await http.get(uri);

    if (response.statusCode == 200) {
      final jsonData = jsonDecode(response.body) as List<dynamic>;
      return jsonData.map((e) => News.fromJson(e as Map<String, dynamic>)).toList();
    } else {
      throw Exception('Failed to load news: ${response.statusCode}');
    }
  } catch (e) {
    print('Error getting news list: $e');
    rethrow;
  }
}

/// دریافت یک خبر خاص
Future<News> getNews(int id) async {
  try {
    final uri = Uri.parse(getApiUrl('news/$id'));
    final response = await http.get(uri);

    if (response.statusCode == 200) {
      final jsonData = jsonDecode(response.body) as Map<String, dynamic>;
      return News.fromJson(jsonData);
    } else {
      throw Exception('Failed to load news: ${response.statusCode}');
    }
  } catch (e) {
    print('Error getting news: $e');
    rethrow;
  }
}

/// ایجاد خبر جدید
Future<Map<String, dynamic>> createNews({
  required String codeCo,
  required String title,
  required String content,
  String? imageUrl,
  String? publishLink,
  bool isActive = true,
  int? idUser,
}) async {
  try {
    final uri = Uri.parse(getApiUrl('news/create'));
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'code_co': codeCo,
        'title': title,
        'content': content,
        'image_url': imageUrl,
        'publish_link': publishLink,
        'is_active': isActive,
        'id_user': idUser,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('Failed to create news: ${response.statusCode}');
    }
  } catch (e) {
    print('Error creating news: $e');
    rethrow;
  }
}

/// به‌روزرسانی خبر
Future<Map<String, dynamic>> updateNews({
  required int id,
  required String title,
  required String content,
  String? imageUrl,
  String? publishLink,
  bool isActive = true,
}) async {
  try {
    final uri = Uri.parse(getApiUrl('news/$id'));
    final response = await http.put(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'title': title,
        'content': content,
        'image_url': imageUrl,
        'publish_link': publishLink,
        'is_active': isActive,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('Failed to update news: ${response.statusCode}');
    }
  } catch (e) {
    print('Error updating news: $e');
    rethrow;
  }
}

/// حذف خبر
Future<Map<String, dynamic>> deleteNews(int id) async {
  try {
    final uri = Uri.parse(getApiUrl('news/$id'));
    final response = await http.delete(uri);

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('Failed to delete news: ${response.statusCode}');
    }
  } catch (e) {
    print('Error deleting news: $e');
    rethrow;
  }
}

