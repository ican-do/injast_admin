import 'dart:convert';

import 'package:injast_admin/features/laws/dade_ghavanin.dart';

class DadeDarkhast {
  final int idRequest;
  final String codeCo;
  final int idUser;
  final String typeRequest;
  final String targetOrg;
  final String titleRequest;
  final String? descriptionRequest;
  final String statusRequest;
  final int priority;
  final String dateSubmit;
  final String? dateUpdate;
  final Map<String, dynamic>? extraFieldsJson;

  DadeDarkhast({
    required this.idRequest,
    required this.codeCo,
    required this.idUser,
    required this.typeRequest,
    required this.targetOrg,
    required this.titleRequest,
    this.descriptionRequest,
    required this.statusRequest,
    this.priority = 1,
    required this.dateSubmit,
    this.dateUpdate,
    this.extraFieldsJson,
  });

  factory DadeDarkhast.fromJson(Map<String, dynamic> json) {
    return DadeDarkhast(
      idRequest: json['id_request'] ?? 0,
      codeCo: json['code_co'] ?? '',
      idUser: json['id_user'] ?? 0,
      typeRequest: json['type_request'] ?? '',
      targetOrg: json['target_org'] ?? '',
      titleRequest: json['title_request'] ?? '',
      descriptionRequest: json['description_request'],
      statusRequest: json['status_request'] ?? 'ثبت شد',
      priority: json['priority'] ?? 1,
      dateSubmit: json['date_submit'] ?? '',
      dateUpdate: json['date_update'],
      extraFieldsJson: json['extra_fields_json'] != null
          ? (json['extra_fields_json'] is String
              ? Map<String, dynamic>.from(
                  jsonDecode(json['extra_fields_json']))
              : Map<String, dynamic>.from(json['extra_fields_json']))
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id_request': idRequest,
      'code_co': codeCo,
      'id_user': idUser,
      'type_request': typeRequest,
      'target_org': targetOrg,
      'title_request': titleRequest,
      'description_request': descriptionRequest,
      'status_request': statusRequest,
      'priority': priority,
      'date_submit': dateSubmit,
      'date_update': dateUpdate,
      'extra_fields_json': extraFieldsJson,
    };
  }

  Map<String, dynamic> toCreateJson() {
    return {
      'code_co': codeCo,
      'id_user': idUser,
      'type_request': typeRequest,
      'target_org': targetOrg,
      'title_request': titleRequest,
      'description_request': descriptionRequest,
      'priority': priority,
      'extra_fields_json': extraFieldsJson,
    };
  }

  bool get isHighPriority => priority == 2;
  bool get canCancel => statusRequest == 'ثبت شد';
}

class DadeDarkhastFile {
  final int idFile;
  final int idRequest;
  final String fileUrl;
  final String? fileType;
  final String? fileName;
  final String datetimeUpload;

  DadeDarkhastFile({
    required this.idFile,
    required this.idRequest,
    required this.fileUrl,
    this.fileType,
    this.fileName,
    required this.datetimeUpload,
  });

  factory DadeDarkhastFile.fromJson(Map<String, dynamic> json) {
    return DadeDarkhastFile(
      idFile: json['id_file'] ?? 0,
      idRequest: json['id_request'] ?? 0,
      fileUrl: json['file_url'] ?? '',
      fileType: json['file_type'],
      fileName: json['file_name'],
      datetimeUpload: json['datetime_upload'] ?? '',
    );
  }

  String? get urlFile {
    if (fileUrl.isEmpty) return null;
    if (fileUrl.startsWith('http')) return fileUrl;
    return 'https://apinovin.iranianasnaf.ir$fileUrl';
  }
}

class DadeStatusLog {
  final int idStatus;
  final int idRequest;
  final String statusValue;
  final String? descriptionStatus;
  final int idUser;
  final String datetimeStatus;

  DadeStatusLog({
    required this.idStatus,
    required this.idRequest,
    required this.statusValue,
    this.descriptionStatus,
    required this.idUser,
    required this.datetimeStatus,
  });

  factory DadeStatusLog.fromJson(Map<String, dynamic> json) {
    return DadeStatusLog(
      idStatus: json['id_status'] ?? 0,
      idRequest: json['id_request'] ?? 0,
      statusValue: json['status_value'] ?? '',
      descriptionStatus: json['description_status'],
      idUser: json['id_user'] ?? 0,
      datetimeStatus: json['datetime_status'] ?? '',
    );
  }
}

class DadeDarkhastDetails {
  final DadeDarkhast request;
  final List<DadeDarkhastFile> files;
  final List<DadeStatusLog> timeline;

