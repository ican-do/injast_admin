import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:injast_admin/import_sync/asnaf_bot_client.dart';
import 'package:injast_admin/import_sync/asnaf_first_five_test_report_store.dart';
import 'package:injast_admin/import_sync/asnaf_recovery_store.dart';
import 'package:injast_admin/import_sync/import_draft_store.dart';
import 'package:injast_admin/import_sync/import_models.dart';
import 'package:injast_admin/import_sync/import_sync_api.dart';
import 'package:url_launcher/url_launcher.dart';

/// تعداد صفحات انتهایی API برای حالت «بروزرسانی جدیدترین موارد».
const int _kAsnafLatestPagesWindow = 6;

class _RecoveryProgressItem {
  const _RecoveryProgressItem({
    required this.id,
    required this.subtitle,
    required this.kind,
  });

  final String id;
  final String subtitle;
  /// ok | skip | error
  final String kind;
}

class AsnafSitePage extends StatefulWidget {
  const AsnafSitePage({
    super.key,
    required this.codeCo,
    required this.userName,
    required this.userCode,
    required this.unionName,
  });

  final String codeCo;
  final String userName;
  final String userCode;
  final String unionName;

  @override
  State<AsnafSitePage> createState() => _AsnafSitePageState();
}

class _AsnafSitePageState extends State<AsnafSitePage> {
  final _bot = AsnafBotClient();
  final _draftStore = ImportDraftStore();
  final _syncApi = ImportSyncApi.instance;
  final _stateStore = AsnafRecoveryStore();
  final _firstFiveTestReportStore = AsnafFirstFiveTestReportStore();

  bool _busy = false;
  bool _stopRequested = false;
  bool _paused = false;
  /// پس از پایان یک دور بازیابی (توقف، خطا، یا اتمام) امکان «ذخیره در سرور» از داخل دیالوگ.
  bool _recoveryEndedAllowingSave = false;
  int _totalCount = 0;
  int _draftCount = 0;
  String _operationStatus = 'منتظر لاگین به وب سایت';

  InAppWebViewController? _webController;
  bool _dialogOpen = false;

  // For dialog UI only (hidden from body).
  int _processedCount = 0;
  int _failedCount = 0;
  int _sessionSkippedCount = 0;
  int _sessionNewSavedCount = 0;
  int _sessionDebtZeroSkipped = 0;
  String _currentRecord = '—';

  final List<String> _logs = [];
  final List<_RecoveryProgressItem> _recoveryProgress = [];
  final ScrollController _recoveryProgressScrollCtrl = ScrollController();

