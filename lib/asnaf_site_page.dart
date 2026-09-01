import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:injast_admin/asnaf_live_operation_dialog.dart';
import 'package:injast_admin/file_management/address_geocoding_service.dart';
import 'package:injast_admin/import_sync/asnaf_bot_client.dart';
import 'package:injast_admin/import_sync/asnaf_first_five_test_report_store.dart';
import 'package:injast_admin/import_sync/asnaf_fetch_pace.dart';
import 'package:injast_admin/import_sync/asnaf_human_pace.dart';
import 'package:injast_admin/import_sync/asnaf_jwt_extract.dart';
import 'package:injast_admin/import_sync/asnaf_jwt_policy.dart';
import 'package:injast_admin/import_sync/asnaf_op_log.dart';
import 'package:injast_admin/import_sync/asnaf_recovery_store.dart';
import 'package:injast_admin/import_sync/asnaf_webview_api.dart';
import 'package:injast_admin/import_sync/asnaf_webview_download.dart';
import 'package:injast_admin/import_sync/import_draft_store.dart';
import 'package:injast_admin/import_sync/import_models.dart';
import 'package:injast_admin/local_cache/parvande_server_send.dart';
import 'package:injast_admin/local_cache/sync_status.dart';
import 'package:url_launcher/url_launcher.dart';

