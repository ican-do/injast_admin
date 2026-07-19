import 'dart:convert';
import 'dart:developer' show log;

import 'package:flutter/foundation.dart';
import 'package:injast_admin/file_management/excel_import/excel_import_columns.dart';
import 'package:injast_admin/file_management/excel_import/excel_import_models.dart';
import 'package:injast_admin/file_management/excel_import/csv_import_dedupe.dart';
import 'package:injast_admin/file_management/excel_import/csv_import_labels.dart';
import 'package:injast_admin/file_management/excel_import/csv_parvande_dates.dart';
import 'package:injast_admin/file_management/excel_import/excel_import_shenase.dart';
import 'package:injast_admin/file_management/excel_import/excel_import_parser.dart'
    as xls_parser;

export 'package:injast_admin/file_management/excel_import/excel_import_models.dart';
import 'package:injast_admin/file_management/jalali_date_util.dart';
import 'package:injast_admin/file_management/parvande_api.dart';
import 'package:injast_admin/file_management/parvande_vaziyat.dart';
import 'package:injast_admin/file_management/address_geocoding_service.dart';
import 'package:injast_admin/import_sync/import_models.dart';
import 'package:injast_admin/local_cache/parvande_server_send.dart';
const _logName = 'excel_import';
const _testLogName = 'csv_import_test';
const _updateLogName = 'csv_import_update';

void _updLog(String message) {
  log(message, name: _updateLogName);
  debugPrint('[$_updateLogName] $message');
}

class ExcelImportAnalysis {
  const ExcelImportAnalysis({
    required this.fileName,
    required this.fileFormat,
    required this.totalRows,
    required this.columnCount,
    required this.headers,
    required this.missingRequiredColumns,
    required this.unknownColumns,
    required this.isHealthy,
    required this.healthMessage,
    required this.duplicateInFileCount,
    required this.insertOnServerCount,
    required this.updateOnServerCount,
    required this.importableCount,
    required this.sampleIssues,
    required this.rows,
    required this.importableRows,
    required this.insertableRows,
    required this.updatableRows,
    required this.serverByShenase,
  });

  final String fileName;
  final xls_parser.ImportFileFormat fileFormat;
  final int totalRows;
  final int columnCount;
  final List<String> headers;
  final List<String> missingRequiredColumns;
  final List<String> unknownColumns;
  final bool isHealthy;
  final String healthMessage;
  /// ردیف‌های حذف‌شده از فایل پس از قوانین تکراری کد صنفی.
  final int duplicateInFileCount;
  final int insertOnServerCount;
  final int updateOnServerCount;
  final int importableCount;
  final List<String> sampleIssues;
  final List<ExcelParsedRow> rows;
  final List<ExcelParsedRow> importableRows;
  final List<ExcelParsedRow> insertableRows;
  final List<ExcelParsedRow> updatableRows;
  final Map<String, Map<String, dynamic>> serverByShenase;

  Set<String> get serverShenaseSet => serverByShenase.keys.toSet();

  /// سازگاری با UI قدیمی که «تکراری با سرور» می‌خواند — اکنون یعنی به‌روزرسانی.
  int get duplicateOnServerCount => updateOnServerCount;
}

class ExcelImportRunProgress {
  const ExcelImportRunProgress({
    required this.message,
    this.current = 0,
    this.total = 0,
    this.phase = 'prepare',
  });

  final String message;
  final int current;
  final int total;
  final String phase;

  double? get fraction =>
      total <= 0 ? null : (current / total).clamp(0.0, 1.0);
}

class ExcelImportRunResult {
  const ExcelImportRunResult({
    required this.sentCount,
    required this.finalize,
    required this.updatedCount,
    required this.updateFailures,
    required this.geocodeFailures,
    required this.stoppedEarly,
  });

  final int sentCount;
  final ImportFinalizeResult finalize;
  final int updatedCount;
  final int updateFailures;
  final int geocodeFailures;
  final bool stoppedEarly;
}

class ExcelImportService {
  ExcelImportService(this.codeCo);

