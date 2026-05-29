/// یک ردیف حق عضویت (مطالبه / پرداخت) برای یک کد صنفی.
class HaghOzviatRow {
  const HaghOzviatRow({
    required this.shenaseStore,
    required this.onvan,
    required this.mablaghRial,
    required this.sal,
    required this.tarikhIjad,
    required this.noeEblagh,
    required this.vaziyat,
    required this.radeSanfi,
    required this.onvanRaste,
    this.sourceRowIndex,
  });

  final String shenaseStore;
  final String onvan;
  final int mablaghRial;
  final String sal;
  final String tarikhIjad;
  final String noeEblagh;
  final String vaziyat;
  final String radeSanfi;
  final String onvanRaste;
  final int? sourceRowIndex;

  bool get isPending => vaziyat.trim() == 'در انتظار پرداخت';

  bool get isConfirmed => vaziyat.trim() == 'تایید شده';

  Map<String, dynamic> toSyncJson() => {
        'shenase_store': shenaseStore,
        'onvan': onvan,
        'mablagh_rial': mablaghRial,
        'sal': sal,
        'tarikh_ijad': tarikhIjad,
        'noe_eblagh': noeEblagh,
        'vaziyat': vaziyat,
        'rade_sanfi': radeSanfi,
        'onvan_raste': onvanRaste,
      };

  factory HaghOzviatRow.fromServerJson(Map<String, dynamic> json) {
    return HaghOzviatRow(
      shenaseStore: json['shenase_store']?.toString() ?? '',
      onvan: json['onvan']?.toString() ?? '',
      mablaghRial: _parseInt(json['mablagh_rial']),
      sal: json['sal']?.toString() ?? '',
      tarikhIjad: json['tarikh_ijad']?.toString() ?? '',
      noeEblagh: json['noe_eblagh']?.toString() ?? '',
      vaziyat: json['vaziyat']?.toString() ?? '',
      radeSanfi: json['rade_sanfi']?.toString() ?? '',
      onvanRaste: json['onvan_raste']?.toString() ?? '',
    );
  }

  static int _parseInt(dynamic v) {
    if (v is int) return v;
    var s = v?.toString().trim() ?? '';
    s = s.replaceAll(',', '').replaceAll('،', '');
    return int.tryParse(s.split('.').first) ?? 0;
  }
}

class HaghOzviatAnalysis {
  const HaghOzviatAnalysis({
    required this.fileName,
    this.importSource = '',
    required this.rawRowsInFile,
    required this.totalRows,
    required this.uniqueMembers,
    required this.totalPendingRial,
    required this.totalConfirmedRial,
    required this.skippedEmptyShenase,
    required this.skippedDeleted,
    required this.filledFromPreviousShenase,
    required this.rowsWithExplicitShenase,
    required this.filledFromMelliInFile,
    required this.filledFromParvandeRegistry,
    required this.uniqueMelliInFile,
    required this.uniqueNamesInFile,
    required this.registryParvandeCount,
    this.detectedShenaseColumn,
    this.filledFromNameInFile = 0,
    this.filledFromScrape = 0,
    required this.rows,
  });

  final String fileName;
  /// csv | xls→csv | xls
  final String importSource;
  final int rawRowsInFile;
  final int totalRows;
  final int uniqueMembers;
  final int totalPendingRial;
  final int totalConfirmedRial;
  final int skippedEmptyShenase;
  final int skippedDeleted;
  /// ردیف‌هایی که کد صنفی از ردیف بالایی (همان کدملی / ادغام سلول) کپی شد.
  final int filledFromPreviousShenase;
  /// ردیف‌هایی که ستون «کد صنفی» در خودشان مقدار داشت.
  final int rowsWithExplicitShenase;
  /// از نگاشت کدملی→کد صنفی داخل همین فایل.
  final int filledFromMelliInFile;
  /// از پرونده‌های ثبت‌شده در برنامه (کدملی مدیر).
  final int filledFromParvandeRegistry;
  /// تعداد کدملی یکتا پس از پر کردن سلول‌های ادغام.
  final int uniqueMelliInFile;
  /// تعداد نام یکتا (نام + نام خانوادگی) پس از پر کردن ادغام.
  final int uniqueNamesInFile;
  /// تعداد پرونده در نگاشت اتحادیه (کدملی/نام → کد صنفی).
  final int registryParvandeCount;
  /// ستونی که بیشترین کد صنفی یکتا را داشت.
  final String? detectedShenaseColumn;
  final int filledFromNameInFile;
  final int filledFromScrape;
  final List<HaghOzviatRow> rows;

  bool get likelyUnderParsed =>
      importSource == 'csv'
          ? uniqueMembers < 200 && rawRowsInFile > 500
          : uniqueMembers < 100 &&
              rawRowsInFile > 500 &&
              rowsWithExplicitShenase < rawRowsInFile ~/ 4;

  int get skippedRows => skippedEmptyShenase + skippedDeleted;

  bool get isHealthy => totalRows > 0 && uniqueMembers > 0;
}

class HaghOzviatSyncProgress {
  const HaghOzviatSyncProgress({
    required this.message,
    required this.current,
    required this.total,
  });

  final String message;
  final int current;
  final int total;
}

class HaghOzviatSyncResult {
  const HaghOzviatSyncResult({
    required this.membersReplaced,
    required this.rowsInserted,
    required this.errors,
  });

  final int membersReplaced;
  final int rowsInserted;
  final List<String> errors;

  bool get ok => errors.isEmpty;
}

class HaghOzviatMemberSummary {
  const HaghOzviatMemberSummary({
    required this.rows,
    required this.pendingRial,
    required this.confirmedRial,
  });

  final List<HaghOzviatRow> rows;
  final int pendingRial;
  final int confirmedRial;

  int get totalRial => pendingRial + confirmedRial;
}
