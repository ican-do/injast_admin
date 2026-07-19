import 'package:flutter/material.dart';
import 'package:injast_admin/features/shekayat/pages/shekayat_docs_gallery.dart';
import 'package:injast_admin/features/shekayat/pages/shekayat_widgets.dart';

/// گالری مدارک بارگذاری‌شده توسط شاکی
class ShekayatComplainantGalleryPage extends StatelessWidget {
  final String codeShekayat;
  final String? complaintTitle;

  const ShekayatComplainantGalleryPage({
    Key? key,
    required this.codeShekayat,
    this.complaintTitle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: const ShekayatAppBar(title: 'مدارک شاکی'),
        body: ShekayatDocsGallery(
          codeShekayat: codeShekayat,
          sourceType: 'complainant',
          readOnly: true,
        ),
      ),
    );
  }
}
