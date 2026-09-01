import 'dart:async';
import 'dart:convert';
import 'dart:developer' show log;
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:injast_admin/file_management/address_geocoding_service.dart';
import 'package:injast_admin/import_sync/asnaf_api_throttle.dart';
import 'package:injast_admin/import_sync/asnaf_fetch_pace.dart';
import 'package:injast_admin/import_sync/asnaf_jwt_policy.dart';
import 'package:injast_admin/import_sync/asnaf_op_log.dart';
import 'package:injast_admin/import_sync/asnaf_webview_api.dart';
import 'package:injast_admin/import_sync/import_models.dart';

class AsnafMeta {
  AsnafMeta({
    required this.totalCount,
    required this.totalPages,
  });

  final int totalCount;
  final int totalPages;
}

class AsnafCollectProgress {
  AsnafCollectProgress({
    required this.stage,
    required this.successCount,
    required this.failedCount,
    required this.plannedCount,
    this.page,
    this.name = '',
    this.details = '',
  });

  final String stage;
  final int successCount;
  final int failedCount;
  final int plannedCount;
  final int? page;
  final String name;
  final String details;
}

class AsnafBotClient {
  static const _base = 'https://apinovin.iranianasnaf.ir';

  /// اگر ست شود، درخواست‌ها از داخل WebView (با کوکی همان سشن) زده می‌شوند.
  AsnafWebViewApi? webViewApi;

  /// همان سرویس نشان بک‌اند (`test_address_2.js`). اگر `NESHAN_API_KEY` با
  /// `--dart-define` ست شود، همان مقدار جایگزین این پیش‌فرض می‌شود.
  static const _neshanApiKeyEmbedded = 'service.1c8e1ac2992643cfa931b8f52a6e0b39';

  String get _neshanApiKey {
    const fromEnv = String.fromEnvironment('NESHAN_API_KEY');
    final t = fromEnv.trim();
    return t.isNotEmpty ? t : _neshanApiKeyEmbedded;
  }

  /// آیا برای فراخوانی نشان کلید مؤثر در دسترس است (پیش‌فرض پروژه یا dart-define).
  bool get isNeshanGeocodingConfigured => _neshanApiKey.trim().isNotEmpty;

  Future<AsnafMeta> fetchMeta(String token) async {
    final first = await fetchParvandehPageWithMeta(token: token, page: 1);
    return first.meta;
  }

