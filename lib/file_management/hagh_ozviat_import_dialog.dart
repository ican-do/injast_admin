import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:injast_admin/file_management/hagh_ozviat_import_service.dart';
import 'package:injast_admin/file_management/hagh_ozviat_models.dart';

Future<void> showHaghOzviatImportDialog({
  required BuildContext context,
  required String codeCo,
}) async {
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _HaghOzviatImportDialog(codeCo: codeCo),
  );
}

class _HaghOzviatImportDialog extends StatefulWidget {
  const _HaghOzviatImportDialog({required this.codeCo});

  final String codeCo;

  @override
  State<_HaghOzviatImportDialog> createState() => _HaghOzviatImportDialogState();
}

enum _Phase { idle, analyzing, ready, syncing, done, error }

class _HaghOzviatImportDialogState extends State<_HaghOzviatImportDialog> {
  late final HaghOzviatImportService _service =
      HaghOzviatImportService(widget.codeCo);

  _Phase _phase = _Phase.idle;
  String? _fileName;
  HaghOzviatAnalysis? _analysis;
  HaghOzviatSyncResult? _result;
  String _status =
      'فایل CSV مطالبات صنفی را انتخاب کنید (UTF-8 از Excel).';
  HaghOzviatSyncProgress? _syncProgress;
  String? _error;

  bool get _canStart =>
      _phase == _Phase.ready && (_analysis?.isHealthy ?? false);

  @override
  Widget build(BuildContext context) {
    final a = _analysis;
    return AlertDialog(
      title: const Text('بروزرسانی بدهی اعضا (حق عضویت)'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_fileName != null)
                SelectableText(
                  'فایل: $_fileName',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              const SizedBox(height: 8),
              Text(_status, style: const TextStyle(height: 1.6)),
              if (_phase == _Phase.analyzing || _phase == _Phase.syncing) ...[
                const SizedBox(height: 12),
                const LinearProgressIndicator(),
              ],
              if (_syncProgress != null && _phase == _Phase.syncing) ...[
                const SizedBox(height: 8),
                Text(
                  '${_syncProgress!.current} / ${_syncProgress!.total}',
                  style: const TextStyle(
                    color: Colors.black54,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              if (a != null) ...[
                const SizedBox(height: 14),
                if (a.importSource.isNotEmpty)
                  _tile('روش خواندن فایل', a.importSource, color: Colors.black54),
                _tile('ردیف‌های خوانده‌شده از فایل', '${a.rawRowsInFile}'),
                _tile('تعداد ردیف‌های معتبر', '${a.totalRows}'),
                _tile('تعداد اعضا (کد صنفی یکتا)', '${a.uniqueMembers}'),
                if (a.detectedShenaseColumn != null &&
                    a.detectedShenaseColumn!.isNotEmpty)
                  _tile(
                    'ستون کد صنفی (تشخیص خودکار)',
                    a.detectedShenaseColumn!,
                    color: Colors.black54,
                  ),
                if (a.likelyUnderParsed)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      'تعداد اعضا کمتر از انتظار است. فایل را با '
                      '«CSV UTF-8» از Excel ذخیره کنید.',
                      style: TextStyle(
                        color: Colors.red.shade800,
                        fontSize: 12,
                        height: 1.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                if (a.rowsWithExplicitShenase > 0)
                  _tile(
                    'ردیف با کد صنفی در خود فایل',
                    '${a.rowsWithExplicitShenase}',
                    color: Colors.black54,
                  ),
                if (a.filledFromPreviousShenase > 0)
                  _tile(
                    'کد صنفی از سلول ادغام (پر شده)',
                    '${a.filledFromPreviousShenase}',
                    color: const Color(0xFF1565C0),
                  ),
                if (a.uniqueMelliInFile > 0)
                  _tile(
                    'کدملی یکتا (پس از پر کردن ادغام)',
                    '${a.uniqueMelliInFile}',
                    color: Colors.black54,
                  ),
                if (a.uniqueNamesInFile > 0)
                  _tile(
                    'نام یکتا (پس از پر کردن ادغام)',
                    '${a.uniqueNamesInFile}',
                    color: Colors.black54,
                  ),
                if (a.registryParvandeCount > 0)
                  _tile(
                    'پرونده در نگاشت اتحادیه',
                    '${a.registryParvandeCount}',
                    color: Colors.black54,
                  ),
                if (a.filledFromMelliInFile > 0)
                  _tile(
                    'کد صنفی از کدملی (در فایل)',
                    '${a.filledFromMelliInFile}',
                    color: const Color(0xFF1565C0),
                  ),
                if (a.filledFromNameInFile > 0)
                  _tile(
                    'کد صنفی از نام (در فایل)',
                    '${a.filledFromNameInFile}',
                    color: const Color(0xFF1565C0),
                  ),
                if (a.filledFromParvandeRegistry > 0)
                  _tile(
                    'کد صنفی از پرونده‌های برنامه',
                    '${a.filledFromParvandeRegistry}',
                    color: const Color(0xFF6A1B9A),
                  ),
                if (a.skippedEmptyShenase > 0)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      'برای ${a.skippedEmptyShenase} ردیف کد صنفی پیدا نشد. '
                      'ابتدا پرونده‌ها را از سرور همگام کنید، سپس فایل را دوباره بگیرید.',
                      style: TextStyle(
                        color: Colors.orange.shade900,
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                  ),
                _tile(
                  'مجموع در انتظار پرداخت',
                  '${_formatRial(a.totalPendingRial)} ریال',
                  color: const Color(0xFFC62828),
                ),
                _tile(
                  'مجموع تایید شده',
                  '${_formatRial(a.totalConfirmedRial)} ریال',
                  color: const Color(0xFF2E7D32),
                ),
                if (a.skippedEmptyShenase > 0)
                  _tile(
                    'رد شده — بدون کد صنفی',
                    '${a.skippedEmptyShenase}',
                    color: Colors.orange.shade900,
                  ),
                if (a.skippedDeleted > 0)
                  _tile('رد شده — وضعیت حذف شده', '${a.skippedDeleted}'),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'پس از «شروع عملیات»، برای هر کد صنفی ردیف‌های قبلی در سرور حذف و '
                    'ردیف‌های جدید همین فایل جایگزین می‌شوند.',
                    style: TextStyle(height: 1.6, fontSize: 12.5),
                  ),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(
                  _error!,
                  style: TextStyle(color: Colors.red.shade800, height: 1.5),
                ),
              ],
              if (_result != null) ...[
                const SizedBox(height: 10),
                Text(
                  'اعضای به‌روز شده: ${_result!.membersReplaced}\n'
                  'ردیف‌های درج‌شده: ${_result!.rowsInserted}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                if (_result!.errors.isNotEmpty)
                  Text(
                    'هشدار: ${_result!.errors.length} خطا',
                    style: TextStyle(color: Colors.orange.shade900),
                  ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _phase == _Phase.syncing
              ? null
              : () => Navigator.pop(context),
          child: const Text('بستن'),
        ),
        if (_phase != _Phase.syncing)
          OutlinedButton(
            onPressed: _pickAndAnalyze,
            child: const Text('انتخاب فایل CSV'),
          ),
        FilledButton(
          onPressed: _canStart ? _startSync : null,
          child: const Text('شروع عملیات'),
        ),
      ],
    );
  }

  Widget _tile(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(label, style: const TextStyle(color: Colors.black54)),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: TextStyle(fontWeight: FontWeight.w800, color: color),
            ),
          ),
        ],
      ),
    );
  }