  final String codeCo;
  final _parvandeApi = ParvandeApi.instance;
  final _geocoder = AddressGeocodingService.instance;

  Future<List<ExcelParsedRow>> parseFileBytes(
    Uint8List bytes, {
    String? fileName,
  }) =>
      xls_parser.parseImportFileBytes(bytes, fileName: fileName);

  @Deprecated('Use parseFileBytes')
  Future<List<ExcelParsedRow>> parseWorkbookBytes(Uint8List bytes) =>
      parseFileBytes(bytes);

  Future<ExcelImportAnalysis> analyze({
    required String fileName,
    required Uint8List fileBytes,
    required List<ExcelParsedRow> rows,
    void Function(String message)? onProgress,
  }) async {
    final fileFormat = xls_parser.detectImportFormat(fileBytes, fileName: fileName);
    onProgress?.call('در حال خواندن ساختار فایل...');
    if (rows.isEmpty) {
      return ExcelImportAnalysis(
        fileName: fileName,
        fileFormat: fileFormat,
        totalRows: 0,
        columnCount: 0,
        headers: const [],
        missingRequiredColumns: List.from(ExcelImportColumns.requiredForRegistration),
        unknownColumns: const [],
        isHealthy: false,
        healthMessage: 'هیچ ردیف داده‌ای در فایل یافت نشد.',
        duplicateInFileCount: 0,
        insertOnServerCount: 0,
        updateOnServerCount: 0,
        importableCount: 0,
        sampleIssues: const ['فایل فاقد ردیف داده است.'],
        rows: const [],
        importableRows: const [],
        insertableRows: const [],
        updatableRows: const [],
        serverByShenase: const {},
      );
    }

    final headers = rows.first.values.keys.toList();
    final normalizedHeaders = headers.map(ExcelImportColumns.normalizeHeader).toSet();
    final missingRequired = ExcelImportColumns.requiredForRegistration
        .where((col) => !normalizedHeaders.contains(col))
        .toList();

    final unknownColumns = headers
        .where((h) {
          if (h.isEmpty) return false;
          return ExcelImportColumns.canonicalColumn(h) == null;
        })
        .toList();

    log(
      'analyze | format=$fileFormat | rows=${rows.length} | '
      'missing=$missingRequired | unknown=${unknownColumns.length}',
      name: _logName,
    );

    onProgress?.call('مرتب‌سازی و حذف تکراری‌های کد صنفی...');
    final dedupe = CsvImportDedupe.apply(rows);
    final dedupedRows = dedupe.kept;

    onProgress?.call('در حال دریافت لیست کدهای صنفی موجود روی سرور...');
    final serverByShenase = await _loadServerByShenase();

    final insertable = <ExcelParsedRow>[];
    final updatable = <ExcelParsedRow>[];
    final issues = <String>[];

    for (final row in dedupedRows) {
      final shenase = _shenaseFromRow(row);
      if (shenase.isEmpty) {
        if (issues.length < 8) {
          issues.add('ردیف ${row.rowIndex}: کد صنفی خالی است.');
        }
        continue;
      }

      final rowIssues = _validateRow(row);
      if (rowIssues.isNotEmpty) {
        if (issues.length < 8) {
          issues.add('ردیف ${row.rowIndex}: ${rowIssues.join('؛ ')}');
        }
        continue;
      }

      if (serverByShenase.containsKey(shenase)) {
        updatable.add(row);
      } else {
        insertable.add(row);
      }
    }

    final importable = [...insertable, ...updatable];
    final isHealthy = missingRequired.isEmpty && importable.isNotEmpty;
    final healthMessage = _buildHealthMessage(
      missingRequired: missingRequired,
      insertCount: insertable.length,
      updateCount: updatable.length,
      removedDuplicates: dedupe.removedCount,
      totalRows: rows.length,
    );

    log(
      'analyze done | importable=${importable.length} '
      '(insert=${insertable.length} update=${updatable.length}) | '
      'dupFile=${dedupe.removedCount} | healthy=$isHealthy',
      name: _logName,
    );

    _updLog(
      'ANALYZE | file=$fileName | rawRows=${rows.length} | '
      'afterDedupe=${dedupedRows.length} | removedDup=${dedupe.removedCount} | '
      'serverShenase=${serverByShenase.length} | '
      'insert=${insertable.length} | update=${updatable.length} | '
      'issues=${issues.length} | missingCols=$missingRequired',
    );
    _updLog('ANALYZE headers: ${headers.take(20).join(' | ')}');
    for (final row in updatable.take(8)) {
      final s = _shenaseFromRow(row);
      final server = serverByShenase[s];
      _updLog(
        'ANALYZE update-candidate csvRow=${row.rowIndex} | shenase=$s | '
        'csvStatus="${_cell(row.values, ExcelImportColumns.status)}" | '
        'csvIssueDate="${_cell(row.values, ExcelImportColumns.issueDate)}" | '
        'serverStatus="${server?['lbl_vaziyat_store']}"/'
        '"${server?['vaziyat_store']}" | '
        'serverIssueDate="${server?['date_sodor_store']}" | '
        'serverId="${server?['id_parvandeh']}"',
      );
    }
    for (final row in insertable.take(5)) {
      _updLog(
        'ANALYZE insert-candidate csvRow=${row.rowIndex} | '
        'shenase=${_shenaseFromRow(row)} | '
        'csvStatus="${_cell(row.values, ExcelImportColumns.status)}" | '
        'csvIssueDate="${_cell(row.values, ExcelImportColumns.issueDate)}"',
      );
    }
    if (issues.isNotEmpty) {
      _updLog('ANALYZE sampleIssues: ${issues.join(' || ')}');
    }

    return ExcelImportAnalysis(
      fileName: fileName,
      fileFormat: fileFormat,
      totalRows: rows.length,
      columnCount: headers.length,
      headers: headers,
      missingRequiredColumns: missingRequired,
      unknownColumns: unknownColumns,
      isHealthy: isHealthy,
      healthMessage: healthMessage,
      duplicateInFileCount: dedupe.removedCount,
      insertOnServerCount: insertable.length,
      updateOnServerCount: updatable.length,
      importableCount: importable.length,
      sampleIssues: issues,
      rows: rows,
      importableRows: importable,
      insertableRows: insertable,
      updatableRows: updatable,
      serverByShenase: serverByShenase,
    );
  }

