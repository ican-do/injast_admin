import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:injast_admin/file_management/excel_import/excel_import_shenase.dart';
import 'package:injast_admin/file_management/hagh_ozviat_api.dart';
import 'package:injast_admin/file_management/hagh_ozviat_member_index.dart';
import 'package:injast_admin/file_management/hagh_ozviat_models.dart';
import 'package:injast_admin/file_management/jalali_date_util.dart';
import 'package:injast_admin/file_management/parvande_api.dart';
import 'package:injast_admin/local_cache/network_reachability.dart';
import 'package:injast_admin/local_cache/offline_mode_prefs.dart';
import 'package:injast_admin/local_cache/parvande_cache_list_service.dart';
import 'package:injast_admin/local_cache/parvande_profile_image.dart';
import 'package:injast_admin/reports/hagh_ozviat_report_cache.dart';
import 'package:injast_admin/reports/hagh_ozviat_report_engine.dart';
import 'package:persian_datetimepickers/persian_datetimepickers.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:url_launcher/url_launcher.dart';

/// گزارشات شاخص بدهی حق عضویت اعضا.
class HaghOzviatDebtReportsPage extends StatefulWidget {
  const HaghOzviatDebtReportsPage({
    super.key,
    required this.codeCo,
    this.unionName = '',
  });

  final String codeCo;
  final String unionName;

  @override
  State<HaghOzviatDebtReportsPage> createState() =>
      _HaghOzviatDebtReportsPageState();
}

class _HaghOzviatDebtReportsPageState extends State<HaghOzviatDebtReportsPage> {
  static const _accent = Color(0xFF6A1B9A);
  static const _accent2 = Color(0xFF283593);
  static const _bg = Color(0xFFF4F6FB);

  final _offlinePrefs = OfflineModePrefs();
  final _cacheList = ParvandeCacheListService.instance;

