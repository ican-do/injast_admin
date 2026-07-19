import 'package:flutter/material.dart';
import 'package:injast_admin/features/shekayat/compat/class_controler.dart';
import 'package:injast_admin/features/shekayat/shekayat_constants.dart';
import 'package:injast_admin/features/shekayat/compat/shekayat_basic.dart';
import 'package:injast_admin/features/shekayat/reports/shekayat_report_service.dart';
import 'package:injast_admin/features/shekayat/pages/shekayat_widgets.dart';
import 'package:persian_datetimepickers/persian_datetimepickers.dart';
import 'package:injast_admin/features/shekayat/compat/persian_fonts_shim.dart';

class ShekayatReportFilterPanel extends StatefulWidget {
  final ShekayatReportFilters filters;
  final List<String> categories;
  final ValueChanged<ShekayatReportFilters> onChanged;

  const ShekayatReportFilterPanel({
    Key? key,
    required this.filters,
    required this.categories,
    required this.onChanged,
  }) : super(key: key);

  @override
  State<ShekayatReportFilterPanel> createState() => _ShekayatReportFilterPanelState();
}

class _ShekayatReportFilterPanelState extends State<ShekayatReportFilterPanel> {
  late final TextEditingController _startCtrl;
  late final TextEditingController _endCtrl;

  @override
  void initState() {
    super.initState();
    _startCtrl = TextEditingController(text: ShekayatReportService.formatFilterDate(widget.filters.startDate));
    _endCtrl = TextEditingController(text: ShekayatReportService.formatFilterDate(widget.filters.endDate));
  }

  @override
  void didUpdateWidget(covariant ShekayatReportFilterPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    _startCtrl.text = ShekayatReportService.formatFilterDate(widget.filters.startDate);
    _endCtrl.text = ShekayatReportService.formatFilterDate(widget.filters.endDate);
  }

  @override
  void dispose() {
    _startCtrl.dispose();
    _endCtrl.dispose();
    super.dispose();
  }

  void _update(ShekayatReportFilters f) => widget.onChanged(f);

  void _clear() {
    _startCtrl.clear();
    _endCtrl.clear();
    _update(ShekayatReportFilters());
  }

  ShekayatReportFilters _copy({
    DateTime? startDate,
    DateTime? endDate,
    String? status,
    String? type,
    String? source,
    String? category,
    String? result,
    String? linkedUnit,
    bool clearStart = false,
    bool clearEnd = false,
  }) {
    final f = widget.filters;
    return ShekayatReportFilters()
      ..startDate = clearStart ? null : (startDate ?? f.startDate)
      ..endDate = clearEnd ? null : (endDate ?? f.endDate)
      ..status = status ?? f.status
      ..type = type ?? f.type
      ..source = source ?? f.source
      ..category = category ?? f.category
      ..result = result ?? f.result
      ..linkedUnit = linkedUnit ?? f.linkedUnit;
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.filters;
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: false,
          tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          leading: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: ShekayatTheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.tune_rounded, color: ShekayatTheme.primary, size: 18),
          ),
          title: Text(
            'فیلترهای گزارش',
            style: PersianFonts.Shabnam.copyWith(fontSize: font_size_12, fontWeight: FontWeight.bold),
          ),
          subtitle: f.hasActive
              ? Text('فیلتر فعال', style: PersianFonts.Shabnam.copyWith(fontSize: font_size_10, color: ShekayatTheme.primary))
              : null,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (f.hasActive)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: Icon(Icons.filter_alt_off, size: 18, color: ShekayatTheme.accentRed),
                  onPressed: _clear,
                  tooltip: 'پاک کردن فیلترها',
                ),
              Icon(Icons.expand_more, color: Colors.grey.shade600, size: 20),
            ],
          ),
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 720;
                final dateRow = Row(
                  children: [
                    Expanded(
                      child: ShekayatDateField(
                        label: 'از تاریخ',
                        controller: _startCtrl,
                        onTap: () async {
                          final d = await showPersianDatePicker(context: context);
                          if (d != null) {
                            _startCtrl.text = convert_date_persian2(d);
                            _update(_copy(startDate: d));
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ShekayatDateField(
                        label: 'تا تاریخ',
                        controller: _endCtrl,
                        onTap: () async {
                          final d = await showPersianDatePicker(context: context);
                          if (d != null) {
                            _endCtrl.text = convert_date_persian2(d);
                            _update(_copy(endDate: d));
                          }
                        },
                      ),
                    ),
                  ],
                );

                final dropdowns = [
                  _dropdown('وضعیت پرونده', f.status ?? 'همه', ['همه', ...ShekayatConstants.statuses], (v) {
                    _update(_copy(status: v));
                  }),
                  _dropdown('نوع شکایت', f.type ?? 'همه', ['همه', ...ShekayatConstants.types.map((e) => e['value']!)], (v) {
                    _update(_copy(type: v));
                  }, labelBuilder: (v) => v == 'همه' ? v : ShekayatConstants.typeLabel(v)),
                  _dropdown('منبع ثبت', f.source ?? 'همه', ['همه', ...ShekayatConstants.sources], (v) {
                    _update(_copy(source: v));
                  }),
                  _dropdown('موضوع شکایت', f.category ?? 'همه', ['همه', ...widget.categories], (v) {
                    _update(_copy(category: v));
                  }),
                  _dropdown('نتیجه رسیدگی', f.result ?? 'همه', ['همه', ...ShekayatConstants.results, 'بدون نتیجه'], (v) {
                    _update(_copy(result: v));
                  }),
                  _dropdown('اتصال واحد صنفی', f.linkedUnit ?? 'همه', ['همه', 'متصل', 'بدون اتصال'], (v) {
                    _update(_copy(linkedUnit: v));
                  }),
                ];

                if (!wide) {
                  return Column(
                    children: [
                      dateRow,
                      ...dropdowns,
                    ],
                  );
                }

                return Column(
                  children: [
                    dateRow,
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: dropdowns
                          .map(
                            (w) => SizedBox(
                              width: (constraints.maxWidth - 8) / 2,
                              child: w,
                            ),
                          )
                          .toList(),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _dropdown(
    String label,
    String value,
    List<String> items,
    ValueChanged<String> onChanged, {
    String Function(String)? labelBuilder,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: ShekayatDropdown(
        label: label,
        value: value,
        items: items,
        itemLabel: labelBuilder,
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
      ),
    );
  }
}
