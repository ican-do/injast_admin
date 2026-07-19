import 'package:flutter/material.dart';
import 'package:injast_admin/features/reports/bazrasi_reports_api.dart' as api;
import 'package:injast_admin/features/shared/admin_ui.dart';

typedef BazrasiReportLoader = Future<Object?> Function(
    DateTime? startDate, DateTime? endDate);

class BazrasiReportsHubPage extends StatelessWidget {
  const BazrasiReportsHubPage({
    super.key,
    required this.codeCo,
    this.sessionUser,
  });

  final String codeCo;
  final Map<String, dynamic>? sessionUser;

  Map<String, dynamic> get _userInfo => {
        'type_user_2': sessionUser?['type_user_2'] ?? 1,
        'code_co': sessionUser?['code_co'] ?? codeCo,
        'state': sessionUser?['state_user'],
        'city': sessionUser?['city_user'],
      };

  List<_ReportTile> get _reports => [
        _ReportTile(
            'تعداد بازرسی در ماه',
            Icons.calendar_month_outlined,
            Colors.blue,
            (s, e) => api.getTotalBazrasiByTimeRange('monthly',
                startDate: s, endDate: e, userInfo: _userInfo)),
        _ReportTile(
            'وضعیت پروانه',
            Icons.badge_outlined,
            Colors.teal,
            (s, e) => api.getBazrasiByLicenseStatus(
                startDate: s, endDate: e, userInfo: _userInfo)),
        _ReportTile(
            'بازرسی بر اساس شهر',
            Icons.location_city_outlined,
            Colors.indigo,
            (s, e) => api.getBazrasiByLocation('city',
                startDate: s, endDate: e, userInfo: _userInfo)),
        _ReportTile(
            'میانگین زمان رسیدگی',
            Icons.timer_outlined,
            Colors.orange,
            (s, e) => api.getAvgProcessingTime(
                startDate: s, endDate: e, userInfo: _userInfo)),
        _ReportTile(
            'فعال و غیرفعال',
            Icons.pie_chart_outline,
            Colors.purple,
            (s, e) => api.getActiveInactiveRatio(
                startDate: s, endDate: e, userInfo: _userInfo)),
        _ReportTile(
            'تخلفات پرتکرار',
            Icons.warning_amber_outlined,
            Colors.red,
            (s, e) => api.getMostCommonViolations(20,
                startDate: s, endDate: e, userInfo: _userInfo)),
        _ReportTile(
            'تخلفات بر اساس اتحادیه',
            Icons.account_balance_outlined,
            Colors.deepPurple,
            (s, e) => api.getViolationsByUnion(
                startDate: s, endDate: e, userInfo: _userInfo)),
        _ReportTile(
            'واحدهای پر تخلف',
            Icons.block_outlined,
            Colors.redAccent,
            (s, e) => api.getBlacklistUnits(3,
                startDate: s, endDate: e, userInfo: _userInfo)),
        _ReportTile(
            'عملکرد بازرسان',
            Icons.groups_outlined,
            Colors.green,
            (s, e) => api.getInspectorInspectionCount(
                startDate: s, endDate: e, userInfo: _userInfo)),
        _ReportTile(
            'بازدهی بازرسان',
            Icons.speed_outlined,
            Colors.cyan,
            (s, e) => api.getInspectorEfficiency(
                startDate: s, endDate: e, userInfo: _userInfo)),
        _ReportTile(
            'پرونده‌های مهم',
            Icons.priority_high,
            Colors.deepOrange,
            (s, e) => api.getImportantCases(
                startDate: s, endDate: e, userInfo: _userInfo)),
        _ReportTile(
            'روند تخلفات',
            Icons.trending_up,
            Colors.blueGrey,
            (s, e) => api.getViolationTrend(
                startDate: s, endDate: e, userInfo: _userInfo)),
      ];

