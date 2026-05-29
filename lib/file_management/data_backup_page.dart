import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';

import 'package:injast_admin/file_management/backup_rtl_text.dart';
import 'package:injast_admin/file_management/data_backup_service.dart';
import 'package:injast_admin/file_management/data_backup_sections.dart';
import 'package:injast_admin/file_management/excel_import/excel_import_dialog.dart';
import 'package:injast_admin/file_management/hagh_ozviat_import_dialog.dart';
import 'package:injast_admin/local_cache/network_reachability.dart';

class DataBackupPage extends StatefulWidget {
  const DataBackupPage({
    super.key,
    required this.codeCo,
    this.sessionUser,
  });

  final String codeCo;
  final Map<String, dynamic>? sessionUser;

  @override
  State<DataBackupPage> createState() => _DataBackupPageState();
}

class _DataBackupPageState extends State<DataBackupPage> {
  late final DataBackupService _service;

  DataBackupOverview? _overview;
  BackupProgress? _loadProgress;
  BackupProgress? _backupProgress;
  BackupProgress? _recoverProgress;
  BackupProgress? _purgeProgress;
  bool _loading = false;
  bool _backupRunning = false;
  bool _recovering = false;
  bool _purging = false;
  String? _actionLabel;
  final List<String> _backupLogs = [];

  bool get _isBusy =>
      _loading ||
      _backupRunning ||
      _recovering ||
      _purging ||
      _actionLabel != null;

  VoidCallback? _tap(VoidCallback fn) => _isBusy ? null : fn;

  @override
  void initState() {
    super.initState();
    _service = DataBackupService(widget.codeCo);
    _loadOverview();
  }

  @override
  void dispose() => super.dispose();