  Future<ExcelImportRunResult> runImport({
    required List<ExcelParsedRow> rows,
    Map<String, Map<String, dynamic>> serverByShenase = const {},
    void Function(ExcelImportRunProgress progress)? onProgress,
    bool Function()? shouldStop,
    bool verboseTestLog = false,
  }) async {
    if (rows.isEmpty) {
      throw Exception('پرونده‌ای برای ثبت باقی نمانده است.');
    }

    final toInsert = <ExcelParsedRow>[];
    final toUpdate = <ExcelParsedRow>[];
    for (final row in rows) {
      final shenase = _shenaseFromRow(row);
      if (serverByShenase.containsKey(shenase)) {
        toUpdate.add(row);
      } else {
        toInsert.add(row);
      }
    }

    if (verboseTestLog) {
      log(
        'runImport start | rows=${rows.length} insert=${toInsert.length} '
        'update=${toUpdate.length} | codeCo=$codeCo',
        name: _testLogName,
      );
    }

    final totalWork = rows.length;
    var workDone = 0;
    var geocodeFailures = 0;
    var updatedCount = 0;
    var updateFailures = 0;

    // —— به‌روزرسانی پرونده‌های موجود (فقط وضعیت + تاریخ صدور) ——
    _updLog(
      'UPDATE START | toUpdate=${toUpdate.length} | toInsert=${toInsert.length} | '
      'codeCo=$codeCo',
    );
    for (var i = 0; i < toUpdate.length; i++) {
      if (shouldStop?.call() == true) break;
      final row = toUpdate[i];
      final shenase = _shenaseFromRow(row);
      onProgress?.call(
        ExcelImportRunProgress(
          message:
              'به‌روزرسانی وضعیت/تاریخ صدور و انقضا ${i + 1}/${toUpdate.length} — کد $shenase',
          current: workDone,
          total: totalWork,
          phase: 'update',
        ),
      );

      final serverRow = serverByShenase[shenase];
      if (serverRow == null) {
        _updLog(
          'UPDATE SKIP no-server-row | ${i + 1}/${toUpdate.length} | '
          'shenase=$shenase | csvRow=${row.rowIndex}',
        );
        updateFailures += 1;
        workDone += 1;
        continue;
      }

      try {
        final rawStatus = _cell(row.values, ExcelImportColumns.status);
        final rawIssueDate = _cell(row.values, ExcelImportColumns.issueDate);
        final statusLabel = ParvandeVaziyat.normalizeLabel(rawStatus);
        final statusCode = ParvandeVaziyat.codeForLabel(statusLabel);
        // تاریخ شمسی با `-` (بدون `/`) تا path سرور نشکند؛ تبدیل میلادی نکن.
        final issueJalali = JalaliDateUtil.toPathSafeJalali(rawIssueDate);
        final expJalali = CsvParvandeDates.computeExpJalaliPathSafe(rawIssueDate);
        final oldStatus = '${serverRow['lbl_vaziyat_store']}/${serverRow['vaziyat_store']}';
        final oldDate = '${serverRow['date_sodor_store']}';
        final oldExp = '${serverRow['date_exp_store']}';
        final id = '${serverRow['id_parvandeh']}';

        _updLog(
          'UPDATE PRE ${i + 1}/${toUpdate.length} | csvRow=${row.rowIndex} | '
          'shenase=$shenase | id=$id | '
          'rawStatus="$rawStatus" → label="$statusLabel" code=$statusCode | '
          'rawDate="$rawIssueDate" → sendDate="$issueJalali" exp="$expJalali" | '
          'OLD status=$oldStatus date=$oldDate exp=$oldExp',
        );
        _updLog(
          'UPDATE ROW KEYS csvRow=${row.rowIndex}: '
          '${row.values.entries.map((e) => '${e.key}=${_short(e.value, 40)}').join(' | ')}',
        );

        final updateResult = await _parvandeApi.updateParvandeh(
          serverRow,
          overrides: {
            'vaziyat_store': statusCode,
            'lbl_vaziyat_store': statusLabel,
            'date_sodor_store': issueJalali,
            'date_exp_store': expJalali,
          },
          verboseLog: true,
        );
        updatedCount += 1;
        _updLog(
          'UPDATE OK ${i + 1}/${toUpdate.length} | shenase=$shenase | id=$id | '
          'sentStatus=$statusCode/$statusLabel | sentDate=$issueJalali | '
          'sentExp=$expJalali | '
          'http=${updateResult.statusCode} | body=${_short(updateResult.body, 120)}',
        );
      } catch (e, st) {
        updateFailures += 1;
        _updLog('UPDATE FAIL ${i + 1}/${toUpdate.length} | shenase=$shenase | $e');
        log('$st', name: _updateLogName);
      }
      workDone += 1;
    }
    _updLog(
      'UPDATE END | ok=$updatedCount | fail=$updateFailures | '
      'insertQueued=${toInsert.length}',
    );

    // —— ثبت پرونده‌های جدید ——
    final records = <ImportDraftRecord>[];
    for (var i = 0; i < toInsert.length; i++) {
      if (shouldStop?.call() == true) break;
      final row = toInsert[i];
      final shenase = _shenaseFromRow(row);
      onProgress?.call(
        ExcelImportRunProgress(
          message: 'آماده‌سازی ثبت جدید ${i + 1}/${toInsert.length} — کد $shenase',
          current: workDone,
          total: totalWork,
          phase: 'map',
        ),
      );

      var payload = _mapRowToPayload(row);
      if (verboseTestLog) {
        log(
          'payload row=${row.rowIndex} | id=${payload['id_parvandeh']} | shenase=$shenase | '
          'tracking=${payload['num_parvande_store']} | '
          'name=${payload['name_admin']} ${payload['family_admin']} | '
          'store=${payload['name_store']} | status=${payload['lbl_vaziyat_store']}'
          '→code=${payload['vaziyat_store']} | date=${payload['date_sodor_store']} | '
          'addr=${_short(payload['address_store'] ?? '', 100)}',
          name: _testLogName,
        );
        log(
          'payload json row=${row.rowIndex}: ${jsonEncode(payload)}',
          name: _testLogName,
        );
      }
      final v = row.values;
      final address = payload['address_store']?.trim() ?? '';
      if (address.isNotEmpty) {
        onProgress?.call(
          ExcelImportRunProgress(
            message:
                'موقعیت‌یابی map.ir/نشان (${i + 1}/${toInsert.length}) — کد $shenase',
            current: workDone,
            total: totalWork,
            phase: 'geocode',
          ),
        );
        final geo = await _geocoder.resolve(
          address: address,
          state: _cell(v, ExcelImportColumns.state),
          city: _cell(v, ExcelImportColumns.city),
        );
        if (geo != null) {
          payload['lat_store'] = geo.$1;
          payload['long_store'] = geo.$2;
          if (verboseTestLog) {
            log(
              'geocode ok | shenase=$shenase | lat=${geo.$1} lng=${geo.$2}',
              name: _testLogName,
            );
          }
        } else {
          geocodeFailures += 1;
          log(
            'geocode miss | row=${row.rowIndex} | shenase=$shenase | '
            'addr=${address.length > 80 ? '${address.substring(0, 80)}…' : address}',
            name: verboseTestLog ? _testLogName : _logName,
          );
        }
        await _geocoder.pauseBetweenImports();
      }

      final recordId = payload['id_parvandeh']?.trim() ?? '';
      records.add(
        ImportDraftRecord(
          clientTempId: recordId.isNotEmpty ? recordId : shenase,
          payload: payload,
        ),
      );
      workDone += 1;
    }

    ImportFinalizeResult finalize = ImportFinalizeResult(
      success: true,
      inserted: 0,
      skipped: 0,
      failed: 0,
      docsInserted: 0,
      docsRowAttempts: 0,
    );
    var sentCount = 0;
    var stoppedEarly = shouldStop?.call() == true;

    if (records.isNotEmpty && !stoppedEarly) {
      final sendResult = await ParvandeServerSend.instance.sendAll(
        codeCo: codeCo,
        records: records,
        skipImagePreparation: true,
        shouldStop: shouldStop,
        verboseLog: verboseTestLog,
        onProgress: (p) {
          onProgress?.call(
            ExcelImportRunProgress(
              message: p.message,
              current: workDone.clamp(0, totalWork),
              total: totalWork,
              phase: p.phase,
            ),
          );
        },
      );
      finalize = sendResult.finalize;
      sentCount = sendResult.sentRecords;
      stoppedEarly = sendResult.stoppedEarly;
    } else if (records.isEmpty && toUpdate.isEmpty) {
      throw Exception('هیچ پرونده‌ای برای ارسال آماده نشد.');
    }

    log(
      'import done | insert=${finalize.inserted} update=$updatedCount '
      'updateFail=$updateFailures geocodeFail=$geocodeFailures',
      name: verboseTestLog ? _testLogName : _logName,
    );

    if (verboseTestLog) {
      log(
        '==== CSV IMPORT TEST END | inserted=${finalize.inserted} '
        'updated=$updatedCount updateFail=$updateFailures '
        'skipped=${finalize.skipped} failed=${finalize.failed} '
        'errors=${finalize.errors} ====',
        name: _testLogName,
      );
      await _logServerPresenceAfterSend(toInsert);
    }

    return ExcelImportRunResult(
      sentCount: sentCount,
      finalize: finalize,
      updatedCount: updatedCount,
      updateFailures: updateFailures,
      geocodeFailures: geocodeFailures,
      stoppedEarly: stoppedEarly,
    );
  }

