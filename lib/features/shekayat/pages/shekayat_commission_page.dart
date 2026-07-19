import 'package:flutter/material.dart';
import 'package:injast_admin/features/shekayat/compat/screen_util_shim.dart';
import 'package:injast_admin/features/shekayat/shekayat_api.dart';
import 'package:injast_admin/features/shekayat/shekayat_constants.dart';
import 'package:injast_admin/features/shekayat/compat/shekayat_basic.dart';
import 'package:injast_admin/features/shekayat/pages/shekayat_complainant_gallery_page.dart';
import 'package:injast_admin/features/shekayat/pages/shekayat_commission_form_sheet.dart';
import 'package:injast_admin/features/shekayat/pages/shekayat_widgets.dart';
import 'package:injast_admin/features/shekayat/compat/persian_fonts_shim.dart';

/// مدیریت جلسات کمیسیون — مطابق طراحی کارشناسی و پیگیری
class ShekayatCommissionPage extends StatefulWidget {
  final String codeShekayat;
  final String codeCo;
  final dynamic complaint;

  const ShekayatCommissionPage({
    Key? key,
    required this.codeShekayat,
    required this.codeCo,
    this.complaint,
  }) : super(key: key);

  @override
  State<ShekayatCommissionPage> createState() => _ShekayatCommissionPageState();
}

