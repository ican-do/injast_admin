import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:injast_admin/server_config.dart';

/// API calls for Bazrasi Reports

/// Helper function to add user info to query parameters
Map<String, String> _addUserInfoToParams(Map<String, String> params, {Map<String, dynamic>? userInfo}) {
  final userInfoData = userInfo ?? const {
    'type_user_2': 1,
    'code_co': null,
    'state': null,
    'city': null,
  };
  params['user_type_user_2'] = (userInfoData['type_user_2'] ?? 1).toString();
  if (userInfoData['code_co'] != null) {
    params['user_code_co'] = userInfoData['code_co'].toString();
  }
  if (userInfoData['state'] != null) {
    params['user_state'] = userInfoData['state'].toString();
  }
  if (userInfoData['city'] != null) {
    params['user_city'] = userInfoData['city'].toString();
  }
  return params;
}

void _addUnionCodesToParams(Map<String, String> params, String? unionCodes) {
  if (unionCodes != null && unionCodes.trim().isNotEmpty) {
    params['union_codes'] = unionCodes;
  }
}

/// گزارش 1: تعداد کل بازرسی‌ها در بازه زمانی
Future<List<Map<String, dynamic>>> getTotalBazrasiByTimeRange(
  String period, // daily, weekly, monthly, yearly
  {
  String? inspectorId,
  DateTime? startDate,
  DateTime? endDate,
  String? unionCodes, // کد اتحادیه‌ها جدا شده با کاما (خالی = همه)
  Map<String, dynamic>? userInfo, // شامل type_user_2, code_co, state, city
}) async {
  try {
    final userInfoData = userInfo ?? {};
    final params = <String, String>{
      'user_type_user_2': (userInfoData['type_user_2'] ?? 1).toString(),
      if (userInfoData['code_co'] != null) 'user_code_co': userInfoData['code_co'].toString(),
      if (userInfoData['state'] != null) 'user_state': userInfoData['state'].toString(),
      if (userInfoData['city'] != null) 'user_city': userInfoData['city'].toString(),
      if (inspectorId != null) 'inspector_id': inspectorId,
      if (startDate != null) 'start_date': startDate.toIso8601String().split('T')[0],
      if (endDate != null) 'end_date': endDate.toIso8601String().split('T')[0],
      if (unionCodes != null && unionCodes.trim().isNotEmpty) 'union_codes': unionCodes,
    };
    final uri = Uri.parse(
      getApiUrl('reports/bazrasi/total_by_time_range/$period'),
    ).replace(queryParameters: params);

    final response = await http.get(uri);

    if (response.statusCode == 200) {
      final jsonData = jsonDecode(response.body) as List<dynamic>;
      return jsonData.map((e) => e as Map<String, dynamic>).toList();
    } else {
      throw Exception('Failed to load report: ${response.statusCode}');
    }
  } catch (e) {
    print('Error in getTotalBazrasiByTimeRange: $e');
    rethrow;
  }
}

/// گزارش 2: تفکیک بازرسی‌ها براساس وضعیت پروانه
Future<List<Map<String, dynamic>>> getBazrasiByLicenseStatus({
  String? inspectorId,
  DateTime? startDate,
  DateTime? endDate,
  String? unionCodes,
  Map<String, dynamic>? userInfo,
}) async {
  try {
    var params = <String, String>{};
    if (inspectorId != null) params['inspector_id'] = inspectorId;
    if (startDate != null) params['start_date'] = startDate.toIso8601String().split('T')[0];
    if (endDate != null) params['end_date'] = endDate.toIso8601String().split('T')[0];
    _addUnionCodesToParams(params, unionCodes);
    params = _addUserInfoToParams(params, userInfo: userInfo);
    
    final uri = Uri.parse(
      getApiUrl('reports/bazrasi/by_license_status'),
    ).replace(queryParameters: params);

    final response = await http.get(uri);

    if (response.statusCode == 200) {
      final jsonData = jsonDecode(response.body) as List<dynamic>;
      return jsonData.map((e) => e as Map<String, dynamic>).toList();
    } else {
      throw Exception('Failed to load report: ${response.statusCode}');
    }
  } catch (e) {
    print('Error in getBazrasiByLicenseStatus: $e');
    rethrow;
  }
}

/// گزارش 3: تعداد بازدیدها بر اساس استان/شهر یا کد شرکت
Future<List<Map<String, dynamic>>> getBazrasiByLocation(
  String groupBy, // state, city, code_co
  {
  String? inspectorId,
  DateTime? startDate,
  DateTime? endDate,
  String? unionCode,
  String? unionCodes,
  Map<String, dynamic>? userInfo,
}) async {
  try {
    var params = <String, String>{};
    if (inspectorId != null) params['inspector_id'] = inspectorId;
    if (startDate != null) params['start_date'] = startDate.toIso8601String().split('T')[0];
    if (endDate != null) params['end_date'] = endDate.toIso8601String().split('T')[0];
    if (unionCode != null) params['union_code'] = unionCode;
    _addUnionCodesToParams(params, unionCodes);
    _addUnionCodesToParams(params, unionCodes);
    params = _addUserInfoToParams(params, userInfo: userInfo);
    
    final uri = Uri.parse(
      getApiUrl('reports/bazrasi/by_location/$groupBy'),
    ).replace(queryParameters: params);

    final response = await http.get(uri);

    if (response.statusCode == 200) {
      final jsonData = jsonDecode(response.body) as List<dynamic>;
      return jsonData.map((e) => e as Map<String, dynamic>).toList();
    } else {
      throw Exception('Failed to load report: ${response.statusCode}');
    }
  } catch (e) {
    print('Error in getBazrasiByLocation: $e');
    rethrow;
  }
}

