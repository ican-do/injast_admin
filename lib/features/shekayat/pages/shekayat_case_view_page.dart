import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:injast_admin/features/shekayat/compat/screen_util_shim.dart';
import 'package:injast_admin/features/shekayat/compat/get_nav.dart';
import 'package:injast_admin/features/shekayat/shekayat_api.dart';
import 'package:injast_admin/features/shekayat/shekayat_constants.dart';
import 'package:injast_admin/features/shekayat/compat/shekayat_basic.dart';
import 'package:injast_admin/features/shekayat/pages/shekayat_all_docs_page.dart';
import 'package:injast_admin/features/shekayat/pages/shekayat_form_mapper.dart';
import 'package:injast_admin/features/shekayat/pages/shekayat_form_pdf.dart';
import 'package:injast_admin/features/shekayat/pages/shekayat_widgets.dart';
import 'package:injast_admin/features/shekayat/compat/persian_fonts_shim.dart';
import 'package:injast_admin/features/shekayat/compat/shekayat_layout.dart';
import 'package:printing/printing.dart';

/// نمای پرونده شکایت — صفحه فقط نمایشی و مجزا از فرم ثبت
class ShekayatCaseViewPage extends StatefulWidget {
  final String codeCo;
  final Map<String, dynamic> complaint;
  final String? unionName;

  const ShekayatCaseViewPage({
    Key? key,
    required this.codeCo,
    required this.complaint,
    this.unionName,
  }) : super(key: key);

  @override
  State<ShekayatCaseViewPage> createState() => _ShekayatCaseViewPageState();
}

