import 'dart:convert';

import 'package:injast_admin/injast_http.dart' as http;
import 'package:injast_admin/server_config.dart';

String mediaAbsoluteUrl(String? path) {
  if (path == null || path.isEmpty || path == 'null') return '';
  if (path.startsWith('http://') || path.startsWith('https://')) {
    final uri = Uri.tryParse(path);
    if (uri != null && uri.path.startsWith('/pic_injast/')) {
      return '$mediaOrigin${uri.path}';
    }
    return path;
  }
  final clean = path.startsWith('/') ? path : '/$path';
  if (clean.startsWith('/pic_injast/')) {
    return '$mediaOrigin$clean';
  }
  return '$mediaOrigin$clean';
}

class PortalSettings {
  PortalSettings({
    this.id,
    required this.codeCo,
    this.unionDisplayName,
    this.tagline,
    this.shortDescription,
    this.logoUrl,
    this.heroImageUrl,
    this.primaryColor = '#1A56DB',
    this.primaryDark = '#1E3A8A',
    this.accentColor = '#0EA5E9',
    this.surfaceTint = '#EFF6FF',
    this.address,
    this.phone,
    this.mobile,
    this.email,
    this.workHours,
    this.city,
    this.province,
    this.latitude,
    this.longitude,
    this.aboutText,
    this.mission,
    this.vision,
    this.goals,
    this.historySummary,
    this.presidentName,
    this.presidentTitle,
    this.presidentMessage,
    this.presidentImageUrl,
    this.heroHighlights = const [],
    this.homeWidgets = const [],
    this.stats = const [],
    this.appAndroidUrl,
    this.appIosUrl,
    this.tickerText,
    this.socialInstagram,
    this.socialTelegram,
    this.socialLinkedin,
    this.isPublished = true,
  });

  final int? id;
  final String codeCo;
  String? unionDisplayName;
  String? tagline;
  String? shortDescription;
  String? logoUrl;
  String? heroImageUrl;
  String primaryColor;
  String primaryDark;
  String accentColor;
  String surfaceTint;
  String? address;
  String? phone;
  String? mobile;
  String? email;
  String? workHours;
  String? city;
  String? province;
  double? latitude;
  double? longitude;
  String? aboutText;
  String? mission;
  String? vision;
  String? goals;
  String? historySummary;
  String? presidentName;
  String? presidentTitle;
  String? presidentMessage;
  String? presidentImageUrl;
  List<dynamic> heroHighlights;
  List<dynamic> homeWidgets;
  List<dynamic> stats;
  String? appAndroidUrl;
  String? appIosUrl;
  String? tickerText;
  String? socialInstagram;
  String? socialTelegram;
  String? socialLinkedin;
  bool isPublished;