class _ShekayatCommissionPageState extends State<ShekayatCommissionPage> {
  final _searchCtrl = TextEditingController();
  List<dynamic> _sessions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() => setState(() {}));
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _sessions = await ShekayatApi.getSessions(widget.codeShekayat);
    } catch (_) {
      _sessions = [];
    }
    if (mounted) setState(() => _loading = false);
  }

  List<dynamic> get _filtered {
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) return _sessions;
    return _sessions.where((r) {
      final m = r as Map;
      return [m['session_date'], m['session_time'], m['description']]
          .any((f) => (f?.toString().toLowerCase() ?? '').contains(q));
    }).toList();
  }

  Future<void> _openNewForm() async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ShekayatCommissionFormSheet(codeShekayat: widget.codeShekayat),
    );
    if (saved == true) _load();
  }

  void _showDetail(dynamic item) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          margin: EdgeInsets.only(top: 80.h),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20.r))),
          padding: EdgeInsets.all(20.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('جلسه کمیسیون', style: PersianFonts.Shabnam.copyWith(fontSize: font_size_16, fontWeight: FontWeight.bold, color: ShekayatTheme.primaryDark)),
              SizedBox(height: 12.h),
              _detailRow('تاریخ', item['session_date']?.toString() ?? '-'),
              _detailRow('ساعت', item['session_time']?.toString() ?? '-'),
              if ((item['description']?.toString() ?? '').isNotEmpty) ...[
                SizedBox(height: 8.h),
                Text('صورتجلسه', style: PersianFonts.Shabnam.copyWith(fontSize: font_size_12, fontWeight: FontWeight.w600)),
                SizedBox(height: 6.h),
                Text(item['description']?.toString() ?? '-', style: PersianFonts.Shabnam.copyWith(fontSize: font_size_14, height: 1.6)),
              ],
              SizedBox(height: 16.h),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, 'minutes'),
                style: ElevatedButton.styleFrom(backgroundColor: ShekayatTheme.primary, padding: EdgeInsets.symmetric(vertical: 12.h)),
                child: Text((item['description']?.toString() ?? '').isEmpty ? 'ثبت صورتجلسه' : 'ویرایش صورتجلسه', style: PersianFonts.Shabnam.copyWith(color: Colors.white)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, 'delete'),
                child: Text('حذف جلسه', style: PersianFonts.Shabnam.copyWith(color: Colors.red)),
              ),
              TextButton(onPressed: () => Navigator.pop(context), child: Text('بستن', style: PersianFonts.Shabnam)),
            ],
          ),
        ),
      ),
    );
    if (action == 'minutes') {
      final saved = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => ShekayatCommissionMinutesSheet(session: item as Map<String, dynamic>, codeShekayat: widget.codeShekayat),
      );
      if (saved == true) _load();
    } else if (action == 'delete') {
      await ShekayatApi.deleteSession(int.parse(item['id'].toString()));
      _load();
    }
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 6.h),
      child: Row(
        children: [
          Text('$label: ', style: PersianFonts.Shabnam.copyWith(fontSize: font_size_12, color: Colors.grey.shade600)),
          Expanded(child: Text(value, style: PersianFonts.Shabnam.copyWith(fontSize: font_size_12, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        appBar: ShekayatAppBar(
          title: 'کمیسیون شکایات',
          actions: [
            IconButton(
              icon: const Icon(Icons.collections),
              tooltip: 'مدارک شاکی',
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(
                  builder: (_) => ShekayatComplainantGalleryPage(
                    codeShekayat: widget.codeShekayat,
                    complaintTitle: widget.complaint?['lbl_shekayat']?.toString(),
                  ),
                ));
              },
            ),
            IconButton(icon: const Icon(Icons.refresh), onPressed: _loading ? null : _load),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _openNewForm,
          backgroundColor: ShekayatTheme.primary,
          icon: const Icon(Icons.add, color: Colors.white),
          label: Text('جلسه جدید', style: PersianFonts.Shabnam.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
        body: _loading
            ? Center(child: CircularProgressIndicator(color: ShekayatTheme.primary))
            : Column(
                children: [
                  _buildSearch(),
                  Expanded(child: _buildList()),
                ],
              ),
      ),
    );
  }

  Widget _buildSearch() {
    return Container(
      margin: EdgeInsets.all(12.w),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)]),
      child: TextField(
        controller: _searchCtrl,
        decoration: InputDecoration(
          hintText: 'جستجو در تاریخ، ساعت، صورتجلسه...',
          hintStyle: PersianFonts.Shabnam.copyWith(fontSize: font_size_12, color: Colors.grey),
          prefixIcon: Icon(Icons.search, color: ShekayatTheme.primary),
          suffixIcon: _searchCtrl.text.isNotEmpty ? IconButton(icon: const Icon(Icons.clear), onPressed: () => _searchCtrl.clear()) : null,
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 12.h),
        ),
        style: PersianFonts.Shabnam.copyWith(fontSize: font_size_12),
      ),
    );
  }

  Widget _buildList() {
    final list = _filtered;
    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.gavel_outlined, size: 48.sp, color: Colors.grey.shade400),
            SizedBox(height: 8.h),
            Text('جلسه‌ای ثبت نشده', style: PersianFonts.Shabnam.copyWith(color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.fromLTRB(12.w, 0, 12.w, 80.h),
      itemCount: list.length,
      itemBuilder: (_, i) => _buildCard(list[i], i),
    );
  }

  Widget _buildCard(dynamic item, int index) {
    final date = item['session_date']?.toString() ?? '-';
    final time = item['session_time']?.toString() ?? '';
    final desc = item['description']?.toString() ?? '';

    return Card(
      margin: EdgeInsets.only(bottom: 10.h),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _showDetail(item),
        child: Padding(
          padding: EdgeInsets.all(14.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                    decoration: BoxDecoration(color: Colors.purple.shade50, borderRadius: BorderRadius.circular(8)),
                    child: Text('#${index + 1}', style: PersianFonts.Shabnam.copyWith(fontSize: font_size_10, color: Colors.purple.shade700, fontWeight: FontWeight.bold)),
                  ),
                  SizedBox(width: 8.w),
                  Expanded(child: Text('جلسه کمیسیون', style: PersianFonts.Shabnam.copyWith(fontSize: font_size_14, fontWeight: FontWeight.bold))),
                  Icon(Icons.visibility, color: ShekayatTheme.primary, size: 20.sp),
                ],
              ),
              SizedBox(height: 8.h),
              Wrap(
                spacing: 8.w,
                children: [
                  _chip(Icons.calendar_today, 'تاریخ', date),
                  if (time.isNotEmpty) _chip(Icons.access_time, 'ساعت', time),
                ],
              ),
              if (desc.isNotEmpty) ...[
                SizedBox(height: 10.h),
                Container(
                  padding: EdgeInsets.all(10.w),
                  decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade200)),
                  child: Text(desc, maxLines: 3, overflow: TextOverflow.ellipsis, style: PersianFonts.Shabnam.copyWith(fontSize: font_size_12, height: 1.5)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(IconData icon, String label, String value) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12.sp, color: ShekayatTheme.primary),
          SizedBox(width: 4.w),
          Text('$label: $value', style: PersianFonts.Shabnam.copyWith(fontSize: font_size_10)),
        ],
      ),
    );
  }
}
