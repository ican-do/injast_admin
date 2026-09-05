import 'package:injast_admin/file_management/excel_import/excel_import_columns.dart';

/// یک فیلد جدول پرونده که ممکن است از هدر CSV شناخته شود.
class CsvTableField {
  const CsvTableField({
    required this.canonical,
    required this.dbField,
    required this.labelFa,
    required this.aliases,
    this.sensitive = false,
  });

  /// کلید استاندارد داخل ردیف‌های ایمپورت (همان ExcelImportColumns.*)
  final String canonical;
  final String dbField;
  final String labelFa;
  final List<String> aliases;
  final bool sensitive;
}

class CsvHeaderBinding {
  const CsvHeaderBinding({
    required this.columnIndex,
    required this.rawHeader,
    required this.field,
    required this.score,
  });

  final int columnIndex;
  final String rawHeader;
  final CsvTableField field;
  final int score;
}

class CsvHeaderMatchReport {
  const CsvHeaderMatchReport({
    required this.rawHeaders,
    required this.bindings,
    required this.unmappedHeaders,
    required this.missingSensitive,
    required this.matchPercent,
    required this.canProceed,
    required this.summary,
  });

  final List<String> rawHeaders;
  final List<CsvHeaderBinding> bindings;
  final List<String> unmappedHeaders;
  final List<String> missingSensitive;
  final int matchPercent;
  final bool canProceed;
  final String summary;

  static const empty = CsvHeaderMatchReport(
    rawHeaders: [],
    bindings: [],
    unmappedHeaders: [],
    missingSensitive: [],
    matchPercent: 0,
    canProceed: false,
    summary: 'هدری برای بررسی وجود ندارد.',
  );

  CsvTableField? fieldForCanonical(String canonical) {
    for (final b in bindings) {
      if (b.field.canonical == canonical) return b.field;
    }
    return null;
  }
}

/// تطبیق هدر فایل با فیلدهای tbl_parvande — مستقل از ترتیب ستون‌ها.
class CsvHeaderMapper {
  CsvHeaderMapper._();

