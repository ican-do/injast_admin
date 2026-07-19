import 'package:flutter/material.dart';
import 'package:injast_admin/features/shekayat/shekayat_constants.dart';
import 'package:injast_admin/features/shekayat/compat/shekayat_basic.dart';
import 'package:injast_admin/features/shekayat/compat/persian_fonts_shim.dart';
import 'package:injast_admin/features/shekayat/compat/persian_number_shim.dart';
import 'package:pie_chart/pie_chart.dart';

class ShekayatChartColors {
  static const List<Color> palette = [
    Color(0xFF008CA7),
    Color(0xFF4CAF50),
    Color(0xFFFF9800),
    Color(0xFF7B1FA2),
    Color(0xFFE53935),
    Color(0xFF00BCD4),
    Color(0xFFFFC107),
    Color(0xFF5C6BC0),
    Color(0xFF8D6E63),
    Color(0xFF26A69A),
  ];
}

class ShekayatKpiGrid extends StatelessWidget {
  final Map<String, dynamic> stats;

  const ShekayatKpiGrid({Key? key, required this.stats}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final cols = w >= 1000 ? 6 : (w >= 700 ? 3 : 2);
        return GridView.count(
          crossAxisCount: cols,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: cols >= 6 ? 1.9 : 1.7,
          children: [
            _KpiCard(
              title: 'کل شکایات',
              value: '${stats['total'] ?? 0}',
              icon: Icons.folder_open_rounded,
              gradient: [ShekayatTheme.primary, ShekayatTheme.primaryDark],
            ),
            _KpiCard(
              title: 'مختومه',
              value: '${stats['closed'] ?? 0}',
              subtitle: '${(stats['closure_rate'] ?? 0).toStringAsFixed(0)}%',
              icon: Icons.check_circle_outline_rounded,
              gradient: const [Color(0xFF43A047), Color(0xFF2E7D32)],
            ),
            _KpiCard(
              title: 'در جریان',
              value: '${stats['open'] ?? 0}',
              icon: Icons.pending_actions_rounded,
              gradient: const [Color(0xFFFB8C00), Color(0xFFE65100)],
            ),
            _KpiCard(
              title: 'با کارشناس',
              value: '${stats['with_expert'] ?? 0}',
              icon: Icons.engineering_rounded,
              gradient: const [Color(0xFF00ACC1), Color(0xFF00838F)],
            ),
            _KpiCard(
              title: 'متصل به واحد',
              value: '${stats['with_unit'] ?? 0}',
              icon: Icons.store_rounded,
              gradient: const [Color(0xFF7E57C2), Color(0xFF512DA8)],
            ),
            _KpiCard(
              title: 'دارای مستند',
              value: '${stats['with_docs'] ?? 0}',
              icon: Icons.attach_file_rounded,
              gradient: const [Color(0xFF5C6BC0), Color(0xFF3949AB)],
            ),
          ],
        );
      },
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String title;
  final String value;
  final String? subtitle;
  final IconData icon;
  final List<Color> gradient;

  const _KpiCard({
    required this.title,
    required this.value,
    this.subtitle,
    required this.icon,
    required this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: gradient, begin: Alignment.topRight, end: Alignment.bottomLeft),
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white.withValues(alpha: 0.9), size: 18),
          const Spacer(),
          Text(
            value,
            style: PersianFonts.Shabnam.copyWith(
              fontSize: font_size_18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          if (subtitle != null)
            Text(subtitle!, style: PersianFonts.Shabnam.copyWith(fontSize: font_size_10, color: Colors.white70)),
          Text(
            title,
            style: PersianFonts.Shabnam.copyWith(
              fontSize: font_size_10,
              color: Colors.white.withValues(alpha: 0.95),
            ),
          ),
        ],
      ),
    );
  }
}

class ShekayatReportCard extends StatelessWidget {
  final Widget child;
  final String? title;
  final String? subtitle;

  const ShekayatReportCard({Key? key, required this.child, this.title, this.subtitle}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title != null) ...[
              Text(
                title!,
                style: PersianFonts.Shabnam.copyWith(
                  fontSize: font_size_14,
                  fontWeight: FontWeight.bold,
                  color: ShekayatTheme.primaryDark,
                ),
              ),
              if (subtitle != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    subtitle!,
                    style: PersianFonts.Shabnam.copyWith(fontSize: font_size_10, color: Colors.grey.shade600),
                  ),
                ),
              const SizedBox(height: 10),
            ],
            child,
          ],
        ),
      ),
    );
  }
}

class ShekayatPieChartWidget extends StatelessWidget {
  final Map<String, int> data;
  final double height;