  DadeDarkhastDetails({
    required this.request,
    required this.files,
    required this.timeline,
  });

  factory DadeDarkhastDetails.fromJson(Map<String, dynamic> json) {
    return DadeDarkhastDetails(
      request: DadeDarkhast.fromJson(json['request']),
      files: (json['files'] as List<dynamic>?)
              ?.map((item) => DadeDarkhastFile.fromJson(item))
              .toList() ??
          [],
      timeline: (json['timeline'] as List<dynamic>?)
              ?.map((item) => DadeStatusLog.fromJson(item))
              .toList() ??
          [],
    );
  }
}

class DadeDarkhastList {
  final List<DadeDarkhast> requests;
  final PaginationInfo? pagination;

  DadeDarkhastList({
    required this.requests,
    this.pagination,
  });

  factory DadeDarkhastList.fromJson(Map<String, dynamic> json) {
    final List<dynamic> requestsList = json['data'] ?? [];
    return DadeDarkhastList(
      requests: requestsList
          .map((item) => DadeDarkhast.fromJson(item))
          .toList(),
      pagination: json['pagination'] != null
          ? PaginationInfo.fromJson(json['pagination'])
          : null,
    );
  }
}

class DadeRequestType {
  final int id;
  final String name;
  final String? description;
  final List<String> fields;
  final String? codeCo;
  final int? isActive;
  final int? sortOrder;

  DadeRequestType({
    required this.id,
    required this.name,
    this.description,
    required this.fields,
    this.codeCo,
    this.isActive,
    this.sortOrder,
  });

  factory DadeRequestType.fromJson(Map<String, dynamic> json) {
    List<String> fieldsList = [];
    
    // اگر fields_json وجود دارد
    if (json['fields_json'] != null) {
      if (json['fields_json'] is String) {
        try {
          final parsed = jsonDecode(json['fields_json']);
          if (parsed is List) {
            fieldsList = parsed.map((item) => item.toString()).toList();
          }
        } catch (e) {
          // ignore
        }
      } else if (json['fields_json'] is List) {
        fieldsList = (json['fields_json'] as List)
            .map((item) => item.toString())
            .toList();
      }
    }
    
    // اگر fields مستقیم وجود دارد
    if (json['fields'] != null && fieldsList.isEmpty) {
      fieldsList = (json['fields'] as List<dynamic>?)
              ?.map((item) => item.toString())
              .toList() ??
          [];
    }

    return DadeRequestType(
      id: json['id'] ?? json['id_type'] ?? 0,
      name: json['name'] ?? json['name_type'] ?? '',
      description: json['description'] ?? json['description_type'],
      fields: fieldsList,
      codeCo: json['code_co'],
      isActive: json['is_active'],
      sortOrder: json['sort_order'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'fields': fields,
      'is_active': isActive,
      'sort_order': sortOrder,
    };
  }

  Map<String, dynamic> toCreateJson() {
    return {
      'code_co': codeCo ?? '',
      'name_type': name,
      'description_type': description,
      'fields_json': fields,
      'sort_order': sortOrder ?? 0,
      'is_active': isActive ?? 1,
    };
  }

  bool get isActiveBool => isActive == null || isActive == 1;
}

class DadeOrganization {
  final int id;
  final String name;
  final String? logo;
  final String? codeCo;
  final String? description;
  final Map<String, dynamic>? contactInfo;
  final int? isActive;
  final int? sortOrder;

  DadeOrganization({
    required this.id,
    required this.name,
    this.logo,
    this.codeCo,
    this.description,
    this.contactInfo,
    this.isActive,
    this.sortOrder,
  });

  factory DadeOrganization.fromJson(Map<String, dynamic> json) {
    return DadeOrganization(
      id: json['id'] ?? json['id_org'] ?? 0,
      name: json['name'] ?? json['name_org'] ?? '',
      logo: json['logo'] ?? json['logo_url'],
      codeCo: json['code_co'],
      description: json['description'] ?? json['description_org'],
      contactInfo: json['contact_info'] != null
          ? (json['contact_info'] is String
              ? jsonDecode(json['contact_info'])
              : json['contact_info'])
          : null,
      isActive: json['is_active'],
      sortOrder: json['sort_order'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'logo': logo,
    };
  }

  Map<String, dynamic> toCreateJson() {
    return {
      'code_co': codeCo ?? '',
      'name_org': name,
      'logo_url': logo,
      'description_org': description,
      'contact_info': contactInfo,
      'sort_order': sortOrder ?? 0,
      'is_active': isActive ?? 1,
    };
  }
}