/// گزارش 4: میانگین زمان رسیدگی به هر پرونده
Future<Map<String, dynamic>> getAvgProcessingTime({
  String? inspectorId,
  DateTime? startDate,
  DateTime? endDate,
  String? unionCodes,
  Map<String, dynamic>? userInfo,
}) async {
  try {
    var params = <String, String>{};
    if (inspectorId != null) params['inspector_id'] = inspectorId;
    if (startDate != null) params['start_date'] = startDate.toIso8601String().split('T')[0];
    if (endDate != null) params['end_date'] = endDate.toIso8601String().split('T')[0];
    _addUnionCodesToParams(params, unionCodes);
    _addUnionCodesToParams(params, unionCodes);
    params = _addUserInfoToParams(params, userInfo: userInfo);
    
    final uri = Uri.parse(
      getApiUrl('reports/bazrasi/avg_processing_time'),
    ).replace(queryParameters: params);

    final response = await http.get(uri);

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('Failed to load report: ${response.statusCode}');
    }
  } catch (e) {
    print('Error in getAvgProcessingTime: $e');
    rethrow;
  }
}

/// گزارش 5: نسبت بازرسی‌های فعال به غیر فعال
Future<Map<String, dynamic>> getActiveInactiveRatio({
  String? inspectorId,
  DateTime? startDate,
  DateTime? endDate,
  String? unionCodes,
  Map<String, dynamic>? userInfo,
}) async {
  try {
    var params = <String, String>{};
    if (inspectorId != null) params['inspector_id'] = inspectorId;
    if (startDate != null) params['start_date'] = startDate.toIso8601String().split('T')[0];
    if (endDate != null) params['end_date'] = endDate.toIso8601String().split('T')[0];
    _addUnionCodesToParams(params, unionCodes);
    params = _addUserInfoToParams(params, userInfo: userInfo);
    
    final uri = Uri.parse(
      getApiUrl('reports/bazrasi/active_inactive_ratio'),
    ).replace(queryParameters: params);

    final response = await http.get(uri);

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('Failed to load report: ${response.statusCode}');
    }
  } catch (e) {
    print('Error in getActiveInactiveRatio: $e');
    rethrow;
  }
}

/// گزارش 6: پرتکرارترین نوع تخلف
Future<List<Map<String, dynamic>>> getMostCommonViolations(
  int limit, {
  String? inspectorId,
  DateTime? startDate,
  DateTime? endDate,
  String? unionCodes,
  Map<String, dynamic>? userInfo,
}) async {
  try {
    var params = <String, String>{};
    if (inspectorId != null) params['inspector_id'] = inspectorId;
    if (startDate != null) params['start_date'] = startDate.toIso8601String().split('T')[0];
    if (endDate != null) params['end_date'] = endDate.toIso8601String().split('T')[0];
    _addUnionCodesToParams(params, unionCodes);
    params = _addUserInfoToParams(params, userInfo: userInfo);
    
    final uri = Uri.parse(
      getApiUrl('reports/bazrasi/most_common_violations/$limit'),
    ).replace(queryParameters: params);

    final response = await http.get(uri);

    if (response.statusCode == 200) {
      final jsonData = jsonDecode(response.body) as List<dynamic>;
      return jsonData.map((e) => e as Map<String, dynamic>).toList();
    } else {
      throw Exception('Failed to load report: ${response.statusCode}');
    }
  } catch (e) {
    print('Error in getMostCommonViolations: $e');
    rethrow;
  }
}

/// دریافت لیست بازرسان بر اساس سطح دسترسی
Future<List<Map<String, dynamic>>> getInspectors({
  Map<String, dynamic>? userInfo,
}) async {
  try {
    var params = _addUserInfoToParams(<String, String>{}, userInfo: userInfo);
    final response = await http.get(
      Uri.parse(
        getApiUrl('reports/bazrasi/inspectors'),
      ).replace(queryParameters: params),
    );

    if (response.statusCode == 200) {
      final jsonData = jsonDecode(response.body) as List<dynamic>;
      return jsonData.map((e) => e as Map<String, dynamic>).toList();
    } else {
      throw Exception('Failed to load inspectors: ${response.statusCode}');
    }
  } catch (e) {
    print('Error in getInspectors: $e');
    rethrow;
  }
}