  Future<void> _loadOverview({bool forceRefresh = false}) async {
    setState(() {
      _loading = true;
      _loadProgress = const BackupProgress(
        stage: 'start',
        message: 'در حال آماده‌سازی آمار...',
      );
    });
    try {
      final overview = await _service.loadOverview(
        forceRefresh: forceRefresh,
        onProgress: (progress) {
          if (!mounted) return;
          setState(() => _loadProgress = progress);
        },
      );
      if (!mounted) return;
      setState(() => _overview = overview);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطا در بارگذاری آمار: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadProgress = null;
        });
      }
    }
  }

  Future<void> _export(String format) async {
    final source = await _askExportSource();
    if (source == null) return;
    setState(() => _actionLabel = 'در حال تولید فایل $format...');
    try {
      final result = switch (format) {
        'JSON' => await _service.exportJson(source),
        'CSV' => await _service.exportCsv(source),
        _ => await _service.exportExcel(source),
      };
      if (!mounted || result == null) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 8),
          content: Text(
            'خروجی ${result.label} از ${source == DataExportSource.server ? 'سرور' : 'حافظه محلی'} ساخته شد.'
            '\nپرونده: ${result.recordCount}'
            '\nمسیر: ${result.mainPath}',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطا در خروجی $format: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _actionLabel = null);
      }
    }
  }

  Future<DataExportSource?> _askExportSource() {
    return showDialog<DataExportSource>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('منبع خروجی را انتخاب کنید'),
        content: const Text(
          'خروجی از اطلاعات آنلاین سرور ساخته شود یا از اطلاعات موجود در حافظه محلی؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('انصراف'),
          ),
          OutlinedButton.icon(
            onPressed: () => Navigator.pop(ctx, DataExportSource.local),
            icon: const Icon(FluentIcons.phone_laptop_24_regular),
            label: const Text('حافظه محلی'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(ctx, DataExportSource.server),
            icon: const Icon(Icons.cloud_outlined),
            label: const Text('سرور'),
          ),
        ],
      ),
    );
  }

  Future<void> _startBackupFlow() async {
    setState(() => _actionLabel = 'در حال بررسی تعداد پرونده‌های سرور...');
    BackupPreparation prep;
    try {
      prep = await _service.prepareFullBackup();
    } catch (e) {
      if (!mounted) return;
      setState(() => _actionLabel = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطا در بررسی سرور: $e')),
      );
      return;
    }
    if (!mounted) return;
    setState(() => _actionLabel = null);

    final firstConfirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('مرحله اول تایید بکاپ کامل'),
        content: Text(
          'تعداد تقریبی ${prep.totalCount} پرونده روی سرور اصلی سیستم شناسایی شد.\n'
          'در این عملیات، کش محلی فعلی پاک و با اطلاعات جدید سرور جایگزین می‌شود.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('انصراف'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('ادامه'),
          ),
        ],
      ),
    );
    if (firstConfirm != true || !mounted) return;

    final secondConfirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('مرحله دوم تایید نهایی'),
        content: const Text(
          'این عملیات نسخه محلی را کاملا نوسازی می‌کند و ممکن است زمان‌بر باشد.\n'
          'اطلاعات پرونده، اسناد، تصویر پروفایل و فایل‌های کش‌شده مستقیما از سرور خود سیستم دریافت می‌شوند.\n'
          'آیا از شروع بکاپ کامل مطمئن هستید؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('خیر'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.backup_outlined),
            label: const Text('شروع بکاپ کامل'),
          ),
        ],
      ),
    );
    if (secondConfirm != true || !mounted) return;

    setState(() {
      _backupRunning = true;
      _backupProgress = const BackupProgress(
        stage: 'start',
        message: 'شروع عملیات بکاپ...',
      );
      _backupLogs.clear();
    });

    try {
      final result = await _service.runFullServerBackup(
        onProgress: (progress) {
          if (!mounted) return;
          setState(() {
            _backupProgress = progress;
            final line = progress.message.trim();
            if (line.isNotEmpty) {
              _backupLogs.insert(0, line);
              if (_backupLogs.length > 18) {
                _backupLogs.removeRange(18, _backupLogs.length);
              }
            }
          });
        },
      );
      if (!mounted) return;
      await _loadOverview(forceRefresh: true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 8),
          content: Text(
            'بکاپ کامل انجام شد.\n'
            'پرونده: ${result.recordsCount} | سند: ${result.documentsCount} | '
            'تصویر واحد صنفی: ${result.storeImagesDownloaded}',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطا در بکاپ کامل: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _backupRunning = false;
          _backupProgress = null;
        });
      }
    }
  }

  Future<void> _startHaghImport() async {
    await showHaghOzviatImportDialog(
      context: context,
      codeCo: widget.codeCo,
    );
    if (!mounted) return;
    await _loadOverview(forceRefresh: true);
  }

  Future<void> _startExcelImport() async {
    await showExcelImportDialog(
      context: context,
      codeCo: widget.codeCo,
    );
    if (!mounted) return;
    await _loadOverview(forceRefresh: true);
  }

  Future<void> _clearLocalDataFlow() async {
    final local = _overview?.local;
    final firstConfirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('مرحله اول تایید حذف کامل حافظه محلی'),
        content: Text(
          'اطلاعات محلی این اتحادیه حذف شود؟\n'
          'پرونده: ${local?.totalCases ?? 0}\n'
          'سند: ${local?.documentsCount ?? 0}\n'
          'فایل فیزیکی: ${local?.mediaFilesOnDisk ?? 0}\n'
          'این عملیات فقط روی حافظه محلی دستگاه انجام می‌شود.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('انصراف'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('ادامه'),
          ),
        ],
      ),
    );
    if (firstConfirm != true || !mounted) return;

    final secondConfirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('مرحله دوم تایید نهایی حذف'),
        content: const Text(
          'تمام داده‌های محلی این اتحادیه شامل رکوردهای کش‌شده، اسناد و فایل‌های ذخیره‌شده از دستگاه حذف می‌شوند.\n'
          'این عملیات قابل بازگشت نیست. آیا از حذف کامل مطمئن هستید؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('خیر'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.delete_forever_outlined),
            label: const Text('حذف کامل حافظه محلی'),
          ),
        ],
      ),
    );
    if (secondConfirm != true || !mounted) return;

    setState(() => _actionLabel = 'در حال حذف کامل اطلاعات حافظه محلی...');
    try {
      await _service.clearLocalDataCompletely();
      if (!mounted) return;
      await _loadOverview(forceRefresh: true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تمام اطلاعات حافظه محلی این اتحادیه حذف شد.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطا در حذف کامل حافظه محلی: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _actionLabel = null);
      }
    }
  }

  Future<void> _purgeUnionCompletelyFlow() async {
    final online = await NetworkReachability.instance.isServerReachable();
    if (!online) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'سرور در دسترس نیست. برای حذف کامل اتحادیه از سرور و محلی، ابتدا اتصال را برقرار کنید.',
          ),
        ),
      );
      return;
    }

    UnionPurgePreview preview;
    setState(() => _actionLabel = 'در حال آماده‌سازی آمار حذف…');
    try {
      preview = await _service.loadUnionPurgePreview();
    } catch (e) {
      if (!mounted) return;
      setState(() => _actionLabel = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطا در دریافت آمار: $e')),
      );
      return;
    }
    if (!mounted) return;
    setState(() => _actionLabel = null);

    final step1 = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded, color: Color(0xFFB71C1C), size: 48),
        title: const Text(
          'هشدار شدید — مرحله ۱ از ۳',
          style: TextStyle(color: Color(0xFFB71C1C), fontWeight: FontWeight.w800),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'شما در حال حذف کامل تمام داده‌های اتحادیه با کد «${widget.codeCo}» هستید.',
                style: TextStyle(fontWeight: FontWeight.w700, color: Colors.red.shade900),
              ),
              const SizedBox(height: 12),
              const Text(
                'این عملیات غیرقابل بازگشت است و شامل موارد زیر می‌شود:',
                style: TextStyle(height: 1.6),
              ),
              const SizedBox(height: 8),
              _purgeBullet('حذف دائم همهٔ پرونده‌ها از سرور (شامل سطل زباله)'),
              _purgeBullet('حذف اسناد و فایل‌های وابسته به پرونده‌ها روی سرور'),
              _purgeBullet('پاک‌سازی کامل SQLite محلی این اتحادیه'),
              _purgeBullet('حذف تمام فایل‌های کش‌شده (تصاویر، مدارک، پروفایل) از دستگاه'),
              const SizedBox(height: 12),
              Text(
                'تخمین حجم:\n'
                '• سرور: ${preview.serverParvandeCount} پرونده\n'
                '• محلی: ${preview.localParvandeCount} پرونده، '
                '${preview.localDocumentsCount} سند، '
                '${preview.localMediaFilesCount} فایل فیزیکی',
                style: const TextStyle(height: 1.6, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('انصراف')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFB71C1C)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('می‌دانم — ادامه'),
          ),
        ],
      ),
    );
    if (step1 != true || !mounted) return;

    final codeCtrl = TextEditingController();
    final step2 = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setLocal) {
          final matches = codeCtrl.text.trim() == widget.codeCo;
          return AlertDialog(
            icon: const Icon(Icons.lock_outline, color: Color(0xFFB71C1C), size: 44),
            title: const Text(
              'تایید هویت — مرحله ۲ از ۳',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'برای ادامه، کد اتحادیه را دقیقاً در کادر زیر وارد کنید:',
                  style: TextStyle(height: 1.6),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: codeCtrl,
                  textDirection: TextDirection.ltr,
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    labelText: 'کد اتحادیه',
                    hintText: widget.codeCo,
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (_) => setLocal(() {}),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('انصراف')),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: matches ? const Color(0xFFB71C1C) : Colors.grey,
                ),
                onPressed: matches ? () => Navigator.pop(ctx, true) : null,
                child: const Text('تایید کد'),
              ),
            ],
          );
        },
      ),
    );
    codeCtrl.dispose();
    if (step2 != true || !mounted) return;

    var acceptedIrreversible = false;
    final step3 = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          icon: const Icon(Icons.delete_forever, color: Color(0xFFB71C1C), size: 52),
          title: const Text(
            'تایید نهایی — مرحله ۳ از ۳',
            style: TextStyle(color: Color(0xFFB71C1C), fontWeight: FontWeight.w900),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEBEE),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFB71C1C)),
                ),
                child: const Text(
                  'پس از تایید، حذف از سرور و دستگاه بلافاصله آغاز می‌شود. '
                  'هیچ راهی برای بازیابی خودکار وجود ندارد.',
                  style: TextStyle(height: 1.7, fontWeight: FontWeight.w700),
                ),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: acceptedIrreversible,
                onChanged: (v) => setLocal(() => acceptedIrreversible = v == true),
                title: const Text(
                  'می‌فهمم که این عملیات برای همیشه و غیرقابل بازگشت است.',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                controlAffinity: ListTileControlAffinity.leading,
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('انصراف')),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFFB71C1C)),
              onPressed: acceptedIrreversible ? () => Navigator.pop(ctx, true) : null,
              icon: const Icon(Icons.delete_forever),
              label: const Text('حذف کامل اتحادیه'),
            ),
          ],
        ),
      ),
    );
    if (step3 != true || !mounted) return;

    setState(() {
      _purging = true;
      _purgeProgress = const BackupProgress(
        stage: 'start',
        message: 'شروع حذف کامل اتحادیه…',
      );
    });
    try {
      final result = await _service.purgeUnionCompletely(
        onProgress: (p) {
          if (!mounted) return;
          setState(() => _purgeProgress = p);
        },
      );
      if (!mounted) return;
      await _loadOverview(forceRefresh: true);
      if (!mounted) return;
      final msg = StringBuffer()
        ..writeln('حذف کامل اتحادیه ${widget.codeCo} انجام شد.')
        ..writeln('سرور: ${result.serverDeleteSucceeded} از ${result.serverDeleteAttempted} حذف شد')
        ..writeln('محلی: پاک‌سازی کامل انجام شد');
      if (result.hasServerFailures) {
        msg.writeln('هشدار: ${result.serverDeleteFailed} مورد روی سرور حذف نشد.');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 10),
          content: Text(msg.toString()),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطا در حذف کامل: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _purging = false;
          _purgeProgress = null;
        });
      }
    }
  }

  Widget _purgeBullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(fontWeight: FontWeight.w800)),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }

  Future<void> _openGeocodeRecoveryDialog() async {
    setState(() => _actionLabel = 'در حال بررسی آمار مختصات...');
    GeocodeRecoveryStats stats;
    try {
      stats = await _service.loadGeocodeRecoveryStats();
    } catch (e) {
      if (!mounted) return;
      setState(() => _actionLabel = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطا در محاسبه آمار مختصات: $e')),
      );
      return;
    }
    if (!mounted) return;
    setState(() => _actionLabel = null);

    final mode = await showDialog<GeocodeRecoveryMode>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('بازیابی مختصات'),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _recoveryStatLine('تعداد پرونده', stats.totalCases),
              _recoveryStatLine(
                  'تعداد پرونده دارای مختصات', stats.withLocation),
              _recoveryStatLine('تعداد بدون مختصات', stats.withoutLocation),
              _recoveryStatLine(
                'تعداد مختصات صحیح (در منطقه استان اتحادیه)',
                stats.validInProvince,
              ),
              _recoveryStatLine(
                  'تعداد اشتباه (خارج از استان)', stats.invalidOutOfProvince),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('لغو'),
          ),
          OutlinedButton(
            onPressed: () =>
                Navigator.pop(ctx, GeocodeRecoveryMode.problematicOnly),
            child: const Text('بازیابی موارد مشکل دار و خالی از مختصات'),
          ),
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx, GeocodeRecoveryMode.testFive),
            child: const Text('بازیابی تست ۵ عدد'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, GeocodeRecoveryMode.all),
            child: const Text('بازیابی همه'),
          ),
        ],
      ),
    );
    if (mode == null || !mounted) return;
    await _runGeocodeRecovery(mode);
  }

  Widget _recoveryStatLine(String title, int value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(title,
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          Text('$value', style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  Future<void> _runGeocodeRecovery(GeocodeRecoveryMode mode) async {
    setState(() {
      _recovering = true;
      _recoverProgress = const BackupProgress(
        stage: 'start',
        message: 'شروع بازیابی مختصات...',
      );
    });
    try {
      final result = await _service.recoverGeocodes(
        mode: mode,
        onProgress: (progress) {
          if (!mounted) return;
          setState(() => _recoverProgress = progress);
        },
      );
      if (!mounted) return;
      await _loadOverview(forceRefresh: true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 8),
          content: Text(
            'بازیابی مختصات تمام شد.\n'
            'بررسی شده: ${result.attempted} | بروزرسانی: ${result.updated} | '
            'ناموفق: ${result.failed} | خارج استان: ${result.skippedOutOfProvince}',
          ),
        ),
      );
      if (mode == GeocodeRecoveryMode.testFive &&
          result.previewRows.isNotEmpty) {
        await _showTestFivePreviewDialog(result.previewRows);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطا در بازیابی مختصات: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _recovering = false;
          _recoverProgress = null;
        });
      }
    }
  }

  Future<void> _showTestFivePreviewDialog(List<Map<String, dynamic>> rows) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        child: SizedBox(
          width: 920,
          height: 620,
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'بررسی پرونده‌های تست ۵تایی',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: rows.length,
                  itemBuilder: (_, i) => _previewCard(rows[i]),
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('بستن'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _previewCard(Map<String, dynamic> row) {
    String v(String key) => row[key]?.toString().trim() ?? '';
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${v('name_admin')} ${v('family_admin')}',
              style:
                  const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5),
            ),
            const SizedBox(height: 4),
            Text('نام واحد: ${v('name_store')}'),
            Text('شناسه صنفی: ${v('shenase_store')}'),
            Text('شماره پرونده: ${v('num_parvande_store')}'),
            Text('استان: ${v('state_store')} | شهر: ${v('city_store')}'),
            Text('آدرس: ${v('address_store')}'),
            Text('مختصات فعلی: ${v('lat_store')}, ${v('long_store')}'),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final overview = _overview;
    final user = widget.sessionUser ?? const <String, dynamic>{};
    final userName =
        '${user['name_user']?.toString().trim() ?? ''} ${user['family_user']?.toString().trim() ?? ''}'
            .trim();

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: const Text('مدیریت اطلاعات و بکاپ'),
        elevation: 0,
        scrolledUnderElevation: 0.5,
        actions: [
          IconButton(
            tooltip: 'بروزرسانی آمار',
            onPressed: _loading || _backupRunning || _recovering || _purging
                ? null
                : () => _loadOverview(forceRefresh: true),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _headerCard(userName: userName),
            const SizedBox(height: 14),
            if (_loading && overview == null)
              _progressCard(
                title: 'در حال بارگذاری آمار',
                progress: _loadProgress,
                logs: const [],
              )
            else ...[
              if (_loading && _loadProgress != null) ...[
                _progressCard(
                  title: 'بروزرسانی آمار',
                  progress: _loadProgress,
                  logs: const [],
                  compact: true,
                ),
                const SizedBox(height: 14),
              ],
              if (overview != null) _statsSection(overview),
            ],
            const SizedBox(height: 18),
            ..._buildCategorySections(),
            if (_actionLabel != null) ...[
              const SizedBox(height: 14),
              _statusBanner(_actionLabel!),
            ],
            if (_backupRunning || _backupProgress != null) ...[
              const SizedBox(height: 14),
              _progressCard(
                title: 'پیشرفت بکاپ کامل',
                progress: _backupProgress,
                logs: _backupLogs,
              ),
            ],
            if (_recovering || _recoverProgress != null) ...[
              const SizedBox(height: 14),
              _progressCard(
                title: 'پیشرفت بازیابی مختصات',
                progress: _recoverProgress,
                logs: const [],
              ),
            ],
            if (_purging || _purgeProgress != null) ...[
              const SizedBox(height: 14),
              _progressCard(
                title: 'پیشرفت حذف کامل اتحادیه',
                progress: _purgeProgress,
                logs: const [],
              ),
            ],
          ],
        ),
        ),
      ),
    );
  }

  Widget _headerCard({required String userName}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFF3E2723), Color(0xFF6D4C41)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  FluentIcons.database_24_regular,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'داشبورد اطلاعات، خروجی و بکاپ',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'کد اتحادیه: ${widget.codeCo}',
                      style: const TextStyle(
                          color: Colors.white70, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (userName.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'کاربر جاری: $userName',
              style: const TextStyle(
                  color: Colors.white70, fontWeight: FontWeight.w600),
            ),
          ],
          const SizedBox(height: 12),
          const BackupRtlText(
            'مرکز مدیریت داده — استخراج، ورود، بکاپ و حذف اطلاعات اتحادیه در یک صفحه.',
            style: TextStyle(color: Colors.white, height: 1.7),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildCategorySections() {
    final sections = [
      BackupCategorySection(
        number: 1,
        title: 'عملیات استخراج اطلاعات از سرور اصلی',
        subtitle: 'دریافت خروجی کامل پرونده‌ها برای آرشیو، گزارش‌گیری یا انتقال',
        color: const Color(0xFF1565C0),
        icon: FluentIcons.arrow_export_24_regular,
        helpIntro:
            'با این گزینه‌ها می‌توانید تمام پرونده‌های اتحادیه را در قالب فایل دریافت کنید. '
            'پس از انتخاب فرمت، منبع «سرور» یا «حافظه محلی» را مشخص کنید.',
        helpSteps: const [
          'یکی از دکمه‌های اکسل، سی‌اس‌وی یا جیسون را بزنید.',
          'در پنجرهٔ بازشده، «سرور» (داده آنلاین) یا «حافظه محلی» (داده آفلاین) را انتخاب کنید.',
          'پس از ساخت فایل، مسیر ذخیره در پیام پایین صفحه نشان داده می‌شود.',
          'فرمت سی‌اس‌وی و اکسل برای گزارش در نرم‌افزار جدول‌نگار؛ جیسون برای برنامه‌نویسی و یکپارچه‌سازی مناسب است.',
        ],
        actions: [
          BackupActionItem(
            title: 'استخراج همه اطلاعات',
            subtitle: 'فایل اکسل با پسوند xlsx',
            icon: Icons.grid_on_rounded,
            formatBadge: 'Excel',
            isPrimary: true,
            onTap: _tap(() => _export('Excel')),
          ),
          BackupActionItem(
            title: 'استخراج همه اطلاعات',
            subtitle: 'فایل متنی جدولی با جداکننده',
            icon: Icons.table_rows_rounded,
            formatBadge: 'CSV',
            onTap: _tap(() => _export('CSV')),
          ),
          BackupActionItem(
            title: 'استخراج همه اطلاعات',
            subtitle: 'ساختار جیسون برای توسعه‌دهندگان',
            icon: Icons.data_object_rounded,
            formatBadge: 'JSON',
            onTap: _tap(() => _export('JSON')),
          ),
        ],
      ),
      BackupCategorySection(
        number: 2,
        title: 'ورود اطلاعات پایه',
        subtitle: 'بارگذاری پرونده، بدهی اعضا و تکمیل خودکار مختصات',
        color: const Color(0xFF00695C),
        icon: FluentIcons.arrow_import_24_regular,
        helpLevel: BackupHelpLevel.full,
        defaultExpanded: true,
        helpIntro:
            'برای راه‌اندازی اولیه یا به‌روزرسانی انبوه از این بخش استفاده کنید. '
            'هر عملیات قبل از اجرا فایل را بررسی می‌کند و گزارش خطا نشان می‌دهد.',
        helpSteps: const [
          'پرونده‌ها: فایل را از سامانه اصناف ذخیره کنید (در اکسل: ذخیره به‌عنوان → سی‌اس‌وی با یو‌تی‌اف‌۸). هر ردیف باید کد صنفی، نام، موبایل و آدرس داشته باشد. پس از انتخاب فایل، تعداد قابل ثبت و تکراری‌ها نمایش داده می‌شود؛ سپس «شروع ثبت» را بزنید.',
          'بدهی اعضا: فایل «بدهی‌های صنفی» را با فرمت سی‌اس‌وی یو‌تی‌اف‌۸ انتخاب کنید. هر ردیف باید «کد صنفی» خودش را داشته باشد. پس از تحلیل، داده‌ها عضو‌به‌عضو روی سرور همگام می‌شوند و در کارت پرونده در بخش «حق عضویت» دیده می‌شوند.',
          'بازیابی مختصات: آدرس پرونده‌ها با سرویس نقشه بررسی و عرض/طول جغرافیایی تکمیل یا اصلاح می‌شود. ابتدا «تست ۵ عدد» را امتحان کنید؛ سپس «موارد مشکل‌دار» یا «همه» را اجرا کنید. مختصات خارج از استان اتحادیه ثبت نمی‌شود.',
          'قبل از ورود انبوه، یک‌بار از بخش ۱ خروجی بگیرید تا در صورت نیاز بتوانید داده را بازیابی کنید.',
          'برای هر دو نوع سی‌اس‌وی، از اکسل گزینه «CSV UTF-8» را انتخاب کنید تا حروف فارسی خراب نشود.',
        ],
        actions: [
          BackupActionItem(
            title: 'پرونده‌ها',
            subtitle: 'ثبت یا به‌روزرسانی پرونده از فایل سی‌اس‌وی',
            icon: FluentIcons.folder_arrow_up_24_regular,
            formatBadge: 'CSV',
            isPrimary: true,
            onTap: _tap(_startExcelImport),
          ),
          BackupActionItem(
            title: 'بدهی اعضا',
            subtitle: 'همگام‌سازی حق عضویت از فایل سی‌اس‌وی',
            icon: FluentIcons.wallet_24_regular,
            formatBadge: 'CSV',
            onTap: _tap(_startHaghImport),
          ),
          BackupActionItem(
            title: 'بازیابی مختصات',
            subtitle: 'تکمیل خودکار مختصات از روی آدرس',
            icon: FluentIcons.location_24_regular,
            onTap: _tap(_openGeocodeRecoveryDialog),
          ),
        ],
      ),
      BackupCategorySection(
        number: 3,
        title: 'حافظه محلی',
        subtitle: 'ذخیرهٔ کامل دادهٔ سرور روی دستگاه برای کار آفلاین',
        color: const Color(0xFF5D4037),
        icon: FluentIcons.phone_laptop_24_regular,
        helpIntro:
            'بکاپ کامل، پرونده‌ها، اسناد، تصاویر و فایل‌های وابسته را از سرور اصلی '
            'دریافت و در پایگاه داده محلی و پوشهٔ کش دستگاه ذخیره می‌کند.',
        helpSteps: const [
          'قبل از شروع مطمئن شوید اتصال اینترنت پایدار است؛ عملیات ممکن است زمان‌بر باشد.',
          '«شروع بکاپ کامل» را بزنید و هر دو مرحلهٔ تأیید را بپذیرید.',
          'کش محلی فعلی با دادهٔ تازهٔ سرور جایگزین می‌شود (نه ادغام جزئی).',
          'پس از اتمام، آمار حافظه محلی در بالای همین صفحه به‌روز می‌شود.',
        ],
        actions: [
          BackupActionItem(
            title: 'بکاپ اطلاعات سرور',
            subtitle: 'دریافت کامل و ذخیره در حافظه محلی',
            icon: Icons.cloud_download_rounded,
            isPrimary: true,
            onTap: _tap(_startBackupFlow),
          ),
        ],
      ),
      BackupCategorySection(
        number: 4,
        title: 'حذف اطلاعات',
        subtitle: 'پاک‌سازی حافظه محلی یا حذف دائم کل اتحادیه',
        color: const Color(0xFFC62828),
        icon: FluentIcons.delete_24_regular,
        helpIntro:
            'این عملیات‌ها غیرقابل بازگشت هستند. قبل از حذف، در صورت نیاز از بخش ۱ خروجی بگیرید.',
        helpSteps: const [
          'حذف از حافظه محلی: فقط دادهٔ ذخیره‌شده روی این دستگاه پاک می‌شود؛ سرور دست‌نخورده می‌ماند.',
          'حذف کامل اتحادیه: تمام پرونده‌ها و فایل‌ها از سرور و دستگاه برای همیشه حذف می‌شوند.',
          'حذف کامل سه مرحله تأیید و وارد کردن کد اتحادیه دارد — با دقت ادامه دهید.',
        ],
        actions: [
          BackupActionItem(
            title: 'حذف از حافظه محلی',
            subtitle: 'پاک‌سازی پایگاه محلی و فایل‌های کش دستگاه',
            icon: Icons.delete_sweep_rounded,
            onTap: _tap(_clearLocalDataFlow),
          ),
          BackupActionItem(
            title: 'حذف کامل اتحادیه',
            subtitle: 'حذف دائم از سرور + محلی (خطرناک)',
            icon: Icons.delete_forever_rounded,
            isDanger: true,
            onTap: _tap(_purgeUnionCompletelyFlow),
          ),
        ],
      ),
    ];

    return [
      for (final section in sections) ...[
        BackupCategoryCard(section: section),
        const SizedBox(height: 14),
      ],
    ];
  }

  Widget _statusBanner(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFE3F2FD),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1565C0).withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: BackupRtlText(
              message,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statsSection(DataBackupOverview overview) {
    Widget serverCard() => _statsCard(
          title: 'آمار سرور',
          subtitle: overview.server.fromCache
              ? 'از کش موقت خوانده شده'
              : 'دریافت‌شده از API آنلاین',
          color: const Color(0xFF1565C0),
          stats: [
            _StatItem('کل پرونده‌ها', overview.server.totalCases.toString(),
                Icons.folder_copy_outlined),
            _StatItem('پرونده فعال', overview.server.activeCases.toString(),
                Icons.check_circle_outline),
            _StatItem('حذف منطقی', overview.server.trashedCases.toString(),
                Icons.delete_outline),
            _StatItem('کل اسناد', overview.server.documentsCount.toString(),
                Icons.description_outlined),
            _StatItem(
                'دارای موقعیت',
                overview.server.withLocationCount.toString(),
                Icons.location_on_outlined),
            _StatItem('دارای بدهی', overview.server.debtorCount.toString(),
                Icons.account_balance_wallet_outlined),
            _StatItem(
                'دارای تصویر پروفایل',
                overview.server.profileImageCount.toString(),
                Icons.account_box_outlined),
          ],
          generatedAt: overview.server.generatedAt,
        );

    Widget localCard() => _statsCard(
          title: 'آمار حافظه محلی',
          subtitle: 'داده‌های SQLite و فایل‌های فیزیکی دستگاه',
          color: const Color(0xFF2E7D32),
          stats: [
            _StatItem('کل پرونده‌ها', overview.local.totalCases.toString(),
                Icons.folder_open_outlined),
            _StatItem('پرونده فعال', overview.local.activeCases.toString(),
                Icons.verified_outlined),
            _StatItem('حذف منطقی', overview.local.trashedCases.toString(),
                Icons.delete_sweep_outlined),
            _StatItem('کل اسناد', overview.local.documentsCount.toString(),
                Icons.file_copy_outlined),
            _StatItem(
                'دارای موقعیت',
                overview.local.withLocationCount.toString(),
                Icons.place_outlined),
            _StatItem('دارای بدهی', overview.local.debtorCount.toString(),
                Icons.payments_outlined),
            _StatItem(
                'تصویر پروفایل',
                overview.local.profileImageCount.toString(),
                Icons.badge_outlined),
            _StatItem(
                'فایل‌های فیزیکی',
                overview.local.mediaFilesOnDisk.toString(),
                Icons.perm_media_outlined),
            _StatItem('همگام‌شده', overview.local.syncedCount.toString(),
                Icons.cloud_done_outlined),
            _StatItem(
                'در انتظار ارسال',
                overview.local.pendingSyncCount.toString(),
                Icons.sync_problem_outlined),
          ],
          generatedAt: overview.local.generatedAt,
          footer: overview.cacheDirectory == null
              ? null
              : 'مسیر کش: ${overview.cacheDirectory}',
        );

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 980;
        if (wide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: serverCard()),
              const SizedBox(width: 14),
              Expanded(child: localCard()),
            ],
          );
        }
        return Column(
          children: [
            serverCard(),
            const SizedBox(height: 14),
            localCard(),
          ],
        );
      },
    );
  }

  Widget _statsCard({
    required String title,
    required String subtitle,
    required Color color,
    required List<_StatItem> stats,
    DateTime? generatedAt,
    String? footer,
  }) {
    return Card(
      elevation: 0,
      color: color.withValues(alpha: 0.06),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: color.withValues(alpha: 0.18)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: color,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: const TextStyle(
                            color: Colors.black54, fontSize: 12.5),
                      ),
                    ],
                  ),
                ),
                if (generatedAt != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      _formatDateTime(generatedAt),
                      style: const TextStyle(
                          fontSize: 11.5, fontWeight: FontWeight.w700),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: stats.map((item) => _metricTile(item, color)).toList(),
            ),
            if (footer != null && footer.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              SelectableText(
                isolateLatinForRtl(footer),
                textDirection: TextDirection.rtl,
                textAlign: TextAlign.right,
                style: const TextStyle(color: Colors.black54, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _metricTile(_StatItem item, Color color) {
    return Container(
      width: 180,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.label,
                  style: const TextStyle(
                      fontSize: 12.5,
                      color: Colors.black54,
                      fontWeight: FontWeight.w700),
                ),
              ),
              Icon(item.icon, size: 18, color: color),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            item.value,
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _progressCard({
    required String title,
    required BackupProgress? progress,
    required List<String> logs,
    bool compact = false,
  }) {
    return Card(
      elevation: 0,
      color: const Color(0xFFF7F9FC),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: EdgeInsets.all(compact ? 14 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title,
                style:
                    const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 10),
            BackupRtlText(progress?.message ?? 'در حال پردازش...',
                style: const TextStyle(height: 1.6)),
            const SizedBox(height: 12),
            LinearProgressIndicator(value: progress?.fraction),
            if ((progress?.total ?? 0) > 0) ...[
              const SizedBox(height: 8),
              Text(
                '${progress?.current ?? 0} / ${progress?.total ?? 0}',
                style: const TextStyle(
                    color: Colors.black54, fontWeight: FontWeight.w700),
              ),
            ],
            if (logs.isNotEmpty && !compact) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 10),
              ...logs.take(8).map(
                    (line) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        line,
                        style: const TextStyle(
                            fontSize: 12.5, color: Colors.black54),
                      ),
                    ),
                  ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime value) {
    final local = value.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(local.hour)}:${two(local.minute)} - ${local.year}/${two(local.month)}/${two(local.day)}';
  }
}

class _StatItem {
  const _StatItem(this.label, this.value, this.icon);

  final String label;
  final String value;
  final IconData icon;
}
