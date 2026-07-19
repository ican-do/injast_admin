import 'package:flutter/material.dart';
import 'package:injast_admin/features/shekayat/compat/screen_util_shim.dart';
import 'package:injast_admin/features/shekayat/compat/select.dart';
import 'package:injast_admin/features/shekayat/shekayat_api.dart';
import 'package:injast_admin/features/shekayat/shekayat_constants.dart';
import 'package:injast_admin/features/shekayat/compat/shekayat_basic.dart';
import 'package:injast_admin/features/shekayat/pages/shekayat_complainant_gallery_page.dart';
import 'package:injast_admin/features/shekayat/pages/shekayat_followup_form_sheet.dart';
import 'package:injast_admin/features/shekayat/pages/shekayat_widgets.dart';
import 'package:injast_admin/features/shekayat/compat/motion_toast_shim.dart';
import 'package:injast_admin/features/shekayat/compat/persian_fonts_shim.dart';

/// مدیریت پیگیری‌ها — مطابق طراحی بخش کارشناسی
class ShekayatFollowupPage extends StatefulWidget {
  final String codeShekayat;
  final String codeCo;
  final dynamic complaint;

  const ShekayatFollowupPage({
    Key? key,
    required this.codeShekayat,
    required this.codeCo,
    this.complaint,
  }) : super(key: key);

  @override
  State<ShekayatFollowupPage> createState() => _ShekayatFollowupPageState();
}