/// گزارش 25: گزارش عملکرد بازرسان با خروجی اکسل
/// برمی‌گرداند: Map با کلیدهای 'header' و 'data'
Future<Map<String, dynamic>> getPerformanceWithExcel({
  String? inspectorId,
  DateTime? startDate,
  DateTime? endDate,
  String? unionCodes,
  Map<String, dynamic>? userInfo,
}) async {
  try {
    var params = <String, String>{};
    if (inspectorId != null) params['inspector_id'] = inspectorId;
    if (startDate != null) params['start_date'] = startDate.toIso8601String().split('T')[0];
    if (endDate != null) params['end_date'] = endDate.toIso8601String().split('T')[0];
    _addUnionCodesToParams(params, unionCodes);
    params = _addUserInfoToParams(params, userInfo: userInfo);
    
    final uri = Uri.parse(
      getApiUrl('reports/bazrasi/performance_with_excel'),
    ).replace(queryParameters: params);

    final response = await http.get(uri);

    if (response.statusCode == 200) {
      final jsonData = jsonDecode(response.body) as Map<String, dynamic>;
      return jsonData;
    } else {
      throw Exception('Failed to load report: ${response.statusCode}');
    }
  } catch (e) {
    print('Error in getPerformanceWithExcel: $e');
    rethrow;
  }
}

/// دریافت لیست اتحادیه‌ها بر اساس سطح دسترسی
Future<List<Map<String, dynamic>>> getUnions({
  Map<String, dynamic>? userInfo,
}) async {
  try {
    var params = _addUserInfoToParams(<String, String>{}, userInfo: userInfo);
    final response = await http.get(
      Uri.parse(
        getApiUrl('reports/bazrasi/unions'),
      ).replace(queryParameters: params),
    );

    if (response.statusCode == 200) {
      final jsonData = jsonDecode(response.body) as List<dynamic>;
      return jsonData.map((e) => e as Map<String, dynamic>).toList();
    } else {
      throw Exception('Failed to load unions: ${response.statusCode}');
    }
  } catch (e) {
    print('Error in getUnions: $e');
    rethrow;
  }
}

/// گزارش 7: تخلفات شایع برای هر وضعیت پروانه
Future<List<Map<String, dynamic>>> getViolationsByLicenseStatus({
  String? inspectorId,
  DateTime? startDate,
  DateTime? endDate,
  String? unionCode,
  String? unionCodes,
  Map<String, dynamic>? userInfo,
}) async {
  try {
    var params = <String, String>{};
    if (inspectorId != null) params['inspector_id'] = inspectorId;
    if (startDate != null) params['start_date'] = startDate.toIso8601String().split('T')[0];
    if (endDate != null) params['end_date'] = endDate.toIso8601String().split('T')[0];
    if (unionCode != null) params['union_code'] = unionCode;
    _addUnionCodesToParams(params, unionCodes);
    params = _addUserInfoToParams(params, userInfo: userInfo);
    
    final uri = Uri.parse(
      getApiUrl('reports/bazrasi/violations_by_license_status'),
    ).replace(queryParameters: params);

    final response = await http.get(uri);

    if (response.statusCode == 200) {
      final jsonData = jsonDecode(response.body) as List<dynamic>;
      return jsonData.map((e) => e as Map<String, dynamic>).toList();
    } else {
      throw Exception('Failed to load report: ${response.statusCode}');
    }
  } catch (e) {
    print('Error in getViolationsByLicenseStatus: $e');
    rethrow;
  }
}

/// گزارش 8: تخلفات بر اساس اتحادیه
Future<List<Map<String, dynamic>>> getViolationsByUnion({
  String? inspectorId,
  DateTime? startDate,
  DateTime? endDate,
  String? unionCode,
  String? unionCodes,
  Map<String, dynamic>? userInfo,
}) async {
  try {
    var params = <String, String>{};
    if (inspectorId != null) params['inspector_id'] = inspectorId;
    if (startDate != null) params['start_date'] = startDate.toIso8601String().split('T')[0];
    if (endDate != null) params['end_date'] = endDate.toIso8601String().split('T')[0];
    if (unionCode != null) params['union_code'] = unionCode;
    _addUnionCodesToParams(params, unionCodes);
    params = _addUserInfoToParams(params, userInfo: userInfo);
    
    final uri = Uri.parse(
      getApiUrl('reports/bazrasi/violations_by_union'),
    ).replace(queryParameters: params);

    final response = await http.get(uri);

    if (response.statusCode == 200) {
      final jsonData = jsonDecode(response.body) as List<dynamic>;
      return jsonData.map((e) => e as Map<String, dynamic>).toList();
    } else {
      throw Exception('Failed to load report: ${response.statusCode}');
    }
  } catch (e) {
    print('Error in getViolationsByUnion: $e');
    rethrow;
  }
}

/// گزارش 9: واحدهایی که بیش از N تخلف دارند (لیست سیاه)
Future<List<Map<String, dynamic>>> getBlacklistUnits(
  int minViolations, {
  String? inspectorId,
  DateTime? startDate,
  DateTime? endDate,
  String? unionCode,
  String? unionCodes,
  Map<String, dynamic>? userInfo,
}) async {
  try {
    var params = <String, String>{};
    if (inspectorId != null) params['inspector_id'] = inspectorId;
    if (startDate != null) params['start_date'] = startDate.toIso8601String().split('T')[0];
    if (endDate != null) params['end_date'] = endDate.toIso8601String().split('T')[0];
    if (unionCode != null) params['union_code'] = unionCode;
    _addUnionCodesToParams(params, unionCodes);
    params = _addUserInfoToParams(params, userInfo: userInfo);
    
    final uri = Uri.parse(
      getApiUrl('reports/bazrasi/blacklist_units/$minViolations'),
    ).replace(queryParameters: params);

    final response = await http.get(uri);

    if (response.statusCode == 200) {
      final jsonData = jsonDecode(response.body) as List<dynamic>;
      return jsonData.map((e) => e as Map<String, dynamic>).toList();
    } else {
      throw Exception('Failed to load report: ${response.statusCode}');
    }
  } catch (e) {
    print('Error in getBlacklistUnits: $e');
    rethrow;
  }
}