  @override
  Widget build(BuildContext context) {
    return AdminPageShell(
      title: 'گزارش‌های بازرسی',
      subtitle: 'گزارش‌های مدیریتی و عملکردی',
      icon: Icons.assessment_outlined,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 1000
              ? 4
              : constraints.maxWidth >= 700
                  ? 3
                  : constraints.maxWidth >= 450
                      ? 2
                      : 1;
          return GridView.builder(
            padding: const EdgeInsets.all(18),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              mainAxisExtent: 155,
            ),
            itemCount: _reports.length,
            itemBuilder: (context, index) {
              final report = _reports[index];
              return InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BazrasiReportViewPage(
                      title: report.title,
                      loader: report.loader,
                    ),
                  ),
                ),
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: AdminUi.cardDecoration(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        backgroundColor: report.color.withValues(alpha: .12),
                        child: Icon(report.icon, color: report.color),
                      ),
                      const Spacer(),
                      Text(report.title,
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: AdminUi.ink)),
                      const SizedBox(height: 5),
                      const Row(
                        children: [
                          Text('مشاهده گزارش',
                              style: TextStyle(
                                  fontSize: 12, color: AdminUi.muted)),
                          Spacer(),
                          Icon(Icons.chevron_left,
                              size: 18, color: AdminUi.muted),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class BazrasiReportViewPage extends StatefulWidget {
  const BazrasiReportViewPage({
    super.key,
    required this.title,
    required this.loader,
  });

  final String title;
  final BazrasiReportLoader loader;

  @override
  State<BazrasiReportViewPage> createState() => _BazrasiReportViewPageState();
}

class _BazrasiReportViewPageState extends State<BazrasiReportViewPage> {
  DateTime? _startDate;
  DateTime? _endDate;
  Object? _result;
  Object? _error;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _pick(bool start) async {
    final selected = await showDatePicker(
      context: context,
      initialDate: (start ? _startDate : _endDate) ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (selected != null) {
      setState(() {
        if (start) {
          _startDate = selected;
        } else {
          _endDate = selected;
        }
      });
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _result = await widget.loader(_startDate, _endDate);
    } catch (e) {
      _result = null;
      _error = e;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _date(DateTime? value) => value == null
      ? ''
      : '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  List<Map<String, dynamic>> get _rows {
    final value = _result;
    if (value is List) {
      return value
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    if (value is Map) {
      final map = Map<String, dynamic>.from(value);
      final nested = map['data'];
      if (nested is List) {
        return nested
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
      return [map];
    }
    return [];
  }

  @override
  Widget build(BuildContext context) {
    return AdminPageShell(
      title: widget.title,
      subtitle: 'فیلتر بازه زمانی و مشاهده نتایج',
      icon: Icons.table_chart_outlined,
      actions: [
        IconButton(
            onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh))
      ],
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(14),
            decoration: AdminUi.cardDecoration(),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _pick(true),
                  icon: const Icon(Icons.date_range),
                  label: Text(_startDate == null
                      ? 'از تاریخ'
                      : 'از ${_date(_startDate)}'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _pick(false),
                  icon: const Icon(Icons.event),
                  label: Text(
                      _endDate == null ? 'تا تاریخ' : 'تا ${_date(_endDate)}'),
                ),
                FilledButton.icon(
                  onPressed: _loading ? null : _load,
                  icon: const Icon(Icons.filter_alt_outlined),
                  label: const Text('اعمال فیلتر'),
                ),
                if (_startDate != null || _endDate != null)
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _startDate = null;
                        _endDate = null;
                      });
                      _load();
                    },
                    child: const Text('پاک‌کردن'),
                  ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? AdminEmptyState(message: 'خطا در دریافت گزارش\n$_error')
                    : _rows.isEmpty
                        ? const AdminEmptyState(
                            message: 'داده‌ای برای این گزارش یافت نشد')
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                            itemCount: _rows.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (_, index) {
                              final row = _rows[index];
                              return Container(
                                padding: const EdgeInsets.all(14),
                                decoration: AdminUi.cardDecoration(),
                                child: Wrap(
                                  spacing: 10,
                                  runSpacing: 10,
                                  children: row.entries
                                      .map((entry) => Container(
                                            width: 230,
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                              color: AdminUi.pageBg,
                                              borderRadius:
                                                  BorderRadius.circular(9),
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(entry.key,
                                                    style: const TextStyle(
                                                        fontSize: 11,
                                                        color: AdminUi.muted)),
                                                const SizedBox(height: 3),
                                                Text('${entry.value ?? '-'}',
                                                    maxLines: 3,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.w700)),
                                              ],
                                            ),
                                          ))
                                      .toList(),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}

class _ReportTile {
  const _ReportTile(this.title, this.icon, this.color, this.loader);

  final String title;
  final IconData icon;
  final Color color;
  final BazrasiReportLoader loader;
}
