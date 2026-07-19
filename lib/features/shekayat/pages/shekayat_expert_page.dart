import 'package:flutter/material.dart';
import 'package:injast_admin/features/shekayat/compat/screen_util_shim.dart';
import 'package:injast_admin/features/shekayat/compat/select.dart';
import 'package:injast_admin/features/shekayat/shekayat_api.dart';
import 'package:injast_admin/features/shekayat/shekayat_constants.dart';
import 'package:injast_admin/features/shekayat/compat/shekayat_basic.dart';
import 'package:injast_admin/features/shekayat/compat/permissions.dart';
import 'package:injast_admin/features/shekayat/pages/shekayat_complainant_gallery_page.dart';
import 'package:injast_admin/features/shekayat/pages/shekayat_expert_form_sheet.dart';
import 'package:injast_admin/features/shekayat/pages/shekayat_opinion_view_page.dart';
import 'package:injast_admin/features/shekayat/pages/shekayat_widgets.dart';
import 'package:injast_admin/features/shekayat/compat/motion_toast_shim.dart';
import 'package:injast_admin/features/shekayat/compat/persian_fonts_shim.dart';

/// مدیریت کارشناسی — برای مسئول: ارجاع و مدیریت؛ برای کارشناس: فقط ثبت نظریه خود
class ShekayatExpertPage extends StatefulWidget {
  final String codeShekayat;
  final String codeCo;
  final dynamic complaint;

  const ShekayatExpertPage({Key? key, required this.codeShekayat, required this.codeCo, required this.complaint}) : super(key: key);

  @override
  State<ShekayatExpertPage> createState() => _ShekayatExpertPageState();
}

class _ShekayatExpertPageState extends State<ShekayatExpertPage> {
  final _searchCtrl = TextEditingController();
  List<dynamic> _records = [];
  List<dynamic> _profiles = [];
  bool _loading = true;
  bool _showProfiles = false;