/// گزارش 10: تعداد بازرسی انجام‌شده توسط هر بازرس
Future<List<Map<String, dynamic>>> getInspectorInspectionCount({
  DateTime? startDate,
  DateTime? endDate,
  String? unionCode,
  String? unionCodes,
  Map<String, dynamic>? userInfo,
}) async {
  try {
    var params = <String, String>{};
    if (startDate != null) params['start_date'] = startDate.toIso8601String().split('T')[0];
    if (endDate != null) params['end_date'] = endDate.toIso8601String().split('T')[0];
    if (unionCode != null) params['union_code'] = unionCode;
    _addUnionCodesToParams(params, unionCodes);
    params = _addUserInfoToParams(params, userInfo: userInfo);
    
    final uri = Uri.parse(
      getApiUrl('reports/bazrasi/inspector_inspection_count'),
    ).replace(queryParameters: params);

    final response = await http.get(uri);

    if (response.statusCode == 200) {
      final jsonData = jsonDecode(response.body) as List<dynamic>;
      return jsonData.map((e) => e as Map<String, dynamic>).toList();
    } else {
      throw Exception('Failed to load report: ${response.statusCode}');
    }
  } catch (e) {
    print('Error in getInspectorInspectionCount: $e');
    rethrow;
  }
}

/// گزارش 11: میانگین تخلفات کشف‌شده توسط هر بازرس
Future<List<Map<String, dynamic>>> getInspectorAvgViolations({
  DateTime? startDate,
  DateTime? endDate,
  String? unionCode,
  String? unionCodes,
  Map<String, dynamic>? userInfo,
}) async {
  try {
    var params = <String, String>{};
    if (startDate != null) params['start_date'] = startDate.toIso8601String().split('T')[0];
    if (endDate != null) params['end_date'] = endDate.toIso8601String().split('T')[0];
    if (unionCode != null) params['union_code'] = unionCode;
    _addUnionCodesToParams(params, unionCodes);
    params = _addUserInfoToParams(params, userInfo: userInfo);
    
    final uri = Uri.parse(
      getApiUrl('reports/bazrasi/inspector_avg_violations'),
    ).replace(queryParameters: params);

    final response = await http.get(uri);

    if (response.statusCode == 200) {
      final jsonData = jsonDecode(response.body) as List<dynamic>;
      return jsonData.map((e) => e as Map<String, dynamic>).toList();
    } else {
      throw Exception('Failed to load report: ${response.statusCode}');
    }
  } catch (e) {
    print('Error in getInspectorAvgViolations: $e');
    rethrow;
  }
}

/// گزارش 12: بررسی بازدهی بازرسان
Future<List<Map<String, dynamic>>> getInspectorEfficiency({
  DateTime? startDate,
  DateTime? endDate,
  String? unionCode,
  String? unionCodes,
  Map<String, dynamic>? userInfo,
}) async {
  try {
    var params = <String, String>{};
    if (startDate != null) params['start_date'] = startDate.toIso8601String().split('T')[0];
    if (endDate != null) params['end_date'] = endDate.toIso8601String().split('T')[0];
    if (unionCode != null) params['union_code'] = unionCode;
    _addUnionCodesToParams(params, unionCodes);
    params = _addUserInfoToParams(params, userInfo: userInfo);
    
    final uri = Uri.parse(
      getApiUrl('reports/bazrasi/inspector_efficiency'),
    ).replace(queryParameters: params);

    final response = await http.get(uri);

    if (response.statusCode == 200) {
      final jsonData = jsonDecode(response.body) as List<dynamic>;
      return jsonData.map((e) => e as Map<String, dynamic>).toList();
    } else {
      throw Exception('Failed to load report: ${response.statusCode}');
    }
  } catch (e) {
    print('Error in getInspectorEfficiency: $e');
    rethrow;
  }
}

/// گزارش 13: پرونده‌های ارسال‌شده به اماکن
Future<List<Map<String, dynamic>>> getSentToAmaken({
  String? inspectorId,
  DateTime? startDate,
  DateTime? endDate,
  String? unionCode,
  String? unionCodes,
  Map<String, dynamic>? userInfo,
}) async {
  try {
    var params = <String, String>{};
    if (inspectorId != null) params['inspector_id'] = inspectorId;
    if (startDate != null) params['start_date'] = startDate.toIso8601String().split('T')[0];
    if (endDate != null) params['end_date'] = endDate.toIso8601String().split('T')[0];
    if (unionCode != null) params['union_code'] = unionCode;
    _addUnionCodesToParams(params, unionCodes);
    params = _addUserInfoToParams(params, userInfo: userInfo);
    
    final uri = Uri.parse(
      getApiUrl('reports/bazrasi/sent_to_amaken'),
    ).replace(queryParameters: params);

    final response = await http.get(uri);

    if (response.statusCode == 200) {
      final jsonData = jsonDecode(response.body) as List<dynamic>;
      return jsonData.map((e) => e as Map<String, dynamic>).toList();
    } else {
      throw Exception('Failed to load report: ${response.statusCode}');
    }
  } catch (e) {
    print('Error in getSentToAmaken: $e');
    rethrow;
  }
}