  Future<List<ImportDraftRecord>> collectRecords({
    required String token,
    required String codeCo,
    required int startPage,
    required int endPage,
    required bool updateDebtOnly,
    int? maxRecords,
    void Function(AsnafCollectProgress progress)? onProgress,
  }) async {
    final out = <ImportDraftRecord>[];
    var successCount = 0;
    var failedCount = 0;
    var plannedCount = 0;

    for (var page = startPage; page <= endPage; page++) {
      onProgress?.call(
        AsnafCollectProgress(
          stage: 'fetch_page',
          page: page,
          successCount: successCount,
          failedCount: failedCount,
          plannedCount: plannedCount,
          details: 'دریافت صفحه $page از $endPage',
        ),
      );
      final pageJson = await _getJson(
        '$_base/parvaneh/?page=$page&management=True',
        token,
        retryOn429: true,
      );
      final results = _extractResults(pageJson);
      plannedCount += results.length;
      if (maxRecords != null && plannedCount > maxRecords) {
        plannedCount = maxRecords;
      }
      for (var i = 0; i < results.length; i++) {
        if (maxRecords != null && out.length >= maxRecords) {
          return out;
        }
        final row = results[i];
        final parvanehId = _toStr(row['id']);
        if (parvanehId.isEmpty) {
          failedCount += 1;
          continue;
        }

        try {
          final detail =
              await _getJson('$_base/parvaneh/$parvanehId/', token, retryOn429: true);
          final payload = _mapParvandePayload(detail, codeCo);

          if (!updateDebtOnly) {
            final docs = await _getJson(
              '$_base/docs/?parvaneh=$parvanehId&no_page=true',
              token,
              retryOn429: true,
            );
            final rawDocsList = _extractDocsList(docs);
            final normalizedDocs = _normalizeDocs(docs);
            final withLink = normalizedDocs
                .where((m) => _toStr(m['link_doc']).trim().isNotEmpty)
                .length;
            log(
              'stage=1_fetch_api | parvaneh=$parvanehId | api_list_len=${rawDocsList.length} | '
              'normalized_len=${normalizedDocs.length} | with_link_doc=$withLink | '
              'response=${_docsResponseShape(docs)}',
              name: 'asnaf_import_docs',
            );
            payload['_docs_json'] = jsonEncode(normalizedDocs);
            payload['_raste_name'] = _toStr(detail['raste_info']?['isic']?['title']);
            payload['_raste_code'] = _toStr(detail['raste_info']?['isic']?['isic']);
          }

          final name =
              '${_toStr(detail['user']?['first_name'])} ${_toStr(detail['user']?['last_name'])}'
                  .trim();
          final status = _toStr(detail['status_display']);
          final debt = _toStr(detail['debt_amount']);

          out.add(
            ImportDraftRecord(
              clientTempId: parvanehId,
              payload: payload.map((k, v) => MapEntry(k, v.toString())),
            ),
          );
          successCount += 1;

          onProgress?.call(
            AsnafCollectProgress(
              stage: 'record_ok',
              page: page,
              successCount: successCount,
              failedCount: failedCount,
              plannedCount: plannedCount,
              name: name,
              details:
                  'شناسه:$parvanehId | وضعیت:${status.isEmpty ? '-' : status} | بدهی:${debt.isEmpty ? '-' : debt}',
            ),
          );
        } catch (e) {
          failedCount += 1;
          onProgress?.call(
            AsnafCollectProgress(
              stage: 'record_error',
              page: page,
              successCount: successCount,
              failedCount: failedCount,
              plannedCount: plannedCount,
              name: 'شناسه $parvanehId',
              details: 'خطا در پردازش رکورد: $e',
            ),
          );
        }
        await Future<void>.delayed(AsnafFetchPace.current.pauseAfterRecordInCollect);
      }
      await Future<void>.delayed(AsnafFetchPace.current.pauseAfterPageInCollect);
    }

    return out;
  }

  Future<List<dynamic>> fetchParvandehPage({
    required String token,
    required int page,
  }) async {
    final sw = Stopwatch()..start();
    final pageJson = await _getJson(
      '$_base/parvaneh/?page=$page&management=True',
      token,
      retryOn429: true,
    );
    final rows = _extractResults(pageJson);
    AsnafOpLog.line(
      AsnafOpLog.api,
      'لیست صفحه $page | rows=${rows.length} | ${sw.elapsedMilliseconds}ms',
    );
    return rows;
  }

  /// همان لیست صفحه به‌همراه `count` / تعداد صفحات (بدون endpoint جدا).
  Future<({List<dynamic> rows, AsnafMeta meta})> fetchParvandehPageWithMeta({
    required String token,
    required int page,
  }) async {
    final pageJson = await _getJson(
      '$_base/parvaneh/?page=$page&management=True',
      token,
      retryOn429: true,
    );
    final rows = _extractResults(pageJson);
    final meta = _metaFromPageJson(pageJson, rows.length);
    AsnafOpLog.line(
      AsnafOpLog.api,
      'لیست+متا صفحه $page | rows=${rows.length} count=${meta.totalCount} pages=${meta.totalPages}',
    );
    return (rows: rows, meta: meta);
  }