  /// اولین [limit] ردیف قابل ثبت؛ اگر همه تکراری‌اند، اولین ردیف‌های معتبر فایل.
  List<ExcelParsedRow> pickTestRows(
    ExcelImportAnalysis analysis, {
    int limit = 5,
  }) {
    if (analysis.importableRows.isNotEmpty) {
      return analysis.importableRows.take(limit).toList();
    }
    final valid = <ExcelParsedRow>[];
    for (final row in analysis.rows) {
      if (_validateRow(row).isEmpty) valid.add(row);
      if (valid.length >= limit) break;
    }
    return valid;
  }

  /// ارسال آزمایشی [limit] پرونده با لاگ کامل در کنسول (`csv_import_test`).
  Future<ExcelImportRunResult> runTestImport({
    required ExcelImportAnalysis analysis,
    int limit = 5,
    void Function(ExcelImportRunProgress progress)? onProgress,
    bool Function()? shouldStop,
  }) async {
    final testRows = pickTestRows(analysis, limit: limit);
    if (testRows.isEmpty) {
      throw Exception('ردیف معتبری برای تست یافت نشد.');
    }

    log('==== CSV IMPORT TEST START ====', name: _testLogName);
    log(
      'file=${analysis.fileName} | codeCo=$codeCo | testCount=${testRows.length} | '
      'importableInFile=${analysis.importableCount} | '
      'insert=${analysis.insertOnServerCount} update=${analysis.updateOnServerCount}',
      name: _testLogName,
    );

    for (var i = 0; i < testRows.length; i++) {
      final row = testRows[i];
      final shenase = _shenaseFromRow(row);
      final tracking = _cell(row.values, ExcelImportColumns.trackingNovin);
      final onServer = analysis.serverByShenase.containsKey(shenase);
      final issues = _validateRow(row);
      log(
        'test pick ${i + 1}/${testRows.length} | csvRow=${row.rowIndex} | '
        'shenase=$shenase | tracking=$tracking | id_parvandeh=${_numericIdParvandehFromShenase(shenase)} | '
        'alreadyOnServer=$onServer | mode=${onServer ? 'update' : 'insert'} | '
        'validationIssues=$issues',
        name: _testLogName,
      );
    }

    return runImport(
      rows: testRows,
      serverByShenase: analysis.serverByShenase,
      onProgress: onProgress,
      shouldStop: shouldStop,
      verboseTestLog: true,
    );
  }