/// گزارش 14: پرونده‌های دارای اجرای حکم
Future<List<Map<String, dynamic>>> getExecutedCases({
  String? inspectorId,
  DateTime? startDate,
  DateTime? endDate,
  String? unionCode,
  String? unionCodes,
  Map<String, dynamic>? userInfo,
}) async {
  try {
    var params = <String, String>{};
    if (inspectorId != null) params['inspector_id'] = inspectorId;
    if (startDate != null) params['start_date'] = startDate.toIso8601String().split('T')[0];
    if (endDate != null) params['end_date'] = endDate.toIso8601String().split('T')[0];
    if (unionCode != null) params['union_code'] = unionCode;
    _addUnionCodesToParams(params, unionCodes);
    params = _addUserInfoToParams(params, userInfo: userInfo);
    
    final uri = Uri.parse(
      getApiUrl('reports/bazrasi/executed_cases'),
    ).replace(queryParameters: params);

    final response = await http.get(uri);

    if (response.statusCode == 200) {
      final jsonData = jsonDecode(response.body) as List<dynamic>;
      return jsonData.map((e) => e as Map<String, dynamic>).toList();
    } else {
      throw Exception('Failed to load report: ${response.statusCode}');
    }
  } catch (e) {
    print('Error in getExecutedCases: $e');
    rethrow;
  }
}

/// گزارش 15: درصد پرونده‌های مختومه نسبت به کل
Future<Map<String, dynamic>> getClosedCasesPercentage({
  String? inspectorId,
  DateTime? startDate,
  DateTime? endDate,
  String? unionCode,
  String? unionCodes,
  Map<String, dynamic>? userInfo,
}) async {
  try {
    var params = <String, String>{};
    if (inspectorId != null) params['inspector_id'] = inspectorId;
    if (startDate != null) params['start_date'] = startDate.toIso8601String().split('T')[0];
    if (endDate != null) params['end_date'] = endDate.toIso8601String().split('T')[0];
    if (unionCode != null) params['union_code'] = unionCode;
    _addUnionCodesToParams(params, unionCodes);
    params = _addUserInfoToParams(params, userInfo: userInfo);
    
    final uri = Uri.parse(
      getApiUrl('reports/bazrasi/closed_cases_percentage'),
    ).replace(queryParameters: params);

    final response = await http.get(uri);

    if (response.statusCode == 200) {
      final jsonData = jsonDecode(response.body) as Map<String, dynamic>;
      return jsonData;
    } else {
      throw Exception('Failed to load report: ${response.statusCode}');
    }
  } catch (e) {
    print('Error in getClosedCasesPercentage: $e');
    rethrow;
  }
}

/// گزارش 16: میزان معطلی پرونده‌ها در وضعیت "در دست اقدام"
Future<Map<String, dynamic>> getPendingCasesDelay({
  String? inspectorId,
  DateTime? startDate,
  DateTime? endDate,
  String? unionCode,
  int minDays = 0,
  String? unionCodes,
  Map<String, dynamic>? userInfo,
}) async {
  try {
    var params = <String, String>{};
    if (inspectorId != null) params['inspector_id'] = inspectorId;
    if (startDate != null) params['start_date'] = startDate.toIso8601String().split('T')[0];
    if (endDate != null) params['end_date'] = endDate.toIso8601String().split('T')[0];
    if (unionCode != null) params['union_code'] = unionCode;
    params['min_days'] = minDays.toString();
    _addUnionCodesToParams(params, unionCodes);
    params = _addUserInfoToParams(params, userInfo: userInfo);
    
    final uri = Uri.parse(
      getApiUrl('reports/bazrasi/pending_cases_delay'),
    ).replace(queryParameters: params);

    final response = await http.get(uri);

    if (response.statusCode == 200) {
      final jsonData = jsonDecode(response.body) as Map<String, dynamic>;
      return jsonData;
    } else {
      throw Exception('Failed to load report: ${response.statusCode}');
    }
  } catch (e) {
    print('Error in getPendingCasesDelay: $e');
    rethrow;
  }
}

