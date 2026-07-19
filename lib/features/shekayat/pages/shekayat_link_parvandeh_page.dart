import 'package:flutter/material.dart';
import 'package:injast_admin/features/shekayat/compat/screen_util_shim.dart';
import 'package:injast_admin/features/shekayat/compat/class_controler.dart';
import 'package:injast_admin/features/shekayat/compat/select.dart';
import 'package:injast_admin/features/shekayat/shekayat_api.dart';
import 'package:injast_admin/features/shekayat/shekayat_constants.dart';
import 'package:injast_admin/features/shekayat/compat/shekayat_basic.dart';
import 'package:injast_admin/features/shekayat/pages/shekayat_widgets.dart';
import 'package:injast_admin/features/shekayat/compat/motion_toast_shim.dart';
import 'package:injast_admin/features/shekayat/compat/persian_fonts_shim.dart';

/// اتصال شکایت به واحد صنفی موجود در اتحادیه
class ShekayatLinkParvandehPage extends StatefulWidget {
  final String codeShekayat;
  final String codeCo;
  final String? currentParvandehId;
  final String? complaintTitle;

  const ShekayatLinkParvandehPage({
    Key? key,
    required this.codeShekayat,
    required this.codeCo,
    this.currentParvandehId,
    this.complaintTitle,
  }) : super(key: key);

  @override
  State<ShekayatLinkParvandehPage> createState() => _ShekayatLinkParvandehPageState();
}

class _ShekayatLinkParvandehPageState extends State<ShekayatLinkParvandehPage> {
  final _searchCtrl = TextEditingController();
  List<dynamic> _all = [];
  List<dynamic> _filtered = [];
  bool _loading = true;
  bool _saving = false;
  String? _selectedId;

  static const _searchFields = [
    'name_store',
    'family_admin',
    'name_admin',
    'mob_admin',
    'shenase_store',
    'num_parvande_store',
    'raste_store',
    'code_meli_admin',
  ];

  @override
  void initState() {
    super.initState();
    _selectedId = widget.currentParvandehId;
    if (_selectedId == '0') _selectedId = null;
    _load();
    _searchCtrl.addListener(_filter);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final prevCodeCo = code_co;
    code_co = widget.codeCo;
    try {
      await select_parvande_val('0');
      _all = List.from(list_parvande_basic);
      _filter();
    } catch (_) {
      _all = [];
      _filtered = [];
    } finally {
      code_co = prevCodeCo;
    }
    if (mounted) setState(() => _loading = false);
  }

  void _filter() {
    final q = _searchCtrl.text.trim();
    if (q.isEmpty) {
      _filtered = List.from(_all);
    } else {
      _filtered = filterListByFields(_all, _searchFields, q);
    }
    setState(() {});
  }

  Future<void> _link(String idParvandeh) async {
    setState(() => _saving = true);
    try {
      final ok = await ShekayatApi.linkParvandeh(widget.codeShekayat, idParvandeh);
      if (!mounted) return;
      if (ok) {
        MotionToast.success(title: const Text('ثبت شد'), description: const Text('شکایت به واحد صنفی متصل شد')).show(context);
        Navigator.pop(context, true);
      } else {
        MotionToast.error(title: const Text('خطا'), description: const Text('اتصال انجام نشد')).show(context);
      }
    } catch (e) {
      if (mounted) MotionToast.error(title: const Text('خطا'), description: Text('$e')).show(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _unlink() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('حذف اتصال', style: PersianFonts.Shabnam),
        content: Text('آیا اتصال این شکایت به واحد صنفی حذف شود؟', style: PersianFonts.Shabnam),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('انصراف')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حذف اتصال')),
        ],
      ),
    );
    if (ok == true) await _link('0');
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: ShekayatAppBar(
          title: 'اتصال به واحد صنفی',
          actions: [
            if (_selectedId != null && _selectedId != '0')
              TextButton(
                onPressed: _saving ? null : _unlink,
                child: Text('حذف اتصال', style: PersianFonts.Shabnam.copyWith(color: Colors.white, fontSize: font_size_12)),
              ),
          ],
        ),
        body: Column(
          children: [
            if (widget.complaintTitle != null)
              Container(
                width: double.infinity,
                margin: EdgeInsets.fromLTRB(12.w, 12.h, 12.w, 0),
                padding: EdgeInsets.all(10.w),
                decoration: BoxDecoration(color: ShekayatTheme.primary.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
                child: Text('شکایت: ${widget.complaintTitle}', style: PersianFonts.Shabnam.copyWith(fontSize: font_size_12)),
              ),
            Padding(
              padding: EdgeInsets.all(12.w),
              child: TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: 'جستجو: نام واحد، مالک، موبایل، شناسه، رسته...',
                  hintStyle: PersianFonts.Shabnam.copyWith(fontSize: font_size_12),
                  prefixIcon: Icon(Icons.search, color: ShekayatTheme.primary),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                style: PersianFonts.Shabnam.copyWith(fontSize: font_size_14),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12.w),
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '${_filtered.length} واحد صنفی — یک مورد را انتخاب کنید',
                  style: PersianFonts.Shabnam.copyWith(fontSize: font_size_10, color: Colors.grey.shade700),
                ),
              ),
            ),
            SizedBox(height: 8.h),
            Expanded(
              child: _loading
                  ? Center(child: CircularProgressIndicator(color: ShekayatTheme.primary))
                  : _filtered.isEmpty
                      ? Center(child: Text('واحدی یافت نشد', style: PersianFonts.Shabnam.copyWith(color: Colors.grey)))
                      : ListView.builder(
                          padding: EdgeInsets.symmetric(horizontal: 12.w),
                          itemCount: _filtered.length,
                          itemBuilder: (_, i) => _buildItem(_filtered[i]),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItem(dynamic p) {
    final id = p['id_parvandeh']?.toString() ?? '';
    final selected = _selectedId == id;
    final nameStore = p['name_store']?.toString() ?? '-';
    final owner = '${p['name_admin'] ?? ''} ${p['family_admin'] ?? ''}'.trim();
    final mob = p['mob_admin']?.toString() ?? '';
    final raste = p['raste_store']?.toString() ?? '';
    final shenase = p['shenase_store']?.toString() ?? '';

    return Card(
      margin: EdgeInsets.only(bottom: 8.h),
      color: selected ? ShekayatTheme.primary.withOpacity(0.1) : null,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: selected ? ShekayatTheme.primary : Colors.grey.shade300,
          child: Icon(selected ? Icons.check : Icons.store, color: Colors.white, size: 20.sp),
        ),
        title: Text(nameStore, style: PersianFonts.Shabnam.copyWith(fontSize: font_size_14, fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (owner.isNotEmpty) Text('مالک: $owner', style: PersianFonts.Shabnam.copyWith(fontSize: font_size_10)),
            if (mob.isNotEmpty) Text('موبایل: $mob', style: PersianFonts.Shabnam.copyWith(fontSize: font_size_10)),
            if (raste.isNotEmpty) Text('رسته: $raste', style: PersianFonts.Shabnam.copyWith(fontSize: font_size_10)),
            if (shenase.isNotEmpty) Text('شناسه: $shenase', style: PersianFonts.Shabnam.copyWith(fontSize: font_size_10)),
          ],
        ),
        onTap: _saving
            ? null
            : () {
                setState(() => _selectedId = id);
                _link(id);
              },
      ),
    );
  }
}