  /// آیا حداقل یک گزارش تست ۵ پرونده در حافظهٔ محلی ذخیره شده است.
  bool _hasSavedFirstFiveTestReport = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadState());
    unawaited(_refreshFirstFiveTestReportFlag());
  }

  @override
  void dispose() {
    _recoveryProgressScrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _waitWhilePaused() async {
    while (mounted && _paused && !_stopRequested) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
  }

  void _scrollRecoveryProgressToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final c = _recoveryProgressScrollCtrl;
      if (!c.hasClients) return;
      c.jumpTo(c.position.maxScrollExtent);
    });
  }

  void _pushRecoveryProgress(String id, String kind, String subtitle) {
    setState(() {
      _recoveryProgress.add(_RecoveryProgressItem(id: id, subtitle: subtitle, kind: kind));
      if (_recoveryProgress.length > 500) {
        _recoveryProgress.removeRange(0, _recoveryProgress.length - 500);
      }
    });
    _scrollRecoveryProgressToEnd();
  }

  Future<void> _refreshFirstFiveTestReportFlag() async {
    final r = await _firstFiveTestReportStore.read();
    if (!mounted) return;
    setState(() => _hasSavedFirstFiveTestReport = r != null);
  }

  Future<void> _openSavedFirstFiveTestReport() async {
    final r = await _firstFiveTestReportStore.read();
    if (!mounted) return;
    if (r == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('گزارش تست ذخیره‌شده‌ای وجود ندارد.')),
      );
      return;
    }
    await _showFirstFiveTestReportSheet(r);
  }

  Future<void> _showFirstFiveTestReportSheet(AsnafFirstFiveTestReport report) async {
    if (!mounted) return;
    final theme = Theme.of(context);
    final when = DateTime.fromMillisecondsSinceEpoch(report.savedAtMs).toLocal();
    final timeStr =
        '${when.year.toString().padLeft(4, '0')}-${when.month.toString().padLeft(2, '0')}-${when.day.toString().padLeft(2, '0')} '
        '${when.hour.toString().padLeft(2, '0')}:${when.minute.toString().padLeft(2, '0')}';

    Widget kv(String label, String value) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 118,
                child: Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12.5,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              Expanded(
                child: SelectableText(
                  value.isEmpty ? '—' : value,
                  style: const TextStyle(fontSize: 13.5, height: 1.25),
                ),
              ),
            ],
          ),
        );

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.9,
          minChildSize: 0.45,
          maxChildSize: 0.96,
          builder: (ctx, scroll) {
            final okList = report.entries.where((e) => e.ok && !e.skippedDebtOnly).toList();
            final failList = report.entries.where((e) => !e.ok).toList();
            String neshanClientSummary() {
              final v = report.neshanKeyConfiguredWhenRun;
              if (v == null) {
                return 'در این نسخهٔ گزارش ثبت نشده (گزارش قدیمی قبل از به‌روزرسانی اپ).';
              }
              if (!v) {
                return 'خیر — بدون --dart-define=NESHAN_API_KEY ژئوکد داخل اپ Flutter اجرا نمی‌شود. '
                    'طبق مستند بک‌اند، تکمیل مختصات معمولاً روی سرور (updateCoordinates / api.neshan.org) انجام می‌شود، نه لزوماً در همین کلاینت.';
              }
              return 'بله — کلید هنگام بیلد تزریق شده؛ اگر برای برخی پرونده‌ها مختصات خالی است، '
                  'علت را در پاسخ API نشان یا کیفیت آدرس ببینید.';
            }

            return ListView(
              controller: scroll,
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
              children: [
                Text(
                  report.debtTestMode
                      ? 'گزارش تست ۵ پروندهٔ دارای بدهی (اسکن تا ۵ مورد با بدهی غیرصفر)'
                      : 'گزارش تست ۵ پروندهٔ اول',
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '۱) جمع‌بندی',
                          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 10),
                        kv('زمان اجرا', timeStr),
                        kv('اتحادیه', report.unionName),
                        kv('کد شرکت', report.codeCo),
                        kv('تعداد کل پرونده‌ها (متای API)', '${report.metaTotalCount}'),
                        kv('تعداد صفحات لیست', '${report.metaTotalPages}'),
                        kv('هدف تست', '${report.targetPlanned} پرونده'),
                        kv('جایگاه‌های پیمایش‌شده', '${report.dossierSlotsFilled}'),
                        kv('موفق', '${report.successCount}'),
                        kv('خطا', '${report.failCount}'),
                        if (report.debtTestMode) kv('رد — بدهی صفر', '${report.skippedDebtZeroCount}'),
                        kv('ژئوکد نشان در کلاینت Flutter', neshanClientSummary()),
                        if (report.fatalError != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            'خطای کلی: ${report.fatalError}',
                            style: TextStyle(color: theme.colorScheme.error, fontSize: 13),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  report.debtTestMode
                      ? '۲) پرونده‌های با بدهی (ذخیره در لیست موقت)'
                      : '۲) پرونده‌های موفق (جزئیات، اسناد، مختصات)',
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                if (okList.isEmpty)
                  Text(
                    'موردی ثبت نشد.',
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                  )
                else
                  ...okList.map((e) {
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ExpansionTile(
                        initiallyExpanded: okList.length == 1,
                        title: Text(
                          'شناسه ${e.parvanehId}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          e.adminFullName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                        children: [
                          kv('نام و نام خانوادگی', e.adminFullName),
                          kv('نام واحد صنفی', e.nameStore ?? ''),
                          kv('آدرس', e.addressStore ?? ''),
                          kv('رسته', e.rasteLine),
                          kv('تعداد اسناد ذخیره‌شده', '${e.documentsCount}'),
                          kv('مختصات (عرض، طول)', e.coordsLine),
                          kv('وضعیت مختصات', e.coordsStatus),
                        ],
                      ),
                    );
                  }),
                const SizedBox(height: 14),
                Text(
                  '۳) موارد خطادار',
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                if (failList.isEmpty)
                  Text(
                    'خطایی برای این اجرا ثبت نشد.',
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                  )
                else
                  ...failList.map(
                    (e) => Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text('شناسه ${e.parvanehId}', style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: SelectableText(e.error ?? '—'),
                        leading: Icon(Icons.error_outline, color: theme.colorScheme.error),
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                Text(
                  'این گزارش در حافظهٔ محلی دستگاه ذخیره شده و از نوار بالا قابل بازگشایی است.',
                  style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _loadState() async {
    final records = await _draftStore.read();
    final state = await _stateStore.readState();
    if (!mounted) return;
    setState(() {
      _draftCount = records.length;
      _totalCount = state?.totalPlanned ?? 0;
    });
  }

  void _appendLog(String line) {
    developer.log(line, name: 'AsnafSite');
    _logs.insert(0, line);
    if (_logs.length > 120) {
      _logs.removeRange(120, _logs.length);
    }
  }

  Future<String> _readToken() async => _stateStore.readJwt();

  Future<void> _extractAndSaveToken({bool silent = false}) async {
    final c = _webController;
    if (c == null) return;
    setState(() => _busy = true);
    try {
      const js = '''
(() => {
  const candidates = ['token', 'access_token', 'Authorization', 'authorization', 'jwt', 'authToken'];
  const storage = window.localStorage || {};
  let selected = '';
  for (const k of candidates) {
    const v = storage.getItem(k);
    if (v && v.trim()) { selected = v.trim(); break; }
  }
  if (!selected) {
    for (let i = 0; i < storage.length; i++) {
      const k = storage.key(i);
      const v = storage.getItem(k);
      if (!k || !v) continue;
      const lk = k.toLowerCase();
      if (lk.includes('token') || lk.includes('auth') || lk.includes('jwt')) {
        selected = v.trim();
        break;
      }
    }
  }
  if (selected.toLowerCase().startsWith('bearer ')) selected = selected.substring(7).trim();
  if (selected.toLowerCase().startsWith('jwt ')) selected = selected.substring(4).trim();
  return JSON.stringify({ token: selected });
})();
''';
      final raw = await c.evaluateJavascript(source: js);
      final text = raw?.toString() ?? '';
      final decoded = jsonDecode(text);
      final token = (decoded is Map ? decoded['token'] : null)?.toString().trim() ?? '';
      if (token.isEmpty) {
        _appendLog('JWT not found; login required.');
        setState(() => _operationStatus = 'منتظر لاگین به وب سایت');
        if (!silent && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                kIsWeb
                    ? 'ورود خودکار فقط در نسخه دسکتاپ فعال است.'
                    : 'ابتدا در سایت لاگین کنید.',
              ),
            ),
          );
        }
        return;
      }
      await _stateStore.saveJwt(token);
      _appendLog('JWT saved in hidden storage.');
      setState(() => _operationStatus = 'لاگین انجام شد');
    } catch (e) {
      _appendLog('Token extract error: $e');
      if (!silent && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطا در بررسی لاگین: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _startFlow({required bool full}) async {
    var token = await _readToken();
    if (token.isEmpty) {
      // Silent token extraction from the same page WebView.
      await _extractAndSaveToken();
      token = await _readToken();
      if (token.isEmpty) return;
    }

    final meta = await _bot.fetchMeta(token);
    final estimatedHours = (meta.totalCount / 300).toStringAsFixed(1);
    if (!mounted) return;
    final start = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(full ? 'بروزرسانی کامل اطلاعات' : 'بروزرسانی جدیدترین موارد'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('تعداد پرونده‌ها: ${meta.totalCount}'),
            Text('مدت زمان تخمینی: حدود $estimatedHours ساعت'),
            const SizedBox(height: 8),
            const Text('توضیحات عملیات در نسخه بعدی تکمیل می‌شود.'),
            if (!full) ...[
              const SizedBox(height: 10),
              Text(
                'در این حالت فقط $_kAsnafLatestPagesWindow صفحهٔ آخر لیست پرونده‌ها از API پردازش می‌شود.',
                style: TextStyle(
                  fontSize: 12.5,
                  color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (full) ...[
              const SizedBox(height: 12),
              Text(
                'با «تست ۵ پروندهٔ اول» همان مسیر کامل (جزئیات پرونده، اسناد و مختصات از روی آدرس) فقط برای پنج پروندهٔ ابتدای لیست اجرا می‌شود.',
                style: TextStyle(
                  fontSize: 12.5,
                  color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('انصراف')),
          if (full)
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'test_first_5'),
              child: const Text('تست ۵ پروندهٔ اول'),
            ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, 'start'),
            child: const Text('شروع عملیات'),
          ),
        ],
      ),
    );
    if (!mounted || start == null) return;

    if (start == 'test_first_5') {
      await _runTestFirstFiveRecords(token: token, meta: meta);
      return;
    }

    if (start != 'start') return;

    final warn = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('هشدار قبل از شروع'),
        content: const Text(
          'عملیات زمان‌بر است. تا پایان، پنجره برنامه و اینترنت را قطع نکنید.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('بازگشت')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('تایید و شروع')),
        ],
      ),
    );
    if (warn != true) return;

    final recoveryMode = full ? 'full' : 'latest';
    setState(() {
      _operationStatus = full
          ? 'عملیات بروز رسانی کامل اطلاعات در حال انجام است'
          : 'عملیات بروز رسانی جدیدترین موارد در حال انجام است';
      _processedCount = 0;
      _failedCount = 0;
      _sessionSkippedCount = 0;
      _sessionNewSavedCount = 0;
      _sessionDebtZeroSkipped = 0;
      _currentRecord = 'شروع عملیات...';
      _recoveryProgress.clear();
      _paused = false;
      _recoveryEndedAllowingSave = false;
    });
    if (!_dialogOpen) {
      _dialogOpen = true;
      unawaited(_showOperationDialog(recoveryMode: recoveryMode));
    }
    unawaited(_runRecovery(recoveryMode: recoveryMode, token: token, freshMeta: meta));
  }

  Future<void> _startDebtFlow() async {
    var token = await _readToken();
    if (token.isEmpty) {
      await _extractAndSaveToken();
      token = await _readToken();
      if (token.isEmpty) return;
    }

    final meta = await _bot.fetchMeta(token);
    final estimatedHours = (meta.totalCount / 600).toStringAsFixed(1);
    if (!mounted) return;
    final start = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('بروزرسانی بدهی پرونده‌ها'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('تعداد پرونده‌ها در لیست API: ${meta.totalCount}'),
            Text('تخمین زمان (سبک‌تر از بروزرسانی کامل): حدود $estimatedHours ساعت'),
            const SizedBox(height: 10),
            Text(
              'برای هر پرونده ابتدا بدهی از API بررسی می‌شود؛ اگر صفر باشد رد می‌شود. '
              'فقط موارد با بدهی غیرصفر در «لیست موقت» ذخیره می‌شوند. '
              'با «ذخیره در سرور»، اگر شناسه صنفی و code_co با پروندهٔ موجود یکی باشد فقط بدهی (money) به‌روز می‌شود؛ '
              'اگر پرونده‌ای با آن شناسه صنفی در دیتابیس نباشد، همان رکورد به‌عنوان پروندهٔ جدید درج می‌شود.',
              style: TextStyle(
                fontSize: 12.5,
                height: 1.35,
                color: Theme.of(ctx).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '«تست ۵ پروندهٔ دارای بدهی» تا پنج مورد با بدهی غیرصفر را از ابتدای لیست پیدا کرده و ذخیره می‌کند (بدون اسناد و ژئوکد).',
              style: TextStyle(
                fontSize: 12.5,
                color: Theme.of(ctx).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('انصراف')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'test_first_5_debt'),
            child: const Text('تست ۵ پروندهٔ دارای بدهی'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, 'start'),
            child: const Text('شروع عملیات'),
          ),
        ],
      ),
    );
    if (!mounted || start == null) return;

    if (start == 'test_first_5_debt') {
      await _runTestFirstFiveDebtRecords(token: token, meta: meta);
      return;
    }
    if (start != 'start') return;

    final warn = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('هشدار قبل از شروع'),
        content: const Text(
          'عملیات زمان‌بر است. تا پایان، پنجره برنامه و اینترنت را قطع نکنید.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('بازگشت')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('تایید و شروع')),
        ],
      ),
    );
    if (warn != true) return;

    setState(() {
      _operationStatus = 'عملیات بروز رسانی بدهی پرونده‌ها در حال انجام است';
      _processedCount = 0;
      _failedCount = 0;
      _sessionSkippedCount = 0;
      _sessionNewSavedCount = 0;
      _sessionDebtZeroSkipped = 0;
      _currentRecord = 'شروع عملیات...';
      _recoveryProgress.clear();
      _paused = false;
      _recoveryEndedAllowingSave = false;
    });
    if (!_dialogOpen) {
      _dialogOpen = true;
      unawaited(_showOperationDialog(recoveryMode: 'debt_full'));
    }
    unawaited(_runRecovery(recoveryMode: 'debt_full', token: token, freshMeta: meta));
  }

  /// همان مسیر [buildDraftRecord] عملیات کامل (جزئیات، اسناد، ژئوکد) برای پنج پروندهٔ اول لیست API.
  Future<void> _runTestFirstFiveRecords({
    required String token,
    required AsnafMeta meta,
  }) async {
    setState(() {
      _busy = true;
      _operationStatus = 'در حال تست ۵ پروندهٔ اول...';
    });
    _appendLog('Test first 5 | totalPages=${meta.totalPages}');
    var ok = 0;
    var fail = 0;
    final entries = <AsnafFirstFiveTestEntry>[];
    final neshanOk = _bot.isNeshanGeocodingConfigured;
    try {
      final existing = await _draftStore.read();
      final drafts = <ImportDraftRecord>[...existing];
      const target = 5;
      var collected = 0;
      var page = 1;

      while (collected < target && page <= meta.totalPages) {
        final rows = await _bot.fetchParvandehPage(token: token, page: page);
        if (rows.isEmpty) break;
        for (var i = 0; i < rows.length && collected < target; i++) {
          final row = rows[i] is Map ? rows[i] as Map : const {};
          final id = row['id']?.toString() ?? '';
          if (id.isEmpty) continue;
          collected++;
          if (!mounted) return;
          setState(() => _currentRecord = id);
          try {
            final record = await _bot.buildDraftRecord(
              token: token,
              codeCo: widget.codeCo,
              parvanehId: id,
              includeDocs: true,
              geocodeIfMissing: true,
            );
            final idx = drafts.indexWhere((e) => e.clientTempId == id);
            if (idx >= 0) {
              drafts[idx] = record;
            } else {
              drafts.add(record);
            }
            await _draftStore.save(drafts);
            ok++;
            entries.add(AsnafFirstFiveTestEntry.fromSuccess(record, neshanKeyConfigured: neshanOk));
            _appendLog('Test first-5 OK id=$id');
          } catch (e) {
            fail++;
            entries.add(AsnafFirstFiveTestEntry.failure(id, e));
            _appendLog('Test first-5 ERROR id=$id | $e');
          }
        }
        page++;
      }

      if (collected < target) {
        _appendLog('Test first 5: only $collected dossiers in API range (expected $target).');
      }

      if (!mounted) return;
      setState(() {
        _operationStatus = fail == 0
            ? 'تست ۵ پروندهٔ اول موفق بود ($ok مورد)'
            : 'تست ۵ پروندهٔ اول: $ok موفق، $fail خطا';
        _draftCount = drafts.length;
      });

      final report = AsnafFirstFiveTestReport(
        savedAtMs: DateTime.now().millisecondsSinceEpoch,
        metaTotalCount: meta.totalCount,
        metaTotalPages: meta.totalPages,
        codeCo: widget.codeCo,
        unionName: widget.unionName,
        targetPlanned: target,
        dossierSlotsFilled: collected,
        entries: entries,
        neshanKeyConfiguredWhenRun: neshanOk,
      );
      await _firstFiveTestReportStore.save(report);
      if (!mounted) return;
      setState(() => _hasSavedFirstFiveTestReport = true);
      await _showFirstFiveTestReportSheet(report);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('گزارش تست در حافظهٔ محلی ذخیره شد؛ جزئیات در پنجرهٔ بالا نمایش داده شد.'),
          duration: Duration(seconds: 4),
        ),
      );
    } catch (e) {
      _appendLog('Test first 5 fatal: $e');
      if (mounted) {
        setState(() => _operationStatus = 'خطا در تست ۵ پروندهٔ اول');
        final report = AsnafFirstFiveTestReport(
          savedAtMs: DateTime.now().millisecondsSinceEpoch,
          metaTotalCount: meta.totalCount,
          metaTotalPages: meta.totalPages,
          codeCo: widget.codeCo,
          unionName: widget.unionName,
          targetPlanned: 5,
          dossierSlotsFilled: entries.length,
          entries: entries,
          fatalError: e.toString(),
          neshanKeyConfiguredWhenRun: neshanOk,
        );
        await _firstFiveTestReportStore.save(report);
        if (!mounted) return;
        setState(() => _hasSavedFirstFiveTestReport = true);
        await _showFirstFiveTestReportSheet(report);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطا در تست: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        await _loadState();
        await _refreshFirstFiveTestReportFlag();
      }
    }
  }

  /// تا ۵ پرونده با بدهی غیرصفر از ابتدای لیست (بدون اسناد و ژئوکد).
  Future<void> _runTestFirstFiveDebtRecords({
    required String token,
    required AsnafMeta meta,
  }) async {
    setState(() {
      _busy = true;
      _operationStatus = 'در حال تست ۵ پروندهٔ دارای بدهی...';
    });
    _appendLog('Test first 5 debt | totalPages=${meta.totalPages}');
    var ok = 0;
    var fail = 0;
    var skippedDebt = 0;
    final entries = <AsnafFirstFiveTestEntry>[];
    final neshanOk = _bot.isNeshanGeocodingConfigured;
    try {
      final existing = await _draftStore.read();
      final drafts = <ImportDraftRecord>[...existing];
      const targetSaved = 5;
      var examined = 0;
      var page = 1;

      while (ok < targetSaved && page <= meta.totalPages) {
        final rows = await _bot.fetchParvandehPage(token: token, page: page);
        if (rows.isEmpty) break;
        for (var i = 0; i < rows.length && ok < targetSaved; i++) {
          final row = rows[i] is Map ? rows[i] as Map : const {};
          final id = row['id']?.toString() ?? '';
          if (id.isEmpty) continue;
          examined++;
          if (!mounted) return;
          setState(() => _currentRecord = id);
          try {
            final record = await _bot.buildDebtOnlyDraftIfNonZeroDebt(
              token: token,
              codeCo: widget.codeCo,
              parvanehId: id,
            );
            if (record == null) {
              skippedDebt++;
              entries.add(AsnafFirstFiveTestEntry.skippedDebtZero(id));
              _appendLog('Test debt skip zero id=$id');
            } else {
              final idx = drafts.indexWhere((e) => e.clientTempId == id);
              if (idx >= 0) {
                drafts[idx] = record;
              } else {
                drafts.add(record);
              }
              await _draftStore.save(drafts);
              ok++;
              entries.add(AsnafFirstFiveTestEntry.fromSuccess(record, neshanKeyConfigured: neshanOk));
              _appendLog('Test debt OK id=$id money=${record.payload['money']}');
            }
          } catch (e) {
            fail++;
            entries.add(AsnafFirstFiveTestEntry.failure(id, e));
            _appendLog('Test debt ERROR id=$id | $e');
          }
        }
        page++;
      }

      if (!mounted) return;
      setState(() {
        _operationStatus = fail == 0
            ? 'تست بدهی: $ok پرونده با بدهی ذخیره شد؛ $skippedDebt مورد بدهی صفر رد شد'
            : 'تست بدهی: $ok موفق، $fail خطا؛ $skippedDebt بدهی صفر';
        _draftCount = drafts.length;
      });

      final report = AsnafFirstFiveTestReport(
        savedAtMs: DateTime.now().millisecondsSinceEpoch,
        metaTotalCount: meta.totalCount,
        metaTotalPages: meta.totalPages,
        codeCo: widget.codeCo,
        unionName: widget.unionName,
        targetPlanned: targetSaved,
        dossierSlotsFilled: examined,
        entries: entries,
        neshanKeyConfiguredWhenRun: neshanOk,
        debtTestMode: true,
      );
      await _firstFiveTestReportStore.save(report);
      if (!mounted) return;
      setState(() => _hasSavedFirstFiveTestReport = true);
      await _showFirstFiveTestReportSheet(report);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('گزارش تست بدهی ذخیره شد.'),
          duration: Duration(seconds: 4),
        ),
      );
    } catch (e) {
      _appendLog('Test debt fatal: $e');
      if (mounted) {
        setState(() => _operationStatus = 'خطا در تست بدهی');
        final report = AsnafFirstFiveTestReport(
          savedAtMs: DateTime.now().millisecondsSinceEpoch,
          metaTotalCount: meta.totalCount,
          metaTotalPages: meta.totalPages,
          codeCo: widget.codeCo,
          unionName: widget.unionName,
          targetPlanned: 5,
          dossierSlotsFilled: entries.length,
          entries: entries,
          fatalError: e.toString(),
          neshanKeyConfiguredWhenRun: neshanOk,
          debtTestMode: true,
        );
        await _firstFiveTestReportStore.save(report);
        if (!mounted) return;
        setState(() => _hasSavedFirstFiveTestReport = true);
        await _showFirstFiveTestReportSheet(report);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطا در تست بدهی: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        await _loadState();
        await _refreshFirstFiveTestReportFlag();
      }
    }
  }

  Future<void> _showOperationDialog({required String recoveryMode}) async {
    bool canResumeRecovery() {
      final s = _operationStatus;
      return s.contains('متوقف') || s.contains('خطا در عملیات');
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final screenH = MediaQuery.of(ctx).size.height;
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
          child: SizedBox(
            width: 660,
            height: (screenH * 0.88).clamp(440.0, 920.0),
            child: StatefulBuilder(
              builder: (context, setLocal) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        switch (recoveryMode) {
                          'full' => 'عملیات بروزرسانی کامل اطلاعات',
                          'latest' => 'عملیات بروزرسانی جدیدترین موارد',
                          'debt_full' => 'عملیات بروزرسانی بدهی پرونده‌ها',
                          'debt_latest' => 'عملیات بروزرسانی بدهی پرونده‌ها',
                          _ => 'عملیات',
                        },
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: StreamBuilder<int>(
                          stream: Stream<int>.periodic(const Duration(milliseconds: 500), (i) => i),
                          builder: (_, _) {
                            final done = _processedCount + _failedCount;
                            final progress = _totalCount > 0 ? (done / _totalCount).clamp(0.0, 1.0) : null;
                            final remain = _totalCount > 0 ? (_totalCount - done).clamp(0, 1 << 30) : 0;
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('وضعیت: $_operationStatus', maxLines: 3),
                                const SizedBox(height: 6),
                                Text('پرونده جاری: $_currentRecord'),
                                const SizedBox(height: 6),
                                Text(
                                  'مانده (تخمینی در برنامه): $remain | '
                                  'پردازش‌شده: $done | خطا: $_failedCount',
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'این اجرا — جدید در موقت: $_sessionNewSavedCount | '
                                  'ردشده (قبلاً در لیست): $_sessionSkippedCount'
                                  '${recoveryMode == 'debt_full' || recoveryMode == 'debt_latest' ? ' | بدهی صفر (رد): $_sessionDebtZeroSkipped' : ''}',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                LinearProgressIndicator(value: progress),
                                const SizedBox(height: 8),
                                Text(
                                  'پیشرفت پرونده‌ها (${_recoveryProgress.length})',
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                ),
                                const SizedBox(height: 6),
                                Expanded(
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Theme.of(context).dividerColor),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: _recoveryProgress.isEmpty
                                        ? const Center(child: Text('هنوز ردیفی ثبت نشده است.'))
                                        : ListView.builder(
                                            controller: _recoveryProgressScrollCtrl,
                                            padding: const EdgeInsets.symmetric(vertical: 4),
                                            itemCount: _recoveryProgress.length,
                                            itemBuilder: (_, i) {
                                              final it = _recoveryProgress[i];
                                              final icon = it.kind == 'error'
                                                  ? Icons.error_outline
                                                  : it.kind == 'skip'
                                                      ? Icons.skip_next_outlined
                                                      : Icons.check_circle_outline;
                                              final color = it.kind == 'error'
                                                  ? Theme.of(context).colorScheme.error
                                                  : it.kind == 'skip'
                                                      ? Theme.of(context).colorScheme.outline
                                                      : Theme.of(context).colorScheme.primary;
                                              return ListTile(
                                                dense: true,
                                                leading: Icon(icon, color: color, size: 22),
                                                title: Text('شناسه ${it.id}', style: const TextStyle(fontWeight: FontWeight.w600)),
                                                subtitle: Text(
                                                  it.subtitle,
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                onTap: () {
                                                  showDialog<void>(
                                                    context: context,
                                                    builder: (dCtx) => AlertDialog(
                                                      title: Text('جزئیات ${it.id}'),
                                                      content: SingleChildScrollView(
                                                        child: SelectableText(
                                                          'وضعیت: ${it.kind == 'ok' ? 'ذخیره در موقت' : it.kind == 'skip' ? 'رد — از قبل در لیست' : 'خطا'}\n'
                                                          '${it.subtitle}',
                                                        ),
                                                      ),
                                                      actions: [
                                                        TextButton(
                                                          onPressed: () => Navigator.pop(dCtx),
                                                          child: const Text('بستن'),
                                                        ),
                                                      ],
                                                    ),
                                                  );
                                                },
                                              );
                                            },
                                          ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                SizedBox(
                                  height: 72,
                                  child: _logs.isEmpty
                                      ? const Center(child: Text('لاگ فنی', style: TextStyle(fontSize: 11)))
                                      : ListView.builder(
                                          itemCount: _logs.length > 12 ? 12 : _logs.length,
                                          itemBuilder: (_, i) => Text(
                                            _logs[i],
                                            style: const TextStyle(fontSize: 10.5),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                      const Divider(height: 16),
                      Wrap(
                        alignment: WrapAlignment.end,
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          FilledButton.tonal(
                            onPressed: (_busy && !_stopRequested)
                                ? () async {
                                    final ok = await showDialog<bool>(
                                      context: context,
                                      builder: (dCtx) => AlertDialog(
                                        title: const Text('توقف کامل عملیات'),
                                        content: const Text(
                                          'عملیات استخراج متوقف می‌شود و از حالت در حال اجرا خارج می‌گردید.\n'
                                          'می‌توانید بعداً با «شروع مجدد» از همان نقطهٔ ذخیره‌شده ادامه دهید.\n'
                                          'آیا مطمئن هستید؟',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(dCtx, false),
                                            child: const Text('خیر'),
                                          ),
                                          FilledButton(
                                            onPressed: () => Navigator.pop(dCtx, true),
                                            child: const Text('بله، توقف کامل'),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (ok != true) return;
                                    if (!mounted) return;
                                    _paused = false;
                                    _stopRequested = true;
                                    setState(() => _operationStatus = 'در حال توقف کامل...');
                                    setLocal(() {});
                                  }
                                : null,
                            child: const Text('توقف کامل'),
                          ),
                          FilledButton.tonal(
                            onPressed: (_busy && !_stopRequested && !_paused)
                                ? () {
                                    _paused = true;
                                    setState(() => _operationStatus = 'متوقف موقت — برای ادامه «شروع مجدد» را بزنید');
                                    setLocal(() {});
                                  }
                                : null,
                            child: const Text('توقف موقت'),
                          ),
                          FilledButton.tonal(
                            onPressed: ((_busy && _paused) || (!_busy && canResumeRecovery()))
                                ? () async {
                                    if (_busy && _paused) {
                                      _paused = false;
                                      setState(() => _operationStatus = 'ادامه پس از توقف موقت...');
                                      setLocal(() {});
                                      return;
                                    }
                                    final token = await _readToken();
                                    if (token.isEmpty) return;
                                    final meta = await _bot.fetchMeta(token);
                                    if (!mounted) return;
                                    setState(() => _operationStatus = 'شروع مجدد از آخرین پروندهٔ ذخیره‌شده');
                                    unawaited(_runRecovery(recoveryMode: recoveryMode, token: token, freshMeta: meta));
                                    setLocal(() {});
                                  }
                                : null,
                            child: Text(_busy && _paused ? 'ادامه از توقف موقت' : 'شروع مجدد'),
                          ),
                          FilledButton.tonal(
                            onPressed: () async {
                              await _showDraftList();
                              if (!mounted) return;
                              setLocal(() {});
                            },
                            child: const Text('بررسی لیست'),
                          ),
                          FilledButton(
                            onPressed: (!_busy &&
                                    _recoveryEndedAllowingSave &&
                                    _draftCount > 0)
                                ? () async {
                                    await _sendToServer();
                                    if (!mounted) return;
                                    setLocal(() {});
                                  }
                                : null,
                            child: const Text('ذخیره اطلاعات'),
                          ),
                          TextButton(
                            onPressed: _busy
                                ? null
                                : () {
                                    _dialogOpen = false;
                                    Navigator.pop(ctx);
                                  },
                            child: const Text('خروج'),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
    _dialogOpen = false;
  }

  Future<void> _runRecovery({
    required String recoveryMode,
    required String token,
    required AsnafMeta freshMeta,
  }) async {
    var lastPersistedPage = 1;
    var lastPersistedIndexInPage = 0;

    final fullWindow = recoveryMode == 'full' || recoveryMode == 'debt_full';
    final debtOnly = recoveryMode == 'debt_full' || recoveryMode == 'debt_latest';

    setState(() {
      _busy = true;
      _stopRequested = false;
      _recoveryEndedAllowingSave = false;
    });
    _appendLog('Recovery started | mode=$recoveryMode');

    try {
      final totalPages = freshMeta.totalPages;
      final startPage = fullWindow
          ? 1
          : (totalPages > _kAsnafLatestPagesWindow
              ? totalPages - (_kAsnafLatestPagesWindow - 1)
              : 1);
      final endPage = totalPages;
      final currentState = await _stateStore.readState();
      final resume = currentState != null &&
          currentState.running &&
          currentState.mode == recoveryMode &&
          currentState.startPage == startPage &&
          currentState.endPage == endPage;
      late int currentPage;
      late int currentIndex;
      late int processed;
      late int failed;
      if (resume) {
        currentPage = currentState.currentPage;
        currentIndex = currentState.currentIndexInPage;
        processed = currentState.processedCount;
        failed = currentState.failedCount;
      } else {
        currentPage = startPage;
        currentIndex = 0;
        processed = 0;
        failed = 0;
      }

      lastPersistedPage = currentPage;
      lastPersistedIndexInPage = currentIndex;

      setState(() {
        _sessionSkippedCount = 0;
        _sessionNewSavedCount = 0;
        _sessionDebtZeroSkipped = 0;
        _processedCount = processed;
        _failedCount = failed;
      });

      final existing = await _draftStore.read();
      final drafts = <ImportDraftRecord>[...existing];
      final knownIds = existing.map((e) => e.clientTempId).toSet();

      if (!debtOnly) {
        _appendLog('Step 1: fetch raste list');
        await _bot.fetchAllRaste(token);
      }

      final pageSpan = endPage - startPage + 1;
      final estPerPage =
          freshMeta.totalPages > 0 ? freshMeta.totalCount / freshMeta.totalPages : 0.0;
      setState(() {
        _totalCount = fullWindow
            ? freshMeta.totalCount
            : (estPerPage * pageSpan).round().clamp(1, freshMeta.totalCount);
      });

      for (var page = currentPage; page <= endPage; page++) {
        await _waitWhilePaused();
        if (_stopRequested) break;
        final rows = await _bot.fetchParvandehPage(token: token, page: page);
        _appendLog('Page $page loaded with ${rows.length} rows');
        final startIndex = (page == currentPage) ? currentIndex : 0;
        for (var i = startIndex; i < rows.length; i++) {
          await _waitWhilePaused();
          if (_stopRequested) break;
          final row = rows[i] is Map ? rows[i] as Map : const {};
          final id = row['id']?.toString() ?? '';
          if (id.isEmpty) continue;
          setState(() => _currentRecord = id);
          if (knownIds.contains(id)) {
            processed++;
            _processedCount = processed;
            setState(() => _sessionSkippedCount++);
            _pushRecoveryProgress(id, 'skip', 'قبلاً در لیست موقت بود — رد شد');
            await _stateStore.saveState(
              AsnafRecoveryState(
                mode: recoveryMode,
                startPage: startPage,
                endPage: endPage,
                currentPage: page,
                currentIndexInPage: i + 1,
                processedCount: processed,
                failedCount: failed,
                totalPlanned: _totalCount,
                running: true,
              ),
            );
            lastPersistedPage = page;
            lastPersistedIndexInPage = i + 1;
            if (!mounted) return;
            setState(() {
              _draftCount = drafts.length;
              _processedCount = processed;
              _failedCount = failed;
            });
            continue;
          }

          try {
            if (debtOnly) {
              final record = await _bot.buildDebtOnlyDraftIfNonZeroDebt(
                token: token,
                codeCo: widget.codeCo,
                parvanehId: id,
              );
              processed++;
              _processedCount = processed;
              if (record == null) {
                setState(() => _sessionDebtZeroSkipped++);
                _pushRecoveryProgress(id, 'skip', 'بدهی صفر یا نامشخص — رد شد');
              } else {
                drafts.add(record);
                knownIds.add(id);
                await _draftStore.save(drafts);
                setState(() => _sessionNewSavedCount++);
                final m = record.payload['money'] ?? '';
                _pushRecoveryProgress(id, 'ok', 'بدهی غیرصفر — ذخیره در موقت (مبلغ: $m)');
                _appendLog('Debt record OK id=$id | drafts=${drafts.length}');
              }
              await Future<void>.delayed(const Duration(milliseconds: 400));
            } else {
              final record = await _bot.buildDraftRecord(
                token: token,
                codeCo: widget.codeCo,
                parvanehId: id,
                includeDocs: true,
                geocodeIfMissing: true,
              );
              drafts.add(record);
              knownIds.add(id);
              await _draftStore.save(drafts);
              processed++;
              _processedCount = processed;
              setState(() => _sessionNewSavedCount++);
              _pushRecoveryProgress(id, 'ok', 'در لیست موقت ذخیره شد');
              _appendLog('Record OK id=$id | drafts=${drafts.length}');
            }
          } catch (e) {
            failed++;
            _failedCount = failed;
            _pushRecoveryProgress(id, 'error', e.toString());
            _appendLog('Record ERROR id=$id | $e');
          }

          await _stateStore.saveState(
            AsnafRecoveryState(
              mode: recoveryMode,
              startPage: startPage,
              endPage: endPage,
              currentPage: page,
              currentIndexInPage: i + 1,
              processedCount: processed,
              failedCount: failed,
              totalPlanned: _totalCount,
              running: true,
            ),
          );
          lastPersistedPage = page;
          lastPersistedIndexInPage = i + 1;
          if (!mounted) return;
          setState(() {
            _draftCount = drafts.length;
            _processedCount = processed;
            _failedCount = failed;
          });
        }
        currentIndex = 0;
      }

      if (_stopRequested) {
        _appendLog('Recovery stopped by user.');
        setState(() => _operationStatus = 'عملیات متوقف شد');
        await _stateStore.saveState(
          AsnafRecoveryState(
            mode: recoveryMode,
            startPage: startPage,
            endPage: endPage,
            currentPage: lastPersistedPage,
            currentIndexInPage: lastPersistedIndexInPage,
            processedCount: processed,
            failedCount: failed,
            totalPlanned: _totalCount,
            running: false,
          ),
        );
      } else {
        _appendLog('Recovery completed successfully.');
        setState(() {
          _operationStatus = switch (recoveryMode) {
            'full' => 'عملیات بروز رسانی کامل اطلاعات به اتمام رسید',
            'latest' => 'عملیات بروز رسانی جدیدترین موارد به اتمام رسید',
            'debt_full' => 'عملیات بروز رسانی بدهی پرونده‌ها به اتمام رسید',
            'debt_latest' => 'عملیات بروز رسانی بدهی پرونده‌ها به اتمام رسید',
            _ => 'عملیات به اتمام رسید',
          };
        });
        await _stateStore.saveState(
          AsnafRecoveryState(
            mode: recoveryMode,
            startPage: startPage,
            endPage: endPage,
            currentPage: endPage,
            currentIndexInPage: 0,
            processedCount: processed,
            failedCount: failed,
            totalPlanned: _totalCount,
            running: false,
          ),
        );
      }
    } catch (e) {
      _appendLog('Recovery fatal error: $e');
      setState(() => _operationStatus = 'خطا در عملیات');
      rethrow;
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _paused = false;
          _recoveryEndedAllowingSave = true;
        });
        await _loadState();
      }
    }
  }

  Future<void> _sendToServer({bool confirmDialog = true}) async {
    if (_busy) return;
    // اگر قبلاً توقف زده شده بود، ارسال نباید با فلگ قدیمی متوقف شود.
    _stopRequested = false;

    // شمارنده را قبل از شروع ارسال از منبع واقعی همگام می‌کنیم.
    await _loadState();
    final records = await _draftStore.read();
    if (!mounted) return;
    if (records.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لیست موقت خالی است.')),
      );
      return;
    }

    if (confirmDialog) {
      final debtOnlySession =
          records.every((r) => (r.payload['_import_mode'] ?? '').trim().toLowerCase() == 'debt_only');
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('ارسال به سرور'),
          content: Text(
            debtOnlySession
                ? 'تعداد ${records.length} رکورد بدهی ارسال شود؟\n\n'
                    'اگر شناسه صنفی و code_co با پروندهٔ موجود یکی باشد فقط بدهی (money) به‌روز می‌شود؛ '
                    'در غیر این صورت همان اطلاعات به‌عنوان پروندهٔ جدید در دیتابیس ذخیره می‌شود.'
                : 'تعداد ${records.length} پرونده ارسال شود؟',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('انصراف')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('ارسال')),
          ],
        ),
      );
      if (ok != true) return;
    }
    if (!mounted) return;

    setState(() => _busy = true);
    try {
      setState(() => _operationStatus = 'در حال ذخیره اطلاعات در سرور');
      final debtOnlySession =
          records.every((r) => (r.payload['_import_mode'] ?? '').trim().toLowerCase() == 'debt_only');
      final session = await _syncApi.startSession(
        codeCo: widget.codeCo,
        totalRecords: records.length,
        debtSyncOnly: debtOnlySession,
      );
      var remaining = <ImportDraftRecord>[...records];
      final total = remaining.length;
      var sent = 0;
      for (var i = 0; i < total; i++) {
        if (_stopRequested) break;
        final r = remaining.first;
        await _syncApi.uploadBatch(
          sessionId: session.sessionId,
          chunkIndex: i + 1,
          totalChunks: total,
          records: [r],
        );
        remaining.removeAt(0);
        await _draftStore.save(remaining);
        if (!mounted) return;
        setState(() {
          _draftCount = remaining.length;
        });
        sent += 1;
        _appendLog('Sent id=${r.clientTempId} | remaining=${remaining.length}');
      }
      final fin = await _syncApi.finalizeSession(session.sessionId);
      _appendLog(
        'Finalize done | parvande_inserted=${fin.inserted} skipped=${fin.skipped} | '
        'docs_inserted=${fin.docsInserted} docs_attempts=${fin.docsRowAttempts} | '
        'api_success=${fin.success} finalize_errors=${fin.failed}',
      );
      await _loadState();
      setState(() => _operationStatus = 'ذخیره اطلاعات در سرور انجام شد');
      if (!mounted) return;
      if (sent == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('هیچ رکوردی ارسال نشد. دوباره تلاش کنید.')),
        );
      } else {
        final buf = StringBuffer()
          ..writeln('ارسال $sent پرونده به سرور انجام شد.')
          ..writeln(
            'دیتابیس: ${fin.inserted} پرونده، ${fin.docsInserted} سند (tbl_doc_parvande).',
          );
        if (fin.skipped > 0) {
          buf.writeln('پرونده رد شده (تکراری/موجود): ${fin.skipped}');
        }
        if (fin.inserted > 0 && fin.docsInserted < fin.inserted) {
          buf.writeln(
            'تعداد سند (${fin.docsInserted}) کمتر از پرونده‌های درج‌شده (${fin.inserted}) است؛ برای پرونده‌هایی که در سامانهٔ اصناف سندی ثبت نشده، API لیست خالی برمی‌گرداند.',
          );
        }
        if (!fin.success && fin.failed > 0) {
          buf.writeln('خطا در بخشی از نهایی‌سازی: ${fin.failed} — جزئیات در لاگ سرور.');
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(buf.toString().trim()),
            duration: const Duration(seconds: 12),
          ),
        );
      }
    } catch (e) {
      _appendLog('Send to server error: $e');
      setState(() => _operationStatus = 'خطا در ذخیره اطلاعات در سرور');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطا در ارسال: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showDraftList() async {
    final initial = await _draftStore.read();
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        var records = <ImportDraftRecord>[...initial];
        return StatefulBuilder(
          builder: (context, setLocal) => SizedBox(
            height: MediaQuery.of(context).size.height * 0.86,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'لیست جاری (${records.length})',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: records.isEmpty
                            ? null
                            : () async {
                                final ok = await showDialog<bool>(
                                  context: context,
                                  builder: (dCtx) => AlertDialog(
                                    title: const Text('خالی کردن لیست جاری'),
                                    content: const Text(
                                      'همه رکوردهای ذخیره‌شده موقت حذف شوند؟',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(dCtx, false),
                                        child: const Text('انصراف'),
                                      ),
                                      FilledButton(
                                        onPressed: () => Navigator.pop(dCtx, true),
                                        child: const Text('بله، حذف شود'),
                                      ),
                                    ],
                                  ),
                                );
                                if (ok != true) return;
                                records.clear();
                                await _draftStore.clear();
                                if (!mounted) return;
                                setState(() => _draftCount = 0);
                                setLocal(() {});
                                _appendLog('Draft list cleared manually.');
                              },
                        icon: const Icon(Icons.delete_sweep_outlined),
                        label: const Text('خالی کردن لیست'),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: records.isEmpty
                      ? const Center(child: Text('لیست موقت خالی است.'))
                      : ListView.builder(
                          itemCount: records.length,
                          itemBuilder: (_, i) {
                            final r = records[i];
                            final name =
                                '${r.payload['name_admin'] ?? ''} ${r.payload['family_admin'] ?? ''}'
                                    .trim();
                            return ListTile(
                              title: Text(name.isEmpty ? '—' : name),
                              subtitle: Text('ID: ${r.clientTempId}'),
                              leading: IconButton(
                                tooltip: 'ویرایش',
                                onPressed: () async {
                                  final edited = await _editDraftRecord(r);
                                  if (edited == null) return;
                                  records[i] = edited;
                                  await _draftStore.save(records);
                                  if (!mounted) return;
                                  setState(() => _draftCount = records.length);
                                  setLocal(() {});
                                  _appendLog('Draft edited id=${edited.clientTempId}');
                                },
                                icon: const Icon(Icons.edit_outlined),
                              ),
                              trailing: IconButton(
                                tooltip: 'حذف',
                                onPressed: () async {
                                  records.removeAt(i);
                                  await _draftStore.save(records);
                                  if (!mounted) return;
                                  setState(() => _draftCount = records.length);
                                  setLocal(() {});
                                },
                                icon: const Icon(Icons.delete_outline, color: Colors.red),
                              ),
                              onTap: () => showDialog<void>(
                                context: context,
                                builder: (dCtx) => AlertDialog(
                                  title: Text('جزئیات ${r.clientTempId}'),
                                  content: SizedBox(
                                    width: 520,
                                    child: SingleChildScrollView(
                                      child: Text(
                                        r.payload.entries
                                            .map((e) => '${e.key}: ${e.value}')
                                            .join('\n'),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<ImportDraftRecord?> _editDraftRecord(ImportDraftRecord record) async {
    final payload = Map<String, String>.from(record.payload);
    final nameCtrl = TextEditingController(text: payload['name_admin'] ?? '');
    final familyCtrl = TextEditingController(text: payload['family_admin'] ?? '');
    final storeCtrl = TextEditingController(text: payload['name_store'] ?? '');
    final addressCtrl = TextEditingController(text: payload['address_store'] ?? '');
    final latCtrl = TextEditingController(text: payload['lat_store'] ?? '');
    final longCtrl = TextEditingController(text: payload['long_store'] ?? '');
    final moneyCtrl = TextEditingController(text: payload['money'] ?? '');
    ImportDraftRecord? result;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text('ویرایش رکورد ${record.clientTempId}'),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'نام')),
                  TextField(controller: familyCtrl, decoration: const InputDecoration(labelText: 'نام خانوادگی')),
                  TextField(controller: storeCtrl, decoration: const InputDecoration(labelText: 'نام واحد')),
                  TextField(controller: addressCtrl, decoration: const InputDecoration(labelText: 'آدرس')),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: latCtrl,
                          decoration: const InputDecoration(labelText: 'عرض جغرافیایی'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: longCtrl,
                          decoration: const InputDecoration(labelText: 'طول جغرافیایی'),
                        ),
                      ),
                    ],
                  ),
                  TextField(controller: moneyCtrl, decoration: const InputDecoration(labelText: 'بدهی')),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.tonalIcon(
                      onPressed: () async {
                        final geo = await _bot.geocodeAddress(addressCtrl.text.trim());
                        if (geo == null) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('استخراج لوکیشن از آدرس ناموفق بود.')),
                          );
                          return;
                        }
                        latCtrl.text = geo.$1;
                        longCtrl.text = geo.$2;
                        setLocal(() {});
                        _appendLog('Geocode updated for ${record.clientTempId}');
                      },
                      icon: const Icon(Icons.place_outlined),
                      label: const Text('استخراج اطلاعات نقشه از آدرس'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('انصراف')),
            FilledButton(
              onPressed: () {
                payload['name_admin'] = nameCtrl.text.trim();
                payload['family_admin'] = familyCtrl.text.trim();
                payload['name_store'] = storeCtrl.text.trim();
                payload['address_store'] = addressCtrl.text.trim();
                payload['lat_store'] = latCtrl.text.trim();
                payload['long_store'] = longCtrl.text.trim();
                payload['money'] = moneyCtrl.text.trim();
                result = ImportDraftRecord(clientTempId: record.clientTempId, payload: payload);
                Navigator.pop(ctx);
              },
              child: const Text('ذخیره ویرایش'),
            ),
          ],
        ),
      ),
    );
    return result;
  }

  static const _appBarGradientA = Color(0xFF1A237E);
  static const _appBarGradientB = Color(0xFF3949AB);
  static const _saveBarAccent = Color(0xFFFF6D00);

  Widget _asnafToolbarAction({
    required String label,
    required IconData icon,
    required VoidCallback? onPressed,
    String? tooltip,
  }) {
    final btn = FilledButton.tonalIcon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11)),
      style: FilledButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: Colors.white.withValues(alpha: 0.2),
        disabledForegroundColor: Colors.white38,
        disabledBackgroundColor: Colors.white.withValues(alpha: 0.08),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        minimumSize: const Size(0, 34),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 6),
      child: tooltip != null ? Tooltip(message: tooltip, child: btn) : btn,
    );
  }

  Widget _asnafToolbarSaveButton() {
    final ready = _draftCount > 0 && !_busy;
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 6),
      child: Tooltip(
        message: 'ارسال لیست موقت به سرور اتحادیه',
        child: FilledButton.icon(
          onPressed: ready ? () => unawaited(_sendToServer()) : null,
          icon: const Icon(Icons.cloud_upload_rounded, size: 18),
          label: Text(
            _draftCount > 0 ? 'ذخیره ($_draftCount)' : 'ذخیره',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11),
          ),
          style: FilledButton.styleFrom(
            backgroundColor: _saveBarAccent,
            foregroundColor: Colors.white,
            disabledBackgroundColor: _saveBarAccent.withValues(alpha: 0.38),
            disabledForegroundColor: Colors.white70,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            minimumSize: const Size(0, 34),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
            elevation: ready ? 2 : 0,
            shadowColor: Colors.black45,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 52,
        elevation: 0,
        scrolledUnderElevation: 1,
        shadowColor: Colors.black38,
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_appBarGradientA, _appBarGradientB],
            ),
          ),
        ),
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        titleSpacing: 4,
        centerTitle: false,
        title: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // چپ: کاربر
            Expanded(
              flex: 26,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.userName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1.15,
                      ),
                    ),
                    Text(
                      '${widget.userCode} · ${widget.unionName}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10.5,
                        color: Colors.white.withValues(alpha: 0.88),
                        height: 1.15,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // وسط: دکمه‌ها
            Expanded(
              flex: 48,
              child: Align(
                alignment: Alignment.center,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _asnafToolbarAction(
                        label: 'جدیدترین‌ها',
                        icon: Icons.update_rounded,
                        tooltip: 'فقط چند صفحهٔ آخر لیست API',
                        onPressed: _busy ? null : () => _startFlow(full: false),
                      ),
                      _asnafToolbarAction(
                        label: 'بروزرسانی کامل',
                        icon: Icons.sync_alt_rounded,
                        tooltip: 'جزئیات، اسناد و مختصات برای همهٔ صفحات',
                        onPressed: _busy ? null : () => _startFlow(full: true),
                      ),
                      _asnafToolbarAction(
                        label: 'بروزرسانی بدهی',
                        icon: Icons.account_balance_wallet_outlined,
                        tooltip:
                            'فقط پرونده‌های با بدهی غیرصفر در لیست موقت؛ در سرور: به‌روزرسانی بدهی با تطبیق شناسه صنفی، یا درج پروندهٔ جدید اگر در دیتابیس نبود',
                        onPressed: _busy ? null : _startDebtFlow,
                      ),
                      _asnafToolbarSaveButton(),
                    ],
                  ),
                ),
              ),
            ),
            // راست: وضعیت + گزارش
            Expanded(
              flex: 26,
              child: Align(
                alignment: Alignment.centerRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                          child: Text(
                            _operationStatus,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.end,
                            style: const TextStyle(
                              fontSize: 10.5,
                              color: Colors.white,
                              height: 1.2,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                      padding: EdgeInsets.zero,
                      tooltip: _hasSavedFirstFiveTestReport ? 'گزارش تست ۵ پرونده' : 'گزارش تست ذخیره نشده',
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.18),
                        foregroundColor: Colors.white,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: _busy ? null : _openSavedFirstFiveTestReport,
                      icon: Icon(
                        Icons.assignment_outlined,
                        size: 20,
                        color: _hasSavedFirstFiveTestReport ? Colors.white : Colors.white38,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      body: SizedBox.expand(
        child: kIsWeb
            ? Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'نمایش داخلی سایت در نسخه وب محدود است. برای نمایش کامل، نسخه دسکتاپ را اجرا کنید.',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 10),
                          FilledButton.tonalIcon(
                            onPressed: () async {
                              await launchUrl(
                                Uri.parse('https://iranianasnaf.ir/'),
                                mode: LaunchMode.externalApplication,
                              );
                            },
                            icon: const Icon(Icons.open_in_browser),
                            label: const Text('باز کردن سایت ایرانی اصناف'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              )
            : InAppWebView(
                initialUrlRequest: URLRequest(url: WebUri('https://iranianasnaf.ir/')),
                initialSettings: InAppWebViewSettings(
                  javaScriptEnabled: true,
                  mediaPlaybackRequiresUserGesture: false,
                ),
                onWebViewCreated: (controller) => _webController = controller,
                onLoadStop: (controller, _) async {
                  await _extractAndSaveToken(silent: true);
                },
              ),
      ),
    );
  }
}