/// گزارش 17: شناسایی مناطق و کد شرکت‌های پر تخلف
Future<List<Map<String, dynamic>>> getHighViolationAreas({
  String groupBy = 'union', // union, state, city
  int limit = 10,
  String? inspectorId,
  DateTime? startDate,
  DateTime? endDate,
  String? unionCodes,
  Map<String, dynamic>? userInfo,
}) async {
  try {
    var params = <String, String>{
      'group_by': groupBy,
      'limit': limit.toString(),
    };
    if (inspectorId != null) params['inspector_id'] = inspectorId;
    if (startDate != null) params['start_date'] = startDate.toIso8601String().split('T')[0];
    if (endDate != null) params['end_date'] = endDate.toIso8601String().split('T')[0];
    _addUnionCodesToParams(params, unionCodes);
    params = _addUserInfoToParams(params, userInfo: userInfo);
    
    final uri = Uri.parse(
      getApiUrl('reports/bazrasi/high_violation_areas'),
    ).replace(queryParameters: params);

    final response = await http.get(uri);

    if (response.statusCode == 200) {
      final jsonData = jsonDecode(response.body) as List<dynamic>;
      return jsonData.map((e) => e as Map<String, dynamic>).toList();
    } else {
      throw Exception('Failed to load report: ${response.statusCode}');
    }
  } catch (e) {
    print('Error in getHighViolationAreas: $e');
    rethrow;
  }
}

/// گزارش 18: روند تغییر تخلفات در بازه زمانی
Future<List<Map<String, dynamic>>> getViolationTrend({
  String period = 'monthly', // daily, weekly, monthly, yearly
  String? inspectorId,
  DateTime? startDate,
  DateTime? endDate,
  String? unionCodes,
  Map<String, dynamic>? userInfo,
}) async {
  try {
    var params = <String, String>{
      'period': period,
    };
    if (inspectorId != null) params['inspector_id'] = inspectorId;
    if (startDate != null) params['start_date'] = startDate.toIso8601String().split('T')[0];
    if (endDate != null) params['end_date'] = endDate.toIso8601String().split('T')[0];
    _addUnionCodesToParams(params, unionCodes);
    params = _addUserInfoToParams(params, userInfo: userInfo);
    
    final uri = Uri.parse(
      getApiUrl('reports/bazrasi/violation_trend'),
    ).replace(queryParameters: params);

    final response = await http.get(uri);

    if (response.statusCode == 200) {
      final jsonData = jsonDecode(response.body) as List<dynamic>;
      return jsonData.map((e) => e as Map<String, dynamic>).toList();
    } else {
      throw Exception('Failed to load report: ${response.statusCode}');
    }
  } catch (e) {
    print('Error in getViolationTrend: $e');
    rethrow;
  }
}

/// گزارش 19: پیش‌بینی تخلفات پرریسک آینده
Future<List<Map<String, dynamic>>> getRiskPrediction({
  String? inspectorId,
  DateTime? startDate,
  DateTime? endDate,
  String? unionCodes,
  Map<String, dynamic>? userInfo,
}) async {
  try {
    var params = <String, String>{};
    if (inspectorId != null) params['inspector_id'] = inspectorId;
    if (startDate != null) params['start_date'] = startDate.toIso8601String().split('T')[0];
    if (endDate != null) params['end_date'] = endDate.toIso8601String().split('T')[0];
    _addUnionCodesToParams(params, unionCodes);
    params = _addUserInfoToParams(params, userInfo: userInfo);
    
    final uri = Uri.parse(
      getApiUrl('reports/bazrasi/risk_prediction'),
    ).replace(queryParameters: params);

    final response = await http.get(uri);

    if (response.statusCode == 200) {
      final jsonData = jsonDecode(response.body) as List<dynamic>;
      return jsonData.map((e) => e as Map<String, dynamic>).toList();
    } else {
      throw Exception('Failed to load report: ${response.statusCode}');
    }
  } catch (e) {
    print('Error in getRiskPrediction: $e');
    rethrow;
  }
}

/// گزارش 20: مقایسه عملکرد بازرسی ماه جاری با ماه قبل
Future<Map<String, dynamic>> getMonthlyComparison({
  String? inspectorId,
  String? unionCodes,
  Map<String, dynamic>? userInfo,
}) async {
  try {
    var params = <String, String>{};
    if (inspectorId != null) params['inspector_id'] = inspectorId;
    _addUnionCodesToParams(params, unionCodes);
    params = _addUserInfoToParams(params, userInfo: userInfo);
    
    final uri = Uri.parse(
      getApiUrl('reports/bazrasi/monthly_comparison'),
    ).replace(queryParameters: params);

    final response = await http.get(uri);

    if (response.statusCode == 200) {
      final jsonData = jsonDecode(response.body) as Map<String, dynamic>;
      return jsonData;
    } else {
      throw Exception('Failed to load report: ${response.statusCode}');
    }
  } catch (e) {
    print('Error in getMonthlyComparison: $e');
    rethrow;
  }
}