  bool get _isManager => Permissions.canShekManageExpertise();
  bool get _isExpert => Permissions.isComplaintExpertRole();

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
      final results = await Future.wait([
        ShekayatApi.getExpertRecords(widget.codeShekayat),
        ShekayatApi.getExpertProfiles(widget.codeCo),
      ]);
      _records = results[0] as List<dynamic>;
      _profiles = results[1] as List<dynamic>;
    } catch (_) {
      _records = [];
      _profiles = [];
    }
    if (mounted) setState(() => _loading = false);
  }

  List<dynamic> get _filtered {
    var list = _records;
    if (_isExpert) {
      final myId = Permissions.currentUserId;
      list = list.where((r) => r['id_expert']?.toString() == myId).toList();
    }
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) return list;
    return list.where((r) {
      final m = r as Map;
      final fields = [
        m['name_user'], m['family_user'], m['profile_name'], m['profile_family'],
        m['mob1_user'], m['profile_mob'], m['codemeli_user'], m['code_meli_user'], m['profile_meli'],
        m['specialty'], m['degree'], m['opinion_text'], m['damage_amount'],
        m['date_delivery'], m['date_expertise'], m['date_receive'], m['opinion_date'],
      ];
      return fields.any((f) => (f?.toString().toLowerCase() ?? '').contains(q));
    }).toList();
  }

  dynamic get _myRecord {
    final myId = Permissions.currentUserId;
    for (final r in _records) {
      if (r['id_expert']?.toString() == myId) return r;
    }
    return null;
  }

  String _expertName(dynamic r) {
    final user = '${r['name_user'] ?? ''} ${r['family_user'] ?? ''}'.trim();
    if (user.isNotEmpty) return user;
    return '${r['profile_name'] ?? ''} ${r['profile_family'] ?? ''}'.trim();
  }

  Future<void> _referToExpert(dynamic profile) async {
    final name = '${profile['name_expert'] ?? profile['name_user'] ?? ''} ${profile['family_expert'] ?? profile['family_user'] ?? ''}'.trim();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('ارجاع به کارشناس', style: PersianFonts.Shabnam),
        content: Text('آیا از ارجاع پرونده به $name مطمئن هستید؟', style: PersianFonts.Shabnam),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('خیر', style: PersianFonts.Shabnam)),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: ShekayatTheme.primary),
            child: Text('بله', style: PersianFonts.Shabnam.copyWith(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final idExpert = profile['id_user'];
    if (idExpert == null) {
      MotionToast.warning(title: const Text('توجه'), description: const Text('کارشناس به کاربر سیستم متصل نیست')).show(context);
      return;
    }
    try {
      await ShekayatApi.saveExpertRaw({
        'code_shekayat': widget.codeShekayat,
        'id_expert': int.parse(idExpert.toString()),
        'update_status': 'ارجاع به کارشناس',
      });
      if (mounted) {
        MotionToast.success(title: const Text('ارجاع شد'), description: Text('پرونده به $name ارجاع شد')).show(context);
        _load();
      }
    } catch (e) {
      if (mounted) MotionToast.error(title: const Text('خطا'), description: Text('$e')).show(context);
    }
  }

  Future<void> _openOpinionForm({dynamic profile, bool selfMode = false}) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ShekayatExpertFormSheet(
        codeShekayat: widget.codeShekayat,
        codeCo: widget.codeCo,
        profiles: _profiles,
        preselectedProfile: profile,
        expertSelfMode: selfMode || _isExpert,
        existingExpertRecord: selfMode || _isExpert ? _myRecord : null,
        onSaved: _load,
      ),
    );
    if (saved == true) _load();
  }

  Future<void> _editProfile(dynamic profile) async {
    final specialtyCtrl = TextEditingController(text: profile['specialty']?.toString() ?? '');
    final positionCtrl = TextEditingController(text: profile['position_title']?.toString() ?? profile['degree']?.toString() ?? '');
    final descCtrl = TextEditingController(text: profile['description']?.toString() ?? '');

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text('ویرایش پروفایل کارشناس', style: PersianFonts.Shabnam),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: positionCtrl, decoration: const InputDecoration(labelText: 'سمت کارشناس'), style: PersianFonts.Shabnam),
              TextField(controller: specialtyCtrl, decoration: const InputDecoration(labelText: 'تخصص'), style: PersianFonts.Shabnam),
              TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'توضیحات'), style: PersianFonts.Shabnam, maxLines: 2),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('انصراف', style: PersianFonts.Shabnam)),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: ShekayatTheme.primary),
              child: Text('ذخیره', style: PersianFonts.Shabnam.copyWith(color: Colors.white)),
            ),
          ],
        ),
      ),
    );

    if (ok == true) {
      await ShekayatApi.saveExpertProfile({
        'id': profile['id'],
        'code_co': widget.codeCo,
        'id_user': profile['id_user'],
        'name_expert': profile['name_expert'] ?? profile['name_user'],
        'family_expert': profile['family_expert'] ?? profile['family_user'],
        'mob_expert': profile['mob_expert'] ?? profile['mob1_user'],
        'code_meli_expert': profile['code_meli_expert'] ?? profile['codemeli_user'] ?? profile['code_meli_user'],
        'specialty': specialtyCtrl.text.trim(),
        'position_title': positionCtrl.text.trim(),
        'degree': positionCtrl.text.trim(),
        'description': descCtrl.text.trim(),
      });
      specialtyCtrl.dispose();
      positionCtrl.dispose();
      descCtrl.dispose();
      _load();
    } else {
      specialtyCtrl.dispose();
      positionCtrl.dispose();
      descCtrl.dispose();
    }
  }

  Future<void> _addProfileFromUnion() async {
    await select_person_co_val(widget.codeCo);
    final users = List.from(list_user_select);
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text('انتخاب عضو اتحادیه', style: PersianFonts.Shabnam),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: users.length,
              itemBuilder: (_, i) {
                final u = users[i];
                final name = '${u['name_user'] ?? ''} ${u['family_user'] ?? ''}'.trim();
                return ListTile(
                  title: Text(name, style: PersianFonts.Shabnam.copyWith(fontSize: font_size_12)),
                  subtitle: Text(u['mob1_user']?.toString() ?? '', style: PersianFonts.Shabnam.copyWith(fontSize: font_size_10)),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await ShekayatApi.saveExpertProfile({
                      'code_co': widget.codeCo,
                      'id_user': u['id_user'],
                      'name_expert': u['name_user'],
                      'family_expert': u['family_user'],
                      'mob_expert': u['mob1_user'],
                      'code_meli_expert': u['codemeli_user'] ?? u['code_meli_user'],
                    });
                    _load();
                  },
                );
              },
            ),
          ),
        ),
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
          title: _isExpert ? 'کارشناسی' : 'مدیریت کارشناسی',
          actions: [
            IconButton(
              icon: const Icon(Icons.collections),
              tooltip: 'مدارک شاکی',
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(
                  builder: (_) => ShekayatComplainantGalleryPage(
                    codeShekayat: widget.codeShekayat,
                    complaintTitle: widget.complaint['lbl_shekayat']?.toString(),
                  ),
                ));
              },
            ),
            IconButton(icon: const Icon(Icons.refresh), onPressed: _loading ? null : _load),
          ],
        ),
        floatingActionButton: (_isExpert || _isManager)
            ? FloatingActionButton.extended(
                onPressed: () => _openOpinionForm(selfMode: _isExpert),
                backgroundColor: ShekayatTheme.primary,
                icon: const Icon(Icons.edit_note, color: Colors.white),
                label: Text(
                  _isExpert ? 'ثبت نظریه کارشناسی' : 'ثبت نظریه',
                  style: PersianFonts.Shabnam.copyWith(color: Colors.white, fontSize: font_size_12),
                ),
              )
            : null,
        body: _loading
            ? Center(child: CircularProgressIndicator(color: ShekayatTheme.primary))
            : Column(
                children: [
                  if (_isManager) ...[
                    _buildSearch(),
                    _buildProfilesSection(),
                  ] else if (_isExpert)
                    _buildExpertHint(),
                  Expanded(child: _buildRecordsList()),
                ],
              ),
      ),
    );
  }

  Widget _buildExpertHint() {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.fromLTRB(12.w, 12.h, 12.w, 4.h),
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: ShekayatTheme.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ShekayatTheme.primary.withOpacity(0.2)),
      ),
      child: Text(
        'فقط ثبت نظریه کارشناس، برآورد خسارت و تاریخ کارشناسی — مدارک را نیز می‌توانید در همان فرم بارگذاری کنید.',
        style: PersianFonts.Shabnam.copyWith(fontSize: font_size_10, color: Colors.grey.shade800, height: 1.4),
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
          hintText: 'جستجو در نام، موبایل، تخصص، نظریه، تاریخ، خسارت...',
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

  Widget _buildProfilesSection() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 12.w),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: _showProfiles,
          onExpansionChanged: (v) => setState(() => _showProfiles = v),
          leading: Icon(Icons.badge_outlined, color: ShekayatTheme.primary),
          title: Text('پروفایل کارشناسان اتحادیه (${_profiles.length})', style: PersianFonts.Shabnam.copyWith(fontSize: font_size_12, fontWeight: FontWeight.bold)),
          trailing: IconButton(
            icon: Icon(Icons.person_add, color: ShekayatTheme.accentGreen),
            onPressed: _addProfileFromUnion,
            tooltip: 'افزودن کارشناس',
          ),
          children: [
            if (_profiles.isEmpty)
              Padding(padding: EdgeInsets.all(12.w), child: Text('کارشناسی ثبت نشده — از دکمه + استفاده کنید', style: PersianFonts.Shabnam.copyWith(fontSize: font_size_10, color: Colors.grey)))
            else
              ..._profiles.map((p) {
                final name = '${p['name_expert'] ?? p['name_user'] ?? ''} ${p['family_expert'] ?? p['family_user'] ?? ''}'.trim();
                final count = p['expertise_count'] ?? 0;
                final position = p['position_title']?.toString() ?? '';
                final specialty = p['specialty']?.toString() ?? '';
                return ListTile(
                  dense: true,
                  leading: CircleAvatar(backgroundColor: ShekayatTheme.primary.withOpacity(0.15), child: Icon(Icons.person, color: ShekayatTheme.primary, size: 18.sp)),
                  title: Text(count > 0 ? '$name ($count)' : name, style: PersianFonts.Shabnam.copyWith(fontSize: font_size_12, fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    [if (position.isNotEmpty) position, if (specialty.isNotEmpty) specialty].join(' | '),
                    style: PersianFonts.Shabnam.copyWith(fontSize: font_size_10),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.send, size: 18.sp, color: ShekayatTheme.primary),
                        tooltip: 'ارجاع پرونده',
                        onPressed: () => _referToExpert(p),
                      ),
                      IconButton(
                        icon: Icon(Icons.edit_note, size: 18.sp, color: ShekayatTheme.accentOrange),
                        tooltip: 'ثبت نظریه',
                        onPressed: () => _openOpinionForm(profile: p),
                      ),
                      IconButton(icon: Icon(Icons.edit, size: 18.sp, color: Colors.grey), onPressed: () => _editProfile(p)),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordsList() {
    final list = _filtered;
    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.engineering_outlined, size: 48.sp, color: Colors.grey.shade400),
            SizedBox(height: 8.h),
            Text(
              _isExpert ? 'هنوز نظریه‌ای ثبت نکرده‌اید' : 'کارشناسی ثبت نشده',
              style: PersianFonts.Shabnam.copyWith(color: Colors.grey),
            ),
            if (_isExpert) ...[
              SizedBox(height: 12.h),
              Text(
                'از دکمه «ثبت نظریه کارشناسی» استفاده کنید',
                style: PersianFonts.Shabnam.copyWith(fontSize: font_size_10, color: Colors.grey.shade600),
              ),
            ],
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.fromLTRB(12.w, 8.h, 12.w, 80.h),
      itemCount: list.length,
      itemBuilder: (_, i) => _buildRecordCard(list[i], i),
    );
  }

  Widget _buildRecordCard(dynamic r, int index) {
    final name = _expertName(r);
    final hasOpinion = (r['opinion_text']?.toString().trim().isNotEmpty ?? false);
    final opinionPreview = r['opinion_text']?.toString() ?? 'بدون نظریه';

    return Card(
      margin: EdgeInsets.only(bottom: 10.h),
      elevation: 2,
      color: ShekayatTheme.primary.withOpacity(0.03),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: ShekayatTheme.primary.withOpacity(0.15))),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: hasOpinion
            ? () => Navigator.push(context, MaterialPageRoute(builder: (_) => ShekayatOpinionViewPage(opinion: r)))
            : (_isExpert ? () => _openOpinionForm(selfMode: true) : null),
        child: Padding(
          padding: EdgeInsets.all(14.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                    decoration: BoxDecoration(color: ShekayatTheme.primary.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                    child: Text('#${index + 1}', style: PersianFonts.Shabnam.copyWith(fontSize: font_size_10, color: ShekayatTheme.primary, fontWeight: FontWeight.bold)),
                  ),
                  SizedBox(width: 8.w),
                  Expanded(child: Text(name, style: PersianFonts.Shabnam.copyWith(fontSize: font_size_14, fontWeight: FontWeight.bold))),
                  if (hasOpinion) Icon(Icons.visibility, color: ShekayatTheme.primary, size: 20.sp),
                ],
              ),
              if ((r['specialty']?.toString() ?? '').isNotEmpty) ...[
                SizedBox(height: 6.h),
                Text('تخصص: ${r['specialty']}', style: PersianFonts.Shabnam.copyWith(fontSize: font_size_10, color: Colors.grey.shade700)),
              ],
              SizedBox(height: 8.h),
              Wrap(
                spacing: 8.w,
                runSpacing: 4.h,
                children: [
                  _chip(Icons.outbox, 'تحویل', r['date_delivery']?.toString() ?? '-'),
                  _chip(Icons.calendar_today, 'کارشناسی', r['date_expertise']?.toString() ?? r['opinion_date']?.toString() ?? '-'),
                  _chip(Icons.inbox, 'دریافت', r['date_receive']?.toString() ?? '-'),
                ],
              ),
              SizedBox(height: 10.h),
              Container(
                padding: EdgeInsets.all(10.w),
                decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade200)),
                child: Text(
                  opinionPreview,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: PersianFonts.Shabnam.copyWith(fontSize: font_size_12, height: 1.5),
                ),
              ),
              if ((r['damage_amount']?.toString() ?? '').isNotEmpty) ...[
                SizedBox(height: 6.h),
                Text('خسارت: ${r['damage_amount']}', style: PersianFonts.Shabnam.copyWith(fontSize: font_size_10, color: ShekayatTheme.accentRed, fontWeight: FontWeight.w600)),
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
          Text('$label: $value', style: PersianFonts.Shabnam.copyWith(fontSize: font_size_8)),
        ],
      ),
    );
  }
}