  const ShekayatPieChartWidget({Key? key, required this.data, this.height = 240}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return _empty();
    final numeric = Map<String, double>.fromEntries(data.entries.map((e) => MapEntry(e.key, e.value.toDouble())));
    final chartH = height.clamp(180.0, 280.0);
    return SizedBox(
      height: chartH,
      child: PieChart(
        dataMap: numeric,
        colorList: ShekayatChartColors.palette,
        chartRadius: chartH * 0.32,
        chartType: ChartType.disc,
        legendOptions: LegendOptions(
          legendPosition: LegendPosition.right,
          showLegends: true,
          legendTextStyle: PersianFonts.Shabnam.copyWith(fontSize: font_size_10),
        ),
        chartValuesOptions: ChartValuesOptions(
          showChartValues: true,
          showChartValuesInPercentage: true,
          decimalPlaces: 0,
          chartValueStyle: PersianFonts.Shabnam.copyWith(
            fontSize: font_size_8,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _empty() => Center(child: Text('داده‌ای برای نمایش نیست', style: PersianFonts.Shabnam.copyWith(color: Colors.grey)));
}

class ShekayatHorizontalBarChart extends StatelessWidget {
  final Map<String, int> data;
  final String Function(String)? labelBuilder;
  final int maxItems;

  const ShekayatHorizontalBarChart({
    Key? key,
    required this.data,
    this.labelBuilder,
    this.maxItems = 10,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return Center(child: Text('داده‌ای برای نمایش نیست', style: PersianFonts.Shabnam.copyWith(color: Colors.grey)));
    }
    final entries = data.entries.take(maxItems).toList();
    final maxVal = entries.map((e) => e.value).reduce((a, b) => a > b ? a : b).toDouble();

    return Column(
      children: entries.asMap().entries.map((entry) {
        final i = entry.key;
        final e = entry.value;
        final color = ShekayatChartColors.palette[i % ShekayatChartColors.palette.length];
        final label = labelBuilder != null ? labelBuilder!(e.key) : e.key;
        final pct = maxVal > 0 ? e.value / maxVal : 0.0;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: Text(label, style: PersianFonts.Shabnam.copyWith(fontSize: font_size_10), maxLines: 1, overflow: TextOverflow.ellipsis)),
                  Text('${e.value}'.toPersianDigit(), style: PersianFonts.Shabnam.copyWith(fontSize: font_size_12, fontWeight: FontWeight.bold, color: color)),
                ],
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: pct,
                  minHeight: 8,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation(color),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class ShekayatVerticalBarChart extends StatelessWidget {
  final Map<String, int> data;
  final String Function(String)? labelBuilder;

  const ShekayatVerticalBarChart({Key? key, required this.data, this.labelBuilder}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return SizedBox(
        height: 120,
        child: Center(child: Text('داده‌ای برای نمایش نیست', style: PersianFonts.Shabnam.copyWith(color: Colors.grey))),
      );
    }
    final entries = data.entries.toList();
    final maxVal = entries.map((e) => e.value).reduce((a, b) => a > b ? a : b).toDouble();

    return SizedBox(
      height: 180,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: entries.asMap().entries.map((entry) {
          final i = entry.key;
          final e = entry.value;
          final color = ShekayatChartColors.palette[i % ShekayatChartColors.palette.length];
          final h = maxVal > 0 ? (e.value / maxVal) * 130.0 : 0.0;
          final label = labelBuilder != null ? labelBuilder!(e.key) : e.key;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text('${e.value}'.toPersianDigit(), style: PersianFonts.Shabnam.copyWith(fontSize: font_size_8, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Container(
                    height: h < 4 ? 4 : h,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: PersianFonts.Shabnam.copyWith(fontSize: font_size_8),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class ShekayatDataTable extends StatelessWidget {
  final Map<String, int> data;
  final String labelHeader;
  final String countHeader;

  const ShekayatDataTable({
    Key? key,
    required this.data,
    this.labelHeader = 'عنوان',
    this.countHeader = 'تعداد',
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox.shrink();
    final total = data.values.fold<int>(0, (s, v) => s + v);
    return Table(
      columnWidths: const {0: FlexColumnWidth(3), 1: FlexColumnWidth(1), 2: FlexColumnWidth(1)},
      border: TableBorder(horizontalInside: BorderSide(color: Colors.grey.shade200)),
      children: [
        TableRow(
          decoration: BoxDecoration(color: ShekayatTheme.primary.withValues(alpha: 0.08)),
          children: [
            _cell(labelHeader, bold: true),
            _cell(countHeader, bold: true, center: true),
            _cell('درصد', bold: true, center: true),
          ],
        ),
        ...data.entries.map((e) {
          final pct = total > 0 ? (e.value / total * 100).toStringAsFixed(1) : '0';
          return TableRow(children: [
            _cell(e.key),
            _cell('${e.value}'.toPersianDigit(), center: true),
            _cell('$pct%'.toPersianDigit(), center: true),
          ]);
        }),
      ],
    );
  }

  Widget _cell(String text, {bool bold = false, bool center = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      child: Text(
        text,
        textAlign: center ? TextAlign.center : TextAlign.right,
        style: PersianFonts.Shabnam.copyWith(
          fontSize: font_size_10,
          fontWeight: bold ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }
}

enum ShekayatReportType {
  dashboard('داشبورد کلی', Icons.dashboard_rounded, 'نمای کلی و شاخص‌های کلیدی'),
  status('وضعیت پرونده‌ها', Icons.pie_chart_outline_rounded, 'توزیع بر اساس وضعیت رسیدگی'),
  typeSource('نوع و منبع', Icons.category_rounded, 'تحلیل نوع شکایت و منبع ثبت'),
  category('موضوعات شکایت', Icons.topic_rounded, 'پرتکرارترین موضوعات شکایت'),
  units('واحدهای پرتکرار', Icons.store_mall_directory_rounded, 'واحدهای صنفی با بیشترین شکایت'),
  experts('بار کاری کارشناسان', Icons.engineering_rounded, 'توزیع پرونده بین کارشناسان'),
  results('نتایج رسیدگی', Icons.gavel_rounded, 'آمار نتایج و توافقات'),
  trend('روند زمانی', Icons.show_chart_rounded, 'روند ثبت شکایات به تفکیک ماه');

  final String title;
  final IconData icon;
  final String subtitle;
  const ShekayatReportType(this.title, this.icon, this.subtitle);
}