  bool _loading = true;
  bool _offlineMode = false;
  bool _togglingOffline = false;
  String _loadingMessage = 'در حال بارگذاری…';
  DateTime? _cacheSavedAt;
  String? _error;
  bool _fullRowData = false;
  List<HaghOzviatRow> _rows = const [];
  Map<String, HaghOzviatMemberIndex> _index = const {};
  Map<String, Map<String, dynamic>> _parvandeByShenase = const {};
  HaghOzviatReportFilters _filters = const HaghOzviatReportFilters();
  final _searchCtrl = TextEditingController();
  bool _filtersExpanded = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _loadingMessage = 'در حال بارگذاری…';
    });

    try {
      final offline = await _offlinePrefs.isOfflineEffective(widget.codeCo);
      if (!mounted) return;

      if (offline) {
        await _loadOffline();
        return;
      }

      await _offlinePrefs.clearAutoOfflineIfOnline(widget.codeCo);
      await _loadOnline();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _loadOffline() async {
    final cached = await HaghOzviatReportCache.instance.loadRows(widget.codeCo);
    final parvandes = await _cacheList.fetchAllFromCache(widget.codeCo);
    final parvandeMap = _buildParvandeMap(parvandes);

    if (!mounted) return;

    if (cached == null || cached.rows.isEmpty) {
      setState(() {
        _offlineMode = true;
        _rows = const [];
        _index = const {};
        _parvandeByShenase = parvandeMap;
        _fullRowData = false;
        _cacheSavedAt = null;
        _loading = false;
        _error = parvandes.isEmpty
            ? 'حافظهٔ محلی خالی است.\n'
                'یک‌بار در حالت آنلاین گزارش را بارگذاری کنید یا از «مدیریت اطلاعات و بکاپ» مطالبات را وارد کنید.'
            : 'کش گزارش حق عضویت موجود نیست.\n'
                'یک‌بار در حالت آنلاین این صفحه را باز کنید تا داده ذخیره شود.';
      });
      return;
    }

    setState(() {
      _offlineMode = true;
      _rows = cached.rows;
      _index = const {};
      _parvandeByShenase = parvandeMap;
      _fullRowData = true;
      _cacheSavedAt = cached.savedAt;
      _loading = false;
      _error = null;
    });
  }

  Future<void> _loadOnline() async {
    List<Map<String, dynamic>> parvandes;
    try {
      parvandes = await ParvandeApi.instance.fetchAll(widget.codeCo);
    } catch (_) {
      parvandes = await _cacheList.fetchAllFromCache(widget.codeCo);
    }
    final parvandeMap = _buildParvandeMap(parvandes);

    if (!mounted) return;
    setState(() {
      _loadingMessage = 'دریافت ردیف‌های حق عضویت از سرور…';
    });

    final rows = await HaghOzviatApi.instance.fetchAllRowsResolved(
      widget.codeCo,
      onProgress: (done, total, shenase) {
        if (!mounted) return;
        setState(() {
          _loadingMessage = shenase == null
              ? 'دریافت حق عضویت…'
              : 'دریافت $done از $total عضو…';
        });
      },
    );

    if (rows.isNotEmpty) {
      await HaghOzviatReportCache.instance.saveRows(
        codeCo: widget.codeCo,
        rows: rows,
      );
    }

    Map<String, HaghOzviatMemberIndex> index = const {};
    if (rows.isEmpty) {
      index = await HaghOzviatApi.instance.fetchIndex(widget.codeCo);
    }

    if (!mounted) return;

    setState(() {
      _offlineMode = false;
      _rows = rows;
      _index = index;
      _parvandeByShenase = parvandeMap;
      _fullRowData = rows.isNotEmpty;
      _cacheSavedAt = rows.isNotEmpty ? DateTime.now() : null;
      _loading = false;
      if (rows.isEmpty && index.isEmpty) {
        _error = 'دادهٔ حق عضویت برای این اتحادیه یافت نشد.\n'
            'ابتدا از «مدیریت اطلاعات و بکاپ» فایل مطالبات را بارگذاری کنید.';
      } else {
        _error = null;
      }
    });
  }

  Future<void> _toggleOfflineMode(bool value) async {
    if (_togglingOffline || _loading) return;

    if (!value) {
      final online = await NetworkReachability.instance.isServerReachable();
      if (!online) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'سرور در دسترس نیست؛ تا برقراری اتصال، حالت آفلاین فعال می‌ماند.',
            ),
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
    setState(() => _togglingOffline = true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          value
              ? 'حالت آفلاین: گزارش از کش محلی.'
              : 'حالت آنلاین: دریافت از سرور.',
        ),
      ),
    );
    await _load();
    if (mounted) setState(() => _togglingOffline = false);
  }

  Widget _offlineModeSwitch() {
    return FutureBuilder<bool>(
      future: NetworkReachability.instance.isServerReachableCached(),
      builder: (context, snap) {
        final serverUp = snap.data ?? true;
        final lockedOffline = _offlineMode && !serverUp;
        final disabled = _loading || _togglingOffline || lockedOffline;

        return Padding(
          padding: const EdgeInsetsDirectional.only(end: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'محلی',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: _offlineMode ? FontWeight.w700 : FontWeight.w400,
                  color: _offlineMode ? Colors.white : Colors.white70,
                ),
              ),
              Switch.adaptive(
                value: !_offlineMode,
                onChanged: disabled
                    ? null
                    : (online) => _toggleOfflineMode(!online),
                activeThumbColor: Colors.white,
                activeTrackColor: Colors.white.withValues(alpha: 0.35),
              ),
              Text(
                'آنلاین',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: !_offlineMode ? FontWeight.w700 : FontWeight.w400,
                  color: !_offlineMode ? Colors.white : Colors.white70,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Map<String, Map<String, dynamic>> _buildParvandeMap(
    List<Map<String, dynamic>> rows,
  ) {
    final out = <String, Map<String, dynamic>>{};
    for (final p in rows) {
      if (p.isTrash) continue;
      final key = ExcelImportShenase.normalize(p.shenase);
      if (key.isEmpty) continue;
      out.putIfAbsent(key, () => p);
    }
    return out;
  }

  Map<String, dynamic>? _parvandeFor(String shenaseStore) {
    return _parvandeByShenase[ExcelImportShenase.normalize(shenaseStore)];
  }

  Future<void> _call(String phone) async {
    final t = phone.trim();
    if (t.isEmpty) return;
    await launchUrl(Uri.parse('tel:$t'));
  }

  Future<void> _sms(String phone) async {
    final t = phone.trim();
    if (t.isEmpty) return;
    await launchUrl(Uri.parse('sms:$t'));
  }

  HaghOzviatReportSnapshot get _snapshot {
    final filters = _filters.copyWith(searchQuery: _searchCtrl.text);
    if (_fullRowData) {
      return HaghOzviatReportEngine.fromRows(
        allRows: _rows,
        filters: filters,
      );
    }
    return HaghOzviatReportEngine.fromIndex(
      index: _index,
      filters: filters,
    );
  }

  void _applyFilters() => setState(() {});

  void _resetFilters() {
    _searchCtrl.clear();
    setState(() => _filters = const HaghOzviatReportFilters());
  }

  void _selectDebtYear(String? sal) {
    setState(() {
      _filters = _filters.copyWith(sal: sal ?? 'همه');
    });
  }

  void _togglePendingOnly(bool on) {
    setState(() {
      _filters = _filters.copyWith(
        vaziyat: on ? 'در انتظار پرداخت' : 'همه',
      );
    });
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final current = isFrom ? _filters.dateFrom : _filters.dateTo;
    final initial = current?.toDateTime() ?? DateTime.now();
    final picked = await showPersianDatePicker(
      context: context,
      initialDate: initial,
    );
    if (picked == null || !mounted) return;
    final j = Gregorian(picked.year, picked.month, picked.day).toJalali();
    setState(() {
      _filters = isFrom
          ? _filters.copyWith(dateFrom: j)
          : _filters.copyWith(dateTo: j);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: _loading
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      _loadingMessage,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                  ),
                ],
              ),
            )
          : _error != null && _rows.isEmpty && _index.isEmpty
              ? _errorBody()
              : CustomScrollView(
                  slivers: [
                    _heroHeader(),
                    SliverToBoxAdapter(child: _filterPanel()),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          _kpiGrid(_snapshot),
                          const SizedBox(height: 10),
                          if (_offlineMode) _offlineBanner(),
                          if (!_offlineMode && _cacheSavedAt != null)
                            _onlineCacheHint(),
                          const SizedBox(height: 6),
                          if (_snapshot.salBreakdown.isNotEmpty) ...[
                            _sectionTitle('توزیع بر اساس سال'),
                            const SizedBox(height: 10),
                            _salChart(_snapshot),
                            const SizedBox(height: 16),
                          ],
                          if (_snapshot.vaziyatBreakdown.isNotEmpty) ...[
                            _sectionTitle('وضعیت ردیف‌ها'),
                            const SizedBox(height: 10),
                            _vaziyatBreakdown(_snapshot),
                            const SizedBox(height: 16),
                          ],
                          _sectionTitle('اعضای دارای بدهی'),
                          const SizedBox(height: 10),
                          _debtorMembersGrid(_snapshot),
                          if (_snapshot.topDebtors.length > 15) ...[
                            const SizedBox(height: 8),
                            Text(
                              'نمایش ${_snapshot.debtorMembersList.length} عضو بدهکار',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                          if (_fullRowData &&
                              _snapshot.filteredRows.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            _sectionTitle('جزئیات ردیف‌ها'),
                            const SizedBox(height: 10),
                            _rowsTable(_snapshot),
                          ],
                        ]),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _errorBody() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.analytics_outlined,
                size: 56, color: Colors.grey.shade500),
            const SizedBox(height: 16),
            Text(
              _error ?? 'خطا',
              textAlign: TextAlign.center,
              style: const TextStyle(height: 1.6),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              label: const Text('تلاش مجدد'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _heroHeader() {
    final snap = _snapshot;
    return SliverAppBar(
      expandedHeight: 168,
      pinned: true,
      backgroundColor: _accent2,
      foregroundColor: Colors.white,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [Color(0xFF4A148C), Color(0xFF283593), Color(0xFF1A237E)],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(56, 8, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    widget.unionName.trim().isEmpty
                        ? 'گزارش بدهی حق عضویت'
                        : 'گزارش بدهی — ${widget.unionName.trim()}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _offlineMode
                        ? 'حالت آفلاین • ${_formatInt(_rows.length)} ردیف کش‌شده'
                        : _filters.sal != 'همه'
                            ? 'سال ${_filters.sal} • ${HaghOzviatReportEngine.formatRial(snap.totalPendingRial)} ریال بدهی'
                            : _fullRowData
                                ? 'تحلیل ${_formatInt(snap.rowCount)} ردیف • ${HaghOzviatReportEngine.formatRial(snap.totalPendingRial)} ریال بدهی باز'
                                : 'تحلیل ${_formatInt(snap.membersWithRecords)} عضو • ${HaghOzviatReportEngine.formatRial(snap.totalPendingRial)} ریال بدهی باز',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.88),
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      actions: [
        _offlineModeSwitch(),
        IconButton(
          tooltip: 'بروزرسانی',
          onPressed: _loading ? null : _load,
          icon: const Icon(Icons.refresh),
        ),
      ],
    );
  }

  Widget _filterPanel() {
    final debtYears = _fullRowData
        ? HaghOzviatReportEngine.yearsWithPendingDebt(_rows)
        : const <HaghOzviatSalDebtYear>[];
    final radeOptions = _fullRowData
        ? ['همه', ...HaghOzviatReportEngine.distinctRade(_rows)]
        : const ['همه'];
    final vaziyatOptions = _fullRowData
        ? ['همه', ...HaghOzviatReportEngine.distinctVaziyat(_rows)]
        : const ['همه', 'در انتظار پرداخت', 'تایید شده'];
    final pendingOnly = _filters.vaziyat == 'در انتظار پرداخت';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
        border: Border.all(color: const Color(0xFFE8ECF4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            onTap: () => setState(() => _filtersExpanded = !_filtersExpanded),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF7B1FA2), Color(0xFF3949AB)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(FluentIcons.filter_24_regular,
                        color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'فیلترهای گزارش',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                        color: Color(0xFF1E3A5F),
                      ),
                    ),
                  ),
                  if (_filters.hasActive)
                    Container(
                      margin: const EdgeInsets.only(left: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFEBEE),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'فعال',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFC62828),
                        ),
                      ),
                    ),
                  Icon(
                    _filtersExpanded
                        ? Icons.expand_less
                        : Icons.expand_more,
                    color: const Color(0xFF1E3A5F),
                  ),
                ],
              ),
            ),
          ),
          if (_filtersExpanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _searchCtrl,
                    textDirection: TextDirection.rtl,
                    onChanged: (_) => _applyFilters(),
                    decoration: InputDecoration(
                      hintText: 'جستجو: کد صنفی، عنوان، رسته…',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: const Color(0xFFF6F8FC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (_fullRowData && debtYears.isNotEmpty) ...[
                    _filterLabel('فیلتر سال بدهی (با انتخاب، همه مبالغ به‌روز می‌شوند)'),
                    const SizedBox(height: 8),
                    _debtYearSelector(debtYears),
                    const SizedBox(height: 14),
                    Material(
                      color: const Color(0xFFF3E5F5),
                      borderRadius: BorderRadius.circular(14),
                      child: SwitchListTile(
                        value: pendingOnly,
                        activeThumbColor: _accent,
                        onChanged: _togglePendingOnly,
                        title: const Text(
                          'فقط مطالبات «در انتظار پرداخت»',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                        subtitle: Text(
                          pendingOnly
                              ? 'جمع‌ها فقط بدهی باز را نشان می‌دهند'
                              : 'همه وضعیت‌های سال انتخاب‌شده',
                          style: const TextStyle(fontSize: 11.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                  ] else if (!_fullRowData) ...[
                    _filterLabel('فیلتر سال بدهی'),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF8E1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'ردیف‌های تفصیلی حق عضویت در دسترس نیست. '
                        'اتصال آنلاین را بررسی کنید یا یک‌بار گزارش را در حالت آنلاین بارگذاری کنید.',
                        style: TextStyle(fontSize: 12, height: 1.45),
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                  _filterLabel('وضعیت مطالبه'),
                  const SizedBox(height: 8),
                  _chipRow(
                    options: vaziyatOptions,
                    selected: _filters.vaziyat,
                    onSelected: (v) {
                      setState(() => _filters = _filters.copyWith(vaziyat: v));
                      _applyFilters();
                    },
                  ),
                  if (_fullRowData) ...[
                    const SizedBox(height: 14),
                    _filterLabel('رده صنفی'),
                    const SizedBox(height: 8),
                    _chipRow(
                      options: radeOptions.take(6).toList(),
                      selected: _filters.radeSanfi,
                      onSelected: (v) {
                        setState(
                            () => _filters = _filters.copyWith(radeSanfi: v));
                        _applyFilters();
                      },
                    ),
                    const SizedBox(height: 14),
                    _filterLabel('بازهٔ تاریخ ایجاد (شمسی)'),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _dateChip(
                            label: 'از تاریخ',
                            value: HaghOzviatReportEngine.formatJalali(
                                _filters.dateFrom),
                            onTap: () => _pickDate(isFrom: true),
                            onClear: _filters.dateFrom != null
                                ? () => setState(() => _filters =
                                    _filters.copyWith(clearDateFrom: true))
                                : null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _dateChip(
                            label: 'تا تاریخ',
                            value: HaghOzviatReportEngine.formatJalali(
                                _filters.dateTo),
                            onTap: () => _pickDate(isFrom: false),
                            onClear: _filters.dateTo != null
                                ? () => setState(() => _filters =
                                    _filters.copyWith(clearDateTo: true))
                                : null,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: _filters.hasActive ? _resetFilters : null,
                        icon: const Icon(Icons.filter_alt_off, size: 18),
                        label: const Text('پاک کردن فیلتر'),
                      ),
                      const Spacer(),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: _accent,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 12),
                        ),
                        onPressed: _applyFilters,
                        icon: const Icon(Icons.analytics_outlined, size: 18),
                        label: const Text('اعمال گزارش'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _debtYearSelector(List<HaghOzviatSalDebtYear> years) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _debtYearChip(
            label: 'همه سال‌ها',
            subtitle: 'کل بدهی',
            selected: _filters.sal == 'همه',
            onTap: () => _selectDebtYear(null),
          ),
          for (final y in years)
            _debtYearChip(
              label: 'سال ${y.sal}',
              subtitle:
                  '${HaghOzviatReportEngine.formatRial(y.pendingRial)} ریال • ${y.debtorCount} عضو',
              selected: _filters.sal == y.sal,
              onTap: () => _selectDebtYear(y.sal),
            ),
        ],
      ),
    );
  }

  Widget _debtYearChip({
    required String label,
    required String subtitle,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Material(
        color: selected
            ? const Color(0xFF6A1B9A)
            : const Color(0xFFF6F8FC),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            width: 132,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected
                    ? const Color(0xFF6A1B9A)
                    : const Color(0xFFDDE5EF),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    color: selected ? Colors.white : const Color(0xFF1E3A5F),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    height: 1.3,
                    color: selected
                        ? Colors.white.withValues(alpha: 0.9)
                        : const Color(0xFF78909C),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _filterLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontWeight: FontWeight.w800,
        fontSize: 12.5,
        color: Color(0xFF546E7A),
      ),
    );
  }

  Widget _chipRow({
    required List<String> options,
    required String selected,
    required ValueChanged<String> onSelected,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((opt) {
        final active = selected == opt;
        return FilterChip(
          label: Text(opt),
          selected: active,
          onSelected: (_) => onSelected(opt),
          selectedColor: _accent.withValues(alpha: 0.18),
          checkmarkColor: _accent,
          labelStyle: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 12,
            color: active ? _accent : const Color(0xFF37474F),
          ),
          side: BorderSide(
            color: active ? _accent.withValues(alpha: 0.5) : const Color(0xFFDDE5EF),
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        );
      }).toList(),
    );
  }

  Widget _dateChip({
    required String label,
    required String value,
    required VoidCallback onTap,
    VoidCallback? onClear,
  }) {
    return Material(
      color: const Color(0xFFF6F8FC),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              const Icon(Icons.calendar_month_outlined,
                  size: 18, color: Color(0xFF6A1B9A)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: const TextStyle(
                            fontSize: 10.5, color: Color(0xFF78909C))),
                    Text(value,
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 13)),
                  ],
                ),
              ),
              if (onClear != null)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: onClear,
                  icon: const Icon(Icons.close, size: 16),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _offlineBanner() {
    final when = _cacheSavedAt;
    final whenText = when == null
        ? 'زمان ذخیره نامشخص'
        : '${when.year}/${when.month.toString().padLeft(2, '0')}/${when.day.toString().padLeft(2, '0')} '
            '${when.hour.toString().padLeft(2, '0')}:${when.minute.toString().padLeft(2, '0')}';
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFE3F2FD),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF90CAF9)),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_outlined, color: Color(0xFF1565C0)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'حالت آفلاین — داده از کش محلی ($whenText). '
              'برای بروزرسانی، سوئیچ را روی آنلاین بگذارید.',
              style: const TextStyle(fontSize: 12.5, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _onlineCacheHint() {
    return Text(
      'آخرین ذخیرهٔ محلی: ${_cacheSavedAt!.year}/${_cacheSavedAt!.month.toString().padLeft(2, '0')}/${_cacheSavedAt!.day.toString().padLeft(2, '0')}',
      style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
    );
  }

  Widget _sectionTitle(String t) {
    return Text(
      t,
      style: const TextStyle(
        fontWeight: FontWeight.w900,
        fontSize: 16,
        color: Color(0xFF1E3A5F),
      ),
    );
  }

  Widget _kpiGrid(HaghOzviatReportSnapshot snap) {
    final cards = [
      _KpiData(
        'بدهی باز',
        '${HaghOzviatReportEngine.formatRial(snap.totalPendingRial)} ریال',
        FluentIcons.money_hand_24_regular,
        const Color(0xFFC62828),
        const Color(0xFFFFEBEE),
      ),
      _KpiData(
        'تسویه‌شده',
        '${HaghOzviatReportEngine.formatRial(snap.totalConfirmedRial)} ریال',
        FluentIcons.checkmark_circle_24_regular,
        const Color(0xFF2E7D32),
        const Color(0xFFE8F5E9),
      ),
      _KpiData(
        'اعضای بدهکار',
        _formatInt(snap.debtorMembers),
        FluentIcons.people_money_24_regular,
        const Color(0xFF6A1B9A),
        const Color(0xFFF3E5F5),
      ),
      _KpiData(
        'تسویه حق عضویت',
        _formatInt(snap.settledMembers),
        FluentIcons.person_available_24_regular,
        const Color(0xFF0277BD),
        const Color(0xFFE1F5FE),
      ),
      _KpiData(
        'میانگین بدهی',
        '${HaghOzviatReportEngine.formatRial(snap.avgDebtPerDebtor)} ریال',
        FluentIcons.calculator_24_regular,
        const Color(0xFFEF6C00),
        const Color(0xFFFFF3E0),
      ),
      _KpiData(
        'بیشترین بدهی',
        '${HaghOzviatReportEngine.formatRial(snap.maxMemberPending)} ریال',
        FluentIcons.top_speed_24_regular,
        const Color(0xFF4527A0),
        const Color(0xFFEDE7F6),
      ),
    ];

    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth > 900
            ? (c.maxWidth - 16) / 3
            : c.maxWidth > 560
                ? (c.maxWidth - 8) / 2
                : c.maxWidth;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: cards
              .map((e) => SizedBox(width: w, child: _kpiCard(e)))
              .toList(),
        );
      },
    );
  }

  Widget _kpiCard(_KpiData d) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: d.fg.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: d.fg.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: d.bg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(d.icon, color: d.fg, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(d.title,
                    style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: d.fg.withValues(alpha: 0.85))),
                const SizedBox(height: 4),
                Text(
                  d.value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    color: d.fg,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _salChart(HaghOzviatReportSnapshot snap) {
    final items = snap.salBreakdown.take(6).toList();
    if (items.isEmpty) return const SizedBox.shrink();
    final maxTotal = items
        .map((e) => e.totalRial)
        .reduce((a, b) => a > b ? a : b)
        .clamp(1, 1 << 62);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8ECF4)),
      ),
      child: Column(
        children: [
          for (final item in items) ...[
            Row(
              children: [
                SizedBox(
                  width: 44,
                  child: Text(
                    item.sal,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 12),
                  ),
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, c) {
                      final w = c.maxWidth;
                      final pendingW = w * (item.pendingRial / maxTotal);
                      final confirmedW = w * (item.confirmedRial / maxTotal);
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Row(
                          children: [
                            if (pendingW > 0)
                              Container(
                                width: pendingW,
                                height: 22,
                                color: const Color(0xFFEF5350),
                              ),
                            if (confirmedW > 0)
                              Container(
                                width: confirmedW,
                                height: 22,
                                color: const Color(0xFF66BB6A),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  HaghOzviatReportEngine.formatRial(item.totalRial),
                  style: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
          Row(
            children: [
              _legendDot(const Color(0xFFEF5350), 'بدهی باز'),
              const SizedBox(width: 16),
              _legendDot(const Color(0xFF66BB6A), 'تسویه'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legendDot(Color c, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 11.5)),
      ],
    );
  }

  Widget _vaziyatBreakdown(HaghOzviatReportSnapshot snap) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: snap.vaziyatBreakdown.entries.map((e) {
        final pending = e.key.contains('انتظار');
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: pending
                ? const Color(0xFFFFEBEE)
                : const Color(0xFFE8F5E9),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: pending
                  ? const Color(0xFFEF9A9A)
                  : const Color(0xFFA5D6A7),
            ),
          ),
          child: Text(
            '${e.key}: ${_formatInt(e.value)} ردیف',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 12.5,
              color: pending
                  ? const Color(0xFFC62828)
                  : const Color(0xFF2E7D32),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _debtorMembersGrid(HaghOzviatReportSnapshot snap) {
    final members = snap.debtorMembersList;
    if (members.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Center(
          child: Text('عضو بدهکاری با فیلتر فعلی یافت نشد.'),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, c) {
        final count = c.maxWidth > 820 ? 2 : 1;
        final width = count == 2 ? (c.maxWidth - 10) / 2 : c.maxWidth;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (var i = 0; i < members.length; i++)
              SizedBox(
                width: width,
                child: _debtorMemberCard(
                  rank: i + 1,
                  debt: members[i],
                  parvande: _parvandeFor(members[i].shenaseStore),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _debtorMemberCard({
    required int rank,
    required HaghOzviatMemberDebtRank debt,
    Map<String, dynamic>? parvande,
  }) {
    final p = parvande;
    final name = p?.fullName.trim().isNotEmpty == true ? p!.fullName : '—';
    final store = p?.storeName ?? '—';
    final raste = p?.raste ?? debt.shenaseStore;
    final mob = p?.mob ?? '';
    final shenase = debt.shenaseStore;
    final hasPhone = mob.trim().isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8ECF4)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    if (p != null)
                      ParvandeProfileImage(
                        codeCo: widget.codeCo,
                        parvande: p,
                        width: 56,
                        height: 56,
                        borderRadius: 14,
                        preferServer: !_offlineMode,
                        fallbackIcon: FluentIcons.person_24_regular,
                      )
                    else
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3E5F5),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(FluentIcons.person_24_regular,
                            color: Color(0xFF6A1B9A)),
                      ),
                    Positioned(
                      right: -4,
                      top: -4,
                      child: CircleAvatar(
                        radius: 11,
                        backgroundColor: const Color(0xFF6A1B9A),
                        child: Text(
                          '$rank',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 14.5,
                          color: Color(0xFF1E3A5F),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        store,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'رسته: $raste',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      Text(
                        'کد صنفی: $shenase',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFEBEE),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFEF9A9A)),
              ),
              child: Row(
                children: [
                  const Icon(FluentIcons.money_hand_24_regular,
                      size: 18, color: Color(0xFFC62828)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'بدهی: ${HaghOzviatReportEngine.formatRial(debt.pendingRial)} ریال',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        color: Color(0xFFC62828),
                        fontSize: 13,
                      ),
                    ),
                  ),
                  Text(
                    '${debt.rowCount} ردیف',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFFC62828),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed:
                        hasPhone ? () => _call(mob) : null,
                    icon: const Icon(Icons.call_outlined, size: 18),
                    label: const Text('تماس'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF1565C0),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed:
                        hasPhone ? () => _sms(mob) : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF2E7D32),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    icon: const Icon(Icons.sms_outlined, size: 18),
                    label: const Text('پیامک'),
                  ),
                ),
              ],
            ),
            if (!hasPhone)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'شماره موبایل در پرونده ثبت نشده',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _rowsTable(HaghOzviatReportSnapshot snap) {
    final rows = snap.filteredRows.take(100).toList();
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8ECF4)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowHeight: 40,
          dataRowMinHeight: 36,
          columnSpacing: 16,
          columns: const [
            DataColumn(label: Text('کد صنفی')),
            DataColumn(label: Text('سال')),
            DataColumn(label: Text('عنوان')),
            DataColumn(label: Text('مبلغ')),
            DataColumn(label: Text('وضعیت')),
            DataColumn(label: Text('تاریخ ایجاد')),
          ],
          rows: [
            for (final r in rows)
              DataRow(
                cells: [
                  DataCell(Text(r.shenaseStore)),
                  DataCell(Text(r.sal.isEmpty ? '—' : r.sal)),
                  DataCell(Text(r.onvan, overflow: TextOverflow.ellipsis)),
                  DataCell(Text(HaghOzviatReportEngine.formatRial(r.mablaghRial))),
                  DataCell(Text(r.vaziyat)),
                  DataCell(Text(JalaliDateUtil.serverToDisplay(
                      r.tarikhIjad.split(',').first.trim()))),
                ],
              ),
          ],
        ),
      ),
    );
  }

  String _formatInt(int n) {
    return HaghOzviatReportEngine.formatRial(n);
  }
}

class _KpiData {
  const _KpiData(this.title, this.value, this.icon, this.fg, this.bg);
  final String title;
  final String value;
  final IconData icon;
  final Color fg;
  final Color bg;
}
