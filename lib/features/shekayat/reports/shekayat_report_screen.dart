import 'package:flutter/material.dart';
import 'package:injast_admin/features/shekayat/shekayat_constants.dart';
import 'package:injast_admin/features/shekayat/reports/shekayat_report_filter.dart';
import 'package:injast_admin/features/shekayat/reports/shekayat_report_service.dart';
import 'package:injast_admin/features/shekayat/reports/shekayat_report_widgets.dart';
import 'package:injast_admin/features/shekayat/pages/shekayat_widgets.dart';
import 'package:injast_admin/features/shekayat/compat/motion_toast_shim.dart';
import 'package:injast_admin/features/shekayat/compat/persian_fonts_shim.dart';
import 'package:injast_admin/features/shekayat/compat/persian_number_shim.dart';
import 'package:injast_admin/features/shekayat/compat/shekayat_basic.dart';
import 'package:injast_admin/features/shekayat/compat/shekayat_layout.dart';

class ShekayatReportScreen extends StatefulWidget {
  final String codeCo;
  final ShekayatReportType type;

  const ShekayatReportScreen({Key? key, required this.codeCo, required this.type}) : super(key: key);

  @override
  State<ShekayatReportScreen> createState() => _ShekayatReportScreenState();
}

class _ShekayatReportScreenState extends State<ShekayatReportScreen> {
  bool _loading = true;
  List<dynamic> _allItems = [];
  List<String> _categories = [];
  ShekayatReportFilters _filters = ShekayatReportFilters();

