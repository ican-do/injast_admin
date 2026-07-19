import 'package:flutter/material.dart';
import 'package:injast_admin/features/shekayat/compat/get_nav.dart';
import 'package:injast_admin/features/shekayat/compat/persian_fonts_shim.dart';
import 'package:injast_admin/features/shekayat/compat/shekayat_basic.dart';
import 'package:injast_admin/features/shekayat/compat/shekayat_layout.dart';
import 'package:injast_admin/features/shekayat/pages/shekayat_widgets.dart';
import 'package:injast_admin/features/shekayat/reports/shekayat_report_screen.dart';
import 'package:injast_admin/features/shekayat/reports/shekayat_report_widgets.dart';
import 'package:injast_admin/features/shekayat/shekayat_constants.dart';

class ShekayatReportsHub extends StatelessWidget {
  final String codeCo;

  const ShekayatReportsHub({Key? key, required this.codeCo}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    ShekayatNav.bind(context);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF0F4F8),
        appBar: ShekayatAppBar(
          title: 'گزارشات شکایات',
          actions: [
            IconButton(
              icon: const Icon(Icons.dashboard_customize_rounded),
              tooltip: 'داشبورد کلی',
              onPressed: () => Get.to(
                () => ShekayatReportScreen(
                  codeCo: codeCo,
                  type: ShekayatReportType.dashboard,
                ),
              ),
            ),
          ],
        ),
        body: ShekayatLayout.constrain(
          maxWidth: ShekayatLayout.reportsMaxWidth,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _HeroBanner(codeCo: codeCo)),
              const SliverToBoxAdapter(child: SizedBox(height: 12)),
              SliverLayoutBuilder(
                builder: (context, constraints) {
                  final w = constraints.crossAxisExtent;
                  final cols = w >= 1000 ? 4 : (w >= 720 ? 3 : 2);
                  return SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: cols,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 1.55,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final report = ShekayatReportType.values[index];
                        return _ReportTile(
                          report: report,
                          onTap: () => Get.to(
                            () => ShekayatReportScreen(
                              codeCo: codeCo,
                              type: report,
                            ),
                          ),
                        );
                      },
                      childCount: ShekayatReportType.values.length,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroBanner extends StatelessWidget {
  const _HeroBanner({required this.codeCo});
  final String codeCo;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [ShekayatTheme.primary, ShekayatTheme.primaryDark],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.analytics_rounded, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'مرکز گزارش‌گیری شکایات',
                  style: PersianFonts.Shabnam.copyWith(
                    fontSize: font_size_14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'نمودار، فیلتر و تحلیل پرونده‌های شکایت',
                  style: PersianFonts.Shabnam.copyWith(
                    fontSize: font_size_10,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: () => Get.to(
              () => ShekayatReportScreen(
                codeCo: codeCo,
                type: ShekayatReportType.dashboard,
              ),
            ),
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            icon: const Icon(Icons.open_in_new, size: 16),
            label: Text('داشبورد', style: PersianFonts.Shabnam.copyWith(fontSize: font_size_12)),
          ),
        ],
      ),
    );
  }
}

class _ReportTile extends StatelessWidget {
  final ShekayatReportType report;
  final VoidCallback onTap;

  const _ReportTile({required this.report, required this.onTap});

  @override
  Widget build(BuildContext context) {
    const colors = [
      [Color(0xFF008CA7), Color(0xFF00ACC1)],
      [Color(0xFF5C6BC0), Color(0xFF3949AB)],
      [Color(0xFF43A047), Color(0xFF2E7D32)],
      [Color(0xFFFB8C00), Color(0xFFE65100)],
      [Color(0xFF7E57C2), Color(0xFF512DA8)],
      [Color(0xFF00BCD4), Color(0xFF0097A7)],
      [Color(0xFFE53935), Color(0xFFC62828)],
      [Color(0xFF26A69A), Color(0xFF00897B)],
    ];
    final c = colors[report.index % colors.length];

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: c[0].withValues(alpha: 0.18)),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: c),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(report.icon, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      report.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: PersianFonts.Shabnam.copyWith(
                        fontSize: font_size_12,
                        fontWeight: FontWeight.bold,
                        color: ShekayatTheme.primaryDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      report.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: PersianFonts.Shabnam.copyWith(
                        fontSize: font_size_10,
                        color: Colors.grey.shade600,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_left, size: 18, color: c[0]),
            ],
          ),
        ),
      ),
    );
  }
}

/// منوی گزارشات شکایات — سازگار با دسکتاپ
void openShekayatReportsPicker(BuildContext context, String codeCo) {
  final wide = ShekayatLayout.isWide(context, min: 900);
  if (wide) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720, maxHeight: 560),
          child: _ReportsPickerBody(codeCo: codeCo, onClose: () => Navigator.pop(ctx)),
        ),
      ),
    );
    return;
  }

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
    ),
    builder: (ctx) => Directionality(
      textDirection: TextDirection.rtl,
      child: SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.55,
          child: _ReportsPickerBody(codeCo: codeCo, onClose: () => Navigator.pop(ctx)),
        ),
      ),
    ),
  );
}

class _ReportsPickerBody extends StatelessWidget {
  const _ReportsPickerBody({required this.codeCo, required this.onClose});

  final String codeCo;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 8),
          child: Row(
            children: [
              const Icon(Icons.assessment_rounded, color: ShekayatTheme.primary, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'گزارشات شکایات',
                  style: PersianFonts.Shabnam.copyWith(fontSize: font_size_14, fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(onPressed: onClose, icon: const Icon(Icons.close)),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 12),
            children: [
              ListTile(
                dense: true,
                leading: const Icon(Icons.dashboard_customize_rounded, color: ShekayatTheme.primary),
                title: Text('همه گزارشات', style: PersianFonts.Shabnam.copyWith(fontWeight: FontWeight.bold, fontSize: font_size_12)),
                subtitle: Text('مرکز گزارش‌گیری و داشبورد کلی', style: PersianFonts.Shabnam.copyWith(fontSize: font_size_10)),
                onTap: () {
                  onClose();
                  Get.to(() => ShekayatReportsHub(codeCo: codeCo));
                },
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              ...ShekayatReportType.values.map(
                (r) => ListTile(
                  dense: true,
                  leading: Icon(r.icon, color: ShekayatTheme.primary, size: 20),
                  title: Text(r.title, style: PersianFonts.Shabnam.copyWith(fontSize: font_size_12)),
                  subtitle: Text(r.subtitle, style: PersianFonts.Shabnam.copyWith(fontSize: font_size_10, color: Colors.grey)),
                  onTap: () {
                    onClose();
                    Get.to(() => ShekayatReportScreen(codeCo: codeCo, type: r));
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