  Future<Map<String, Map<String, dynamic>>> _loadServerByShenase() async {
    final rows = await _parvandeApi.fetchAll(codeCo);
    final out = <String, Map<String, dynamic>>{};
    for (final row in rows) {
      final s = ExcelImportShenase.normalize(
        row['shenase_store']?.toString() ?? '',
      );
      if (s.isNotEmpty) out[s] = row;
    }
    return out;
  }

  Future<void> _logServerPresenceAfterSend(List<ExcelParsedRow> rows) async {
    try {
      final all = await _parvandeApi.fetchAll(codeCo);
      log('server verify | fetchAll count=${all.length} codeCo=$codeCo',
          name: _testLogName);
      for (final row in rows) {
        final shenase = _shenaseFromRow(row);
        final tracking = _cell(row.values, ExcelImportColumns.trackingNovin);
        final id = '${_numericIdParvandehFromShenase(shenase)}';
        Map<String, dynamic>? byShenase;
        Map<String, dynamic>? byId;
        Map<String, dynamic>? byTracking;
        for (final s in all) {
          final ss = ExcelImportShenase.normalize(
            s['shenase_store']?.toString() ?? '',
          );
          if (ss == shenase) byShenase = s;
          if (s['id_parvandeh']?.toString() == id) byId = s;
          if (tracking.isNotEmpty &&
              s['num_parvande_store']?.toString() == tracking) {
            byTracking = s;
          }
        }
        log(
          'server verify | shenase=$shenase | id=$id | tracking=$tracking | '
          'foundByShenase=${byShenase != null} foundById=${byId != null} '
          'foundByTracking=${byTracking != null} | '
          'ifShenase id=${byShenase?['id_parvandeh']} ss=${byShenase?['shenase_store']}',
          name: _testLogName,
        );
      }
    } catch (e) {
      log('server verify failed: $e', name: _testLogName);
    }
  }