  List<dynamic> get _filtered => ShekayatReportService.applyFilters(_allItems, _filters);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        ShekayatReportService.loadAll(widget.codeCo),
        ShekayatReportService.loadCategories(widget.codeCo),
      ]);
      _allItems = results[0] as List<dynamic>;
      _categories = (results[1] as List<dynamic>)
          .map((e) => (e as Map)['name_category']?.toString() ?? '')
          .where((s) => s.isNotEmpty)
          .toList();
    } catch (e) {
      _allItems = [];
      _categories = [];
      if (mounted) {
        MotionToast.error(title: const Text('خطا'), description: Text('بارگذاری داده‌ها: $e')).show(context);
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF0F4F8),
        appBar: ShekayatAppBar(
          title: widget.type.title,
          actions: [
            IconButton(icon: const Icon(Icons.refresh), onPressed: _loading ? null : _load),
          ],
        ),
        body: ShekayatLayout.constrain(
          maxWidth: ShekayatLayout.reportsMaxWidth,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Column(
            children: [
              ShekayatReportFilterPanel(
                filters: _filters,
                categories: _categories,
                onChanged: (f) => setState(() => _filters = f),
              ),
              if (_filters.hasActive)
                Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 2),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Chip(
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      avatar: Icon(Icons.filter_alt, size: 14, color: ShekayatTheme.primary),
                      label: Text(
                        '${_filtered.length} از ${_allItems.length} پرونده',
                        style: PersianFonts.Shabnam.copyWith(fontSize: font_size_10),
                      ),
                      backgroundColor: ShekayatTheme.primary.withValues(alpha: 0.1),
                    ),
                  ),
                ),
              Expanded(
                child: _loading
                    ? Center(child: CircularProgressIndicator(color: ShekayatTheme.primary))
                    : _filtered.isEmpty
                        ? Center(
                            child: Text(
                              'داده‌ای یافت نشد',
                              style: PersianFonts.Shabnam.copyWith(fontSize: font_size_14, color: Colors.grey),
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _load,
                            color: ShekayatTheme.primary,
                            child: SingleChildScrollView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(0, 8, 0, 24),
                              child: _buildContent(),
                            ),
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    switch (widget.type) {
      case ShekayatReportType.dashboard:
        return _buildDashboard();
      case ShekayatReportType.status:
        return _buildStatus();
      case ShekayatReportType.typeSource:
        return _buildTypeSource();
      case ShekayatReportType.category:
        return _buildCategory();
      case ShekayatReportType.units:
        return _buildUnits();
      case ShekayatReportType.experts:
        return _buildExperts();
      case ShekayatReportType.results:
        return _buildResults();
      case ShekayatReportType.trend:
        return _buildTrend();
    }
  }

  Widget _buildDashboard() {
    final stats = ShekayatReportService.summaryStats(_filtered);
    final byStatus = ShekayatReportService.countByStatus(_filtered);
    final byMonth = ShekayatReportService.countByMonth(_filtered);
    final recentMonths = Map.fromEntries(byMonth.entries.toList().reversed.take(6).toList().reversed);

    return Column(
      children: [
        ShekayatKpiGrid(stats: stats),
        const SizedBox(height: 12),
        ShekayatReportCard(
          title: 'توزیع وضعیت',
          subtitle: 'سهم هر وضعیت از کل پرونده‌های فیلترشده',
          child: ShekayatPieChartWidget(data: byStatus),
        ),
        ShekayatReportCard(
          title: 'روند ۶ ماه اخیر',
          child: ShekayatVerticalBarChart(
            data: recentMonths,
            labelBuilder: ShekayatReportDate.monthLabel,
          ),
        ),
        if ((stats['total_damage'] as double) > 0)
          ShekayatReportCard(
            title: 'خسارت اعلام‌شده',
            child: Row(
              children: [
                _statBox('مجموع خسارت', '${(stats['total_damage'] as double).toStringAsFixed(0).seRagham()} ریال'),
                const SizedBox(width: 10),
                _statBox('میانگین', '${(stats['avg_damage'] as double).toStringAsFixed(0).seRagham()} ریال'),
              ],
            ),
          ),
      ],
    );
  }

  Widget _statBox(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: ShekayatTheme.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: PersianFonts.Shabnam.copyWith(fontSize: font_size_10, color: Colors.grey.shade700)),
            const SizedBox(height: 4),
            Text(
              value,
              style: PersianFonts.Shabnam.copyWith(
                fontSize: font_size_12,
                fontWeight: FontWeight.bold,
                color: ShekayatTheme.primaryDark,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatus() {
    final data = ShekayatReportService.countByStatus(_filtered);
    return Column(
      children: [
        ShekayatReportCard(
          title: 'نمودار وضعیت پرونده‌ها',
          child: ShekayatPieChartWidget(data: data, height: 240),
        ),
        ShekayatReportCard(
          title: 'جدول تفصیلی',
          child: ShekayatDataTable(data: data, labelHeader: 'وضعیت'),
        ),
      ],
    );
  }

  Widget _buildTypeSource() {
    final byType = ShekayatReportService.countByType(_filtered);
    final bySource = ShekayatReportService.countBySource(_filtered);
    return Column(
      children: [
        ShekayatReportCard(
          title: 'نوع شکایت',
          subtitle: 'مشتری↔واحد صنفی',
          child: Column(
            children: [
              ShekayatPieChartWidget(data: byType, height: 200),
              const SizedBox(height: 10),
              ShekayatDataTable(data: byType, labelHeader: 'نوع'),
            ],
          ),
        ),
        ShekayatReportCard(
          title: 'منبع ثبت شکایت',
          child: Column(
            children: [
              ShekayatHorizontalBarChart(data: bySource, maxItems: 12),
              const SizedBox(height: 10),
              ShekayatDataTable(data: bySource, labelHeader: 'منبع'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCategory() {
    final data = ShekayatReportService.countByCategory(_filtered);
    return Column(
      children: [
        ShekayatReportCard(
          title: 'پرتکرارترین موضوعات',
          child: ShekayatHorizontalBarChart(data: data, maxItems: 15),
        ),
        ShekayatReportCard(
          title: 'جدول موضوعات',
          child: ShekayatDataTable(data: data, labelHeader: 'موضوع'),
        ),
      ],
    );
  }

  Widget _buildUnits() {
    final data = ShekayatReportService.countByUnit(_filtered);
    final linked = _filtered.where((e) {
      final id = (e as Map)['id_store']?.toString() ?? '0';
      return id != '0' && id.isNotEmpty;
    }).length;
    final unlinked = _filtered.length - linked;

    return Column(
      children: [
        ShekayatReportCard(
          title: 'خلاصه اتصال',
          child: Row(
            children: [
              _statBox('متصل به واحد', '${linked}'.toPersianDigit()),
              const SizedBox(width: 10),
              _statBox('بدون اتصال', '${unlinked}'.toPersianDigit()),
            ],
          ),
        ),
        ShekayatReportCard(
          title: '۱۵ واحد با بیشترین شکایت',
          child: data.isEmpty
              ? Text('هیچ پرونده‌ای به واحد صنفی متصل نیست', style: PersianFonts.Shabnam.copyWith(color: Colors.grey))
              : ShekayatHorizontalBarChart(data: data, maxItems: 15),
        ),
        if (data.isNotEmpty)
          ShekayatReportCard(
            title: 'جدول واحدها',
            child: ShekayatDataTable(data: data, labelHeader: 'نام واحد'),
          ),
      ],
    );
  }

  Widget _buildExperts() {
    final data = ShekayatReportService.countByExpert(_filtered);
    final without = data['بدون کارشناس'] ?? 0;
    final withExpert = _filtered.length - without;

    return Column(
      children: [
        ShekayatReportCard(
          title: 'وضعیت ارجاع',
          child: Row(
            children: [
              _statBox('ارجاع‌شده', '${withExpert}'.toPersianDigit()),
              const SizedBox(width: 10),
              _statBox('بدون کارشناس', '${without}'.toPersianDigit()),
            ],
          ),
        ),
        ShekayatReportCard(
          title: 'توزیع بین کارشناسان',
          child: ShekayatPieChartWidget(
            data: Map.fromEntries(data.entries.where((e) => e.key != 'بدون کارشناس')),
            height: 240,
          ),
        ),
        ShekayatReportCard(
          title: 'جدول کارشناسان',
          child: ShekayatDataTable(data: data, labelHeader: 'کارشناس'),
        ),
      ],
    );
  }

  Widget _buildResults() {
    final data = ShekayatReportService.countByResult(_filtered);
    final closed = _filtered.where((e) => (e as Map)['status_shekayat']?.toString().contains('مختومه') == true).length;

    return Column(
      children: [
        ShekayatReportCard(
          title: 'خلاصه نتایج',
          child: Row(
            children: [
              _statBox('مختومه', '${closed}'.toPersianDigit()),
              const SizedBox(width: 10),
              _statBox(
                'با نتیجه ثبت‌شده',
                '${data.entries.where((e) => e.key != 'بدون نتیجه').fold<int>(0, (s, e) => s + e.value)}'.toPersianDigit(),
              ),
            ],
          ),
        ),
        ShekayatReportCard(
          title: 'نمودار نتایج رسیدگی',
          child: ShekayatPieChartWidget(data: data, height: 240),
        ),
        ShekayatReportCard(
          title: 'جدول نتایج',
          child: ShekayatDataTable(data: data, labelHeader: 'نتیجه'),
        ),
      ],
    );
  }

  Widget _buildTrend() {
    final data = ShekayatReportService.countByMonth(_filtered);
    final last12 = Map.fromEntries(data.entries.toList().reversed.take(12).toList().reversed);

    return Column(
      children: [
        ShekayatReportCard(
          title: 'روند ماهانه ثبت شکایات',
          subtitle: '۱۲ ماه اخیر (بر اساس تاریخ شکایت)',
          child: ShekayatVerticalBarChart(
            data: last12,
            labelBuilder: ShekayatReportDate.monthLabel,
          ),
        ),
        ShekayatReportCard(
          title: 'جدول ماهانه',
          child: ShekayatDataTable(
            data: last12,
            labelHeader: 'ماه',
          ),
        ),
      ],
    );
  }
}