  AsnafMeta _metaFromPageJson(dynamic pageJson, int rowCountOnPage) {
    final totalCount = _toInt((pageJson is Map) ? pageJson['count'] : 0);
    final explicitPages = _toInt(
      (pageJson is Map)
          ? (pageJson['total_pages'] ??
              pageJson['totalPages'] ??
              pageJson['num_pages'] ??
              pageJson['pages'])
          : null,
    );
    final safePageSize = rowCountOnPage > 0 ? rowCountOnPage : 20;
    final fallbackPages =
        totalCount <= 0 ? 1 : ((totalCount + safePageSize - 1) ~/ safePageSize);
    final totalPages = explicitPages > 0 ? explicitPages : fallbackPages;
    return AsnafMeta(totalCount: totalCount, totalPages: totalPages);
  }

  /// پارس مقدار بدهی از API (رشته با ویرگول، ارقام فارسی، …).
  static double? parseDebtAmount(dynamic raw) {
    if (raw == null) return null;
    var s = raw.toString().trim();
    if (s.isEmpty || s.toLowerCase() == 'null') return null;
    s = s.replaceAll(',', '').replaceAll('،', '');
    const fa = '۰۱۲۳۴۵۶۷۸۹';
    const en = '0123456789';
    for (var i = 0; i < fa.length; i++) {
      s = s.replaceAll(fa[i], en[i]);
    }
    return double.tryParse(s);
  }

  static bool isNonZeroDebtAmount(double? v) => v != null && v.abs() > 1e-9;

  bool _detailHasNonZeroDebt(dynamic detail) {
    if (detail is! Map) return false;
    return isNonZeroDebtAmount(parseDebtAmount(detail['debt_amount']));
  }

  /// فقط در صورت بدهی غیرصفر: یک درخواست جزئیات + payload بدون اسناد و ژئوکد.
  /// [payload] شامل `_import_mode` = `debt_only` برای نهایی‌سازی سمت سرور است.
  Future<ImportDraftRecord?> buildDebtOnlyDraftIfNonZeroDebt({
    required String token,
    required String codeCo,
    required String parvanehId,
  }) async {
    final detail = await _getJson('$_base/parvaneh/$parvanehId/', token, retryOn429: true);
    if (!_detailHasNonZeroDebt(detail)) return null;
    final d = (detail is Map) ? detail : const {};
    final payload = _mapParvandePayload(d, codeCo);
    payload['_import_mode'] = 'debt_only';
    return ImportDraftRecord(
      clientTempId: parvanehId,
      payload: payload.map((k, v) => MapEntry(k, v.toString())),
    );
  }