/// تعداد صفحات انتهایی API برای حالت «بروزرسانی جدیدترین موارد» (~۱۰۰ پرونده).
const int _kAsnafLatestPagesWindow = 5;

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
  late final ImportDraftStore _draftStore;
  final _stateStore = AsnafRecoveryStore();
  final _firstFiveTestReportStore = AsnafFirstFiveTestReportStore();

  bool _busy = false;
  bool _stopRequested = false;
  bool _paused = false;
  /// پس از پایان یک دور بازیابی (توقف، خطا، یا اتمام) امکان «ذخیره در سرور» از داخل دیالوگ.
  bool _recoveryEndedAllowingSave = false;
  int _totalCount = 0;
  int _draftCount = 0;
  int _pendingSendCount = 0;
  ParvandeSyncCounts? _syncCounts;
  String _operationStatus = 'منتظر لاگین به وب سایت';

  InAppWebViewController? _webController;

  // For dialog UI only (hidden from body).
  int _processedCount = 0;
  int _failedCount = 0;
  int _sessionSkippedCount = 0;
  int _sessionNewSavedCount = 0;
  int _sessionDebtZeroSkipped = 0;
  String _currentRecord = '—';

  final List<String> _logs = [];
  final List<_RecoveryProgressItem> _recoveryProgress = [];
  final ScrollController _liveLogScrollCtrl = ScrollController();
  StreamController<void>? _liveUiStream;
  final ScrollController _recoveryProgressScrollCtrl = ScrollController();

  /// آیا حداقل یک گزارش تست ۵ پرونده در حافظهٔ محلی ذخیره شده است.
  bool _hasSavedFirstFiveTestReport = false;

  @override
  void initState() {
    super.initState();
    _liveUiStream = StreamController<void>.broadcast();
    AsnafOpLog.uiSink = _onOpLogEntry;
    _draftStore = ImportDraftStore(widget.codeCo);
    unawaited(_loadState());
    unawaited(_refreshFirstFiveTestReportFlag());
    unawaited(_purgeExpiredJwtOnOpen());
    AsnafOpLog.line(
      AsnafOpLog.site,
      'صفحه باز شد | user=${widget.userName} code=${widget.userCode} '
      'union=${widget.unionName} codeCo=${widget.codeCo} web=$kIsWeb',
    );
    AsnafOpLog.line(
      AsnafOpLog.site,
      'چک‌لیست تست: LOGIN → TOKEN → بروزرسانی (تست۵ / جدیدترین / کامل) → DRAFT → SEND',
    );
  }

  Future<void> _purgeExpiredJwtOnOpen() async {
    final t = await _readToken();
    if (t.isEmpty) return;
    if (!AsnafJwtPolicy.isExpired(t)) return;
    await _stateStore.clearJwt();
    AsnafOpLog.line(AsnafOpLog.token, 'توکن منقضی هنگام باز شدن صفحه پاک شد');
    if (mounted) {
      setState(() => _operationStatus = 'توکن منقضی پاک شد — در WebView دوباره لاگین کنید');
    }
  }

  @override
  void dispose() {
    AsnafOpLog.uiSink = null;
    _liveUiStream?.close();
    _liveLogScrollCtrl.dispose();
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
    _pulseLiveUi();
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
    final counts = await _draftStore.syncCounts();
    final state = await _stateStore.readState();
    if (!mounted) return;
    setState(() {
      _syncCounts = counts;
      _draftCount = counts.total;
      _pendingSendCount = counts.pendingSend;
      _totalCount = state?.totalPlanned ?? 0;
    });
    if (mounted && !_busy) {
      AsnafOpLog.line(
        AsnafOpLog.draft,
        'وضعیت حافظه | کل=${counts.total} ارسال‌نشده=${counts.pendingSend} '
        'checkpoint=${state?.mode ?? '—'} p=${state?.currentPage ?? '-'}',
      );
    }
  }

  String _syncStatusLabel(ImportDraftRecord r) {
    final st = ParvandeSyncStatusX.fromStorage(r.payload['_sync_status']);
    return st.labelFa;
  }

  void _onOpLogEntry(String entry) {
    _logs.insert(0, entry);
    if (_logs.length > 400) {
      _logs.removeRange(400, _logs.length);
    }
    _pulseLiveUi();
  }

  void _appendLog(String line, {String op = AsnafOpLog.site}) {
    AsnafOpLog.line(op, line);
  }

  String _logsChronologicalText() => _logs.reversed.join('\n');

  Future<void> _copySessionLogs() async {
    final text = _logsChronologicalText();
    if (text.trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لاگی برای کپی نیست.')),
      );
      return;
    }
    await Clipboard.setData(ClipboardData(text: text));
    AsnafOpLog.line(AsnafOpLog.site, 'لاگ‌ها در کلیپ‌بورد کپی شد | n=${_logs.length}');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${_logs.length} خط لاگ کپی شد — اینجا پیست کنید.')),
    );
  }

  Future<void> _showSessionLogsSheet() async {
    AsnafOpLog.line(AsnafOpLog.site, 'نمایشگر لاگ باز شد | n=${_logs.length}');
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return SizedBox(
          height: MediaQuery.of(ctx).size.height * 0.82,
          child: StreamBuilder<void>(
            stream: _liveUiStream?.stream,
            builder: (context, _) {
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 8, 8),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'لاگ تست عملیات اصناف',
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _logs.isEmpty
                              ? null
                              : () {
                                  _logs.clear();
                                  AsnafOpLog.line(AsnafOpLog.site, 'لیست لاگ خالی شد');
                                  _pulseLiveUi();
                                },
                          icon: const Icon(Icons.delete_outline, size: 18),
                          label: const Text('پاک کردن'),
                        ),
                        FilledButton.tonalIcon(
                          onPressed: _copySessionLogs,
                          icon: const Icon(Icons.copy, size: 18),
                          label: const Text('کپی همه'),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Text(
                      'تگ‌ها: LOGIN TOKEN WEB LATEST FULL TEST5 DRAFT SEND OFFLINE DOWNLOAD API GEO RECORD CTRL',
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: _logs.isEmpty
                        ? const Center(child: Text('هنوز لاگی ثبت نشده.'))
                        : ListView.builder(
                            padding: const EdgeInsets.all(12),
                            itemCount: _logs.length,
                            itemBuilder: (_, i) => Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: SelectableText(
                                _logs[i],
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 11.5,
                                  height: 1.35,
                                ),
                              ),
                            ),
                          ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  void _pulseLiveUi() {
    final s = _liveUiStream;
    if (s != null && !s.isClosed) {
      s.add(null);
    }
    WidgetsBinding.instance.scheduleFrameCallback((_) {
      if (_liveLogScrollCtrl.hasClients) {
        _liveLogScrollCtrl.jumpTo(0);
      }
    });
  }

  AsnafLiveOperationSnapshot _readLiveSnapshot() {
    final status = _operationStatus;
    final canResume = status.contains('متوقف') || status.contains('خطا در عملیات');
    return AsnafLiveOperationSnapshot(
      operationStatus: status,
      currentRecord: _currentRecord,
      processedCount: _processedCount,
      failedCount: _failedCount,
      totalCount: _totalCount,
      sessionNewSavedCount: _sessionNewSavedCount,
      sessionSkippedCount: _sessionSkippedCount,
      sessionDebtZeroSkipped: _sessionDebtZeroSkipped,
      logs: List<String>.from(_logs),
      progressItems: _recoveryProgress
          .map(
            (e) => AsnafLiveProgressRow(
              id: e.id,
              subtitle: e.subtitle,
              kind: e.kind,
            ),
          )
          .toList(),
      isBusy: _busy,
      canResumeRecovery: canResume,
      isPaused: _paused,
      stopRequested: _stopRequested,
      recoveryEndedAllowingSave: _recoveryEndedAllowingSave,
      pendingSendCount: _pendingSendCount,
      draftCount: _draftCount,
    );
  }

  String _sessionTitle(String sessionMode) => switch (sessionMode) {
        'full' => 'بروزرسانی کامل اطلاعات',
        'latest' => 'بروزرسانی جدیدترین موارد',
        'test_first_5' => 'تست ۵ پرونده',
        'test_first_5_debt' => 'تست ۵ پروندهٔ دارای بدهی',
        'debt_full' => 'بروزرسانی بدهی پرونده‌ها',
        'debt_latest' => 'بروزرسانی بدهی (جدیدترین)',
        'server_send' => 'ارسال به سرور',
        _ => 'عملیات اصناف',
      };

  void _beginLiveSession(
    String sessionMode, {
    AsnafMeta? planMeta,
    int? plannedCount,
  }) {
    AsnafFetchPace.currentMode = AsnafFetchPaceMode.safe;
    if (sessionMode != 'debt_full' && sessionMode != 'debt_latest') {
      AsnafHumanPace.instance.resetSession();
    }
    _recoveryProgress.clear();
    AsnafOpLog.line(
      _opTagForSession(sessionMode),
      '──────── جلسه جدید ────────',
    );
    setState(() {
      _busy = true;
      _stopRequested = false;
      _paused = false;
      _recoveryEndedAllowingSave = false;
      _processedCount = 0;
      _failedCount = 0;
      _sessionSkippedCount = 0;
      _sessionNewSavedCount = 0;
      _sessionDebtZeroSkipped = 0;
      _currentRecord = '—';
      _totalCount = plannedCount ??
          switch (sessionMode) {
            'test_first_5' || 'test_first_5_debt' => 5,
            'full' || 'debt_full' || 'server_send' => planMeta?.totalCount ?? 0,
            'latest' => _kAsnafLatestPagesWindow * 20,
            _ => planMeta?.totalCount ?? 0,
          };
      _operationStatus = switch (sessionMode) {
        'test_first_5' => 'آمادهٔ تست ۵ پرونده…',
        'test_first_5_debt' => 'آمادهٔ تست بدهی…',
        'full' => 'آمادهٔ بروزرسانی کامل…',
        'latest' => 'آمادهٔ بروزرسانی جدیدترین‌ها…',
        'debt_full' => 'آمادهٔ بروزرسانی بدهی…',
        'server_send' => 'آمادهٔ ارسال به سرور…',
        _ => 'آمادهٔ شروع…',
      };
    });
    _appendLog('▶ شروع: ${_sessionTitle(sessionMode)}', op: _opTagForSession(sessionMode));
  }

  /// دیالوگ زنده بلافاصله باز می‌شود؛ کار در پس‌زمینه ادامه دارد.
  Future<void> _openLiveOperationDialogThenRun({
    required String sessionMode,
    AsnafMeta? planMeta,
    int? plannedCount,
    required Future<void> Function() run,
  }) async {
    _beginLiveSession(sessionMode, planMeta: planMeta, plannedCount: plannedCount);
    if (!mounted) return;
    unawaited(
      run().whenComplete(() {
        if (!mounted) return;
        _appendLog('── پایان عملیات ──', op: _opTagForSession(sessionMode));
        _pulseLiveUi();
      }),
    );
    await _showOperationDialog(sessionMode: sessionMode);
  }

  Future<String> _readToken() async => _stateStore.readJwt();

  String _opTagForSession(String sessionMode) => switch (sessionMode) {
        'full' => AsnafOpLog.full,
        'latest' => AsnafOpLog.latest,
        'test_first_5' || 'test_first_5_debt' => AsnafOpLog.test5,
        'server_send' => AsnafOpLog.send,
        _ => AsnafOpLog.site,
      };

  Future<void> _clearStoredJwt() async {
    await _stateStore.clearJwt();
    AsnafOpLog.line(AsnafOpLog.token, 'توکن JWT دستی پاک شد');
    if (!mounted) return;
    setState(() => _operationStatus = 'توکن اصناف پاک شد — در WebView لاگین کنید');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'توکن JWT اصناف پاک شد. فقط پس از لاگین کامل در پنل، بازیابی را شروع کنید.',
        ),
        duration: Duration(seconds: 6),
      ),
    );
  }

  Future<bool> _handleAsnafAuthFailure(Object e) async {
    if (e is! AsnafApiAuthException) return false;
    if (e.fromWebView) {
      await _stateStore.clearJwt();
    }
    AsnafOpLog.line(
      AsnafOpLog.token,
      e.fromWebView
          ? 'قطع دسترسی API ${e.statusCode} از WebView — JWT پاک شد | ${AsnafOpLog.shortUrl(e.url)}'
          : 'HTTP ${e.statusCode} — JWT نگه داشته شد | ${AsnafOpLog.shortUrl(e.url)}',
      error: e,
    );
    if (!mounted) return true;
    setState(
      () => _operationStatus =
          'متوقف — توکن منقضی یا دسترسی قطع شد؛ لاگین کنید و از همان صفحه ادامه دهید',
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'خطای ${e.statusCode} از API اصناف (احتمال توکن نامعتبر یا محدودیت IP). '
          'چند ساعت صبر کنید یا از پشتیبانی اصناف بپرسید.',
        ),
        duration: const Duration(seconds: 10),
      ),
    );
    return true;
  }

  bool _isHardNetworkError(Object e) {
    final m = e.toString().toLowerCase();
    return m.contains('timed out') ||
        m.contains('timeout') ||
        m.contains('socketexception') ||
        m.contains('connection reset') ||
        m.contains('connection refused');
  }

  void _syncBotWebViewApi() {
    final c = _webController;
    _bot.webViewApi = c != null ? AsnafWebViewApi(c) : null;
  }

  Future<void> _saveWebViewDownload({
    required WebUri url,
    String? mimeType,
    String? suggestedFilename,
    String? contentDisposition,
  }) async {
    if (!mounted) return;
    AsnafOpLog.line(
      AsnafOpLog.download,
      'درخواست دانلود | url=${AsnafOpLog.clip(url.toString())} mime=$mimeType',
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('در حال دانلود فایل…'),
        duration: Duration(seconds: 2),
      ),
    );
    try {
      final token = await _readToken();
      final path = await AsnafWebViewDownload.saveFromUrl(
        url: url,
        mimeType: mimeType,
        suggestedFilename: suggestedFilename,
        contentDisposition: contentDisposition,
        jwtToken: token,
      );
      if (!mounted) return;
      if (path == null) {
        AsnafOpLog.line(AsnafOpLog.download, 'دانلود لغو یا مسیر خالی');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ذخیره فایل لغو شد.')),
        );
        return;
      }
      AsnafOpLog.line(AsnafOpLog.download, 'موفق | $path');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('فایل ذخیره شد:\n$path'),
          duration: const Duration(seconds: 6),
        ),
      );
    } catch (e) {
      AsnafOpLog.line(AsnafOpLog.download, 'خطا در دانلود: $e', error: e);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطا در دانلود: $e')),
      );
    }
  }

  Future<void> _maybeOfferSaveCsvPage(
    InAppWebViewController controller,
    WebUri? url,
  ) async {
    final urlStr = url?.toString() ?? '';
    if (!AsnafWebViewDownload.looksLikeFileUrl(urlStr)) return;

    String? contentType;
    try {
      contentType = (await controller.evaluateJavascript(
        source: "document.contentType || ''",
        contentWorld: ContentWorld.PAGE,
      ))
          ?.toString();
    } catch (_) {}

    final ct = contentType?.toLowerCase() ?? '';
    final isTextExport = ct.contains('csv') ||
        ct.contains('text/plain') ||
        urlStr.toLowerCase().contains('.csv');
    if (!isTextExport) {
      AsnafOpLog.line(
        AsnafOpLog.download,
        'URL شبیه فایل بود ولی CSV نیست | ct=$ct url=${AsnafOpLog.clip(urlStr)}',
      );
      return;
    }
    AsnafOpLog.line(AsnafOpLog.download, 'پیشنهاد ذخیره CSV | url=${AsnafOpLog.clip(urlStr)}');
    if (!mounted) return;

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'فایل CSV در WebView به‌صورت متن باز شده — برای ذخیره روی دیسک «ذخیره فایل» را بزنید.',
        ),
        duration: const Duration(seconds: 12),
        action: SnackBarAction(
          label: 'ذخیره فایل',
          onPressed: () {
            unawaited(
              _saveWebViewDownload(
                url: url!,
                mimeType: 'text/csv',
              ),
            );
          },
        ),
      ),
    );
  }

  /// توکن از WebView (تازه) + حافظه؛ ربات از همان سشن WebView درخواست می‌زند.
  Future<String?> _ensureValidToken({bool tryWebExtract = true}) async {
    AsnafOpLog.line(
      AsnafOpLog.token,
      'بررسی توکن | tryWeb=$tryWebExtract webView=${_webController != null}',
    );
    if (tryWebExtract && _webController != null) {
      _syncBotWebViewApi();
      await _extractAndSaveToken(silent: true);
    }
    var token = await _readToken();
    if (token.isNotEmpty && AsnafJwtPolicy.isExpired(token)) {
      await _stateStore.clearJwt();
      AsnafOpLog.line(AsnafOpLog.token, 'توکن ذخیره‌شده منقضی بود — پاک شد');
      token = '';
    }
    if (token.isEmpty && tryWebExtract && _webController != null) {
      AsnafOpLog.line(AsnafOpLog.token, 'توکن خالی — استخراج دوباره از WebView');
      await _extractAndSaveToken(silent: true);
      token = await _readToken();
    }
    if (token.isEmpty) {
      AsnafOpLog.line(AsnafOpLog.token, 'نتیجه: توکن معتبر نیست');
      return null;
    }
    if (AsnafJwtPolicy.isExpired(token)) {
      await _stateStore.clearJwt();
      AsnafOpLog.line(AsnafOpLog.token, 'توکن بعد از استخراج هم منقضی بود');
      return null;
    }
    AsnafOpLog.line(AsnafOpLog.token, 'توکن معتبر | ${AsnafOpLog.jwtSafe(token)}');
    return token;
  }

  Future<void> _extractAndSaveToken({bool silent = false, String? pageUrl}) async {
    final c = _webController;
    if (c == null) {
      AsnafOpLog.line(AsnafOpLog.login, 'استخراج توکن ممکن نیست — WebView آماده نیست');
      return;
    }
    if (pageUrl != null && !AsnafJwtPolicy.isAuthenticatedPanelUrl(pageUrl)) {
      AsnafOpLog.line(
        AsnafOpLog.login,
        'صفحه پنل احرازشده نیست — استخراج نشد | url=${AsnafOpLog.clip(pageUrl)} '
        'public=${AsnafJwtPolicy.isPublicOrLoginUrl(pageUrl)}',
      );
      return;
    }
    if (!silent && mounted) setState(() => _busy = true);
    try {
      final raw = await c.evaluateJavascript(
        source: AsnafJwtExtract.extractJavaScript,
        contentWorld: ContentWorld.PAGE,
      );
      final diag = AsnafJwtExtract.diagnoseJsResult(raw);
      AsnafOpLog.line(
        AsnafOpLog.login,
        'نتیجه JS | found=${diag.foundCount} note=${diag.note} expired=${diag.expired} '
        '| ${AsnafOpLog.jwtSafe(diag.token)} silent=$silent',
      );
      final token = (diag.expired || diag.token == null || diag.token!.isEmpty)
          ? null
          : diag.token;
      if (token == null || token.isEmpty) {
        setState(() => _operationStatus = 'منتظر لاگین به وب سایت');
        if (!silent && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                kIsWeb
                    ? 'ورود خودکار فقط در نسخه دسکتاپ فعال است.'
                    : 'پس از ورود کامل به پنل (خارج از صفحه login)، توکن ذخیره می‌شود.',
              ),
            ),
          );
        }
        return;
      }
      await _stateStore.saveJwt(token);
      AsnafOpLog.line(AsnafOpLog.login, 'JWT ذخیره شد | ${AsnafOpLog.jwtSafe(token)}');
      setState(() => _operationStatus = 'لاگین انجام شد');
    } catch (e) {
      AsnafOpLog.line(AsnafOpLog.login, 'خطا در استخراج توکن: $e', error: e);
      if (!silent && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطا در بررسی لاگین: $e')),
        );
      }
    } finally {
      if (!silent && mounted) setState(() => _busy = false);
    }
  }

  Future<void> _onUpdatePressed() async {
    AsnafOpLog.line(AsnafOpLog.site, 'کلیک بروزرسانی | busy=$_busy');
    final token = await _ensureValidToken();
    if (token == null) {
      AsnafOpLog.line(AsnafOpLog.token, 'لغو بروزرسانی — توکن معتبر نیست');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'ابتدا در همین صفحه وارد پنل اصناف شوید (بعد از صفحهٔ login)، سپس دوباره «بروزرسانی» را بزنید.',
          ),
        ),
      );
      return;
    }
    if (!mounted) return;

    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('بروزرسانی از سایت اصناف'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.science_outlined),
              title: const Text('تست ۵ پرونده'),
              subtitle: const Text('برای اطمینان از لاگین و دریافت داده'),
              onTap: () => Navigator.pop(ctx, 'test5'),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.update_rounded),
              title: const Text('جدیدترین موارد'),
              subtitle: const Text('حدود ۱۰۰ پروندهٔ آخر'),
              onTap: () => Navigator.pop(ctx, 'latest'),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.sync_alt_rounded),
              title: const Text('بروزرسانی کامل'),
              subtitle: const Text('انتخاب صفحه، تعداد، یا ادامه از آخرین توقف'),
              onTap: () => Navigator.pop(ctx, 'full'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('انصراف')),
        ],
      ),
    );
    if (!mounted || choice == null) {
      AsnafOpLog.line(AsnafOpLog.site, 'انصراف از انتخاب نوع بروزرسانی');
      return;
    }

    switch (choice) {
      case 'test5':
        AsnafOpLog.line(AsnafOpLog.test5, 'انتخاب تست ۵ پرونده');
        await _openLiveOperationDialogThenRun(
          sessionMode: 'test_first_5',
          run: () => _runTestFirstFiveRecords(token: token),
        );
        break;
      case 'latest':
        AsnafOpLog.line(AsnafOpLog.latest, 'انتخاب جدیدترین‌ها');
        await _openLiveOperationDialogThenRun(
          sessionMode: 'latest',
          run: () => _runRecovery(
            recoveryMode: 'latest',
            token: token,
            discoverLatestPages: true,
          ),
        );
        break;
      case 'full':
        await _startFullAfterChoice(token);
        break;
      default:
        break;
    }
  }

  Future<void> _startFullAfterChoice(String token) async {
    AsnafOpLog.line(AsnafOpLog.full, 'دریافت تعداد صفحات از API…');
    late AsnafMeta planMeta;
    try {
      planMeta = await _bot.fetchMeta(token);
    } catch (e) {
      AsnafOpLog.line(AsnafOpLog.full, 'خطا در دریافت متا: $e', error: e);
      if (await _handleAsnafAuthFailure(e)) return;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('نتوانستیم لیست پرونده‌ها را بگیریم: $e')),
      );
      return;
    }
    if (!mounted) return;
    AsnafOpLog.line(
      AsnafOpLog.full,
      'برنامه | count=${planMeta.totalCount} pages=${planMeta.totalPages}',
    );
    final checkpoint = await _stateStore.readState();
    if (!mounted) return;
    final plan = await showDialog<_FullUpdatePlan>(
      context: context,
      builder: (ctx) => _FullUpdatePlanDialog(
        totalPages: planMeta.totalPages,
        totalCount: planMeta.totalCount,
        checkpoint: _isIncompleteFullCheckpoint(checkpoint) ? checkpoint : null,
      ),
    );
    if (plan == null) {
      AsnafOpLog.line(AsnafOpLog.full, 'هشدار شروع تأیید نشد');
      return;
    }
    final planned = _plannedCountForRange(
      startPage: plan.startPage,
      endPage: plan.endPage,
      apiTotalCount: planMeta.totalCount,
      apiTotalPages: planMeta.totalPages,
      maxRecords: plan.maxRecords,
    );
    AsnafOpLog.line(
      AsnafOpLog.full,
      'شروع تأیید شد | resume=${plan.resumeCheckpoint} '
      'pages=${plan.startPage}..${plan.endPage} max=${plan.maxRecords ?? '—'} planned=$planned',
    );
    await _openLiveOperationDialogThenRun(
      sessionMode: 'full',
      planMeta: planMeta,
      plannedCount: planned,
      run: () => _runRecovery(
        recoveryMode: 'full',
        token: token,
        planMeta: planMeta,
        overrideStartPage: plan.resumeCheckpoint ? null : plan.startPage,
        overrideEndPage: plan.resumeCheckpoint ? null : plan.endPage,
        maxRecords: plan.maxRecords,
        resumeFromCheckpoint: plan.resumeCheckpoint,
      ),
    );
  }

  int _plannedCountForRange({
    required int startPage,
    required int endPage,
    required int apiTotalCount,
    required int apiTotalPages,
    int? maxRecords,
  }) {
    final pages = (endPage - startPage + 1).clamp(1, 100000);
    late final int approx;
    if (startPage == 1 && endPage == apiTotalPages && apiTotalCount > 0) {
      approx = apiTotalCount;
    } else {
      final perPage = apiTotalPages > 0
          ? (apiTotalCount / apiTotalPages).round().clamp(1, 50)
          : 20;
      approx = pages * perPage;
    }
    if (maxRecords != null && maxRecords > 0 && maxRecords < approx) {
      return maxRecords;
    }
    return approx;
  }

  bool _isIncompleteFullCheckpoint(AsnafRecoveryState? s) {
    if (s == null || s.mode != 'full') return false;
    if (s.currentPage < 1) return false;
    if (s.currentPage < s.endPage) return true;
    return s.currentPage == s.endPage && s.currentIndexInPage > 0;
  }

  /// همان مسیر [buildDraftRecord] عملیات کامل (جزئیات، اسناد، ژئوکد) برای پنج پروندهٔ اول لیست API.
  Future<void> _runTestFirstFiveRecords({
    required String token,
  }) async {
    var ok = 0;
    var fail = 0;
    final entries = <AsnafFirstFiveTestEntry>[];
    final neshanOk = _bot.isNeshanGeocodingConfigured;
    try {
      const target = 5;
      var collected = 0;
      var page = 1;

      while (collected < target) {
        _appendLog('دریافت لیست صفحه $page…', op: AsnafOpLog.test5);
        setState(() => _operationStatus = 'دریافت لیست صفحه $page');
        _pulseLiveUi();
        final rows = await _bot.fetchParvandehPage(token: token, page: page);
        _appendLog('صفحه $page: ${rows.length} ردیف', op: AsnafOpLog.test5);
        if (rows.isEmpty) break;
        for (var i = 0; i < rows.length && collected < target; i++) {
          final row = rows[i] is Map ? rows[i] as Map : const {};
          final id = row['id']?.toString() ?? '';
          if (id.isEmpty) continue;
          collected++;
          if (!mounted) return;
          setState(() {
            _currentRecord = id;
            _operationStatus = 'پردازش پرونده $id ($collected/$target)';
          });
          _pulseLiveUi();
          _appendLog('── پرونده $collected/$target | id=$id ──', op: AsnafOpLog.test5);
          _appendLog('دریافت جزئیات و مدارک…', op: AsnafOpLog.test5);
          final sw = Stopwatch()..start();
          try {
            final record = await _bot.buildDraftRecord(
              token: token,
              codeCo: widget.codeCo,
              parvanehId: id,
              includeDocs: true,
              geocodeIfMissing: false,
            );
            _appendLog('ذخیره در حافظه و دانلود تصاویر…', op: AsnafOpLog.test5);
            final up = await _draftStore.upsert(record);
            ok++;
            _processedCount = ok + fail;
            _pushRecoveryProgress(id, 'ok', 'ذخیره شد — ${record.payload['name_store'] ?? ''}');
            entries.add(AsnafFirstFiveTestEntry.fromSuccess(record, neshanKeyConfigured: neshanOk));
            _appendLog('✓ موفق id=$id upsert=$up', op: AsnafOpLog.test5);
            _pulseLiveUi();
          } catch (e) {
            fail++;
            _processedCount = ok + fail;
            _failedCount = fail;
            _pushRecoveryProgress(id, 'error', e.toString());
            entries.add(AsnafFirstFiveTestEntry.failure(id, e));
            _appendLog('✗ خطا id=$id | $e', op: AsnafOpLog.test5);
            if (_isHardNetworkError(e)) {
              setState(() => _operationStatus = 'timeout شبکه — استراحت قبل از ادامه');
              _appendLog('⏸ استراحت ۱۰–۱۵ دقیقه پس از timeout…');
              await AsnafHumanPace.instance.cooldownAfterHardNetworkError(
                (m) {
                  if (mounted) setState(() => _operationStatus = m);
                  _appendLog(m);
                },
              );
            }
          }
          _appendLog('مکث ایمن ۱۰–۲۰ ثانیه…');
          await AsnafHumanPace.instance.waitAfterParvande(sw);
        }
        page++;
      }

      if (collected < target) {
        _appendLog(
          'فقط $collected پرونده در محدوده API بود (هدف $target).',
          op: AsnafOpLog.test5,
        );
      }

      await _loadState();
      if (!mounted) return;
      setState(() {
        _operationStatus = fail == 0
            ? 'تست ۵ پروندهٔ اول موفق بود ($ok مورد)'
            : 'تست ۵ پروندهٔ اول: $ok موفق، $fail خطا';
      });
      _pulseLiveUi();

      final report = AsnafFirstFiveTestReport(
        savedAtMs: DateTime.now().millisecondsSinceEpoch,
        metaTotalCount: 0,
        metaTotalPages: 0,
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
      _appendLog('خطای کلی تست ۵ پرونده: $e', op: AsnafOpLog.test5);
      if (await _handleAsnafAuthFailure(e)) return;
      if (mounted) {
        setState(() => _operationStatus = 'خطا در تست ۵ پروندهٔ اول');
        final report = AsnafFirstFiveTestReport(
          savedAtMs: DateTime.now().millisecondsSinceEpoch,
          metaTotalCount: 0,
          metaTotalPages: 0,
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
        _pulseLiveUi();
        await _loadState();
        await _refreshFirstFiveTestReportFlag();
      }
    }
  }

  Future<void> _showOperationDialog({required String sessionMode}) async {
    final isTest = sessionMode == 'test_first_5' || sessionMode == 'test_first_5_debt';
    final showRecoveryControls = !isTest && sessionMode != 'server_send';

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AsnafLiveOperationDialog(
          title: _sessionTitle(sessionMode),
          readSnapshot: _readLiveSnapshot,
          logScrollController: _liveLogScrollCtrl,
          liveUiStream: _liveUiStream!.stream,
          progressScrollController: _recoveryProgressScrollCtrl,
          showDebtStats: sessionMode == 'debt_full' || sessionMode == 'debt_latest',
          showRecoveryControls: showRecoveryControls,
          onStopFull: (_busy && !_stopRequested)
              ? () async {
                  final ok = await showDialog<bool>(
                    context: ctx,
                    builder: (dCtx) => AlertDialog(
                      title: const Text('توقف کامل عملیات'),
                      content: const Text(
                        'عملیات استخراج متوقف می‌شود. بعداً می‌توانید از «شروع مجدد» ادامه دهید.',
                      ),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('خیر')),
                        FilledButton(onPressed: () => Navigator.pop(dCtx, true), child: const Text('بله')),
                      ],
                    ),
                  );
                  if (ok != true) return;
                  _paused = false;
                  _stopRequested = true;
                  setState(() => _operationStatus = 'در حال توقف کامل…');
                  _appendLog('⏹ درخواست توقف کامل', op: AsnafOpLog.pause);
                }
              : null,
          onPause: (_busy && !_stopRequested && !_paused)
              ? () {
                  _paused = true;
                  setState(() => _operationStatus = 'متوقف موقت');
                  _appendLog('⏸ توقف موقت', op: AsnafOpLog.pause);
                }
              : null,
          onResume: ((_busy && _paused) || (!_busy && (_operationStatus.contains('متوقف') || _operationStatus.contains('خطا در عملیات'))))
              ? () async {
                  if (_busy && _paused) {
                    _paused = false;
                    setState(() => _operationStatus = 'ادامه پس از توقف موقت…');
                    _appendLog('▶ ادامه از توقف موقت', op: AsnafOpLog.pause);
                    return;
                  }
                  final token = await _readToken();
                  if (token.isEmpty) return;
                  final st = await _stateStore.readState();
                  if (st == null || !mounted) return;
                  setState(() => _operationStatus = 'شروع مجدد…');
                  _appendLog('▶ شروع مجدد از checkpoint', op: AsnafOpLog.pause);
                  unawaited(_runRecovery(
                    recoveryMode: sessionMode,
                    token: token,
                    planMeta: AsnafMeta(
                      totalCount: st.totalPlanned,
                      totalPages: st.endPage,
                    ),
                    resumeFromCheckpoint: true,
                  ));
                }
              : null,
          onShowDraft: () async {
            await _showDraftList();
            if (!mounted) return;
            _pulseLiveUi();
          },
          onSendToServer: (!_busy && _recoveryEndedAllowingSave && _pendingSendCount > 0)
              ? () async {
                  Navigator.pop(ctx);
                  await Future<void>.delayed(Duration.zero);
                  if (!mounted) return;
                  await _sendToServer(confirmDialog: false);
                }
              : null,
          onClose: () {
            Navigator.pop(ctx);
          },
        );
      },
    );
  }

  Future<void> _runRecovery({
    required String recoveryMode,
    required String token,
    AsnafMeta? planMeta,
    bool discoverLatestPages = false,
    int? overrideStartPage,
    int? overrideEndPage,
    int? maxRecords,
    bool resumeFromCheckpoint = false,
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
    _appendLog('Recovery started | mode=$recoveryMode', op: _opTagForSession(recoveryMode));
    var authBlocked = false;

    try {
      final currentState = await _stateStore.readState();
      final resumeRunning = currentState != null &&
          currentState.running &&
          currentState.mode == recoveryMode;
      final resume = resumeFromCheckpoint
          ? (currentState != null && currentState.mode == recoveryMode)
          : resumeRunning;

      late int startPage;
      late int endPage;
      late int totalCount;

      if (resume) {
        startPage = currentState.startPage;
        endPage = currentState.endPage;
        totalCount = currentState.totalPlanned;
      } else if (overrideStartPage != null && overrideEndPage != null) {
        startPage = overrideStartPage.clamp(1, overrideEndPage);
        endPage = overrideEndPage;
        totalCount = _plannedCountForRange(
          startPage: startPage,
          endPage: endPage,
          apiTotalCount: planMeta?.totalCount ?? 0,
          apiTotalPages: planMeta?.totalPages ?? endPage,
          maxRecords: maxRecords,
        );
      } else if (discoverLatestPages) {
        final first = await _bot.fetchParvandehPageWithMeta(token: token, page: 1);
        final totalPages = first.meta.totalPages;
        endPage = totalPages;
        startPage = totalPages > _kAsnafLatestPagesWindow
            ? totalPages - _kAsnafLatestPagesWindow + 1
            : 1;
        totalCount = (_kAsnafLatestPagesWindow * 20).clamp(1, first.meta.totalCount);
        _appendLog(
          'پنجره جدیدترین‌ها | صفحات $startPage..$endPage (totalPages=$totalPages count=${first.meta.totalCount})',
          op: AsnafOpLog.latest,
        );
      } else if (planMeta != null) {
        endPage = planMeta.totalPages;
        startPage = fullWindow
            ? 1
            : (endPage > _kAsnafLatestPagesWindow ? endPage - _kAsnafLatestPagesWindow + 1 : 1);
        totalCount = planMeta.totalCount;
      } else {
        throw StateError('Recovery requires planMeta or discoverLatestPages');
      }

      final resumeCheckpoint = !resume &&
          currentState != null &&
          currentState.mode == recoveryMode &&
          currentState.startPage == startPage &&
          currentState.endPage == endPage &&
          (currentState.currentPage > startPage ||
              (currentState.currentPage == startPage && currentState.currentIndexInPage > 0));
      final continueSamePage = !resume &&
          !resumeCheckpoint &&
          currentState != null &&
          currentState.mode == recoveryMode &&
          overrideStartPage != null &&
          currentState.currentPage == startPage &&
          currentState.currentIndexInPage > 0;
      late int currentPage;
      late int currentIndex;
      late int processed;
      late int failed;
      if (resume) {
        currentPage = currentState.currentPage;
        currentIndex = currentState.currentIndexInPage;
        processed = currentState.processedCount;
        failed = currentState.failedCount;
      } else if (resumeCheckpoint || continueSamePage) {
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

      _appendLog(
        'پنجره کار | resume=$resume checkpoint=$resumeCheckpoint '
        'pages=$startPage..$endPage from p$currentPage idx=$currentIndex '
        'processed=$processed failed=$failed planned=$totalCount max=${maxRecords ?? '—'}',
        op: _opTagForSession(recoveryMode),
      );

      if (!resume && !resumeCheckpoint && !continueSamePage) {
        AsnafHumanPace.instance.resetSession();
      }

      setState(() {
        _sessionSkippedCount = 0;
        _sessionNewSavedCount = 0;
        _sessionDebtZeroSkipped = 0;
        _processedCount = processed;
        _failedCount = failed;
      });

      setState(() {
        _totalCount = totalCount;
      });

      var sessionAdded = 0;
      var hitRecordCap = false;

      for (var page = currentPage; page <= endPage; page++) {
        if (authBlocked || hitRecordCap) break;
        await _waitWhilePaused();
        if (_stopRequested) break;
        List<dynamic> rows;
        try {
          rows = await _bot.fetchParvandehPage(token: token, page: page);
        } catch (e) {
          if (await _handleAsnafAuthFailure(e)) {
            authBlocked = true;
            break;
          }
          rethrow;
        }
        final startIndex = (page == currentPage) ? currentIndex : 0;
        _appendLog(
          'صفحه $page بارگذاری شد | ${rows.length} ردیف | از ایندکس $startIndex',
          op: _opTagForSession(recoveryMode),
        );
        for (var i = startIndex; i < rows.length; i++) {
          await _waitWhilePaused();
          if (_stopRequested) break;
          final row = rows[i] is Map ? rows[i] as Map : const {};
          final id = row['id']?.toString() ?? '';
          if (id.isEmpty) continue;
          setState(() => _currentRecord = id);
          final sw = Stopwatch()..start();
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
                final up = await _draftStore.upsert(record, downloadImages: false);
                if (up == UpsertResult.unchanged) {
                  setState(() => _sessionSkippedCount++);
                  _pushRecoveryProgress(id, 'skip', 'بدون تغییر — رد شد');
                } else {
                  setState(() => _sessionNewSavedCount++);
                  final m = record.payload['money'] ?? '';
                  _pushRecoveryProgress(id, 'ok', 'بدهی در حافظه ($m) — ${up.name}');
                }
                _appendLog('بدهی OK id=$id | upsert=$up', op: _opTagForSession(recoveryMode));
              }
              await Future<void>.delayed(AsnafFetchPace.current.pauseAfterDebtParvande);
            } else {
              final record = await _bot.buildDraftRecord(
                token: token,
                codeCo: widget.codeCo,
                parvanehId: id,
                includeDocs: true,
                geocodeIfMissing: true,
              );
              final up = await _draftStore.upsert(record);
              processed++;
              _processedCount = processed;
              if (up == UpsertResult.unchanged) {
                setState(() => _sessionSkippedCount++);
                _pushRecoveryProgress(id, 'skip', 'بدون تغییر — رد شد');
              } else {
                setState(() => _sessionNewSavedCount++);
                _pushRecoveryProgress(
                  id,
                  'ok',
                  up == UpsertResult.updatedDirty
                      ? 'بروزرسانی شد — نیاز به ارسال مجدد'
                      : 'در حافظهٔ محلی ذخیره شد',
                );
              }
              _appendLog('پرونده OK id=$id | upsert=$up', op: _opTagForSession(recoveryMode));
              await AsnafHumanPace.instance.waitAfterParvande(sw);
              await AsnafHumanPace.instance.maybeLongRest(
                processedCount: processed,
                onStatus: (m) {
                  if (mounted) setState(() => _operationStatus = m);
                },
                shouldAbort: () => _stopRequested,
                waitWhilePaused: _waitWhilePaused,
              );
            }
          } catch (e) {
            if (await _handleAsnafAuthFailure(e)) {
              authBlocked = true;
              break;
            }
            failed++;
            _failedCount = failed;
            _pushRecoveryProgress(id, 'error', e.toString());
            _appendLog('خطای پرونده id=$id | $e', op: _opTagForSession(recoveryMode));
          }

          if (authBlocked) break;

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
          await _loadState();
          if (!mounted) return;
          setState(() {
            _processedCount = processed;
            _failedCount = failed;
          });
          sessionAdded++;
          if (maxRecords != null && sessionAdded >= maxRecords) {
            hitRecordCap = true;
            _appendLog(
              'سقف تعداد این اجرا رسید ($maxRecords) — پیشرفت در صفحه $page ایندکس ${i + 1} ذخیره شد',
              op: _opTagForSession(recoveryMode),
            );
            break;
          }
        }
        currentIndex = 0;
        if (hitRecordCap || authBlocked || _stopRequested) break;
        await Future<void>.delayed(AsnafFetchPace.current.pauseAfterListPage);
      }

      final incomplete = _stopRequested || authBlocked || hitRecordCap;
      if (incomplete) {
        final reason = authBlocked
            ? 'قطع احراز هویت — پیشرفت ذخیره شد (صفحه $lastPersistedPage)'
            : (hitRecordCap
                ? 'سقف تعداد این اجرا — می‌توانید بعداً از همین صفحه ادامه دهید'
                : 'توقف توسط کاربر');
        _appendLog(reason, op: _opTagForSession(recoveryMode));
        if (mounted) {
          setState(() {
            _operationStatus = authBlocked
                ? 'متوقف — توکن منقضی شد؛ لاگین کنید و از صفحه $lastPersistedPage ادامه دهید'
                : (hitRecordCap
                    ? 'متوقف — سقف تعداد رسید؛ پیشرفت در صفحه $lastPersistedPage ذخیره شد'
                    : 'عملیات متوقف شد');
          });
        }
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
        _appendLog(
          'اتمام موفق | processed=$processed failed=$failed new=$_sessionNewSavedCount skip=$_sessionSkippedCount',
          op: _opTagForSession(recoveryMode),
        );
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
      _appendLog('خطای کلی بازیابی: $e', op: _opTagForSession(recoveryMode));
      setState(() => _operationStatus = 'خطا در عملیات');
      rethrow;
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _paused = false;
          _recoveryEndedAllowingSave = true;
        });
        _pulseLiveUi();
        await _loadState();
      }
    }
  }

  Future<void> _sendToServer({bool confirmDialog = true}) async {
    AsnafOpLog.line(
      AsnafOpLog.send,
      'کلیک ارسال | busy=$_busy pending=$_pendingSendCount confirm=$confirmDialog',
    );
    if (_busy) {
      AsnafOpLog.line(AsnafOpLog.send, 'لغو — عملیات دیگری در حال اجراست');
      return;
    }
    // اگر قبلاً توقف زده شده بود، ارسال نباید با فلگ قدیمی متوقف شود.
    _stopRequested = false;

    // شمارنده را قبل از شروع ارسال از منبع واقعی همگام می‌کنیم.
    await _loadState();
    final records = await _draftStore.readPendingForSync();
    if (!mounted) return;
    if (records.isEmpty) {
      AsnafOpLog.line(AsnafOpLog.send, 'لغو — پروندهٔ ارسال‌نشده نیست');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('پرونده‌ای برای ارسال نیست (همه ارسال‌شده‌اند یا حافظه خالی است).'),
        ),
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
                ? 'تعداد ${records.length} رکورد بدهی (ارسال‌نشده/نیاز به بروزرسانی) ارسال شود؟\n\n'
                    'تصاویر محلی ابتدا آپلود و سپس داده در سرور ثبت می‌شود. رکوردها در حافظه باقی می‌مانند.'
                : 'تعداد ${records.length} پرونده (ارسال‌نشده/نیاز به بروزرسانی) ارسال شود؟\n\n'
                    'فقط فایل‌های فیزیکی موجود روی این دستگاه آپلود می‌شوند.\n'
                    'هیچ دانلودی از سایت اصناف انجام نمی‌شود؛ مسیر تصاویر فقط از سرور شماست.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('انصراف')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('ارسال')),
          ],
        ),
      );
      if (ok != true) {
        AsnafOpLog.line(AsnafOpLog.send, 'کاربر انصراف داد');
        return;
      }
      AsnafOpLog.line(AsnafOpLog.send, 'تأیید شد | n=${records.length}');
    }
    if (!mounted) return;

    await _openLiveOperationDialogThenRun(
      sessionMode: 'server_send',
      planMeta: AsnafMeta(totalCount: records.length, totalPages: 0),
      run: () => _executeServerSend(records),
    );
  }

  Future<void> _executeServerSend(List<ImportDraftRecord> records) async {
    try {
      final result = await ParvandeServerSend.instance.sendAll(
        codeCo: widget.codeCo,
        records: records,
        shouldStop: () => _stopRequested,
        onProgress: (p) {
          if (!mounted) return;
          setState(() {
            _operationStatus = p.message;
            if (p.recordId != null && p.recordId!.isNotEmpty) {
              _currentRecord = p.recordId!;
            }
            _processedCount = p.done;
            _totalCount = p.total;
          });
          _appendLog(p.message, op: AsnafOpLog.send);
        },
      );

      final fin = result.finalize;
      final sent = result.sentRecords;
      _appendLog(
        'نهایی‌سازی | پرونده=${fin.inserted} رد=${fin.skipped} | '
        'سند=${fin.docsInserted} | خطا=${fin.failed} sent=$sent stopped=${result.stoppedEarly}',
        op: AsnafOpLog.send,
      );
      await _loadState();
      if (!mounted) return;
      setState(() => _operationStatus = 'ارسال به سرور انجام شد');
      _pulseLiveUi();

      if (sent == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('هیچ رکوردی ارسال نشد.')),
        );
      } else {
        final buf = StringBuffer()
          ..writeln('ارسال $sent پرونده به سرور انجام شد.')
          ..writeln('دیتابیس: ${fin.inserted} پرونده، ${fin.docsInserted} سند.');
        if (fin.skipped > 0) {
          buf.writeln('رد شده (تکراری): ${fin.skipped}');
        }
        if (!fin.success && fin.failed > 0) {
          buf.writeln('خطا در نهایی‌سازی: ${fin.failed}');
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(buf.toString().trim()),
            duration: const Duration(seconds: 12),
          ),
        );
      }
    } catch (e) {
      _appendLog('خطا در ارسال: $e', op: AsnafOpLog.send);
      if (mounted) {
        setState(() => _operationStatus = 'خطا در ارسال به سرور');
        _pulseLiveUi();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطا در ارسال: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        _pulseLiveUi();
        await _loadState();
      }
    }
  }

  Future<void> _showDraftList() async {
    if (!mounted) return;
    var filter = SyncStatusFilter.all;
    var records = await _draftStore.read(filter: filter);
    AsnafOpLog.line(AsnafOpLog.draft, 'باز شدن حافظه محلی | n=${records.length}');
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setLocal) {
            Future<void> reload() async {
              records = await _draftStore.read(filter: filter);
              setLocal(() {});
            }

            final c = _syncCounts;
            return SizedBox(
            height: MediaQuery.of(context).size.height * 0.86,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 10, 10, 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'حافظه محلی (${records.length})'
                          '${c != null ? ' · ارسال‌نشده:${c.local} · ارسال‌شده:${c.synced} · بروز:${c.dirty}' : ''}',
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
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
                                await _loadState();
                                await reload();
                                _appendLog('حافظه محلی دستی خالی شد', op: AsnafOpLog.draft);
                              },
                        icon: const Icon(Icons.delete_sweep_outlined),
                        label: const Text('خالی کردن حافظه'),
                      ),
                    ],
                  ),
                ),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    children: [
                      for (final f in SyncStatusFilter.values)
                        Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: FilterChip(
                            label: Text(_filterLabel(f)),
                            selected: filter == f,
                            onSelected: (_) async {
                              filter = f;
                              AsnafOpLog.line(AsnafOpLog.draft, 'فیلتر=${_filterLabel(f)}');
                              await reload();
                            },
                          ),
                        ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: records.isEmpty
                      ? const Center(child: Text('رکوردی با این فیلتر نیست.'))
                      : ListView.builder(
                          itemCount: records.length,
                          itemBuilder: (_, i) {
                            final r = records[i];
                            final name =
                                '${r.payload['name_admin'] ?? ''} ${r.payload['family_admin'] ?? ''}'
                                    .trim();
                            return ListTile(
                              title: Text(name.isEmpty ? '—' : name),
                              subtitle: Text(
                                'ID: ${r.clientTempId} · ${_syncStatusLabel(r)}',
                              ),
                              leading: IconButton(
                                tooltip: 'ویرایش',
                                onPressed: () async {
                                  final edited = await _editDraftRecord(r);
                                  if (edited == null) return;
                                  await _draftStore.updateAfterEdit(edited);
                                  await reload();
                                  if (!mounted) return;
                                  await _loadState();
                                  setLocal(() {});
                                  _appendLog('ویرایش رکورد id=${edited.clientTempId}', op: AsnafOpLog.draft);
                                },
                                icon: const Icon(Icons.edit_outlined),
                              ),
                              trailing: IconButton(
                                tooltip: 'حذف',
                                onPressed: () async {
                                  await _draftStore.deleteRecord(r.clientTempId);
                                  AsnafOpLog.line(AsnafOpLog.draft, 'حذف رکورد id=${r.clientTempId}');
                                  await reload();
                                  if (!mounted) return;
                                  await _loadState();
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
          );
          },
        );
      },
    );
  }

  String _filterLabel(SyncStatusFilter f) => switch (f) {
        SyncStatusFilter.all => 'همه',
        SyncStatusFilter.pendingSend => 'ارسال‌نشده + بروز',
        SyncStatusFilter.synced => 'ارسال‌شده',
        SyncStatusFilter.dirty => 'نیاز ارسال مجدد',
      };

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
                        final geo = await AddressGeocodingService.instance.resolve(
                          address: addressCtrl.text.trim(),
                          state: payload['state_store'] ?? '',
                          city: payload['city_store'] ?? '',
                        );
                        if (geo == null) {
                          AsnafOpLog.line(AsnafOpLog.geo, 'ژئوکد ناموفق برای ${record.clientTempId}');
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'استخراج لوکیشن ناموفق بود یا مختصات خارج از محدوده استان است.',
                              ),
                            ),
                          );
                          return;
                        }
                        latCtrl.text = geo.$1;
                        longCtrl.text = geo.$2;
                        setLocal(() {});
                        AsnafOpLog.line(AsnafOpLog.geo, 'ژئوکد موفق برای ${record.clientTempId}');
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
    final ready = _pendingSendCount > 0 && !_busy;
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 6),
      child: Tooltip(
        message: 'ارسال پرونده‌های ارسال‌نشده/نیاز به بروزرسانی به سرور',
        child: FilledButton.icon(
          onPressed: ready ? () => unawaited(_sendToServer()) : null,
          icon: const Icon(Icons.cloud_upload_rounded, size: 18),
          label: Text(
            _pendingSendCount > 0 ? 'ارسال ($_pendingSendCount)' : 'ارسال',
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
                        label: 'بروزرسانی',
                        icon: Icons.sync_rounded,
                        tooltip: 'تست ۵ پرونده، جدیدترین‌ها یا بروزرسانی کامل',
                        onPressed: _busy ? null : _onUpdatePressed,
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
                      tooltip: 'لاگ تست عملیات (کپی و ارسال برای رفع ایراد)',
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.18),
                        foregroundColor: Colors.white,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: _showSessionLogsSheet,
                      icon: const Icon(Icons.terminal, size: 20),
                    ),
                    IconButton(
                      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                      padding: EdgeInsets.zero,
                      tooltip: 'تازه‌سازی توکن از WebView',
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.18),
                        foregroundColor: Colors.white,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: _busy || _webController == null
                          ? null
                          : () => _extractAndSaveToken(silent: false),
                      icon: const Icon(Icons.key_outlined, size: 20),
                    ),
                    IconButton(
                      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                      padding: EdgeInsets.zero,
                      tooltip: 'پاک کردن توکن JWT ذخیره‌شده',
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.18),
                        foregroundColor: Colors.white,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: _busy ? null : _clearStoredJwt,
                      icon: const Icon(Icons.key_off_outlined, size: 20),
                    ),
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
                  useOnDownloadStart: true,
                  useShouldOverrideUrlLoading: true,
                  useOnLoadResource: true,
                ),
                initialUserScripts: UnmodifiableListView<UserScript>([
                  UserScript(
                    source: AsnafWebViewApi.networkHookSource,
                    injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
                    forMainFrameOnly: false,
                  ),
                ]),
                onWebViewCreated: (controller) {
                  _webController = controller;
                  _syncBotWebViewApi();
                  AsnafOpLog.line(AsnafOpLog.web, 'WebView ساخته شد');
                },
                onLoadStart: (controller, url) {
                  AsnafOpLog.line(
                    AsnafOpLog.web,
                    'load_start | ${AsnafOpLog.clip(url?.toString() ?? '')}',
                  );
                },
                onLoadResource: (controller, resource) {
                  final u = resource.url?.toString() ?? '';
                  if (u.contains('parvaneh') ||
                      u.contains('apinovin') ||
                      u.contains('/docs')) {
                    AsnafOpLog.line(
                      AsnafOpLog.api,
                      'resource ${AsnafOpLog.shortUrl(u)}',
                    );
                  }
                },
                onConsoleMessage: (controller, consoleMessage) {
                  final m = consoleMessage.message;
                  if (m.startsWith('[AsnafNet]')) {
                    AsnafOpLog.line(AsnafOpLog.api, m);
                  }
                },
                onReceivedError: (controller, request, error) {
                  AsnafOpLog.line(
                    AsnafOpLog.web,
                    'خطای بارگذاری | type=${error.type} desc=${error.description} '
                    'url=${AsnafOpLog.clip(request.url.toString())}',
                  );
                },
                onReceivedServerTrustAuthRequest: (controller, challenge) async {
                  final host = challenge.protectionSpace.host;
                  if (host.contains('apinovin.iranianasnaf.ir')) {
                    AsnafOpLog.line(AsnafOpLog.web, 'SSL trust قبول شد | host=$host');
                  }
                  return ServerTrustAuthResponse(
                    action: ServerTrustAuthResponseAction.PROCEED,
                  );
                },
                onUpdateVisitedHistory: (controller, url, isReload) {
                  final urlStr = url?.toString() ?? '';
                  if (!AsnafJwtPolicy.isAuthenticatedPanelUrl(urlStr)) return;
                  AsnafOpLog.line(
                    AsnafOpLog.web,
                    'ورود به پنل (hash) | ${AsnafOpLog.clip(urlStr)}',
                  );
                  unawaited(_extractAndSaveToken(silent: true, pageUrl: urlStr));
                },
                onDownloadStartRequest: (controller, request) {
                  unawaited(
                    _saveWebViewDownload(
                      url: request.url,
                      mimeType: request.mimeType,
                      suggestedFilename: request.suggestedFilename,
                      contentDisposition: request.contentDisposition,
                    ),
                  );
                },
                shouldOverrideUrlLoading: (controller, action) async {
                  final url = action.request.url;
                  if (url == null) {
                    return NavigationActionPolicy.ALLOW;
                  }
                  final urlStr = url.toString();
                  if (!AsnafWebViewDownload.looksLikeFileUrl(urlStr)) {
                    return NavigationActionPolicy.ALLOW;
                  }
                  unawaited(
                    _saveWebViewDownload(url: url),
                  );
                  return NavigationActionPolicy.CANCEL;
                },
                onLoadStop: (controller, url) async {
                  final urlStr = url?.toString() ?? '';
                  AsnafOpLog.line(
                    AsnafOpLog.web,
                    'load_stop | panel=${AsnafJwtPolicy.isAuthenticatedPanelUrl(urlStr)} '
                    'loginPage=${AsnafJwtPolicy.isPublicOrLoginUrl(urlStr)} '
                    'url=${AsnafOpLog.clip(urlStr)}',
                  );
                  _syncBotWebViewApi();
                  await _extractAndSaveToken(
                    silent: true,
                    pageUrl: urlStr,
                  );
                  await _maybeOfferSaveCsvPage(controller, url);
                },
              ),
      ),
    );
  }
}

