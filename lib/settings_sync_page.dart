import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:injast_admin/asnaf_login_desktop_page.dart';
import 'package:injast_admin/import_sync/asnaf_bot_client.dart';
import 'package:injast_admin/import_sync/import_draft_store.dart';
import 'package:injast_admin/import_sync/import_models.dart';
import 'package:injast_admin/import_sync/import_sync_api.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsSyncPage extends StatefulWidget {
  const SettingsSyncPage({
    super.key,
    required this.codeCo,
  });

  final String codeCo;

  @override
  State<SettingsSyncPage> createState() => _SettingsSyncPageState();
}

class _SettingsSyncPageState extends State<SettingsSyncPage> {
  final _bot = AsnafBotClient();
  final _draftStore = ImportDraftStore();
  final _syncApi = ImportSyncApi.instance;
  final _tokenCtrl = TextEditingController();

  bool _busy = false;
  int _draftCount = 0;
  int? _metaTotalCount;
  int? _metaTotalPages;
  String _recoveryMode = 'direct'; // direct | csv
  int _progressSuccess = 0;
  int _progressFailed = 0;
  int _progressPlanned = 0;
  String _progressCurrentName = '—';
  String _progressCurrentDetails = '';
  final List<String> _progressLogs = [];

  @override
  void initState() {
    super.initState();
    _reloadDraftCount();
  }

  @override
  void dispose() {
    _tokenCtrl.dispose();
    super.dispose();
  }

  Future<void> _reloadDraftCount() async {
    final records = await _draftStore.read();
    if (!mounted) return;
    setState(() => _draftCount = records.length);
  }

