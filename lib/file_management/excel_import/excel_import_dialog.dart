import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:injast_admin/file_management/excel_import/csv_header_mapper.dart';
import 'package:injast_admin/file_management/excel_import/excel_import_parser.dart';
import 'package:injast_admin/file_management/excel_import/excel_import_service.dart';

/// دیالوگ بررسی فایل اکسل و ثبت پرونده‌ها روی سرور.
Future<void> showExcelImportDialog({
  required BuildContext context,
  required String codeCo,
}) async {
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _ExcelImportDialog(codeCo: codeCo),
  );
}

class _ExcelImportDialog extends StatefulWidget {
  const _ExcelImportDialog({required this.codeCo});

  final String codeCo;

  @override
  State<_ExcelImportDialog> createState() => _ExcelImportDialogState();
}

class _ExcelImportDialogState extends State<_ExcelImportDialog> {
  late final ExcelImportService _service = ExcelImportService(widget.codeCo);

  _Phase _phase = _Phase.idle;
  String? _fileName;
  Uint8List? _fileBytes;
  ExcelImportAnalysis? _analysis;
  ExcelImportRunResult? _result;
  String _statusMessage = 'فایل CSV (.csv) را انتخاب کنید.';
  ExcelImportRunProgress? _runProgress;
  bool _cancelRequested = false;
  String? _error;

  bool get _canStart =>
      _phase == _Phase.ready &&
      (_analysis?.headerMatch.canProceed ?? false) &&
      (_analysis?.isHealthy ?? false) &&
      (_analysis?.importableCount ?? 0) > 0;

  bool get _canTest =>
      (_phase == _Phase.ready || _phase == _Phase.done || _phase == _Phase.error) &&
      _analysis != null &&
      _service.pickTestRows(_analysis!, limit: 1).isNotEmpty &&
      _phase != _Phase.importing &&
      _phase != _Phase.analyzing;

