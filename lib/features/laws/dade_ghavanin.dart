class DadeGhavanin {
  final int idLaw;
  final String codeCo;
  final String titleLaw;
  final String categoryLaw;
  final String? contentLaw;
  final String versionLaw;
  final String datePublish;
  final String? dateUpdate;
  final String? attachmentUrl;
  final int isActive;
  final int? idUser;
  final String? datetimeCreate;

  DadeGhavanin({
    required this.idLaw,
    required this.codeCo,
    required this.titleLaw,
    required this.categoryLaw,
    this.contentLaw,
    required this.versionLaw,
    required this.datePublish,
    this.dateUpdate,
    this.attachmentUrl,
    this.isActive = 1,
    this.idUser,
    this.datetimeCreate,
  });

  factory DadeGhavanin.fromJson(Map<String, dynamic> json) {
    return DadeGhavanin(
      idLaw: _asInt(json['id_law']),
      codeCo: json['code_co']?.toString() ?? '',
      titleLaw: json['title_law']?.toString() ?? '',
      categoryLaw: json['category_law']?.toString() ?? '',
      contentLaw: json['content_law']?.toString(),
      versionLaw: json['version_law']?.toString() ?? '1.0',
      datePublish: json['date_publish']?.toString() ?? '',
      dateUpdate: json['date_update']?.toString(),
      attachmentUrl: json['attachment_url']?.toString(),
      isActive: _asInt(json['is_active'], fallback: 1),
      idUser: json['id_user'] == null ? null : _asInt(json['id_user']),
      datetimeCreate: json['datetime_create']?.toString(),
    );
  }

  static int _asInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  Map<String, dynamic> toJson() {
    return {
      'id_law': idLaw,
      'code_co': codeCo,
      'title_law': titleLaw,
      'category_law': categoryLaw,
      'content_law': contentLaw,
      'version_law': versionLaw,
      'date_publish': datePublish,
      'date_update': dateUpdate,
      'attachment_url': attachmentUrl,
      'is_active': isActive,
      'id_user': idUser,
      'datetime_create': datetimeCreate,
    };
  }

  Map<String, dynamic> toCreateJson() {
    return {
      'code_co': codeCo,
      'title_law': titleLaw,
      'category_law': categoryLaw,
      'content_law': contentLaw ?? '',
      'version_law': versionLaw,
      'date_publish': datePublish,
      'attachment_url': attachmentUrl,
      'is_active': isActive,
      'id_user': idUser,
    };
  }

  Map<String, dynamic> toUpdateJson() {
    final Map<String, dynamic> data = {};
    if (titleLaw.isNotEmpty) data['title_law'] = titleLaw;
    if (categoryLaw.isNotEmpty) data['category_law'] = categoryLaw;
    if (contentLaw != null && contentLaw!.isNotEmpty) {
      data['content_law'] = contentLaw;
    }
    if (datePublish.isNotEmpty) data['date_publish'] = datePublish;
    if (attachmentUrl != null) data['attachment_url'] = attachmentUrl;
    data['is_active'] = isActive;
    return data;
  }

  bool get hasAttachment => attachmentUrl != null && attachmentUrl!.isNotEmpty;

  String? get urlAttachment {
    if (attachmentUrl == null || attachmentUrl!.isEmpty) {
      return null;
    }
    if (attachmentUrl!.startsWith('http')) {
      return attachmentUrl;
    }
    return 'https://apinovin.iranianasnaf.ir${attachmentUrl}';
  }

  bool get isActiveBool => isActive == 1;

  DadeGhavanin copyWith({
    int? idLaw,
    String? codeCo,
    String? titleLaw,
    String? categoryLaw,
    String? contentLaw,
    String? versionLaw,
    String? datePublish,
    String? dateUpdate,
    String? attachmentUrl,
    int? isActive,
    int? idUser,
    String? datetimeCreate,
  }) {
    return DadeGhavanin(
      idLaw: idLaw ?? this.idLaw,
      codeCo: codeCo ?? this.codeCo,
      titleLaw: titleLaw ?? this.titleLaw,
      categoryLaw: categoryLaw ?? this.categoryLaw,
      contentLaw: contentLaw ?? this.contentLaw,
      versionLaw: versionLaw ?? this.versionLaw,
      datePublish: datePublish ?? this.datePublish,
      dateUpdate: dateUpdate ?? this.dateUpdate,
      attachmentUrl: attachmentUrl ?? this.attachmentUrl,
      isActive: isActive ?? this.isActive,
      idUser: idUser ?? this.idUser,
      datetimeCreate: datetimeCreate ?? this.datetimeCreate,
    );
  }
}

class DadeGhavaninList {
  final List<DadeGhavanin> laws;
  final PaginationInfo? pagination;

  DadeGhavaninList({
    required this.laws,
    this.pagination,
  });

  factory DadeGhavaninList.fromJson(Map<String, dynamic> json) {
    final List<dynamic> lawsList = json['data'] ?? [];
    return DadeGhavaninList(
      laws: lawsList.map((item) => DadeGhavanin.fromJson(item)).toList(),
      pagination: json['pagination'] != null
          ? PaginationInfo.fromJson(json['pagination'])
          : null,
    );
  }
}

class PaginationInfo {
  final int page;
  final int limit;
  final int total;
  final int totalPages;

  PaginationInfo({
    required this.page,
    required this.limit,
    required this.total,
    required this.totalPages,
  });

  factory PaginationInfo.fromJson(Map<String, dynamic> json) {
    return PaginationInfo(
      page: json['page'] ?? 1,
      limit: json['limit'] ?? 20,
      total: json['total'] ?? 0,
      totalPages: json['totalPages'] ?? 0,
    );
  }
}

class DadeCategory {
  final String categoryLaw;
  final int count;

  DadeCategory({
    required this.categoryLaw,
    required this.count,
  });

  factory DadeCategory.fromJson(Map<String, dynamic> json) {
    return DadeCategory(
      categoryLaw: json['category_law'] ?? '',
      count: json['count'] ?? 0,
    );
  }
}

class PasokhGhavanin {
  final bool success;
  final String? message;
  final dynamic data;

  PasokhGhavanin({
    required this.success,
    this.message,
    this.data,
  });

  factory PasokhGhavanin.fromJson(Map<String, dynamic> json) {
    return PasokhGhavanin(
      success: json['success'] ?? false,
      message: json['message'],
      data: json['data'],
    );
  }
}