  String _formatRial(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  Future<void> _pickAndAnalyze() async {
    if (kIsWeb) {
      setState(() {
        _error = 'بارگذاری فایل فقط در نسخه دسکتاپ پشتیبانی می‌شود.';
      });
      return;
    }
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['csv'],
      withData: true,
    );
    if (!mounted || picked == null || picked.files.isEmpty) return;
    final f = picked.files.first;
    final bytes = f.bytes;
    if (bytes == null || bytes.isEmpty) {
      setState(() => _error = 'فایل خالی است.');
      return;
    }

    setState(() {
      _phase = _Phase.analyzing;
      _error = null;
      _result = null;
      _fileName = f.name;
      _status = 'در حال بررسی فایل…';
    });

    try {
      final analysis = await _service.analyzeFile(
        fileName: f.name,
        bytes: bytes,
      );
      if (!mounted) return;
      setState(() {
        _analysis = analysis;
        _phase = _Phase.ready;
        _status = 'بررسی انجام شد. در صورت تایید «شروع عملیات» را بزنید.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.error;
        _error = e.toString();
        _status = 'خطا در بررسی فایل';
      });
    }
  }

  Future<void> _startSync() async {
    final rows = _analysis?.rows;
    if (rows == null || rows.isEmpty) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تایید همگام‌سازی'),
        content: Text(
          'برای ${_analysis!.uniqueMembers} عضو، ${_analysis!.totalRows} ردیف '
          'حق عضویت روی سرور جایگزین می‌شود.\n\nادامه می‌دهید؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('انصراف'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('شروع'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() {
      _phase = _Phase.syncing;
      _status = 'در حال ارسال به سرور…';
      _syncProgress = null;
      _error = null;
    });

    try {
      final result = await _service.runSync(
        rows: rows,
        onProgress: (p) {
          if (!mounted) return;
          setState(() {
            _syncProgress = p;
            _status = p.message;
          });
        },
      );
      if (!mounted) return;
      setState(() {
        _result = result;
        _phase = result.ok ? _Phase.done : _Phase.error;
        _status = result.ok
            ? 'همگام‌سازی با موفقیت انجام شد.'
            : 'همگام‌سازی با خطا پایان یافت.';
        if (!result.ok && result.errors.isNotEmpty) {
          _error = result.errors.take(5).join('\n');
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.error;
        _error = e.toString();
        _status = 'خطا در همگام‌سازی';
      });
    }
  }
}
