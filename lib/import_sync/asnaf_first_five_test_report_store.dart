import 'dart:convert';

import 'package:injast_admin/import_sync/import_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// تعداد اسناد ذخیره‌شده در payload پس از [buildDraftRecord].
int asnafCountDocsInPayload(Map<String, String> payload) {
  final raw = payload['_docs_json'] ?? '';
  if (raw.isEmpty) return 0;
  try {
    final d = jsonDecode(raw);
    if (d is List) return d.length;
    return 0;
  } catch (_) {
    return 0;
  }
}

class AsnafFirstFiveTestEntry {
  AsnafFirstFiveTestEntry({
    required this.parvanehId,
    required this.ok,
    this.error,
    this.nameAdmin,
    this.familyAdmin,
    this.nameStore,
    this.addressStore,
    this.latStore,
    this.longStore,
    this.documentsCount = 0,
    this.rasteName,
    this.rasteCode,
    this.neshanKeyConfigured,
    this.skippedDebtOnly = false,
  });

  final String parvanehId;
  final bool ok;
  final String? error;
  final String? nameAdmin;
  final String? familyAdmin;
  final String? nameStore;
  final String? addressStore;
  final String? latStore;
  final String? longStore;
  final int documentsCount;
  final String? rasteName;
  final String? rasteCode;
  /// آیا هنگام این اجرا، کلید نشان در کلاینت Flutter پیکربندی بوده است (`dart-define`).
  final bool? neshanKeyConfigured;
  /// رد به‌خاطر بدهی صفر (تست بدهی).
  final bool skippedDebtOnly;

  factory AsnafFirstFiveTestEntry.fromSuccess(
    ImportDraftRecord record, {
    required bool neshanKeyConfigured,
  }) {
    final p = record.payload;
    return AsnafFirstFiveTestEntry(
      parvanehId: record.clientTempId,
      ok: true,
      nameAdmin: p['name_admin'],
      familyAdmin: p['family_admin'],
      nameStore: p['name_store'],
      addressStore: p['address_store'],
      latStore: p['lat_store'],
      longStore: p['long_store'],
      documentsCount: asnafCountDocsInPayload(p),
      rasteName: p['_raste_name'],
      rasteCode: p['_raste_code'],
      neshanKeyConfigured: neshanKeyConfigured,
    );
  }

  factory AsnafFirstFiveTestEntry.failure(String parvanehId, Object error) {
    return AsnafFirstFiveTestEntry(
      parvanehId: parvanehId,
      ok: false,
      error: error.toString(),
    );
  }

  /// رد در تست بدهی — بدهی صفر یا نامشخص.
  factory AsnafFirstFiveTestEntry.skippedDebtZero(String parvanehId) {
    return AsnafFirstFiveTestEntry(
      parvanehId: parvanehId,
      ok: true,
      skippedDebtOnly: true,
    );
  }

  Map<String, dynamic> toJson() => {
        'parvaneh_id': parvanehId,
        'ok': ok,
        if (error != null) 'error': error,
        'skipped_debt_only': skippedDebtOnly,
        if (nameAdmin != null) 'name_admin': nameAdmin,
        if (familyAdmin != null) 'family_admin': familyAdmin,
        if (nameStore != null) 'name_store': nameStore,
        if (addressStore != null) 'address_store': addressStore,
        if (latStore != null) 'lat_store': latStore,
        if (longStore != null) 'long_store': longStore,
        'documents_count': documentsCount,
        if (rasteName != null) 'raste_name': rasteName,
        if (rasteCode != null) 'raste_code': rasteCode,
        if (neshanKeyConfigured != null) 'neshan_key_configured': neshanKeyConfigured,
      };

  factory AsnafFirstFiveTestEntry.fromJson(Map<String, dynamic> json) {
    int toInt(dynamic v) => int.tryParse(v?.toString() ?? '') ?? 0;
    return AsnafFirstFiveTestEntry(
      parvanehId: json['parvaneh_id']?.toString() ?? '',
      ok: json['ok'] == true,
      error: json['error']?.toString(),
      nameAdmin: json['name_admin']?.toString(),
      familyAdmin: json['family_admin']?.toString(),
      nameStore: json['name_store']?.toString(),
      addressStore: json['address_store']?.toString(),
      latStore: json['lat_store']?.toString(),
      longStore: json['long_store']?.toString(),
      documentsCount: toInt(json['documents_count']),
      rasteName: json['raste_name']?.toString(),
      rasteCode: json['raste_code']?.toString(),
      neshanKeyConfigured: json.containsKey('neshan_key_configured')
          ? json['neshan_key_configured'] == true
          : null,
      skippedDebtOnly: json['skipped_debt_only'] == true,
    );
  }

  String get adminFullName {
    final s = '${nameAdmin ?? ''} ${familyAdmin ?? ''}'.trim();
    return s.isEmpty ? '—' : s;
  }

  String get coordsLine {
    final la = latStore?.trim() ?? '';
    final lo = longStore?.trim() ?? '';
    if (la.isNotEmpty && lo.isNotEmpty) return '$la ، $lo';
    return '—';
  }