  Future<ImportDraftRecord> buildDraftRecord({
    required String token,
    required String codeCo,
    required String parvanehId,
    required bool includeDocs,
    required bool geocodeIfMissing,
  }) async {
    final sw = Stopwatch()..start();
    AsnafOpLog.line(
      AsnafOpLog.record,
      'شروع id=$parvanehId docs=$includeDocs geocode=$geocodeIfMissing',
    );
    final detail = await _getJson('$_base/parvaneh/$parvanehId/', token, retryOn429: true);
    final payload = _mapParvandePayload(detail, codeCo);
    AsnafOpLog.line(
      AsnafOpLog.record,
      'جزئیات id=$parvanehId | واحد=${AsnafOpLog.clip(payload['name_store'] ?? '', 40)} | '
      'آدرس=${(payload['address_store'] ?? '').isEmpty ? 'خالی' : 'ok'} | '
      'lat=${payload['lat_store']?.isEmpty == true ? 'خالی' : 'ok'} | '
      'بدهی=${payload['money'] ?? ''}',
    );

    if (includeDocs) {
      await AsnafApiThrottle.instance.randomBetweenSteps();
      final docs = await _getJson(
        '$_base/docs/?parvaneh=$parvanehId&no_page=true',
        token,
        retryOn429: true,
      );
      final rawDocsList = _extractDocsList(docs);
      final normalizedDocs = _normalizeDocs(docs);
      final withLink = normalizedDocs
          .where((m) => _toStr(m['link_doc']).trim().isNotEmpty)
          .length;
      log(
        'stage=1_fetch_api | parvaneh=$parvanehId | api_list_len=${rawDocsList.length} | '
        'normalized_len=${normalizedDocs.length} | with_link_doc=$withLink | '
        'response=${_docsResponseShape(docs)}',
        name: 'asnaf_import_docs',
      );
      AsnafOpLog.line(
        AsnafOpLog.record,
        'مدارک id=$parvanehId | raw=${rawDocsList.length} normalized=${normalizedDocs.length} '
        'با_لینک=$withLink shape=${_docsResponseShape(docs)}',
      );
      payload['_docs_json'] = jsonEncode(normalizedDocs);
      payload['_raste_name'] = _toStr(detail['raste_info']?['isic']?['title']);
      payload['_raste_code'] = _toStr(detail['raste_info']?['isic']?['isic']);
    }

    if (geocodeIfMissing) {
      final lat = payload['lat_store']?.trim() ?? '';
      final lon = payload['long_store']?.trim() ?? '';
      if (lat.isEmpty || lon.isEmpty) {
        AsnafOpLog.line(AsnafOpLog.geo, 'مختصات خالی — ژئوکد id=$parvanehId');
        final geocoded = await AddressGeocodingService.instance.resolve(
          address: payload['address_store'] ?? '',
          state: payload['state_store'] ?? '',
          city: payload['city_store'] ?? '',
        );
        if (geocoded != null) {
          payload['lat_store'] = geocoded.$1;
          payload['long_store'] = geocoded.$2;
          AsnafOpLog.line(AsnafOpLog.geo, 'ژئوکد موفق id=$parvanehId');
        } else {
          AsnafOpLog.line(AsnafOpLog.geo, 'ژئوکد ناموفق id=$parvanehId');
        }
        await AddressGeocodingService.instance.pauseBetweenImports();
      } else {
        AsnafOpLog.line(AsnafOpLog.geo, 'مختصات از API موجود است id=$parvanehId');
      }
    }

    AsnafOpLog.line(
      AsnafOpLog.record,
      'پایان ساخت پیش‌نویس id=$parvanehId | ${sw.elapsedMilliseconds}ms',
    );
    return ImportDraftRecord(
      clientTempId: parvanehId,
      payload: payload.map((k, v) => MapEntry(k, v.toString())),
    );
  }

  Future<List<Map<String, String>>> fetchAllRaste(String token) async {
    final out = <Map<String, String>>[];
    for (var page = 1; page <= 200; page++) {
      final json = await _getJson(
        '$_base/raste/?page=$page&ordering=-created_at',
        token,
        retryOn429: true,
      );
      final rows = _extractResults(json);
      if (rows.isEmpty) break;
      for (final row in rows) {
        final m = row is Map ? row : const {};
        out.add({
          'title': _toStr(m['title']),
          'isic': _toStr(m['isic']),
        });
      }
      if (rows.length < 50) break;
      await Future<void>.delayed(AsnafFetchPace.current.pauseBetweenRastePages);
    }
    return out;
  }