  @override
  Widget build(BuildContext context) {
    final analysis = _analysis;
    return AlertDialog(
      title: const Text('بارگذاری پرونده از CSV'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_fileName != null) ...[
                SelectableText(
                  'فایل: $_fileName',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
              ],
              Text(_statusMessage, style: const TextStyle(height: 1.6)),
              if (_phase == _Phase.analyzing ||
                  _phase == _Phase.importing) ...[
                const SizedBox(height: 14),
                const LinearProgressIndicator(),
              ],
              if (_runProgress != null && _phase == _Phase.importing) ...[
                const SizedBox(height: 8),
                Text(
                  '${_runProgress!.current} / ${_runProgress!.total}',
                  style: const TextStyle(
                    color: Colors.black54,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              if (analysis != null) ...[
                const SizedBox(height: 14),
                _headerMatchPanel(analysis.headerMatch),
                const SizedBox(height: 12),
                _infoTile('فرمت شناسایی‌شده', _formatLabel(analysis.fileFormat)),
                _infoTile('تعداد پرونده در فایل', '${analysis.totalRows}'),
                _infoTile('تعداد ستون‌های فایل', '${analysis.columnCount}'),
                if (analysis.headerMatch.canProceed)
                  _infoTile(
                    'قابل پردازش (پس از حذف تکراری)',
                    '${analysis.importableCount}',
                  ),
                if (analysis.insertOnServerCount > 0)
                  _infoTile(
                    'ثبت جدید روی سرور',
                    '${analysis.insertOnServerCount}',
                  ),
                if (analysis.updateOnServerCount > 0)
                  _infoTile(
                    'به‌روزرسانی وضعیت/تاریخ صدور',
                    '${analysis.updateOnServerCount}',
                    color: Colors.blue.shade800,
                  ),
                if (analysis.duplicateInFileCount > 0)
                  _infoTile(
                    'حذف‌شده به‌عنوان تکراری در فایل',
                    '${analysis.duplicateInFileCount}',
                    color: Colors.orange.shade800,
                  ),
                const SizedBox(height: 8),
                _healthBanner(analysis),
                if (analysis.missingRequiredColumns.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'ستون‌های ضروری: ${analysis.missingRequiredColumns.join('، ')}',
                    style: TextStyle(color: Colors.red.shade700, height: 1.5),
                  ),
                ],
                if (analysis.unknownColumns.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    'ستون‌های ناشناخته (نادیده گرفته می‌شوند): ${analysis.unknownColumns.take(6).join('، ')}'
                    '${analysis.unknownColumns.length > 6 ? '…' : ''}',
                    style: const TextStyle(color: Colors.black54, fontSize: 12),
                  ),
                ],
                if (analysis.sampleIssues.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'نمونه خطاهای ردیف:',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  ...analysis.sampleIssues.take(5).map(
                        (line) => Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '• $line',
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: Colors.black54,
                            ),
                          ),
                        ),
                      ),
                ],
              ],
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(
                  _error!,
                  style: TextStyle(color: Colors.red.shade700, height: 1.5),
                ),
              ],
              if (_result != null) ...[
                const SizedBox(height: 12),
                _infoTile('ثبت‌شده در سرور (جدید)', '${_result!.finalize.inserted}'),
                if (_result!.updatedCount > 0)
                  _infoTile(
                    'به‌روزرسانی وضعیت/تاریخ',
                    '${_result!.updatedCount}',
                    color: Colors.blue.shade800,
                  ),
                if (_result!.updateFailures > 0)
                  _infoTile(
                    'خطا در به‌روزرسانی',
                    '${_result!.updateFailures}',
                    color: Colors.red.shade700,
                  ),
                if (_result!.finalize.skipped > 0)
                  _infoTile(
                    'رد شده در ثبت جدید',
                    '${_result!.finalize.skipped}',
                    color: Colors.orange.shade800,
                  ),
                if (_result!.geocodeFailures > 0)
                  _infoTile(
                    'بدون موقعیت (map.ir/نشان)',
                    '${_result!.geocodeFailures}',
                    color: Colors.orange.shade800,
                  ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _phase == _Phase.importing ? _requestCancel : () => Navigator.pop(context),
          child: Text(_phase == _Phase.importing ? 'لغو عملیات' : 'بستن'),
        ),
        if (_phase == _Phase.idle || _phase == _Phase.ready || _phase == _Phase.error)
          OutlinedButton.icon(
            onPressed: _phase == _Phase.analyzing || _phase == _Phase.importing
                ? null
                : _pickAndAnalyze,
            icon: const Icon(Icons.upload_file_outlined),
            label: Text(_fileBytes == null ? 'انتخاب فایل' : 'فایل دیگر'),
          ),
        if (_canTest)
          OutlinedButton.icon(
            onPressed: _startTestImport,
            icon: const Icon(Icons.bug_report_outlined),
            label: const Text('تست ۵ پرونده'),
          ),
        FilledButton.icon(
          onPressed: _canStart && _phase != _Phase.importing ? _startImport : null,
          style: FilledButton.styleFrom(
            backgroundColor: _canStart ? Colors.green.shade700 : null,
            disabledBackgroundColor: Colors.grey.shade400,
          ),
          icon: const Icon(Icons.play_arrow_rounded),
          label: const Text('شروع عملیات'),
        ),
      ],
    );
  }

  Widget _headerMatchPanel(CsvHeaderMatchReport match) {
    final color = match.canProceed ? Colors.teal : Colors.orange;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.account_tree_outlined, color: color.shade800, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'انطباق هدر با جدول پرونده: ${match.matchPercent}٪',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: color.shade900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(match.summary, style: const TextStyle(height: 1.5, fontSize: 13)),
          if (match.bindings.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Text(
              'جایگاه ستون‌ها در این فایل',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
            ),
            const SizedBox(height: 6),
            ...match.bindings.take(14).map(
                  (b) => Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Text(
                      'ستون ${b.columnIndex + 1}: «${b.rawHeader}» → ${b.field.labelFa} (${b.field.dbField})',
                      style: const TextStyle(fontSize: 12, height: 1.4),
                    ),
                  ),
                ),
            if (match.bindings.length > 14)
              Text(
                'و ${match.bindings.length - 14} ستون دیگر…',
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
          ],
          if (match.unmappedHeaders.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'نادیده: ${match.unmappedHeaders.take(6).join('، ')}'
              '${match.unmappedHeaders.length > 6 ? '…' : ''}',
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ],
      ),
    );
  }

  Widget _infoTile(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: color ?? const Color(0xFF2E7D32),
            ),
          ),
        ],
      ),
    );
  }

  Widget _healthBanner(ExcelImportAnalysis analysis) {
    final ok = analysis.isHealthy;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ok ? Colors.green.shade50 : Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: ok ? Colors.green.shade200 : Colors.red.shade200,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            ok ? Icons.verified_outlined : Icons.error_outline,
            color: ok ? Colors.green.shade800 : Colors.red.shade800,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              analysis.healthMessage,
              style: TextStyle(
                height: 1.6,
                fontWeight: FontWeight.w600,
                color: ok ? Colors.green.shade900 : Colors.red.shade900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickAndAnalyze() async {
    setState(() {
      _error = null;
      _result = null;
      _analysis = null;
      _phase = _Phase.analyzing;
      _statusMessage = 'در حال خواندن فایل...';
    });

    try {
      final picked = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['csv', 'xlsx'],
        withData: true,
      );
      if (!mounted) return;
      if (picked == null || picked.files.isEmpty) {
        setState(() {
          _phase = _fileBytes == null ? _Phase.idle : _Phase.ready;
          _statusMessage = _fileBytes == null
              ? 'انتخاب فایل لغو شد.'
              : 'همان فایل قبلی باقی ماند.';
        });
        return;
      }

      final file = picked.files.first;
      final bytes = await _readPickedFileBytes(file);
      if (bytes.isEmpty) {
        throw Exception('محتوای فایل خوانده نشد.');
      }

      _fileName = file.name;
      _fileBytes = bytes;

      setState(() => _statusMessage = 'در حال آنالیز هدر و تطبیق ستون‌ها...');

      final parsed = await _service.parseFile(bytes, fileName: file.name);
      final analysis = await _service.analyze(
        fileName: file.name,
        fileBytes: bytes,
        rows: parsed.rows,
        headerMatch: parsed.headerMatch,
        onProgress: (msg) {
          if (mounted) setState(() => _statusMessage = msg);
        },
      );

      if (!mounted) return;
      setState(() {
        _analysis = analysis;
        _phase = _Phase.ready;
        _statusMessage = analysis.healthMessage;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.error;
        _error = '$e';
        _statusMessage = 'خطا در بررسی فایل.';
      });
    }
  }

  Future<void> _startTestImport() async {
    final analysis = _analysis;
    if (analysis == null) return;

    setState(() {
      _phase = _Phase.importing;
      _cancelRequested = false;
      _error = null;
      _result = null;
      _statusMessage =
          'تست ۵ پرونده — لاگ کنسول را با فیلتر csv_import_test ببینید…';
    });

    try {
      final result = await _service.runTestImport(
        analysis: analysis,
        limit: 5,
        shouldStop: () => _cancelRequested,
        onProgress: (p) {
          if (!mounted) return;
          setState(() {
            _runProgress = p;
            _statusMessage = '[تست] ${p.message}';
          });
        },
      );

      if (!mounted) return;
      setState(() {
        _result = result;
        _phase = _Phase.done;
        _statusMessage =
            'تست پایان یافت — ثبت: ${result.finalize.inserted}، '
            'به‌روزرسانی: ${result.updatedCount}، '
            'رد: ${result.finalize.skipped}، '
            'خطا: ${result.finalize.failed + result.updateFailures}. '
            'لاگ: csv_import_test';
      });
    } catch (e, st) {
      debugPrint('[csv_import_test] ERROR: $e\n$st');
      if (!mounted) return;
      setState(() {
        _phase = _Phase.error;
        _error = '$e';
        _statusMessage = 'خطا در تست — جزئیات در کنسول (csv_import_test).';
      });
    }
  }

  Future<void> _startImport() async {
    final analysis = _analysis;
    final rows = analysis?.importableRows;
    if (analysis == null || rows == null || rows.isEmpty) return;

    setState(() {
      _phase = _Phase.importing;
      _cancelRequested = false;
      _error = null;
      _result = null;
      _statusMessage =
          'در حال پردازش ${rows.length} پرونده '
          '(جدید: ${analysis.insertOnServerCount}، '
          'به‌روزرسانی: ${analysis.updateOnServerCount})...';
    });

    try {
      final result = await _service.runImport(
        rows: rows,
        serverByShenase: analysis.serverByShenase,
        shouldStop: () => _cancelRequested,
        onProgress: (p) {
          if (!mounted) return;
          setState(() {
            _runProgress = p;
            _statusMessage = p.message;
          });
        },
      );

      if (!mounted) return;
      setState(() {
        _result = result;
        _phase = _Phase.done;
        _statusMessage = result.stoppedEarly
            ? 'عملیات توسط کاربر متوقف شد.'
            : 'عملیات پایان یافت — ثبت جدید: ${result.finalize.inserted}، '
                'به‌روزرسانی: ${result.updatedCount}'
                '${result.updateFailures > 0 ? '، خطا: ${result.updateFailures}' : ''}. '
                'لاگ: csv_import_update';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.error;
        _error = '$e';
        _statusMessage = 'خطا در ثبت پرونده‌ها.';
      });
    }
  }

  void _requestCancel() {
    setState(() {
      _cancelRequested = true;
      _statusMessage = 'در حال توقف عملیات...';
    });
  }

  Future<Uint8List> _readPickedFileBytes(PlatformFile file) async {
    final fromPicker = file.bytes;
    if (fromPicker != null && fromPicker.isNotEmpty) {
      return fromPicker;
    }
    final path = file.path?.trim();
    if (!kIsWeb && path != null && path.isNotEmpty) {
      return File(path).readAsBytes();
    }
    return Uint8List(0);
  }

  String _formatLabel(ImportFileFormat format) => switch (format) {
        ImportFileFormat.csv => 'CSV (.csv)',
        ImportFileFormat.xlsxZip => 'Excel جدید (.xlsx)',
        ImportFileFormat.unknown => 'نامشخص',
      };
}

enum _Phase { idle, analyzing, ready, importing, done, error }
