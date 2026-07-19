import 'package:flutter/material.dart';
import 'package:injast_admin/features/shekayat/compat/persian_fonts_shim.dart';
import 'package:injast_admin/features/shekayat/compat/shekayat_basic.dart';
import 'package:injast_admin/features/shekayat/compat/shekayat_layout.dart';
import 'package:injast_admin/features/shekayat/pages/shekayat_docs_gallery.dart';
import 'package:injast_admin/features/shekayat/pages/shekayat_widgets.dart';
import 'package:injast_admin/features/shekayat/shekayat_constants.dart';

/// مدارک و مستندات یکپارچه — سه تب با ظاهر یکسان
class ShekayatAllDocsPage extends StatefulWidget {
  final String codeShekayat;
  final String? complaintTitle;

  const ShekayatAllDocsPage({Key? key, required this.codeShekayat, this.complaintTitle}) : super(key: key);

  @override
  State<ShekayatAllDocsPage> createState() => _ShekayatAllDocsPageState();
}

class _ShekayatAllDocsPageState extends State<ShekayatAllDocsPage> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        appBar: ShekayatAppBar(
          title: 'مدارک و مستندات',
          bottom: TabBar(
            controller: _tabCtrl,
            labelStyle: PersianFonts.Shabnam.copyWith(fontSize: font_size_12, fontWeight: FontWeight.bold),
            unselectedLabelStyle: PersianFonts.Shabnam.copyWith(fontSize: font_size_12),
            indicatorColor: Colors.white,
            tabs: const [
              Tab(height: 40, text: 'شاکی'),
              Tab(height: 40, text: 'کارشناس'),
              Tab(height: 40, text: 'مسئول'),
            ],
          ),
        ),
        body: ShekayatLayout.constrain(
          maxWidth: ShekayatLayout.docsMaxWidth,
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if ((widget.complaintTitle ?? '').trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    widget.complaintTitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: PersianFonts.Shabnam.copyWith(
                      fontSize: font_size_12,
                      color: ShekayatTheme.primaryDark,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              Expanded(
                child: TabBarView(
                  controller: _tabCtrl,
                  children: [
                    ShekayatDocsGallery(
                      codeShekayat: widget.codeShekayat,
                      sourceType: 'complainant',
                      readOnly: true,
                      embedded: true,
                    ),
                    ShekayatDocsGallery(
                      codeShekayat: widget.codeShekayat,
                      sourceType: 'expert',
                      embedded: true,
                    ),
                    ShekayatDocsGallery(
                      codeShekayat: widget.codeShekayat,
                      sourceType: 'officer',
                      embedded: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