  static const fields = <CsvTableField>[
    CsvTableField(
      canonical: ExcelImportColumns.shenase,
      dbField: 'shenase_store',
      labelFa: 'کد / شناسه صنفی',
      sensitive: true,
      aliases: [
        'کد صنفی',
        'کدصنفی',
        'شناسه صنفی',
        'شناصه صنفی',
        'شناسه',
        'shenase',
        'code senfi',
      ],
    ),
    CsvTableField(
      canonical: ExcelImportColumns.status,
      dbField: 'lbl_vaziyat_store',
      labelFa: 'وضعیت پرونده',
      sensitive: true,
      aliases: [
        'وضعیت',
        'وضعیت پرونده',
        'وضعیت پروانه',
        'status',
      ],
    ),
    CsvTableField(
      canonical: ExcelImportColumns.issueDate,
      dbField: 'date_sodor_store',
      labelFa: 'تاریخ صدور',
      sensitive: true,
      aliases: [
        'تاریخ صدور',
        'تاريخ صدور',
        'صدور',
        'تاریخ صدور پروانه',
        'issue date',
      ],
    ),
    CsvTableField(
      canonical: ExcelImportColumns.firstName,
      dbField: 'name_admin',
      labelFa: 'نام',
      aliases: ['نام', 'نام عضو', 'name'],
    ),
    CsvTableField(
      canonical: ExcelImportColumns.lastName,
      dbField: 'family_admin',
      labelFa: 'نام خانوادگی',
      aliases: ['نام خانوادگی', 'نام خانوادگي', 'فامیلی', 'family'],
    ),
    CsvTableField(
      canonical: ExcelImportColumns.storeTitle,
      dbField: 'name_store',
      labelFa: 'نام واحد / عنوان تابلو',
      aliases: [
        'عنوان تابلو',
        'نام واحد صنفی',
        'نام واحد',
        'نام فروشگاه',
        'عنوان واحد',
      ],
    ),
    CsvTableField(
      canonical: ExcelImportColumns.address,
      dbField: 'address_store',
      labelFa: 'آدرس',
      aliases: ['آدرس', 'نشانی', 'نشاني', 'address'],
    ),
    CsvTableField(
      canonical: ExcelImportColumns.nationalId,
      dbField: 'code_meli_admin',
      labelFa: 'کد ملی',
      aliases: ['کدملی', 'کد ملی', 'کد ملي'],
    ),
    CsvTableField(
      canonical: ExcelImportColumns.mobile,
      dbField: 'mob_admin',
      labelFa: 'موبایل',
      aliases: ['موبایل', 'همراه', 'تلفن همراه', 'شماره همراه', 'mobile'],
    ),
    CsvTableField(
      canonical: ExcelImportColumns.phone,
      dbField: 'tel_admin',
      labelFa: 'تلفن',
      aliases: ['تلفن', 'تلفن ثابت', 'تلفن محل کار'],
    ),
    CsvTableField(
      canonical: ExcelImportColumns.raste,
      dbField: 'raste_store',
      labelFa: 'رسته',
      aliases: ['عنوان رسته', 'رسته', 'رسته صنفی'],
    ),
    CsvTableField(
      canonical: ExcelImportColumns.state,
      dbField: 'state_store',
      labelFa: 'استان',
      aliases: ['استان'],
    ),
    CsvTableField(
      canonical: ExcelImportColumns.city,
      dbField: 'city_store',
      labelFa: 'شهر',
      aliases: ['شهر', 'شهرستان'],
    ),
    CsvTableField(
      canonical: ExcelImportColumns.postalCode,
      dbField: 'code_posti_store',
      labelFa: 'کد پستی',
      aliases: ['کدپستی', 'کد پستی'],
    ),
    CsvTableField(
      canonical: ExcelImportColumns.fatherName,
      dbField: 'name_pedar_admin',
      labelFa: 'نام پدر',
      aliases: ['نام پدر'],
    ),
    CsvTableField(
      canonical: ExcelImportColumns.gender,
      dbField: 'sex_admin',
      labelFa: 'جنسیت',
      aliases: ['جنسیت'],
    ),
    CsvTableField(
      canonical: ExcelImportColumns.birthDate,
      dbField: 'tavalod_admin',
      labelFa: 'تاریخ تولد',
      aliases: ['تاریخ تولد', 'تولد'],
    ),
    CsvTableField(
      canonical: ExcelImportColumns.education,
      dbField: 'madrak_admin',
      labelFa: 'مدرک تحصیلی',
      aliases: ['سطح تحصیلات', 'مدرک تحصیلی', 'تحصیلات'],
    ),
    CsvTableField(
      canonical: ExcelImportColumns.religion,
      dbField: 'din_admin',
      labelFa: 'دین / مذهب',
      aliases: ['مذهب', 'دین'],
    ),
    CsvTableField(
      canonical: ExcelImportColumns.ownership,
      dbField: 'type_melki_store',
      labelFa: 'نوع مالکیت',
      aliases: ['نوع مالکیت', 'مالکیت'],
    ),
    CsvTableField(
      canonical: ExcelImportColumns.validity,
      dbField: 'date_etebar_store',
      labelFa: 'اعتبار',
      aliases: ['اعتبار', 'مدت اعتبار'],
    ),
    CsvTableField(
      canonical: ExcelImportColumns.expiryDate,
      dbField: 'date_exp_store',
      labelFa: 'تاریخ انقضا',
      aliases: ['تاریخ انقضا', 'انقضا', 'تاریخ انقضاء'],
    ),
    CsvTableField(
      canonical: ExcelImportColumns.trackingNovin,
      dbField: 'num_parvande_store',
      labelFa: 'شماره پرونده / کد رهگیری',
      aliases: [
        'کدرهگیری نوین',
        'کد رهگیری',
        'شماره پرونده',
        'کد رهگیری نوین',
      ],
    ),
    CsvTableField(
      canonical: ExcelImportColumns.lat,
      dbField: 'lat_store',
      labelFa: 'عرض جغرافیایی',
      aliases: ['عرض جغرافیایی', 'عرض جغرافيايي', 'lat', 'latitude'],
    ),
    CsvTableField(
      canonical: ExcelImportColumns.lng,
      dbField: 'long_store',
      labelFa: 'طول جغرافیایی',
      aliases: ['طول جغرافیایی', 'طول جغرافيايي', 'long', 'lng', 'longitude'],
    ),
    CsvTableField(
      canonical: ExcelImportColumns.district,
      dbField: 'mantaghe_store',
      labelFa: 'منطقه',
      aliases: ['منطقه', 'منطقه شهرداری'],
    ),
    CsvTableField(
      canonical: ExcelImportColumns.area,
      dbField: 'masahat_store',
      labelFa: 'مساحت',
      aliases: ['مساحت'],
    ),
    CsvTableField(
      canonical: ExcelImportColumns.source,
      dbField: 'caption_parvande',
      labelFa: 'توضیحات / مبدأ',
      aliases: ['مبدا', 'مبدأ', 'توضیحات', 'توضیح'],
    ),
  ];

