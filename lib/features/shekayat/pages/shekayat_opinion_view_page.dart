import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:injast_admin/features/shekayat/compat/screen_util_shim.dart';
import 'package:injast_admin/features/shekayat/shekayat_constants.dart';
import 'package:injast_admin/features/shekayat/pages/shekayat_widgets.dart';
import 'package:injast_admin/features/shekayat/compat/shekayat_basic.dart';
import 'package:injast_admin/features/shekayat/compat/persian_fonts_shim.dart';

/// مشاهده نظریه کارشناسی — فقط خواندنی + کپی
class ShekayatOpinionViewPage extends StatelessWidget {
  final dynamic opinion;

  const ShekayatOpinionViewPage({Key? key, required this.opinion}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final text = opinion['opinion_text']?.toString() ?? '';
    final damage = opinion['damage_amount']?.toString() ?? '';
    final date = opinion['date_expertise']?.toString() ?? '';

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: ShekayatAppBar(
          title: 'نظریه کارشناسی',
          actions: [
            IconButton(
              icon: const Icon(Icons.copy),
              tooltip: 'کپی',
              onPressed: () {
                Clipboard.setData(ClipboardData(text: '$text\n\nبرآورد خسارت: $damage'));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('متن کپی شد', style: PersianFonts.Shabnam)),
                );
              },
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: EdgeInsets.all(16.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('تاریخ کارشناسی: $date', style: PersianFonts.Shabnam.copyWith(fontSize: font_size_14, fontWeight: FontWeight.w600)),
              SizedBox(height: 12.h),
              Container(
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.grey.shade50,
                ),
                child: Text(text, style: PersianFonts.Shabnam.copyWith(fontSize: font_size_14)),
              ),
              if (damage.isNotEmpty) ...[
                SizedBox(height: 12.h),
                Text('برآورد خسارت: $damage', style: PersianFonts.Shabnam.copyWith(fontSize: font_size_14, color: ShekayatTheme.primary)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