  factory PortalSettings.fromJson(Map<String, dynamic> j) {
    return PortalSettings(
      id: j['id'] is int ? j['id'] as int : int.tryParse('${j['id']}'),
      codeCo: '${j['code_co'] ?? ''}',
      unionDisplayName: j['union_display_name']?.toString(),
      tagline: j['tagline']?.toString(),
      shortDescription: j['short_description']?.toString(),
      logoUrl: j['logo_url']?.toString(),
      heroImageUrl: j['hero_image_url']?.toString(),
      primaryColor: j['primary_color']?.toString() ?? '#1A56DB',
      primaryDark: j['primary_dark']?.toString() ?? '#1E3A8A',
      accentColor: j['accent_color']?.toString() ?? '#0EA5E9',
      surfaceTint: j['surface_tint']?.toString() ?? '#EFF6FF',
      address: j['address']?.toString(),
      phone: j['phone']?.toString(),
      mobile: j['mobile']?.toString(),
      email: j['email']?.toString(),
      workHours: j['work_hours']?.toString(),
      city: j['city']?.toString(),
      province: j['province']?.toString(),
      latitude: j['latitude'] == null ? null : double.tryParse('${j['latitude']}'),
      longitude: j['longitude'] == null ? null : double.tryParse('${j['longitude']}'),
      aboutText: j['about_text']?.toString(),
      mission: j['mission']?.toString(),
      vision: j['vision']?.toString(),
      goals: j['goals']?.toString(),
      historySummary: j['history_summary']?.toString(),
      presidentName: j['president_name']?.toString(),
      presidentTitle: j['president_title']?.toString(),
      presidentMessage: j['president_message']?.toString(),
      presidentImageUrl: j['president_image_url']?.toString(),
      heroHighlights: (j['hero_highlights'] as List?) ?? const [],
      homeWidgets: (j['home_widgets'] as List?) ?? const [],
      stats: (j['stats'] as List?) ?? const [],
      appAndroidUrl: j['app_android_url']?.toString(),
      appIosUrl: j['app_ios_url']?.toString(),
      tickerText: j['ticker_text']?.toString(),
      socialInstagram: j['social_instagram']?.toString(),
      socialTelegram: j['social_telegram']?.toString(),
      socialLinkedin: j['social_linkedin']?.toString(),
      isPublished: j['is_published'] == 1 || j['is_published'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
        'union_display_name': unionDisplayName,
        'tagline': tagline,
        'short_description': shortDescription,
        'logo_url': logoUrl,
        'hero_image_url': heroImageUrl,
        'primary_color': primaryColor,
        'primary_dark': primaryDark,
        'accent_color': accentColor,
        'surface_tint': surfaceTint,
        'address': address,
        'phone': phone,
        'mobile': mobile,
        'email': email,
        'work_hours': workHours,
        'city': city,
        'province': province,
        'latitude': latitude,
        'longitude': longitude,
        'about_text': aboutText,
        'mission': mission,
        'vision': vision,
        'goals': goals,
        'history_summary': historySummary,
        'president_name': presidentName,
        'president_title': presidentTitle,
        'president_message': presidentMessage,
        'president_image_url': presidentImageUrl,
        'hero_highlights': heroHighlights,
        'home_widgets': homeWidgets,
        'stats': stats,
        'app_android_url': appAndroidUrl,
        'app_ios_url': appIosUrl,
        'ticker_text': tickerText,
        'social_instagram': socialInstagram,
        'social_telegram': socialTelegram,
        'social_linkedin': socialLinkedin,
        'is_published': isPublished,
      };
}

class PortalApi {
  static Future<PortalSettings?> getSettings(String codeCo) async {
    final res = await http.get(Uri.parse(getApiUrl('portal/settings/$codeCo')));
    if (res.statusCode != 200) throw Exception('settings ${res.statusCode}');
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final data = body['data'];
    if (data == null) {
      return PortalSettings(codeCo: codeCo);
    }
    return PortalSettings.fromJson(Map<String, dynamic>.from(data as Map));
  }

  static Future<PortalSettings> saveSettings(String codeCo, PortalSettings s, {int? idUser}) async {
    final payload = s.toJson();
    if (idUser != null) payload['id_user'] = idUser;
    final res = await http.put(
      Uri.parse(getApiUrl('portal/settings/$codeCo')),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );
    if (res.statusCode != 200) throw Exception('save settings ${res.statusCode}: ${res.body}');
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return PortalSettings.fromJson(Map<String, dynamic>.from(body['data'] as Map));
  }

  static Future<List<Map<String, dynamic>>> list(String resource, String codeCo) async {
    final res = await http.get(Uri.parse(getApiUrl('portal/$resource/list/$codeCo')));
    if (res.statusCode != 200) throw Exception('list $resource ${res.statusCode}');
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final data = body['data'] as List? ?? [];
    return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  static Future<int> create(String resource, Map<String, dynamic> body) async {
    final res = await http.post(
      Uri.parse(getApiUrl('portal/$resource/create')),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    if (res.statusCode != 200) throw Exception('create $resource ${res.statusCode}: ${res.body}');
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    return int.tryParse('${json['id']}') ?? 0;
  }

  static Future<void> update(String resource, int id, Map<String, dynamic> body) async {
    final res = await http.put(
      Uri.parse(getApiUrl('portal/$resource/$id')),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    if (res.statusCode != 200) throw Exception('update $resource ${res.statusCode}: ${res.body}');
  }

  static Future<void> delete(String resource, int id) async {
    final res = await http.delete(Uri.parse(getApiUrl('portal/$resource/$id')));
    if (res.statusCode != 200) throw Exception('delete $resource ${res.statusCode}');
  }
}