class _FullUpdatePlan {
  const _FullUpdatePlan({
    required this.startPage,
    required this.endPage,
    this.maxRecords,
    this.resumeCheckpoint = false,
  });

  final int startPage;
  final int endPage;
  final int? maxRecords;
  final bool resumeCheckpoint;
}

class _FullUpdatePlanDialog extends StatefulWidget {
  const _FullUpdatePlanDialog({
    required this.totalPages,
    required this.totalCount,
    this.checkpoint,
  });

  final int totalPages;
  final int totalCount;
  final AsnafRecoveryState? checkpoint;

  @override
  State<_FullUpdatePlanDialog> createState() => _FullUpdatePlanDialogState();
}

class _FullUpdatePlanDialogState extends State<_FullUpdatePlanDialog> {
  late final TextEditingController _fromCtrl;
  late final TextEditingController _toCtrl;
  late final TextEditingController _maxCtrl;
  String? _error;

  @override
  void initState() {
    super.initState();
    final cp = widget.checkpoint;
    final defaultFrom = (cp != null && cp.currentPage > 0) ? cp.currentPage : 1;
    _fromCtrl = TextEditingController(text: '$defaultFrom');
    _toCtrl = TextEditingController(
      text: '${widget.totalPages > 0 ? widget.totalPages : 1}',
    );
    _maxCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _fromCtrl.dispose();
    _toCtrl.dispose();
    _maxCtrl.dispose();
    super.dispose();
  }