/// گزارش 21: لیست کامل پرونده‌های مهم (ویژه) برای پیگیری مدیرکل
Future<List<Map<String, dynamic>>> getImportantCases({
  String? inspectorId,
  DateTime? startDate,
  DateTime? endDate,
  int minViolations = 3,
  String? severity, // high, medium, low
  String? unionCodes,
  Map<String, dynamic>? userInfo,
}) async {
  try {
    var params = <String, String>{
      'min_violations': minViolations.toString(),
    };
    if (inspectorId != null) params['inspector_id'] = inspectorId;
    if (startDate != null) params['start_date'] = startDate.toIso8601String().split('T')[0];
    if (endDate != null) params['end_date'] = endDate.toIso8601String().split('T')[0];
    if (severity != null) params['severity'] = severity;
    _addUnionCodesToParams(params, unionCodes);
    params = _addUserInfoToParams(params, userInfo: userInfo);
    
    final uri = Uri.parse(
      getApiUrl('reports/bazrasi/important_cases'),
    ).replace(queryParameters: params);

    final response = await http.get(uri);

    if (response.statusCode == 200) {
      final jsonData = jsonDecode(response.body) as List<dynamic>;
      return jsonData.map((e) => e as Map<String, dynamic>).toList();
    } else {
      throw Exception('Failed to load report: ${response.statusCode}');
    }
  } catch (e) {
    print('Error in getImportantCases: $e');
    rethrow;
  }
}

/// گزارش 22: واحدهایی که اخطار تکراری گرفتند اما اصلاح نکردند
Future<List<Map<String, dynamic>>> getRepeatWarningsNoFix({
  String? inspectorId,
  DateTime? startDate,
  DateTime? endDate,
  int minWarnings = 2,
  String? unionCodes,
  Map<String, dynamic>? userInfo,
}) async {
  try {
    var params = <String, String>{
      'min_warnings': minWarnings.toString(),
    };
    if (inspectorId != null) params['inspector_id'] = inspectorId;
    if (startDate != null) params['start_date'] = startDate.toIso8601String().split('T')[0];
    if (endDate != null) params['end_date'] = endDate.toIso8601String().split('T')[0];
    _addUnionCodesToParams(params, unionCodes);
    params = _addUserInfoToParams(params, userInfo: userInfo);
    
    final uri = Uri.parse(
      getApiUrl('reports/bazrasi/repeat_warnings_no_fix'),
    ).replace(queryParameters: params);

    final response = await http.get(uri);

    if (response.statusCode == 200) {
      final jsonData = jsonDecode(response.body) as List<dynamic>;
      return jsonData.map((e) => e as Map<String, dynamic>).toList();
    } else {
      throw Exception('Failed to load report: ${response.statusCode}');
    }
  } catch (e) {
    print('Error in getRepeatWarningsNoFix: $e');
    rethrow;
  }
}

/// گزارش 23: گزارش چرخه عمر پرونده‌ها (از تاریخ صدور تا اجرای حکم)
Future<List<Map<String, dynamic>>> getCaseLifecycle({
  String? inspectorId,
  DateTime? startDate,
  DateTime? endDate,
  String? unionCode,
  String? status, // all, closed, pending, sent
  String? unionCodes,
  Map<String, dynamic>? userInfo,
}) async {
  try {
    var params = <String, String>{};
    if (inspectorId != null) params['inspector_id'] = inspectorId;
    if (startDate != null) params['start_date'] = startDate.toIso8601String().split('T')[0];
    if (endDate != null) params['end_date'] = endDate.toIso8601String().split('T')[0];
    if (unionCode != null) params['union_code'] = unionCode;
    if (status != null) params['status'] = status;
    _addUnionCodesToParams(params, unionCodes);
    params = _addUserInfoToParams(params, userInfo: userInfo);
    
    final uri = Uri.parse(
      getApiUrl('reports/bazrasi/case_lifecycle'),
    ).replace(queryParameters: params);

    final response = await http.get(uri);

    if (response.statusCode == 200) {
      final jsonData = jsonDecode(response.body) as List<dynamic>;
      return jsonData.map((e) => e as Map<String, dynamic>).toList();
    } else {
      throw Exception('Failed to load report: ${response.statusCode}');
    }
  } catch (e) {
    print('Error in getCaseLifecycle: $e');
    rethrow;
  }
}

/// گزارش 24: مقایسه آمار بازرسی بین اتحادیه‌ها
Future<Map<String, dynamic>> getUnionsComparison({
  String? inspectorId,
  DateTime? startDate,
  DateTime? endDate,
  String? unionCodes,
  Map<String, dynamic>? userInfo,
}) async {
  try {
    var params = <String, String>{};
    if (inspectorId != null) params['inspector_id'] = inspectorId;
    if (startDate != null) params['start_date'] = startDate.toIso8601String().split('T')[0];
    if (endDate != null) params['end_date'] = endDate.toIso8601String().split('T')[0];
    _addUnionCodesToParams(params, unionCodes);
    params = _addUserInfoToParams(params, userInfo: userInfo);
    
    final uri = Uri.parse(
      getApiUrl('reports/bazrasi/unions_comparison'),
    ).replace(queryParameters: params);

    final response = await http.get(uri);

    if (response.statusCode == 200) {
      final jsonData = jsonDecode(response.body) as Map<String, dynamic>;
      return jsonData;
    } else {
      throw Exception('Failed to load report: ${response.statusCode}');
    }
  } catch (e) {
    print('Error in getUnionsComparison: $e');
    rethrow;
  }
}

// ==================== گزارش‌های بدهی اعضا ====================