  Map<String, String> _mapRowToPayload(ExcelParsedRow row) {
    final v = row.values;
    final shenase = _shenaseFromRow(row);
    final statusLabel = ParvandeVaziyat.normalizeLabel(v[ExcelImportColumns.status]);
    final issueGregorian = _jalaliCellToServer(v[ExcelImportColumns.issueDate]);
    final birthGregorian = _jalaliCellToServer(v[ExcelImportColumns.birthDate]);
    final csvValidity = _cell(v, ExcelImportColumns.validity);
    final dateExp = CsvParvandeDates.computeExpServer(
      csvValidity: csvValidity,
      issueDateServer: issueGregorian,
    );
    final city = _cell(v, ExcelImportColumns.city);
    // سرور insert.js مقدار id_parvandeh را با parseInt می‌خواند — فقط رقم مجاز است.
    final idParvandeh = _numericIdParvandehFromShenase(shenase);

    return {
      'id_parvandeh': idParvandeh > 0 ? '$idParvandeh' : '',
      'code_co': codeCo,
      'name_admin': _cell(v, ExcelImportColumns.firstName),
      'family_admin': _cell(v, ExcelImportColumns.lastName),
      'sex_admin': _mapGender(_cell(v, ExcelImportColumns.gender)),
      'sadere_admin': city,
      'tavalod_admin': birthGregorian.isNotEmpty
          ? birthGregorian
          : _yearOnlyFromJalali(v[ExcelImportColumns.birthDate]),
      'name_pedar_admin': _cell(v, ExcelImportColumns.fatherName),
      'num_shenasname_admin': '',
      'code_meli_admin': _cell(v, ExcelImportColumns.nationalId),
      'mob_admin': '',
      'tel_admin': '',
      'madrak_admin':
          CsvImportLabels.normalizeEducation(_cell(v, ExcelImportColumns.education)),
      'din_admin': CsvImportLabels.normalizeReligion(_cell(v, ExcelImportColumns.religion)),
      'sarbazi_admin': '',
      'taahol_admin': '',
      'name_store': _cell(v, ExcelImportColumns.storeTitle).isNotEmpty
          ? _cell(v, ExcelImportColumns.storeTitle)
          : '${_cell(v, ExcelImportColumns.firstName)} ${_cell(v, ExcelImportColumns.lastName)}'
              .trim(),
      'shenase_store': _shenaseFromRow(row),
      'raste_store': _cell(v, ExcelImportColumns.raste),
      'masahat_store': '',
      'type_melki_store':
          CsvImportLabels.normalizeOwnership(_cell(v, ExcelImportColumns.ownership)),
      'address_store': _cell(v, ExcelImportColumns.address),
      'code_posti_store': _cell(v, ExcelImportColumns.postalCode),
      'mantaghe_store': '',
      'lat_store': '',
      'long_store': '',
      'state_store': _cell(v, ExcelImportColumns.state),
      'city_store': city,
      'date_sodor_store': issueGregorian,
      'date_exp_store': dateExp,
      'date_etebar_store': '',
      if (csvValidity.isNotEmpty) '_csv_validity_status': csvValidity,
      'daraje_store': '',
      'num_parvande_store': _cell(v, ExcelImportColumns.trackingNovin),
      'vaziyat_store': ParvandeVaziyat.codeForLabel(statusLabel),
      'lbl_vaziyat_store': statusLabel,
      'num_person_store': '',
      'caption_parvande': _cell(v, ExcelImportColumns.source),
      'id_user': '1000',
      'act_parvande': '1',
      'image_profile': '',
      'image_parvaneh': '',
      'licence_file': '',
      'money': '0',
      '_import_source': 'csv',
      '_excel_row': '${row.rowIndex}',
      if (_cell(v, ExcelImportColumns.companyName).isNotEmpty)
        '_excel_company': _cell(v, ExcelImportColumns.companyName),
      if (_cell(v, ExcelImportColumns.unionName).isNotEmpty)
        '_excel_union': _cell(v, ExcelImportColumns.unionName),
    };
  }