  int? _parsePositive(String raw) {
    final n = int.tryParse(raw.trim());
    if (n == null || n < 1) return null;
    return n;
  }

  int _approxCount(int start, int end, int? max) {
    final pages = (end - start + 1).clamp(1, 100000);
    late final int approx;
    if (start == 1 && end == widget.totalPages && widget.totalCount > 0) {
      approx = widget.totalCount;
    } else {
      final perPage = widget.totalPages > 0
          ? (widget.totalCount / widget.totalPages).round().clamp(1, 50)
          : 20;
      approx = pages * perPage;
    }
    if (max != null && max > 0 && max < approx) return max;
    return approx;
  }

  void _submit({required bool resume}) {
    if (resume) {
      final cp = widget.checkpoint;
      if (cp == null) return;
      Navigator.pop(
        context,
        _FullUpdatePlan(
          startPage: cp.startPage,
          endPage: cp.endPage,
          resumeCheckpoint: true,
        ),
      );
      return;
    }
    final start = _parsePositive(_fromCtrl.text);
    final end = _parsePositive(_toCtrl.text);
    final maxRaw = _maxCtrl.text.trim();
    final max = maxRaw.isEmpty ? null : _parsePositive(maxRaw);
    if (start == null || end == null) {
      setState(() => _error = 'شماره صفحه باید عدد بزرگ‌تر از صفر باشد.');
      return;
    }
    if (end < start) {
      setState(() => _error = 'صفحهٔ پایان نباید از صفحهٔ شروع کوچک‌تر باشد.');
      return;
    }
    if (maxRaw.isNotEmpty && max == null) {
      setState(() => _error = 'حداکثر تعداد باید عدد بزرگ‌تر از صفر باشد، یا خالی بماند.');
      return;
    }
    final lastPage = widget.totalPages > 0 ? widget.totalPages : end;
    Navigator.pop(
      context,
      _FullUpdatePlan(
        startPage: start,
        endPage: end > lastPage ? lastPage : end,
        maxRecords: max,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final start = _parsePositive(_fromCtrl.text) ?? 1;
    final end = _parsePositive(_toCtrl.text) ?? start;
    final maxRaw = _maxCtrl.text.trim();
    final max = maxRaw.isEmpty ? null : _parsePositive(maxRaw);
    final planned = end >= start ? _approxCount(start, end, max) : 0;
    final hours = AsnafHumanPace.estimateHoursForCount(planned);
    final cp = widget.checkpoint;

    return AlertDialog(
      title: const Text('بروزرسانی کامل'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'در API حدود ${widget.totalCount} پرونده در ${widget.totalPages} صفحه است.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              if (cp != null) ...[
                const SizedBox(height: 12),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'پیشرفت ناتمام: صفحه ${cp.currentPage} '
                          '(مورد ${cp.currentIndexInPage}) — ${cp.processedCount} پرونده پردازش شده.',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'اگر توکن قطع شد، «ادامه از همان‌جا» را بزنید تا از صفحهٔ اول تکرار نشود.',
                        ),
                        const SizedBox(height: 8),
                        FilledButton.tonal(
                          onPressed: () => _submit(resume: true),
                          child: Text('ادامه از صفحه ${cp.currentPage}'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Text(
                cp == null ? 'محدوده این اجرا' : 'یا محدودهٔ جدید',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _fromCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: 'از صفحه',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => setState(() => _error = null),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _toCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: 'تا صفحه',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => setState(() => _error = null),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _maxCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'حداکثر تعداد این اجرا (اختیاری)',
                  hintText: 'مثلاً ۴۰۰ — خالی یعنی همهٔ صفحات انتخاب‌شده',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() => _error = null),
              ),
              const SizedBox(height: 12),
              Text(
                planned > 0
                    ? 'تخمین این اجرا: حدود $planned پرونده، ${hours.toStringAsFixed(1)} ساعت.'
                    : 'محدوده را وارد کنید.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('بازگشت'),
        ),
        FilledButton(
          onPressed: () => _submit(resume: false),
          child: const Text('شروع'),
        ),
      ],
    );
  }
}