class _ShekayatCaseViewPageState extends State<ShekayatCaseViewPage> {
  Map<String, dynamic>? _detail;
  List<dynamic> _attachments = [];
  List<dynamic> _categories = [];
  bool _loading = true;
  bool _pdfLoading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Map<String, dynamic> get _data => _detail ?? widget.complaint;

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final code = widget.complaint['code_shekayat']?.toString() ?? '';
      final results = await Future.wait([
        ShekayatApi.getDetail(code),
        ShekayatApi.getAttachments(code),
        ShekayatApi.getComplaintCategories(code),
      ]);
      _detail = (results[0] as Map<String, dynamic>?) ?? widget.complaint;
      _attachments = results[1] as List<dynamic>;
      _categories = results[2] as List<dynamic>;
    } catch (_) {
      _detail = widget.complaint;
      _attachments = const [];
      _categories = const [];
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _downloadPdf() async {
    setState(() => _pdfLoading = true);
    try {
      final Uint8List bytes = await ShekayatFormPdf.generate(
        complaint: _data,
        codeCo: widget.codeCo,
        unionName: widget.unionName,
      );
      await Printing.layoutPdf(onLayout: (_) async => bytes, name: 'complaint_case_${_codeShekayat()}');
    } finally {
      if (mounted) setState(() => _pdfLoading = false);
    }
  }

  String _codeShekayat() => _data['code_shekayat']?.toString() ?? widget.complaint['code_shekayat']?.toString() ?? '';

  String _complaintNumber() => _data['complaint_number']?.toString() ?? '—';

  String _dateShekayat() => _data['date_shekayat']?.toString().trim().isNotEmpty == true ? _data['date_shekayat'].toString() : '—';

  String _sourceLabel() {
    final source = _data['source_shekayat']?.toString().trim() ?? '';
    return source.isEmpty ? 'اتحادیه' : source;
  }

  String _statusLabel() {
    final status = _data['status_shekayat']?.toString().trim() ?? '';
    final lbl = _data['lbl_vaziyat_sf']?.toString().trim() ?? '';
    return status.isNotEmpty ? status : (lbl.isNotEmpty ? lbl : 'ثبت اولیه');
  }

  String _resultLabel() {
    final result = _data['result_shekayat']?.toString().trim() ?? '';
    return result.isEmpty ? 'ثبت نشده' : result;
  }

  String _priorityLabel() {
    final priority = _data['priority_shekayat']?.toString().trim() ?? '';
    return priority.isEmpty ? 'عادی' : priority;
  }

  String _complaintTitle() {
    final title = _data['lbl_shekayat']?.toString().trim() ?? '';
    return title.isEmpty ? 'بدون عنوان' : title;
  }

  String _complaintText() {
    final caption = _data['caption']?.toString().trim() ?? '';
    return caption.isEmpty ? 'توضیحی ثبت نشده است.' : caption;
  }

  String _shakiFullName() {
    final full = ShekayatFormMapper.shakiFullName(_data);
    return full.isEmpty ? '—' : full;
  }

  String _respondentFullName() {
    final full = ShekayatFormMapper.moteshakiFullName(_data);
    return full.isEmpty ? '—' : full;
  }

  Map<String, String> get _motFields => ShekayatFormMapper.respondentFields(_data);

  String _respondentUnitName() {
    final unit = _motFields['motStore']?.trim() ?? '';
    return unit.isEmpty ? '—' : unit;
  }

  String _mobile(dynamic value) {
    final s = value?.toString().trim() ?? '';
    return s.isEmpty || s == '0' ? '—' : s;
  }

  String _text(dynamic value) {
    final s = value?.toString().trim() ?? '';
    return s.isEmpty || s == '0' ? '—' : s;
  }

  String _unionLabel() {
    final union = widget.unionName?.trim() ?? _data['name_co']?.toString().trim() ?? '';
    return union.isEmpty ? widget.codeCo : union;
  }

  String _categoryNames() {
    if (_categories.isEmpty) return 'ثبت نشده';
    final names = _categories
        .map((e) => (e as Map)['title']?.toString().trim() ?? (e)['lbl']?.toString().trim() ?? '')
        .where((e) => e.isNotEmpty)
        .toList();
    return names.isEmpty ? 'ثبت نشده' : names.join('، ');
  }

  int _attachmentCount() => _attachments.where((e) => ((e as Map)['file_path'] ?? '').toString().isNotEmpty).length;

  String _lastAttachmentDate() {
    for (final doc in _attachments) {
      final d = (doc as Map)['file_date']?.toString().trim() ?? '';
      if (d.isNotEmpty) return d;
    }
    return '—';
  }

  Color _priorityColor() {
    final value = _priorityLabel();
    if (value.contains('فوری') || value.contains('زیاد')) return ShekayatTheme.accentRed;
    if (value.contains('متوسط')) return ShekayatTheme.accentOrange;
    return Colors.grey.shade700;
  }

  void _openDocs() {
    Get.to(() => ShekayatAllDocsPage(
          codeShekayat: _codeShekayat(),
          complaintTitle: _complaintTitle(),
        ));
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF6F8FB),
        appBar: ShekayatAppBar(
          title: 'پرونده شکایت',
          actions: [
            if (_pdfLoading)
              Padding(
                padding: EdgeInsets.all(14.w),
                child: SizedBox(
                  width: 20.w,
                  height: 20.w,
                  child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                ),
              )
            else
              IconButton(
                icon: const Icon(Icons.download_rounded),
                tooltip: 'دانلود PDF',
                onPressed: _downloadPdf,
              ),
          ],
        ),
        body: _loading
            ? Center(child: CircularProgressIndicator(color: ShekayatTheme.primary))
            : RefreshIndicator(
                onRefresh: _load,
                child: ShekayatLayout.constrain(
                  maxWidth: ShekayatLayout.formMaxWidth,
                  child: ListView(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    children: [
                      _buildCaseSummary(),
                      _buildInfoSection(
                        title: 'اطلاعات شاکی',
                        icon: Icons.person_outline,
                        children: [
                          _compactRow('نام و نام خانوادگی', _shakiFullName()),
                          _compactRow('شماره موبایل', _mobile(_data['mob_shaki'])),
                          _compactRow('کد ملی', _text(_data['code_meli_shaki'])),
                          _compactRow('نام پدر', _text(_data['name_pedar_shaki'])),
                          _compactRow('آدرس', _text(_data['address_shaki'])),
                        ],
                      ),
                    _buildInfoSection(
                      title: 'اطلاعات متشاکی',
                      icon: Icons.storefront_outlined,
                      children: [
                        _compactRow('نام و نام خانوادگی', _respondentFullName()),
                        _compactRow('شماره موبایل', _mobile(_motFields['motMob'])),
                        _compactRow('کد ملی', _text(_motFields['motMeli'])),
                        _compactRow('آدرس', _text(_motFields['motAddr'])),
                      ],
                    ),
                    _buildInfoSection(
                      title: 'شرح شکایت',
                      icon: Icons.description_outlined,
                      children: [
                        _compactRow('عنوان شکایت', _complaintTitle()),
                        _compactBlock('شرح و توضیحات پرونده', _complaintText()),
                      ],
                    ),
                    _buildInfoSection(
                      title: 'ارتباط با واحد صنفی',
                      icon: Icons.account_tree_outlined,
                      children: [
                        _compactRow('نام اتحادیه', _unionLabel()),
                        _compactRow('مرجع ثبت شکایت', _sourceLabel()),
                        _compactRow('موضوعات شکایت', _categoryNames()),
                        _compactRow('نام واحد صنفی (ثبت‌شده)', _respondentUnitName()),
                        _compactRow('شناسه پرونده مرتبط', _text(_data['linked_parvandeh_id'] ?? _data['id_store'])),
                        _compactRow(
                          'وضعیت اتصال',
                          ShekayatFormMapper.isLinked(_data) ? 'دارای ارتباط پرونده' : 'بدون ارتباط پرونده',
                        ),
                      ],
                    ),
                    _buildInfoSection(
                      title: 'مدارک و پیوست‌ها',
                      icon: Icons.attach_file_outlined,
                      children: [
                        _compactRow('تعداد مدارک ثبت‌شده', _attachmentCount().toString()),
                        _compactRow('آخرین تاریخ بارگذاری', _lastAttachmentDate()),
                        _compactRow('وضعیت بررسی', _attachmentCount() > 0 ? 'آماده مشاهده' : 'مدرکی ثبت نشده'),
                        SizedBox(height: 6.h),
                        SizedBox(
                          width: double.infinity,
                          height: 40.h,
                          child: ElevatedButton.icon(
                            onPressed: _openDocs,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: ShekayatTheme.accentGreen,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(horizontal: 12.w),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: Icon(Icons.folder_open_outlined, size: 18.sp),
                            label: Text(
                              'مشاهده مدارک و مستندات',
                              style: PersianFonts.Shabnam.copyWith(fontSize: font_size_10, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
      ),
    );
  }

  Widget _buildCaseSummary() {
    final status = _statusLabel();
    final result = _resultLabel();
    return Container(
      margin: EdgeInsets.only(bottom: 8.h),
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ShekayatTheme.primary.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  _complaintTitle(),
                  style: PersianFonts.Shabnam.copyWith(
                    fontSize: font_size_12,
                    fontWeight: FontWeight.bold,
                    color: ShekayatTheme.primaryDark,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(width: 8.w),
              Text(
                'شماره ${_complaintNumber()}',
                style: PersianFonts.Shabnam.copyWith(fontSize: font_size_10, color: Colors.grey.shade700, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Wrap(
            spacing: 6.w,
            runSpacing: 4.h,
            children: [
              _summaryBadge('وضعیت: $status', ShekayatConstants.statusColor(status)),
              _summaryBadge('نتیجه: $result', ShekayatConstants.resultColor(result)),
              _summaryBadge('نوع: ${ShekayatConstants.typeLabel(_data['type_shekayat']?.toString())}', ShekayatTheme.primary),
              _summaryBadge('اولویت: ${_priorityLabel()}', _priorityColor()),
            ],
          ),
          Divider(height: 14.h, color: Colors.grey.shade200),
          _compactRow('تاریخ ثبت', _dateShekayat(), dense: true),
          _compactRow('مرجع ثبت', _sourceLabel(), dense: true),
        ],
      ),
    );
  }

  Widget _buildInfoSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 8.h),
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: ShekayatTheme.primary, size: 16.sp),
              SizedBox(width: 6.w),
              Text(
                title,
                style: PersianFonts.Shabnam.copyWith(fontSize: font_size_12, fontWeight: FontWeight.bold, color: ShekayatTheme.primaryDark),
              ),
            ],
          ),
          SizedBox(height: 6.h),
          ...children,
        ],
      ),
    );
  }

  Widget _compactRow(String label, String value, {bool dense = false}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: dense ? 2.h : 3.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 108.w,
            child: Text(
              label,
              style: PersianFonts.Shabnam.copyWith(fontSize: font_size_10, color: Colors.grey.shade600),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: PersianFonts.Shabnam.copyWith(
                fontSize: font_size_10,
                color: Colors.black87,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _compactBlock(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(top: 2.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: PersianFonts.Shabnam.copyWith(fontSize: font_size_10, color: Colors.grey.shade600)),
          SizedBox(height: 3.h),
          Text(
            value,
            style: PersianFonts.Shabnam.copyWith(fontSize: font_size_10, color: Colors.black87, height: 1.45),
          ),
        ],
      ),
    );
  }

  Widget _summaryBadge(String text, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Text(
        text,
        style: PersianFonts.Shabnam.copyWith(fontSize: font_size_10, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}