  List<String> _validateRow(ExcelParsedRow row) {
    final issues = <String>[];
    final v = row.values;
    if (_shenaseFromRow(row).isEmpty) issues.add('کد صنفی خالی');
    if (_cell(v, ExcelImportColumns.firstName).isEmpty) {
      issues.add('نام خالی');
    }
    if (_cell(v, ExcelImportColumns.lastName).isEmpty) {
      issues.add('نام خانوادگی خالی');
    }
    if (_cell(v, ExcelImportColumns.address).isEmpty) issues.add('آدرس خالی');
    if (_cell(v, ExcelImportColumns.storeTitle).isEmpty &&
        (_cell(v, ExcelImportColumns.firstName).isEmpty ||
            _cell(v, ExcelImportColumns.lastName).isEmpty)) {
      issues.add('عنوان تابلو خالی');
    }
    if (_jalaliCellToServer(v[ExcelImportColumns.issueDate]).isEmpty) {
      issues.add('تاریخ صدور نامعتبر');
    }
    return issues;
  }

  String _buildHealthMessage({
    required List<String> missingRequired,
    required int insertCount,
    required int updateCount,
    required int removedDuplicates,
    required int totalRows,
  }) {
    if (missingRequired.isNotEmpty) {
      return 'ستون‌های ضروری یافت نشد: ${missingRequired.join('، ')}';
    }
    final importable = insertCount + updateCount;
    if (importable == 0) {
      return 'هیچ ردیف قابل ثبت باقی نمانده (همه تکراری یا ناقص هستند).';
    }
    final parts = <String>[
      'فایل سالم است؛ از $totalRows ردیف، $importable پرونده قابل پردازش است',
      'ثبت جدید: $insertCount',
      'به‌روزرسانی وضعیت/تاریخ: $updateCount',
    ];
    if (removedDuplicates > 0) {
      parts.add('حذف تکراری در فایل: $removedDuplicates');
    }
    return '${parts.join(' — ')}.';
  }