  Future<(String, String)?> geocodeAddress(String address) async {
    final cleaned = _sanitizeAddressForGeocode(address);
    if (cleaned.isEmpty) return null;
    final key = _neshanApiKey;
    if (key.trim().isEmpty) return null;
    final uri = Uri.parse(
      'https://api.neshan.org/v6/geocoding?address=${Uri.encodeQueryComponent(cleaned)}',
    );

    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        final res = await http
            .get(uri, headers: {'Api-Key': key})
            .timeout(const Duration(seconds: 15));
        if (res.statusCode == 429 || res.statusCode == 503) {
          await Future<void>.delayed(Duration(milliseconds: 800 * (attempt + 1)));
          continue;
        }
        if (res.statusCode < 200 || res.statusCode >= 300) return null;
        final json = jsonDecode(res.body);
        if (json is! Map) return null;
        final lat = _toStr(json['location']?['y']);
        final lon = _toStr(json['location']?['x']);
        if (lat.isEmpty || lon.isEmpty) return null;
        return (lat, lon);
      } on TimeoutException {
        if (attempt == 2) return null;
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
    }
    return null;
  }

  /// همان منطق `sanitizeAddress` در `test_address_2.js` (بک‌اند).
  String _sanitizeAddressForGeocode(String address) {
    return address
        .replaceAll(RegExp(r'[^\w\sآ-یء-ئ،.۰-۹]', unicode: true), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static const _requestTimeout = Duration(seconds: 50);

  static bool _isRetryableNetwork(Object e) {
    if (e is TimeoutException) return true;
    if (e is SocketException) return true;
    if (e is http.ClientException) {
      final m = e.message.toLowerCase();
      return m.contains('timeout') ||
          m.contains('timed out') ||
          m.contains('connection') ||
          m.contains('socket');
    }
    return false;
  }

  Future<dynamic> _getJson(
    String url,
    String token, {
    bool retryOn429 = false,
  }) async {
    final short = AsnafOpLog.shortUrl(url);
    final viaWeb = webViewApi;
    if (viaWeb != null) {
      final sw = Stopwatch()..start();
      try {
        final json = await viaWeb.getJson(url, token);
        AsnafOpLog.line(
          AsnafOpLog.api,
          'OK via=webview $short | ${sw.elapsedMilliseconds}ms',
        );
        return json;
      } on AsnafApiAuthException catch (e) {
        AsnafOpLog.line(
          AsnafOpLog.api,
          'AUTH via=webview status=${e.statusCode} $short',
          error: e,
        );
        rethrow;
      } catch (e) {
        AsnafOpLog.line(
          AsnafOpLog.api,
          'webview شکست — HTTP کمکی زده نشد (پنل با JWT داخل XHR کار می‌کند؛ HTTP خارجی 401/429 می‌دهد)',
          error: e,
        );
        rethrow;
      }
    }

    final cookieHeader = await viaWeb?.collectCookieHeader() ?? '';
    var attempt = 0;
    var authScheme = 'JWT';
    while (true) {
      attempt++;
      try {
        await AsnafApiThrottle.instance.waitTurn();
        final sw = Stopwatch()..start();
        final res = await http
            .get(
              Uri.parse(url),
              headers: {
                'Authorization': '$authScheme $token',
                'Accept': 'application/json, text/plain, */*',
                'Accept-Language': 'fa-IR,fa;q=0.9,en;q=0.8',
                'Origin': 'https://iranianasnaf.ir',
                'Referer': 'https://iranianasnaf.ir/panel/',
                'User-Agent': AsnafJwtPolicy.browserUserAgent,
                if (cookieHeader.isNotEmpty) 'Cookie': cookieHeader,
              },
            )
            .timeout(_requestTimeout);
        if (res.statusCode >= 200 && res.statusCode < 300) {
          AsnafOpLog.line(
            AsnafOpLog.api,
            'OK via=http $short | status=${res.statusCode} bytes=${res.bodyBytes.length} '
            '| ${sw.elapsedMilliseconds}ms attempt=$attempt',
          );
          return jsonDecode(res.body);
        }
        AsnafOpLog.line(
          AsnafOpLog.api,
          'HTTP ${res.statusCode} $short | ${sw.elapsedMilliseconds}ms attempt=$attempt',
        );
        if (res.statusCode == 401 || res.statusCode == 403) {
          if (authScheme == 'JWT') {
            AsnafOpLog.line(AsnafOpLog.api, 'HTTP 401 با JWT — تلاش Bearer');
            authScheme = 'Bearer';
            continue;
          }
          throw AsnafApiAuthException(res.statusCode, url);
        }
        if (retryOn429 && res.statusCode == 429 && attempt < 6) {
          AsnafOpLog.line(AsnafOpLog.api, '429 — backoff attempt=$attempt $short');
          await AsnafApiThrottle.instance.backoff429(attempt);
          continue;
        }
        throw Exception('API error ${res.statusCode} for $url');
      } catch (e) {
        if (e is AsnafApiAuthException) rethrow;
        if (_isRetryableNetwork(e) && attempt < 4) {
          AsnafOpLog.line(
            AsnafOpLog.api,
            'retry شبکه attempt=$attempt $short | $e',
            error: e,
          );
          await AsnafApiThrottle.instance.backoffNetworkError(attempt);
          continue;
        }
        AsnafOpLog.line(AsnafOpLog.api, 'شکست نهایی $short | $e', error: e);
        rethrow;
      }
    }
  }

  List<dynamic> _extractResults(dynamic pageJson) {
    if (pageJson is List) return pageJson;
    if (pageJson is Map && pageJson['results'] is List) {
      return pageJson['results'] as List;
    }
    return const [];
  }

  /// پاسخ `GET .../docs/?parvaneh=...` گاهی آرایه است و گاهی شیء با `results` / `data` / ...
  String _docsResponseShape(dynamic docsJson) {
    if (docsJson is List) {
      return 'List(len=${docsJson.length})';
    }
    if (docsJson is Map) {
      final keys = docsJson.keys.map((k) => k.toString()).take(12).join(',');
      return 'Map(keys=[$keys])';
    }
    return docsJson.runtimeType.toString();
  }

  List<dynamic> _extractDocsList(dynamic docsJson) {
    if (docsJson is List) return docsJson;
    if (docsJson is Map) {
      const keys = ['results', 'data', 'docs', 'documents', 'items'];
      for (final k in keys) {
        final v = docsJson[k];
        if (v is List) return v;
      }
    }
    return const [];
  }

  /// لینک فایل سند در پاسخ‌های مختلف API (شیء `file` یا رشتهٔ مستقیم).
  String _docLinkFromAsnafRow(Map<dynamic, dynamic> m) {
    final f = m['file'];
    if (f is String && f.trim().isNotEmpty) return f.trim();
    if (f is Map) {
      for (final k in ['file', 'url', 'path', 'src']) {
        final v = _toStr(f[k]);
        if (v.isNotEmpty) return v;
      }
    }
    for (final k in ['link_doc', 'file_url', 'url', 'link', 'download_url', 'href']) {
      final v = _toStr(m[k]);
      if (v.isNotEmpty) return v;
    }
    return '';
  }

  String _docIdFromAsnafRow(Map<dynamic, dynamic> m) {
    final f = m['file'];
    if (f is Map) {
      final id = _toStr(f['id']);
      if (id.isNotEmpty) return id;
    }
    final id = _toStr(m['id']);
    if (id.isNotEmpty) return id;
    return _toStr(m['id_doc']);
  }

  List<Map<String, dynamic>> _normalizeDocs(dynamic docsJson) {
    final rawList = _extractDocsList(docsJson);
    return rawList.map<Map<String, dynamic>>((e) {
      final m = e is Map ? Map<dynamic, dynamic>.from(e) : const <dynamic, dynamic>{};
      return {
        'parvaneh': _toStr(m['parvaneh']),
        'user': _toStr(m['user']),
        'id_doc': _docIdFromAsnafRow(m),
        'link_doc': _docLinkFromAsnafRow(m),
      };
    }).toList();
  }

  Map<String, String> _mapParvandePayload(dynamic data, String codeCo) {
    final d = (data is Map) ? data : const {};
    final genderMap = {'m': 'آقا', 'f': 'خانم'};
    const educationMap = {
      '1': 'بی سواد',
      '2': 'خواندن ونوشتن',
      '3': 'پنجم ابتدایی',
      '5': 'سیکل',
      '6': 'دیپلم ردی',
      '7': 'دیپلم',
      '8': 'فوق دیپلم',
      '9': 'لیسانس',
      '10': 'فوق لیسانس',
      '11': 'دکتری عمومی',
    };
    const religionMap = {
      '1': 'وارد نشده',
      '2': 'اسلام - شیعه',
      '3': 'اسلام - سنی',
      '4': 'مسیحی',
      '8': 'سایر',
      '9': 'اسلام سایر',
    };
    const militaryMap = {
      'crd': 'دارای کارت پایان خدمت',
      'med': 'معافیت پزشکی',
      'edu': 'معافیت تحصیلی',
      'nic': 'غیرمشمول',
      'inc': 'مشمول خدمت',
      '1': 'معافیت دو برادری',
      '3': 'خرید خدمت',
      '6': 'معافیت کفالت',
      '7': 'معافیت رهبری',
      '9': 'معافیت موارد خاص',
      '11': 'معافیت سه برادری',
    };
    const maritalMap = {'mr': 'متأهل', 'sn': 'مجرد'};
    const ownershipMap = {
      '1': 'مالک',
      '2': 'استیجاری',
      '3': 'صلح نامه',
      '4': 'هبه',
      '5': 'قرارداد شراکت',
      '6': 'مبایعه نامه',
    };

    return {
      'id_parvandeh': _toStr(d['id']),
      'code_co': codeCo,
      'name_admin': _toStr(d['user']?['first_name']),
      'family_admin': _toStr(d['user']?['last_name']),
      'sex_admin': genderMap[_toStr(d['senf']?['user']?['gender'])] ?? '',
      'sadere_admin': _toStr(d['user']?['issue_city']?['title']),
      'tavalod_admin': _toStr(d['user']?['birth_date']),
      'name_pedar_admin': _toStr(d['user']?['father_name']),
      'num_shenasname_admin': _toStr(d['user']?['identity_number']),
      'code_meli_admin': _toStr(d['user']?['national_id']),
      'mob_admin': _toStr(d['user']?['mobile']),
      'tel_admin': _toStr(d['senf']?['phone']),
      'madrak_admin': educationMap[_toStr(d['senf']?['user']?['edu_degree'])] ?? '',
      'din_admin': religionMap[_toStr(d['senf']?['user']?['religion'])] ?? '',
      'sarbazi_admin': militaryMap[_toStr(d['senf']?['user']?['military_status'])] ?? '',
      'taahol_admin': maritalMap[_toStr(d['user']?['marital_status'])] ?? '',
      'name_store': _toStr(d['senf']?['title']),
      'shenase_store': _toStr(d['senf']?['senf_code']),
      'raste_store': _toStr(d['raste_info']?['isic']?['title']),
      'masahat_store': _toStr(d['senf']?['area']),
      'type_melki_store': ownershipMap[_toStr(d['senf']?['estate_type'])] ?? '',
      'address_store': _toStr(d['senf']?['address']).isNotEmpty
          ? _toStr(d['senf']?['address'])
          : _toStr(d['user']?['address']),
      'code_posti_store': _toStr(d['senf']?['postal_code']),
      'mantaghe_store': '',
      'lat_store': _toStr(d['senf']?['latitude']),
      'long_store': _toStr(d['senf']?['longitude']),
      'state_store': _toStr(d['senf']?['state']?['title']),
      'city_store': _toStr(d['senf']?['city']?['title']),
      'date_sodor_store': _toStr(d['start_at']),
      'date_exp_store': _toStr(d['expire_date']),
      'date_etebar_store': '',
      'daraje_store': _toStr(d['grade']),
      'num_parvande_store': _toStr(d['raste_info']?['parvaneh']),
      'vaziyat_store': _toStr(d['status']),
      'lbl_vaziyat_store': _toStr(d['status_display']),
      'num_person_store': '',
      'caption_parvande': _toStr(d['senf']?['loc_state']),
      'id_user': '1000',
      'act_parvande': '1',
      'image_profile': _toStr(d['user']?['avatar']?['file']),
      'image_parvaneh': _toStr(d['html_link']),
      'licence_file': _toStr(d['licence']?['file']),
      'money': _toStr(d['debt_amount']),
    };
  }

  int _toInt(dynamic v) => int.tryParse(_toStr(v)) ?? 0;
  String _toStr(dynamic v) => v?.toString() ?? '';
}