  static CsvHeaderMatchReport analyze(List<String> rawHeaders) {
    final usedFields = <String>{};
    final bindings = <CsvHeaderBinding>[];
    final unmapped = <String>[];

    for (var i = 0; i < rawHeaders.length; i++) {
      final raw = rawHeaders[i].trim();
      if (raw.isEmpty) continue;
      final hit = _bestField(raw, usedFields);
      if (hit == null) {
        unmapped.add(raw);
        continue;
      }
      usedFields.add(hit.field.canonical);
      bindings.add(
        CsvHeaderBinding(
          columnIndex: i,
          rawHeader: raw,
          field: hit.field,
          score: hit.score,
        ),
      );
    }

    bindings.sort((a, b) => a.columnIndex.compareTo(b.columnIndex));

    final namedHeaders = rawHeaders.where((h) => h.trim().isNotEmpty).length;
    final matchPercent = namedHeaders == 0
        ? 0
        : ((bindings.length / namedHeaders) * 100).round();

    final missingSensitive = fields
        .where((f) => f.sensitive)
        .where((f) => !usedFields.contains(f.canonical))
        .map((f) => f.labelFa)
        .toList();

    final canProceed = missingSensitive.isEmpty && bindings.length >= 3;
    final summary = missingSensitive.isEmpty
        ? 'هدر فایل $matchPercent٪ با جدول پرونده منطبق است. ستون‌های حساس کامل‌اند.'
        : 'هدر فایل $matchPercent٪ منطبق است، اما ستون حساس نیست: ${missingSensitive.join('، ')}';

    return CsvHeaderMatchReport(
      rawHeaders: rawHeaders,
      bindings: bindings,
      unmappedHeaders: unmapped,
      missingSensitive: missingSensitive,
      matchPercent: matchPercent,
      canProceed: canProceed,
      summary: summary,
    );
  }

  /// تبدیل سلول‌های یک ردیف به کلیدهای استاندارد (canonical).
  static Map<String, String> remapValues({
    required List<String> rawHeaders,
    required List<String> cells,
    required CsvHeaderMatchReport report,
  }) {
    final out = <String, String>{};
    for (final b in report.bindings) {
      final value = b.columnIndex < cells.length ? cells[b.columnIndex].trim() : '';
      out[b.field.canonical] = value;
    }
    return out;
  }

  static ({CsvTableField field, int score})? _bestField(
    String raw,
    Set<String> usedFields,
  ) {
    final compact = _compact(raw);
    if (compact.isEmpty) return null;

    ({CsvTableField field, int score})? best;
    for (final field in fields) {
      if (usedFields.contains(field.canonical)) continue;
      var score = 0;
      for (final alias in field.aliases) {
        final a = _compact(alias);
        if (a.isEmpty) continue;
        if (compact == a) {
          score = 100;
          break;
        }
        if (compact.contains(a) && a.length >= 3) {
          score = score < 82 ? 82 : score;
        } else if (a.contains(compact) && compact.length >= 4) {
          score = score < 74 ? 74 : score;
        }
      }
      if (score < 74) continue;
      if (best == null || score > best.score) {
        best = (field: field, score: score);
      }
    }
    return best;
  }

  static String _compact(String raw) {
    return ExcelImportColumns.normalizeHeader(raw)
        .replaceAll(' ', '')
        .replaceAll('_', '')
        .replaceAll('-', '')
        .toLowerCase();
  }
}