/// گزارش 1: آمار کلی بدهی
Future<Map<String, dynamic>> getDebtGeneralStats({
  String? unionCodes,
  Map<String, dynamic>? userInfo,
}) async {
  try {
    var params = _addUserInfoToParams(<String, String>{}, userInfo: userInfo);
    if (unionCodes != null && unionCodes.isNotEmpty) params['union_codes'] = unionCodes;
    final response = await http.get(
      Uri.parse(getApiUrl('reports/debt/general_stats'))
          .replace(queryParameters: params),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('Failed to load report: ${response.statusCode}');
    }
  } catch (e) {
    print('Error in getDebtGeneralStats: $e');
    rethrow;
  }
}

/// گزارش 2: توزیع بدهی‌ها در بازه‌های مقداری
Future<List<Map<String, dynamic>>> getDebtDistribution({
  String? unionCodes,
  Map<String, dynamic>? userInfo,
}) async {
  try {
    var params = _addUserInfoToParams(<String, String>{}, userInfo: userInfo);
    if (unionCodes != null && unionCodes.isNotEmpty) params['union_codes'] = unionCodes;
    final response = await http.get(
      Uri.parse(getApiUrl('reports/debt/distribution'))
          .replace(queryParameters: params),
    );

    if (response.statusCode == 200) {
      final jsonData = jsonDecode(response.body) as List<dynamic>;
      return jsonData.map((e) => e as Map<String, dynamic>).toList();
    } else {
      throw Exception('Failed to load report: ${response.statusCode}');
    }
  } catch (e) {
    print('Error in getDebtDistribution: $e');
    rethrow;
  }
}

/// گزارش 3: TOP بدهکاران
Future<List<Map<String, dynamic>>> getTopDebtors({
  int limit = 10,
  String? unionCodes,
  Map<String, dynamic>? userInfo,
}) async {
  try {
    var params = _addUserInfoToParams(<String, String>{}, userInfo: userInfo);
    params['limit'] = limit.toString();
    if (unionCodes != null && unionCodes.isNotEmpty) params['union_codes'] = unionCodes;
    final response = await http.get(
      Uri.parse(getApiUrl('reports/debt/top_debtors'))
          .replace(queryParameters: params),
    );

    if (response.statusCode == 200) {
      final jsonData = jsonDecode(response.body) as List<dynamic>;
      return jsonData.map((e) => e as Map<String, dynamic>).toList();
    } else {
      throw Exception('Failed to load report: ${response.statusCode}');
    }
  } catch (e) {
    print('Error in getTopDebtors: $e');
    rethrow;
  }
}

/// گزارش 4: میانگین بدهی بر اساس رسته
Future<List<Map<String, dynamic>>> getDebtByRaste({
  String? unionCodes,
  Map<String, dynamic>? userInfo,
}) async {
  try {
    var params = _addUserInfoToParams(<String, String>{}, userInfo: userInfo);
    if (unionCodes != null && unionCodes.isNotEmpty) params['union_codes'] = unionCodes;
    final response = await http.get(
      Uri.parse(getApiUrl('reports/debt/by_raste'))
          .replace(queryParameters: params),
    );

    if (response.statusCode == 200) {
      final jsonData = jsonDecode(response.body) as List<dynamic>;
      return jsonData.map((e) => e as Map<String, dynamic>).toList();
    } else {
      throw Exception('Failed to load report: ${response.statusCode}');
    }
  } catch (e) {
    print('Error in getDebtByRaste: $e');
    rethrow;
  }
}

/// گزارش 5: بدهی بر اساس وضعیت اعتبار پروانه
Future<List<Map<String, dynamic>>> getDebtByLicenseStatus({
  String? unionCodes,
  Map<String, dynamic>? userInfo,
}) async {
  try {
    var params = _addUserInfoToParams(<String, String>{}, userInfo: userInfo);
    if (unionCodes != null && unionCodes.isNotEmpty) params['union_codes'] = unionCodes;
    final response = await http.get(
      Uri.parse(getApiUrl('reports/debt/by_license_status'))
          .replace(queryParameters: params),
    );

    if (response.statusCode == 200) {
      final jsonData = jsonDecode(response.body) as List<dynamic>;
      return jsonData.map((e) => e as Map<String, dynamic>).toList();
    } else {
      throw Exception('Failed to load report: ${response.statusCode}');
    }
  } catch (e) {
    print('Error in getDebtByLicenseStatus: $e');
    rethrow;
  }
}

/// گزارش 6: روند بدهی‌ها بر اساس سال صدور پروانه
Future<List<Map<String, dynamic>>> getDebtByIssueYear({
  String? unionCodes,
  Map<String, dynamic>? userInfo,
}) async {
  try {
    var params = _addUserInfoToParams(<String, String>{}, userInfo: userInfo);
    if (unionCodes != null && unionCodes.isNotEmpty) params['union_codes'] = unionCodes;
    final response = await http.get(
      Uri.parse(getApiUrl('reports/debt/by_issue_year'))
          .replace(queryParameters: params),
    );

    if (response.statusCode == 200) {
      final jsonData = jsonDecode(response.body) as List<dynamic>;
      return jsonData.map((e) => e as Map<String, dynamic>).toList();
    } else {
      throw Exception('Failed to load report: ${response.statusCode}');
    }
  } catch (e) {
    print('Error in getDebtByIssueYear: $e');
    rethrow;
  }
}