  String _shenaseFromRow(ExcelParsedRow row) =>
      ExcelImportShenase.normalize(_cell(row.values, ExcelImportColumns.shenase));

  /// شناسه عددی پرونده برای API سرور (ستون INT `id_parvandeh`).
  int _numericIdParvandehFromShenase(String shenase) {
    final digits = shenase.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return 0;
    return int.tryParse(digits) ?? 0;
  }

  String _cell(Map<String, String> row, String key) =>
      row[key]?.trim() ?? '';

  String _mapGender(String raw) {
    final t = raw.trim();
    if (t == 'مرد') return 'آقا';
    if (t == 'زن') return 'خانم';
    return t;
  }

  String _jalaliCellToServer(String? raw) {
    final cleaned = _cleanJalaliDateText(raw);
    if (cleaned.isEmpty) return '';
    return JalaliDateUtil.displayToServer(cleaned);
  }

  String _yearOnlyFromJalali(String? raw) {
    final cleaned = _cleanJalaliDateText(raw);
    if (cleaned.isEmpty) return '';
    final j = JalaliDateUtil.parse(cleaned);
    return j?.year.toString() ?? '';
  }

  String _cleanJalaliDateText(String? raw) {
    var t = raw?.trim() ?? '';
    if (t.isEmpty || t == 'null') return '';
    final comma = t.indexOf(',');
    if (comma > 0) t = t.substring(0, comma).trim();
    return t;
  }

  String _short(String text, int max) {
    final t = text.trim();
    if (t.length <= max) return t;
    return '${t.substring(0, max)}…';
  }

}