class _ShekayatFollowupPageState extends State<ShekayatFollowupPage> {
  final _searchCtrl = TextEditingController();
  List<dynamic> _items = [];
  List<dynamic> _unionUsers = [];
  bool _loading = true;
  bool _showStaff = false;

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
      _items = await ShekayatApi.getFollowups(widget.codeShekayat);
      await select_person_co_val(widget.codeCo);
      _unionUsers = List.from(list_user_select);
    } catch (_) {
      _items = [];
      _unionUsers = [];
    }
    if (mounted) setState(() => _loading = false);
  }

  List<dynamic> get _filtered {
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) return _items;
    return _items.where((r) {
      final m = r as Map;
      final fields = [
        m['user_name'], m['followup_date'], m['description'], m['id_user'],
      ];
      return fields.any((f) => (f?.toString().toLowerCase() ?? '').contains(q));
    }).toList();
  }

  Future<void> _openNewForm() async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ShekayatFollowupFormSheet(
        codeShekayat: widget.codeShekayat,
        codeCo: widget.codeCo,
      ),
    );
    if (saved == true) _load();
  }

  void _showDetail(dynamic item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          margin: EdgeInsets.only(top: 80.h),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
          ),
          padding: EdgeInsets.all(20.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('جزئیات پیگیری', style: PersianFonts.Shabnam.copyWith(fontSize: font_size_16, fontWeight: FontWeight.bold, color: ShekayatTheme.primaryDark)),
              SizedBox(height: 12.h),
              _detailRow('تاریخ', item['followup_date']?.toString() ?? '-'),
              _detailRow('مسئول پیگیری', item['user_name']?.toString() ?? '-'),
              SizedBox(height: 8.h),
              Text('شرح پیگیری', style: PersianFonts.Shabnam.copyWith(fontSize: font_size_12, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
              SizedBox(height: 6.h),
              Container(
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Text(
                  item['description']?.toString() ?? '',
                  style: PersianFonts.Shabnam.copyWith(fontSize: font_size_14, height: 1.6),
                ),
              ),
              SizedBox(height: 16.h),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (d) => AlertDialog(
                      title: Text('حذف پیگیری', style: PersianFonts.Shabnam),
                      content: Text('آیا از حذف این پیگیری اطمینان دارید؟', style: PersianFonts.Shabnam),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('انصراف')),
                        TextButton(onPressed: () => Navigator.pop(d, true), child: Text('حذف', style: TextStyle(color: Colors.red))),
                      ],
                    ),
                  );
                  if (ok == true) {
                    await ShekayatApi.deleteFollowup(int.parse(item['id'].toString()));
                    _load();
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red, padding: EdgeInsets.symmetric(vertical: 12.h)),
                child: Text('حذف پیگیری', style: PersianFonts.Shabnam.copyWith(color: Colors.white)),
              ),
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text('بستن', style: PersianFonts.Shabnam)),
            ],
          ),
        ),
      ),
    );
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
          title: 'مدیریت پیگیری‌ها',
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
          label: Text('پیگیری جدید', style: PersianFonts.Shabnam.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
        body: _loading
            ? Center(child: CircularProgressIndicator(color: ShekayatTheme.primary))
            : Column(
                children: [
                  _buildSearch(),
                  _buildStaffSection(),
                  Expanded(child: _buildList()),
                ],
              ),
      ),
    );
  }

  Widget _buildSearch() {
    return Container(
      margin: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: TextField(
        controller: _searchCtrl,
        decoration: InputDecoration(
          hintText: 'جستجو در تاریخ، مسئول، شرح پیگیری...',
          hintStyle: PersianFonts.Shabnam.copyWith(fontSize: font_size_10, color: Colors.grey),
          prefixIcon: Icon(Icons.search, color: ShekayatTheme.primary),
          suffixIcon: _searchCtrl.text.isNotEmpty
              ? IconButton(icon: const Icon(Icons.clear), onPressed: () => _searchCtrl.clear())
              : null,
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 12.h),
        ),
        style: PersianFonts.Shabnam.copyWith(fontSize: font_size_12),
      ),
    );
  }

  Widget _buildStaffSection() {
    return Container(
      margin: EdgeInsets.fromLTRB(12.w, 0, 12.w, 8.h),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: _showStaff,
          onExpansionChanged: (v) => setState(() => _showStaff = v),
          leading: Icon(Icons.people_outline, color: ShekayatTheme.primary),
          title: Text(
            'اعضای اتحادیه (${_unionUsers.length})',
            style: PersianFonts.Shabnam.copyWith(fontSize: font_size_12, fontWeight: FontWeight.bold),
          ),
          children: [
            if (_unionUsers.isEmpty)
              Padding(
                padding: EdgeInsets.all(12.w),
                child: Text('عضوی یافت نشد', style: PersianFonts.Shabnam.copyWith(fontSize: font_size_10, color: Colors.grey)),
              )
            else
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: 220.h),
                child: ListView.builder(
                  padding: EdgeInsets.only(bottom: 8.h),
                  itemCount: _unionUsers.length > 20 ? 20 : _unionUsers.length,
                  itemBuilder: (_, i) {
                    final u = _unionUsers[i];
                    final name = '${u['name_user'] ?? ''} ${u['family_user'] ?? ''}'.trim();
                    return ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        backgroundColor: ShekayatTheme.primary.withOpacity(0.15),
                        child: Icon(Icons.person, color: ShekayatTheme.primary, size: 18.sp),
                      ),
                      title: Text(name, style: PersianFonts.Shabnam.copyWith(fontSize: font_size_12)),
                      subtitle: Text(u['mob1_user']?.toString() ?? '', style: PersianFonts.Shabnam.copyWith(fontSize: font_size_10)),
                    );
                  },
                ),
              ),
          ],
        ),
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
            Icon(Icons.history_edu_outlined, size: 48.sp, color: Colors.grey.shade400),
            SizedBox(height: 8.h),
            Text('پیگیری ثبت نشده', style: PersianFonts.Shabnam.copyWith(color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.fromLTRB(12.w, 4.h, 12.w, 80.h),
      itemCount: list.length,
      itemBuilder: (_, i) => _buildCard(list[i], i),
    );
  }

  Widget _buildCard(dynamic item, int index) {
    final desc = item['description']?.toString() ?? '';
    final user = item['user_name']?.toString() ?? '-';
    final date = item['followup_date']?.toString() ?? '-';

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
                    decoration: BoxDecoration(
                      color: Colors.indigo.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '#${index + 1}',
                      style: PersianFonts.Shabnam.copyWith(fontSize: font_size_10, color: Colors.indigo.shade700, fontWeight: FontWeight.bold),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(user, style: PersianFonts.Shabnam.copyWith(fontSize: font_size_14, fontWeight: FontWeight.bold)),
                  ),
                  Icon(Icons.visibility, color: ShekayatTheme.primary, size: 20.sp),
                ],
              ),
              SizedBox(height: 8.h),
              _chip(Icons.calendar_today, 'تاریخ پیگیری', date),
              SizedBox(height: 10.h),
              Container(
                padding: EdgeInsets.all(10.w),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Text(
                  desc,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: PersianFonts.Shabnam.copyWith(fontSize: font_size_12, height: 1.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(IconData icon, String label, String value) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12.sp, color: ShekayatTheme.primary),
          SizedBox(width: 4.w),
          Text('$label: $value', style: PersianFonts.Shabnam.copyWith(fontSize: font_size_8)),
        ],
      ),
    );
  }
}