  String get coordsStatus {
    final la = latStore?.trim() ?? '';
    final lo = longStore?.trim() ?? '';
    if (la.isNotEmpty && lo.isNotEmpty) {
      return 'مختصات پر است (از API اسناف و/یا پس از فراخوانی نشان).';
    }
    final addr = addressStore?.trim() ?? '';
    if (addr.isEmpty) {
      return 'بدون آدرس؛ ژئوکد سمت کلاینت اجرا نشد.';
    }
    if (neshanKeyConfigured == false) {
      return 'کلید API نشان در این اپ Flutter ست نشده؛ ژئوکد سمت دستگاه اصلاً صدا زده نمی‌شود. '
          'برای فعال‌سازی: flutter run --dart-define=NESHAN_API_KEY=کلید_سرویس_نشان '
          '(یا معادل در فایل launch). در معماری مستند بک‌اند، تکمیل مختصات معمولاً پس از سینک '
          'روی سرور با updateCoordinates / api.neshan.org انجام می‌شود، نه الزاماً داخل این اپ.';
    }
    if (neshanKeyConfigured == true) {
      return 'کلید نشان در کلاینت تنظیم بود اما برای این آدرس مختصات خالی ماند '
          '(پاسخ نامعتبر، محدودیت سرویس، یا آدرس قابل‌ژئوکد نبود).';
    }
    return 'با وجود آدرس، مختصات خالی است (گزارش قدیمی: وضعیت کلید نشان ثبت نشده بود).';
  }

  String get rasteLine {
    final t = rasteName?.trim() ?? '';
    final c = rasteCode?.trim() ?? '';
    if (t.isEmpty && c.isEmpty) return '—';
    if (t.isEmpty) return c;
    if (c.isEmpty) return t;
    return '$t ($c)';
  }
}

class AsnafFirstFiveTestReport {
  AsnafFirstFiveTestReport({
    required this.savedAtMs,
    required this.metaTotalCount,
    required this.metaTotalPages,
    required this.codeCo,
    required this.unionName,
    required this.targetPlanned,
    required this.dossierSlotsFilled,
    required this.entries,
    this.fatalError,
    this.neshanKeyConfiguredWhenRun,
    this.debtTestMode = false,
  });

  final int savedAtMs;
  final int metaTotalCount;
  final int metaTotalPages;
  final String codeCo;
  final String unionName;
  final int targetPlanned;
  /// چند جایگاه پرونده (شناسهٔ معتبر) واقعاً در این اجرا پیمایش شد.
  final int dossierSlotsFilled;
  final List<AsnafFirstFiveTestEntry> entries;
  final String? fatalError;
  /// آیا در لحظهٔ این اجرا، `NESHAN_API_KEY` در کلاینت Flutter (dart-define) تنظیم بوده است.
  final bool? neshanKeyConfiguredWhenRun;
  /// تست ۵ پروندهٔ اول با فیلتر بدهی (بدون اسناد/ژئوکد).
  final bool debtTestMode;

  int get successCount => entries.where((e) => e.ok && !e.skippedDebtOnly).length;
  int get failCount => entries.where((e) => !e.ok).length;
  int get skippedDebtZeroCount => entries.where((e) => e.skippedDebtOnly).length;

  Map<String, dynamic> toJson() => {
        'saved_at_ms': savedAtMs,
        'meta_total_count': metaTotalCount,
        'meta_total_pages': metaTotalPages,
        'code_co': codeCo,
        'union_name': unionName,
        'target_planned': targetPlanned,
        'dossier_slots_filled': dossierSlotsFilled,
        'entries': entries.map((e) => e.toJson()).toList(),
        if (fatalError != null) 'fatal_error': fatalError,
        if (neshanKeyConfiguredWhenRun != null) 'neshan_key_configured_when_run': neshanKeyConfiguredWhenRun,
        'debt_test_mode': debtTestMode,
      };

  factory AsnafFirstFiveTestReport.fromJson(Map<String, dynamic> json) {
    int toInt(dynamic v) => int.tryParse(v?.toString() ?? '') ?? 0;
    final rawEntries = json['entries'];
    final list = rawEntries is List
        ? rawEntries
            .whereType<Map>()
            .map((e) => AsnafFirstFiveTestEntry.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : <AsnafFirstFiveTestEntry>[];
    return AsnafFirstFiveTestReport(
      savedAtMs: toInt(json['saved_at_ms']),
      metaTotalCount: toInt(json['meta_total_count']),
      metaTotalPages: toInt(json['meta_total_pages']),
      codeCo: json['code_co']?.toString() ?? '',
      unionName: json['union_name']?.toString() ?? '',
      targetPlanned: toInt(json['target_planned']),
      dossierSlotsFilled: toInt(json['dossier_slots_filled']),
      entries: list,
      fatalError: json['fatal_error']?.toString(),
      neshanKeyConfiguredWhenRun: json.containsKey('neshan_key_configured_when_run')
          ? json['neshan_key_configured_when_run'] == true
          : null,
      debtTestMode: json['debt_test_mode'] == true,
    );
  }
}

class AsnafFirstFiveTestReportStore {
  static const _kKey = 'asnaf_first_five_test_report_v1';

  Future<void> save(AsnafFirstFiveTestReport report) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kKey, jsonEncode(report.toJson()));
  }

  Future<AsnafFirstFiveTestReport?> read() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kKey);
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return AsnafFirstFiveTestReport.fromJson(Map<String, dynamic>.from(decoded));
    } catch (_) {
      return null;
    }
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kKey);
  }

  Future<bool> hasReport() async => (await read()) != null;
}
