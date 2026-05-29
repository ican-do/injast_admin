import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:injast_admin/asnaf_live_operation_dialog.dart';
import 'package:injast_admin/file_management/address_geocoding_service.dart';
import 'package:injast_admin/import_sync/asnaf_bot_client.dart';
import 'package:injast_admin/import_sync/asnaf_first_five_test_report_store.dart';
import 'package:injast_admin/import_sync/asnaf_fetch_pace.dart';
import 'package:injast_admin/import_sync/asnaf_human_pace.dart';
import 'package:injast_admin/import_sync/asnaf_jwt_extract.dart';
import 'package:injast_admin/import_sync/asnaf_jwt_policy.dart';
import 'package:injast_admin/import_sync/asnaf_recovery_store.dart';
import 'package:injast_admin/import_sync/asnaf_webview_api.dart';
import 'package:injast_admin/import_sync/asnaf_webview_download.dart';
import 'package:injast_admin/import_sync/import_draft_store.dart';
import 'package:injast_admin/import_sync/import_models.dart';
import 'package:injast_admin/local_cache/network_reachability.dart';
import 'package:injast_admin/local_cache/offline_mode_prefs.dart';
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
  final _offlinePrefs = OfflineModePrefs();

  bool _busy = false;
  bool _stopRequested = false;
  bool _paused = false;
  /// پس از پایان یک دور بازیابی (توقف، خطا، یا اتمام) امکان «ذخیره در سرور» از داخل دیالوگ.
  bool _recoveryEndedAllowingSave = false;
  int _totalCount = 0;
  int _draftCount = 0;
  int _pendingSendCount = 0;
  bool _offlineMode = false;
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
    _draftStore = ImportDraftStore(widget.codeCo);
    unawaited(_loadState());
    unawaited(_refreshFirstFiveTestReportFlag());
    unawaited(_purgeExpiredJwtOnOpen());
  }

  Future<void> _purgeExpiredJwtOnOpen() async {
    final t = await _readToken();
    if (t.isEmpty) return;
    if (!AsnafJwtPolicy.isExpired(t)) return;
    await _stateStore.clearJwt();
    _appendLog('Expired JWT removed on page open.');
    if (mounted) {
      setState(() => _operationStatus = 'توکن منقضی پاک شد — در WebView دوباره لاگین کنید');
    }
  }

  @override
  void dispose() {
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
    final offline = await _offlinePrefs.isOfflineEffective(widget.codeCo);
    final state = await _stateStore.readState();
    if (!mounted) return;
    setState(() {
      _syncCounts = counts;
      _draftCount = counts.total;
      _pendingSendCount = counts.pendingSend;
      _offlineMode = offline;
      _totalCount = state?.totalPlanned ?? 0;
    });
  }

  Future<void> _toggleOfflineMode(bool value) async {
    if (!value) {
      final online = await NetworkReachability.instance.isServerReachable();
      if (!online) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('سرور در دسترس نیست؛ تا برقراری اتصال، حالت آفلاین فعال می‌ماند.'),
          ),
        );
        return;
      }
      await _offlinePrefs.setUserOffline(widget.codeCo, false);
      await _offlinePrefs.clearAutoOfflineIfOnline(widget.codeCo);
    } else {
      await _offlinePrefs.setUserOffline(widget.codeCo, true);
    }
    if (!mounted) return;
    setState(() => _offlineMode = value);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          value
              ? 'حالت آفلاین: فقط حافظهٔ محلی (بدون API اصناف).'
              : 'حالت آنلاین: استخراج و بروزرسانی از API فعال است.',
        ),
      ),
    );
  }

  String _syncStatusLabel(ImportDraftRecord r) {
    final st = ParvandeSyncStatusX.fromStorage(r.payload['_sync_status']);
    return st.labelFa;
  }

  void _appendLog(String line) {
    final now = DateTime.now();
    final ts =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
    final entry = '[$ts] $line';
    developer.log(line, name: 'AsnafSite');
    _logs.insert(0, entry);
    if (_logs.length > 200) {
      _logs.removeRange(200, _logs.length);
    }
    _pulseLiveUi();
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

  void _beginLiveSession(String sessionMode, {AsnafMeta? planMeta}) {
    AsnafFetchPace.currentMode = AsnafFetchPaceMode.safe;
    if (sessionMode != 'debt_full' && sessionMode != 'debt_latest') {
      AsnafHumanPace.instance.resetSession();
    }
    _logs.clear();
    _recoveryProgress.clear();
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
      _totalCount = switch (sessionMode) {
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
    _appendLog('▶ شروع: ${_sessionTitle(sessionMode)}');
  }

  /// دیالوگ زنده بلافاصله باز می‌شود؛ کار در پس‌زمینه ادامه دارد.
  Future<void> _openLiveOperationDialogThenRun({
    required String sessionMode,
    AsnafMeta? planMeta,
    required Future<void> Function() run,
  }) async {
    _beginLiveSession(sessionMode, planMeta: planMeta);
    if (!mounted) return;
    unawaited(
      run().whenComplete(() {
        if (!mounted) return;
        _appendLog('── پایان عملیات ──');
        _pulseLiveUi();
      }),
    );
    await _showOperationDialog(sessionMode: sessionMode);
  }

  Future<String> _readToken() async => _stateStore.readJwt();

  Future<void> _clearStoredJwt() async {
    await _stateStore.clearJwt();
    _appendLog('JWT cleared (manual or policy).');
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
    await _stateStore.clearJwt();
    _appendLog('API ${e.statusCode} — JWT cleared; recovery stopped.');
    if (!mounted) return true;
    setState(() => _operationStatus = 'دسترسی API قطع شد — لاگین مجدد در WebView');
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ذخیره فایل لغو شد.')),
        );
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('فایل ذخیره شد:\n$path'),
          duration: const Duration(seconds: 6),
        ),
      );
    } catch (e) {
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
    if (!isTextExport) return;
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
    if (tryWebExtract && _webController != null) {
      _syncBotWebViewApi();
      await _extractAndSaveToken(silent: true);
    }
    var token = await _readToken();
    if (token.isNotEmpty && AsnafJwtPolicy.isExpired(token)) {
      await _stateStore.clearJwt();
      _appendLog('Stored JWT was expired — cleared.');
      token = '';
    }
    if (token.isEmpty && tryWebExtract && _webController != null) {
      await _extractAndSaveToken(silent: true);
      token = await _readToken();
    }
    if (token.isEmpty) return null;
    if (AsnafJwtPolicy.isExpired(token)) {
      await _stateStore.clearJwt();
      return null;
    }
    return token;
  }

  Future<void> _extractAndSaveToken({bool silent = false, String? pageUrl}) async {
    final c = _webController;
    if (c == null) return;
    if (pageUrl != null && !AsnafJwtPolicy.isAuthenticatedPanelUrl(pageUrl)) {
      return;
    }
    setState(() => _busy = true);
    try {
      final raw = await c.evaluateJavascript(
        source: AsnafJwtExtract.extractJavaScript,
        contentWorld: ContentWorld.PAGE,
      );
      final token = AsnafJwtExtract.parseTokenFromJsResult(raw);
      if (token == null || token.isEmpty) {
        _appendLog('JWT not found; login required.');
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
      _appendLog('JWT saved from WebView (authenticated panel).');
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
    if (!full) {
      await _startLatestFlow();
      return;
    }

    final token = await _ensureValidToken();
    if (token == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'توکن معتبر نیست. در WebView تا صفحهٔ پنل (بعد از login) بروید، سپس دوباره تلاش کنید.',
          ),
        ),
      );
      return;
    }

  if (!mounted) return;
    final choice = await _showManualFullUpdateDialog();
    if (!mounted || choice == null) return;

    if (choice.isTestFirst5) {
      await _openLiveOperationDialogThenRun(
        sessionMode: 'test_first_5',
        run: () => _runTestFirstFiveRecords(token: token),
      );
      return;
    }

    final planMeta = choice.metaOrNull;
    if (planMeta == null) return;

    final warn = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('هشدار قبل از شروع'),
        content: Text(
          'بروزرسانی کامل ${planMeta.totalPages} صفحه (تخمین ${planMeta.totalCount} پرونده) '
          'با فاصلهٔ تصادفی ۱۰–۲۰ ثانیه بین پرونده‌ها و استراحت ۳۰–۴۵ دقیقه هر ۳۰۰ پرونده انجام می‌شود.\n\n'
          'تا پایان، پنجره برنامه و اینترنت را قطع نکنید.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('بازگشت')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('تایید و شروع')),
        ],
      ),
    );
    if (warn != true) return;

    await _openLiveOperationDialogThenRun(
      sessionMode: 'full',
      planMeta: planMeta,
      run: () => _runRecovery(
        recoveryMode: 'full',
        token: token,
        planMeta: planMeta,
      ),
    );
  }

  Future<void> _startLatestFlow() async {
    final token = await _ensureValidToken();
    if (token == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('توکن معتبر نیست. ابتدا در WebView لاگین کنید.')),
      );
      return;
    }

    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('بروزرسانی جدیدترین موارد'),
        content: const Text(
          'فقط $_kAsnafLatestPagesWindow صفحهٔ آخر لیست (حدود ۱۰۰ پرونده) پردازش می‌شود.\n\n'
          'تعداد کل پرونده‌ها از سرور دریافت نمی‌شود؛ پس از شروع، صفحهٔ پایانی از همان پاسخ لیست مشخص می‌شود.\n\n'
          'تصاویر پروانه، پروفایل و همهٔ مدارک دانلود می‌شوند. '
          'بین هر پرونده ۱۰–۲۰ ثانیه (تصادفی) و هر ۳۰۰ پرونده استراحت ۳۰–۴۵ دقیقه.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('انصراف')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('شروع')),
        ],
      ),
    );
    if (ok != true) return;

    await _openLiveOperationDialogThenRun(
      sessionMode: 'latest',
      run: () => _runRecovery(
        recoveryMode: 'latest',
        token: token,
        discoverLatestPages: true,
      ),
    );
  }

  Future<_ManualFullUpdateChoice?> _showManualFullUpdateDialog() async {
    final countCtrl = TextEditingController();
    final pagesCtrl = TextEditingController();
    try {
      return await showDialog<_ManualFullUpdateChoice>(
        context: context,
        builder: (ctx) {
          return StatefulBuilder(
            builder: (ctx, setLocal) {
              final count = int.tryParse(countCtrl.text.trim()) ?? 0;
              final pages = int.tryParse(pagesCtrl.text.trim()) ?? 0;
              final est = AsnafHumanPace.estimateHoursForCount(count);
              return AlertDialog(
                title: const Text('بروزرسانی کامل اطلاعات'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'تعداد پرونده و صفحات را دستی وارد کنید (فقط برای تخمین زمان در همین دیالوگ؛ '
                        'هنگام فشردن دکمه درخواست شمارشی به سرور ارسال نمی‌شود).',
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: countCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'تعداد تقریبی پرونده‌ها',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        onChanged: (_) => setLocal(() {}),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: pagesCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'تعداد صفحات لیست API',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        onChanged: (_) => setLocal(() {}),
                      ),
                      if (count > 0) ...[
                        const SizedBox(height: 10),
                        Text('تخمین زمان (رفتار ایمن): حدود ${est.toStringAsFixed(1)} ساعت'),
                      ],
                      const SizedBox(height: 10),
                      Text(
                        'پس از شروع: فاصلهٔ ۱۰–۲۰ ثانیه بین پرونده‌ها، استراحت ۳۰–۴۵ دقیقه هر ۳۰۰ پرونده. '
                        'عکس پروانه، تصویر شخص و همهٔ مدارک استخراج می‌شوند.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('انصراف')),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, const _ManualFullUpdateChoice.testFirst5()),
                    child: const Text('تست ۵ پرونده'),
                  ),
                  FilledButton(
                    onPressed: pages > 0
                        ? () => Navigator.pop(
                              ctx,
                              _ManualFullUpdateChoice.start(
                                AsnafMeta(totalCount: count > 0 ? count : pages * 20, totalPages: pages),
                              ),
                            )
                        : null,
                    child: const Text('شروع عملیات'),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      countCtrl.dispose();
      pagesCtrl.dispose();
    }
  }

  /// همان مسیر [buildDraftRecord] عملیات کامل (جزئیات، اسناد، ژئوکد) برای پنج پروندهٔ اول لیست API.
  Future<void> _runTestFirstFiveRecords({
    required String token,
  }) async {
    var ok = 0;
    var fail = 0;
    final entries = <AsnafFirstFiveTestEntry>[];
    final neshanOk = _bot.isNeshanGeocodingConfigured;
    if (_offlineMode) {
      _appendLog('خطا: حالت آفلاین — تست آنلاین غیرفعال است');
      if (mounted) {
        setState(() {
          _busy = false;
          _operationStatus = 'تست در حالت آفلاین ممکن نیست';
        });
      }
      return;
    }
    try {
      const target = 5;
      var collected = 0;
      var page = 1;

      while (collected < target) {
        _appendLog('دریافت لیست صفحه $page…');
        setState(() => _operationStatus = 'دریافت لیست صفحه $page');
        _pulseLiveUi();
        final rows = await _bot.fetchParvandehPage(token: token, page: page);
        _appendLog('صفحه $page: ${rows.length} ردیف');
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
          _appendLog('── پرونده $collected/$target | id=$id ──');
          _appendLog('دریافت جزئیات و مدارک…');
          final sw = Stopwatch()..start();
          try {
            final record = await _bot.buildDraftRecord(
              token: token,
              codeCo: widget.codeCo,
              parvanehId: id,
              includeDocs: true,
              geocodeIfMissing: false,
            );
            _appendLog('ذخیره در حافظه و دانلود تصاویر…');
            await _draftStore.upsert(record);
            ok++;
            _processedCount = ok + fail;
            _pushRecoveryProgress(id, 'ok', 'ذخیره شد — ${record.payload['name_store'] ?? ''}');
            entries.add(AsnafFirstFiveTestEntry.fromSuccess(record, neshanKeyConfigured: neshanOk));
            _appendLog('✓ موفق id=$id');
            _pulseLiveUi();
          } catch (e) {
            fail++;
            _processedCount = ok + fail;
            _failedCount = fail;
            _pushRecoveryProgress(id, 'error', e.toString());
            entries.add(AsnafFirstFiveTestEntry.failure(id, e));
            _appendLog('✗ خطا id=$id | $e');
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
        _appendLog('Test first 5: only $collected dossiers in API range (expected $target).');
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
      _appendLog('Test first 5 fatal: $e');
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
                  _appendLog('⏹ درخواست توقف کامل');
                }
              : null,
          onPause: (_busy && !_stopRequested && !_paused)
              ? () {
                  _paused = true;
                  setState(() => _operationStatus = 'متوقف موقت');
                  _appendLog('⏸ توقف موقت');
                }
              : null,
          onResume: ((_busy && _paused) || (!_busy && (_operationStatus.contains('متوقف') || _operationStatus.contains('خطا در عملیات'))))
              ? () async {
                  if (_busy && _paused) {
                    _paused = false;
                    setState(() => _operationStatus = 'ادامه پس از توقف موقت…');
                    _appendLog('▶ ادامه از توقف موقت');
                    return;
                  }
                  final token = await _readToken();
                  if (token.isEmpty) return;
                  final st = await _stateStore.readState();
                  if (st == null || !mounted) return;
                  setState(() => _operationStatus = 'شروع مجدد…');
                  _appendLog('▶ شروع مجدد از checkpoint');
                  unawaited(_runRecovery(
                    recoveryMode: sessionMode,
                    token: token,
                    planMeta: AsnafMeta(
                      totalCount: st.totalPlanned,
                      totalPages: st.endPage,
                    ),
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
    var authBlocked = false;

    if (_offlineMode) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('در حالت آفلاین استخراج از API اصناف غیرفعال است. سوئیچ را روی آنلاین بگذارید.'),
        ),
      );
      return;
    }

    try {
      final currentState = await _stateStore.readState();
      final resume = currentState != null &&
          currentState.running &&
          currentState.mode == recoveryMode;

      late int startPage;
      late int endPage;
      late int totalCount;

      if (resume) {
        startPage = currentState.startPage;
        endPage = currentState.endPage;
        totalCount = currentState.totalPlanned;
      } else if (discoverLatestPages) {
        final first = await _bot.fetchParvandehPageWithMeta(token: token, page: 1);
        final totalPages = first.meta.totalPages;
        endPage = totalPages;
        startPage = totalPages > _kAsnafLatestPagesWindow
            ? totalPages - _kAsnafLatestPagesWindow + 1
            : 1;
        totalCount = (_kAsnafLatestPagesWindow * 20).clamp(1, first.meta.totalCount);
        _appendLog('Latest window | pages $startPage..$endPage (discovered totalPages=$totalPages)');
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
      late int currentPage;
      late int currentIndex;
      late int processed;
      late int failed;
      if (resume) {
        currentPage = currentState.currentPage;
        currentIndex = currentState.currentIndexInPage;
        processed = currentState.processedCount;
        failed = currentState.failedCount;
      } else if (resumeCheckpoint) {
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

      if (!resume && !resumeCheckpoint) {
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

      for (var page = currentPage; page <= endPage; page++) {
        if (authBlocked) break;
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
        _appendLog('Page $page loaded with ${rows.length} rows');
        final startIndex = (page == currentPage) ? currentIndex : 0;
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
                _appendLog('Debt record OK id=$id | upsert=$up');
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
              _appendLog('Record OK id=$id | upsert=$up');
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
            _appendLog('Record ERROR id=$id | $e');
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
        }
        currentIndex = 0;
        if (!authBlocked) {
          await Future<void>.delayed(AsnafFetchPace.current.pauseAfterListPage);
        }
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
        _pulseLiveUi();
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
    final records = await _draftStore.readPendingForSync();
    if (!mounted) return;
    if (records.isEmpty) {
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
      if (ok != true) return;
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
          _appendLog(p.message);
        },
      );

      final fin = result.finalize;
      final sent = result.sentRecords;
      _appendLog(
        'نهایی‌سازی | پرونده=${fin.inserted} رد=${fin.skipped} | '
        'سند=${fin.docsInserted} | خطا=${fin.failed}',
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
      _appendLog('خطا در ارسال: $e');
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
                                _appendLog('Local cache cleared manually.');
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
                                  _appendLog('Draft edited id=${edited.clientTempId}');
                                },
                                icon: const Icon(Icons.edit_outlined),
                              ),
                              trailing: IconButton(
                                tooltip: 'حذف',
                                onPressed: () async {
                                  await _draftStore.deleteRecord(r.clientTempId);
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
                        label: 'جدیدترین‌ها',
                        icon: Icons.update_rounded,
                        tooltip: '۵ صفحهٔ آخر (~۱۰۰ پرونده)',
                        onPressed: _busy ? null : () => _startFlow(full: false),
                      ),
                      _asnafToolbarAction(
                        label: 'بروزرسانی کامل',
                        icon: Icons.sync_alt_rounded,
                        tooltip: 'جزئیات، اسناد و مختصات برای همهٔ صفحات',
                        onPressed: _busy ? null : () => _startFlow(full: true),
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
                    FutureBuilder<bool>(
                      future: NetworkReachability.instance.isServerReachableCached(),
                      builder: (context, snap) {
                        final serverUp = snap.data ?? true;
                        final lockedOffline = _offlineMode && !serverUp;
                        return Tooltip(
                          message: lockedOffline
                              ? 'قطع اینترنت/سرور — آفلاین اجباری'
                              : (_offlineMode
                                  ? 'حالت آفلاین — فقط حافظه محلی'
                                  : 'حالت آنلاین — استخراج از API'),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'آفلاین',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.white.withValues(alpha: 0.9),
                                ),
                              ),
                              Switch(
                                value: _offlineMode,
                                onChanged: (_busy || lockedOffline) ? null : _toggleOfflineMode,
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 4),
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
                ),
                onWebViewCreated: (controller) {
                  _webController = controller;
                  _syncBotWebViewApi();
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
                  _syncBotWebViewApi();
                  await _extractAndSaveToken(
                    silent: true,
                    pageUrl: url?.toString(),
                  );
                  await _maybeOfferSaveCsvPage(controller, url);
                },
              ),
      ),
    );
  }
}

class _ManualFullUpdateChoice {
  const _ManualFullUpdateChoice._(this.action, this.meta);

  const _ManualFullUpdateChoice.testFirst5() : this._('test_first_5', null);

  const _ManualFullUpdateChoice.start(AsnafMeta m) : this._('start', m);

  final String action;
  final AsnafMeta? meta;

  bool get isTestFirst5 => action == 'test_first_5';
  AsnafMeta? get metaOrNull => meta;
}