  Future<void> _collectToDraft({
    required int startPage,
    required int endPage,
    int? maxRecords,
  }) async {
    final token = _tokenCtrl.text.trim();
    if (token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('توکن JWT الزامی است.')),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      setState(() {
        _progressSuccess = 0;
        _progressFailed = 0;
        _progressPlanned = maxRecords ?? 0;
        _progressCurrentName = 'شروع عملیات...';
        _progressCurrentDetails = '';
        _progressLogs.clear();
      });
      final records = await _bot.collectRecords(
        token: token,
        codeCo: widget.codeCo,
        startPage: startPage,
        endPage: endPage,
        updateDebtOnly: false,
        maxRecords: maxRecords,
        onProgress: (p) {
          if (!mounted) return;
          setState(() {
            _progressSuccess = p.successCount;
            _progressFailed = p.failedCount;
            _progressPlanned = p.plannedCount;
            _progressCurrentName = p.name.isEmpty ? '—' : p.name;
            _progressCurrentDetails = p.details;
            if (p.stage == 'record_ok' || p.stage == 'record_error') {
              final line =
                  '${p.stage == 'record_ok' ? '✅' : '❌'} ${p.name.isEmpty ? 'رکورد' : p.name} | ${p.details}';
              _progressLogs.insert(0, line);
              if (_progressLogs.length > 24) {
                _progressLogs.removeRange(24, _progressLogs.length);
              }
            }
          });
        },
      );
      await _draftStore.save(records);
      await _reloadDraftCount();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${records.length} رکورد در حافظه موقت ذخیره شد.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطا در دریافت/ذخیره موقت: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _fetchMeta() async {
    final token = _tokenCtrl.text.trim();
    if (token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('توکن JWT الزامی است.')),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      final meta = await _bot.fetchMeta(token);
      if (!mounted) return;
      setState(() {
        _metaTotalCount = meta.totalCount;
        _metaTotalPages = meta.totalPages;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('متادیتا دریافت شد: ${meta.totalCount} رکورد / ${meta.totalPages} صفحه')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطا در دریافت متادیتا: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendDraftToServer() async {
    setState(() => _busy = true);
    try {
      final records = await _draftStore.read();
      if (records.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لیست موقت خالی است.')),
        );
        return;
      }
      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('تایید ارسال'),
          content: Text('تعداد ${records.length} رکورد به سرور ارسال شود؟'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('انصراف')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('تایید و ارسال')),
          ],
        ),
      );
      if (confirmed != true) return;

      const chunkSize = 40;
      final chunks = <List<ImportDraftRecord>>[];
      for (var i = 0; i < records.length; i += chunkSize) {
        final end = (i + chunkSize < records.length) ? i + chunkSize : records.length;
        chunks.add(records.sublist(i, end));
      }

      final session = await _syncApi.startSession(
        codeCo: widget.codeCo,
        totalRecords: records.length,
      );
      for (var i = 0; i < chunks.length; i++) {
        await _syncApi.uploadBatch(
          sessionId: session.sessionId,
          chunkIndex: i + 1,
          totalChunks: chunks.length,
          records: chunks[i],
        );
      }
      final fin = await _syncApi.finalizeSession(session.sessionId);
      await _draftStore.clear();
      await _reloadDraftCount();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            fin.success
                ? 'ارسال انجام شد — پرونده درج/به‌روز: ${fin.inserted}، سند: ${fin.docsInserted}'
                : 'پایان با خطا — پرونده: ${fin.inserted}، سند: ${fin.docsInserted}، خطا: ${fin.failed}',
          ),
          duration: const Duration(seconds: 8),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطا در ارسال به سرور: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _runFullRecovery() async {
    final token = _tokenCtrl.text.trim();
    if (token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ابتدا توکن JWT را وارد کنید.')),
      );
      return;
    }
    await _fetchMeta();
    if (!mounted) return;
    final totalPages = _metaTotalPages ?? 0;
    if (totalPages <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعداد صفحات معتبر دریافت نشد.')),
      );
      return;
    }
    await _collectToDraft(startPage: 1, endPage: totalPages);
    await _sendDraftToServer();
  }

  Future<void> _runLast5PagesUpdate() async {
    final token = _tokenCtrl.text.trim();
    if (token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ابتدا توکن JWT را وارد کنید.')),
      );
      return;
    }
    await _fetchMeta();
    if (!mounted) return;
    final totalPages = _metaTotalPages ?? 0;
    if (totalPages <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعداد صفحات معتبر دریافت نشد.')),
      );
      return;
    }
    final start = totalPages > 5 ? (totalPages - 4) : 1;
    await _collectToDraft(startPage: start, endPage: totalPages);
    await _sendDraftToServer();
  }

  Future<void> _runFirstPage5Test() async {
    await _collectToDraft(startPage: 1, endPage: 1, maxRecords: 5);
  }

  Future<void> _openIranianAsnafLogin() async {
    if (!kIsWeb) {
      final token = await Navigator.of(context).push<String>(
        MaterialPageRoute(builder: (_) => const AsnafLoginDesktopPage()),
      );
      if (token != null && token.trim().isNotEmpty) {
        _tokenCtrl.text = token.trim();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('توکن با موفقیت از WebView استخراج شد.')),
        );
        return;
      }
    }
    final uri = Uri.parse('http://iranianasnaf.ir/');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('پس از لاگین، JWT را دستی وارد کنید.')),
    );
  }

  Future<void> _clearDraft() async {
    await _draftStore.clear();
    await _reloadDraftCount();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('لیست موقت پاک شد.')),
    );
  }

  Future<void> _openDraftReviewSheet() async {
    final initial = await _draftStore.read();
    if (!mounted) return;
    if (initial.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لیست موقت خالی است.')),
      );
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        var records = [...initial];
        return StatefulBuilder(
          builder: (context, setLocal) {
            return SafeArea(
              child: Container(
                height: MediaQuery.of(context).size.height * 0.86,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 8, 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'بازبینی لیست موقت (${records.length})',
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () async {
                              await _draftStore.save(records);
                              if (!mounted) return;
                              await _reloadDraftCount();
                              if (!context.mounted) return;
                              Navigator.pop(context);
                              if (!mounted) return;
                              ScaffoldMessenger.of(this.context).showSnackBar(
                                const SnackBar(content: Text('تغییرات لیست موقت ذخیره شد.')),
                              );
                            },
                            icon: const Icon(Icons.save_outlined),
                            label: const Text('ذخیره'),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                        itemCount: records.length,
                        separatorBuilder: (_, sepIndex) => const SizedBox(height: 6),
                        itemBuilder: (context, i) {
                          final r = records[i];
                          final p = r.payload;
                          final name = '${p['name_admin'] ?? ''} ${p['family_admin'] ?? ''}'.trim();
                          final store = (p['name_store'] ?? '').trim();
                          return Material(
                            color: const Color(0xFFF6F8FB),
                            borderRadius: BorderRadius.circular(10),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(10),
                              onTap: () => _showDraftRecordDetails(r),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFFE3E8F1)),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            name.isEmpty ? '—' : name,
                                            style: const TextStyle(fontWeight: FontWeight.w700),
                                          ),
                                          Text(
                                            'واحد: ${store.isEmpty ? '—' : store}',
                                            style: const TextStyle(fontSize: 12, color: Colors.black54),
                                          ),
                                          Text(
                                            'شناسه موقت: ${r.clientTempId}',
                                            style: const TextStyle(fontSize: 11.5, color: Colors.black45),
                                          ),
                                          const Text(
                                            'برای مشاهده جزئیات کلیک کنید',
                                            style: TextStyle(fontSize: 11, color: Color(0xFF1E3A5F)),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'حذف از لیست موقت',
                                      onPressed: () => setLocal(() => records.removeAt(i)),
                                      icon: const Icon(Icons.delete_outline, color: Color(0xFFC62828)),
                                    ),
                                  ],
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
      },
    );
  }

  Future<void> _showDraftRecordDetails(ImportDraftRecord r) async {
    final entries = r.payload.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('جزئیات رکورد: ${r.clientTempId}'),
        content: SizedBox(
          width: 560,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: entries.length,
            separatorBuilder: (_, sepIndex) => const Divider(height: 10),
            itemBuilder: (_, i) {
              final e = entries[i];
              final v = e.value.trim().isEmpty ? '—' : e.value;
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 170,
                    child: Text(
                      e.key,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SelectableText(
                      v,
                      style: const TextStyle(fontSize: 12.5),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('بستن'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('بازیابی اطلاعات')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 86,
                  height: 86,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E3A5F).withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.sync, size: 44, color: Color(0xFF1E3A5F)),
                ),
                const SizedBox(height: 14),
                const Text(
                  'بازیابی اطلاعات',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 10),
                Text(
                  'کد اتحادیه: ${widget.codeCo}\n'
                  'تعداد رکورد موقت: $_draftCount\n'
                  'متادیتا: ${_metaTotalCount ?? '-'} رکورد / ${_metaTotalPages ?? '-'} صفحه',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.black54, height: 1.8),
                ),
                const SizedBox(height: 18),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'csv',
                      icon: Icon(Icons.file_open_outlined),
                      label: Text('بازیابی از طریق فایل CSV'),
                    ),
                    ButtonSegment(
                      value: 'direct',
                      icon: Icon(Icons.language_outlined),
                      label: Text('بازیابی مستقیم'),
                    ),
                  ],
                  selected: {_recoveryMode},
                  onSelectionChanged: _busy
                      ? null
                      : (s) {
                          setState(() => _recoveryMode = s.first);
                        },
                ),
                const SizedBox(height: 8),
                if (_recoveryMode == 'csv')
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F8FC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE1E6EF)),
                    ),
                    child: const Text(
                      'حالت بازیابی از CSV در گام بعدی فعال می‌شود. در این فاز، بازیابی مستقیم عملیاتی است.',
                      style: TextStyle(color: Colors.black54),
                    ),
                  ),
                if (_recoveryMode == 'direct') ...[
                  FilledButton.tonalIcon(
                    onPressed: _busy ? null : _openIranianAsnafLogin,
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('باز کردن سایت iranianasnaf برای لاگین'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _tokenCtrl,
                    decoration: InputDecoration(
                      labelText: 'JWT Token',
                      hintText: 'توکن استخراج‌شده بعد از لاگین',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.tonalIcon(
                    onPressed: _busy ? null : _fetchMeta,
                    icon: const Icon(Icons.analytics_outlined),
                    label: const Text('بررسی توکن و دریافت متادیتا'),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: _busy ? null : _runFullRecovery,
                    icon: const Icon(Icons.cloud_sync_outlined),
                    label: const Text('بازیابی کامل اطلاعات'),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: _busy ? null : _runLast5PagesUpdate,
                    icon: const Icon(Icons.update_outlined),
                    label: const Text('بروزرسانی اطلاعات (۵ صفحه آخر)'),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.tonalIcon(
                    onPressed: _busy ? null : _runFirstPage5Test,
                    icon: const Icon(Icons.science_outlined),
                    label: const Text('آزمایش ۵ رکورد از صفحه اول'),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.tonalIcon(
                    onPressed: _busy ? null : _openDraftReviewSheet,
                    icon: const Icon(Icons.playlist_add_check_circle_outlined),
                    label: const Text('بازبینی/حذف از لیست موقت'),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: _busy ? null : _sendDraftToServer,
                    icon: const Icon(Icons.cloud_upload_outlined),
                    label: const Text('ارسال اطلاعات به سرور'),
                  ),
                ],
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _clearDraft,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('پاک‌سازی لیست موقت'),
                ),
                if (_busy) ...[
                  const SizedBox(height: 14),
                  const LinearProgressIndicator(),
                ],
                const SizedBox(height: 12),
                _progressPanel(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _progressPanel() {
    final done = _progressSuccess + _progressFailed;
    final remain = _progressPlanned > 0 ? (_progressPlanned - done).clamp(0, 1 << 30) : 0;
    final progressValue =
        _progressPlanned > 0 ? (done / _progressPlanned).clamp(0.0, 1.0) : null;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F8FB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE3E8F1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('پیشرفت بازیابی', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text('رکورد جاری: $_progressCurrentName'),
          if (_progressCurrentDetails.isNotEmpty)
            Text(_progressCurrentDetails, style: const TextStyle(fontSize: 12, color: Colors.black54)),
          const SizedBox(height: 8),
          Text(
            'موفق: $_progressSuccess | ناموفق: $_progressFailed | مانده: $remain',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          LinearProgressIndicator(value: progressValue),
          const SizedBox(height: 8),
          SizedBox(
            height: 120,
            child: _progressLogs.isEmpty
                ? const Center(
                    child: Text('هنوز لاگ پردازش ثبت نشده است.',
                        style: TextStyle(color: Colors.black45, fontSize: 12)),
                  )
                : ListView.builder(
                    itemCount: _progressLogs.length,
                    itemBuilder: (_, i) => Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Text(
                        _progressLogs[i],
                        style: const TextStyle(fontSize: 11.5),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
