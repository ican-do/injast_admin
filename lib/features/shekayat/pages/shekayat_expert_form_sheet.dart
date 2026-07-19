import 'package:flutter/material.dart';
import 'package:injast_admin/features/shekayat/compat/screen_util_shim.dart';
import 'package:injast_admin/features/shekayat/compat/class_controler.dart';
import 'package:injast_admin/features/shekayat/shekayat_api.dart';
import 'package:injast_admin/features/shekayat/shekayat_constants.dart';
import 'package:injast_admin/features/shekayat/compat/shekayat_basic.dart';
import 'package:injast_admin/features/shekayat/compat/permissions.dart';
import 'package:injast_admin/features/shekayat/pages/shekayat_docs_page.dart';
import 'package:injast_admin/features/shekayat/pages/shekayat_widgets.dart';
import 'package:injast_admin/features/shekayat/compat/motion_toast_shim.dart';
import 'package:injast_admin/features/shekayat/compat/persian_fonts_shim.dart';

/// فرم ثبت نظریه کارشناسی
/// برای کارشناس: فقط نظریه، برآورد خسارت، تاریخ کارشناسی و بارگذاری مدارک
class ShekayatExpertFormSheet extends StatefulWidget {
  final String codeShekayat;
  final String codeCo;
  final List<dynamic> profiles;
  final dynamic preselectedProfile;
  final VoidCallback onSaved;
  final bool expertSelfMode;
  final dynamic existingExpertRecord;

  const ShekayatExpertFormSheet({
    Key? key,
    required this.codeShekayat,
    required this.codeCo,
    required this.profiles,
    this.preselectedProfile,
    required this.onSaved,
    this.expertSelfMode = false,
    this.existingExpertRecord,
  }) : super(key: key);

  @override
  State<ShekayatExpertFormSheet> createState() => _ShekayatExpertFormSheetState();
}

class _ShekayatExpertFormSheetState extends State<ShekayatExpertFormSheet> {
  final _opinionCtrl = TextEditingController();
  final _damageCtrl = TextEditingController();
  final _dateCtrl = TextEditingController();
  String? _selectedProfileId;
  bool _loading = false;
  late List<dynamic> _profiles;

  bool get _selfMode => widget.expertSelfMode || Permissions.isComplaintExpertRole();

  @override
  void initState() {
    super.initState();
    _profiles = List.from(widget.profiles);
    _dateCtrl.text = convert_date_persian(DateTime.now());
    if (widget.preselectedProfile != null) {
      _selectedProfileId = widget.preselectedProfile['id']?.toString();
    } else if (_selfMode) {
      final myId = Permissions.currentUserId;
      for (final p in _profiles) {
        if (p['id_user']?.toString() == myId) {
          _selectedProfileId = p['id']?.toString();
          break;
        }
      }
    }
    final existing = widget.existingExpertRecord;
    if (existing != null) {
      final existingOpinion = existing['opinion_text']?.toString() ?? '';
      final existingDamage = existing['damage_amount']?.toString() ?? '';
      final existingDate = existing['date_expertise']?.toString() ?? existing['opinion_date']?.toString() ?? '';
      if (existingOpinion.isNotEmpty) _opinionCtrl.text = existingOpinion;
      if (existingDamage.isNotEmpty) _damageCtrl.text = existingDamage;
      if (existingDate.isNotEmpty) _dateCtrl.text = existingDate;
    }
  }

  @override
  void dispose() {
    _opinionCtrl.dispose();
    _damageCtrl.dispose();
    _dateCtrl.dispose();
    super.dispose();
  }

  dynamic get _selectedProfile {
    if (_selectedProfileId == null) return widget.preselectedProfile;
    for (final p in _profiles) {
      if (p['id']?.toString() == _selectedProfileId) return p;
    }
    return widget.preselectedProfile;
  }

  String _profileLabel(dynamic p) {
    final name = '${p['name_expert'] ?? p['name_user'] ?? ''} ${p['family_expert'] ?? p['family_user'] ?? ''}'.trim();
    final count = p['expertise_count'] ?? 0;
    return count > 0 ? '$name ($count)' : name;
  }

  int? _resolveExpertId() {
    if (_selfMode) {
      final id = Permissions.currentUserId;
      if (id.isEmpty) return null;
      return int.tryParse(id);
    }
    final profile = _selectedProfile;
    final idExpert = profile?['id_user'];
    if (idExpert == null) return null;
    return int.tryParse(idExpert.toString());
  }

  Future<void> _submit() async {
    final idExpert = _resolveExpertId();
    if (idExpert == null) {
      MotionToast.warning(
        title: const Text('توجه'),
        description: Text(_selfMode ? 'شناسه کارشناس یافت نشد' : 'کارشناس را انتخاب کنید'),
      ).show(context);
      return;
    }
    if (!_selfMode && _selectedProfile == null) {
      MotionToast.warning(title: const Text('توجه'), description: const Text('کارشناس را انتخاب کنید')).show(context);
      return;
    }
    if (_opinionCtrl.text.trim().isEmpty) {
      MotionToast.warning(title: const Text('توجه'), description: const Text('نظریه کارشناس الزامی است')).show(context);
      return;
    }
    if (_dateCtrl.text.trim().isEmpty) {
      MotionToast.warning(title: const Text('توجه'), description: const Text('تاریخ کارشناسی الزامی است')).show(context);
      return;
    }

    setState(() => _loading = true);
    try {
      final expertiseDate = _dateCtrl.text.trim();
      dynamic expertRefId = widget.existingExpertRecord?['id'] ??
          widget.existingExpertRecord?['expert_ref_id'];

      if (expertRefId == null) {
        final experts = await ShekayatApi.getExperts(widget.codeShekayat);
        for (final e in experts) {
          if (e['id_expert']?.toString() == idExpert.toString()) {
            expertRefId = e['id'];
            break;
          }
        }
      }

      if (expertRefId == null) {
        final expertRes = await ShekayatApi.saveExpertRaw({
          'code_shekayat': widget.codeShekayat,
          'id_expert': idExpert,
          'date_delivery': expertiseDate,
          'date_expertise': expertiseDate,
          'date_receive': expertiseDate,
          'update_status': 'کارشناسی',
        });
        expertRefId = expertRes['data']?['id'];
      }

      await ShekayatApi.saveOpinion({
        'code_shekayat': widget.codeShekayat,
        'id_expert_ref': expertRefId,
        'id_expert': idExpert,
        'date_expertise': expertiseDate,
        'opinion_text': _opinionCtrl.text.trim(),
        'damage_amount': _damageCtrl.text.trim(),
      });

      if (!mounted) return;
      MotionToast.success(title: const Text('ثبت شد'), description: const Text('نظریه کارشناسی ثبت شد')).show(context);
      widget.onSaved();
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) MotionToast.error(title: const Text('خطا'), description: Text('$e')).show(context);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = _selectedProfile;
    final maxHeight = MediaQuery.of(context).size.height * 0.92;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          constraints: BoxConstraints(maxHeight: maxHeight),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20.r))),
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 24.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(child: Container(width: 40.w, height: 4.h, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(4)))),
                SizedBox(height: 12.h),
                Text('ثبت نظریه کارشناسی', style: PersianFonts.Shabnam.copyWith(fontSize: font_size_18, fontWeight: FontWeight.bold, color: ShekayatTheme.primaryDark)),
                SizedBox(height: 8.h),
                if (_selfMode) ...[
                  Container(
                    padding: EdgeInsets.all(12.w),
                    decoration: BoxDecoration(color: ShekayatTheme.primary.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
                    child: Text(
                      'ثبت نظریه، برآورد خسارت و تاریخ کارشناسی برای پرونده ارجاع‌شده',
                      style: PersianFonts.Shabnam.copyWith(fontSize: font_size_10, color: Colors.grey.shade700),
                    ),
                  ),
                ] else ...[
                  Text(
                    'مسئول شکایت می‌تواند به جای کارشناس (مثلاً کارشناسان مسن) نظریه را ثبت کند.',
                    style: PersianFonts.Shabnam.copyWith(fontSize: font_size_10, color: Colors.grey.shade600),
                  ),
                  SizedBox(height: 12.h),
                  if (profile == null)
                    DropdownButtonFormField<String>(
                      decoration: InputDecoration(labelText: 'انتخاب کارشناس', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
                      value: _profiles.any((p) => p['id']?.toString() == _selectedProfileId) ? _selectedProfileId : null,
                      items: _profiles.map((p) => DropdownMenuItem(value: p['id']?.toString(), child: Text(_profileLabel(p), style: PersianFonts.Shabnam.copyWith(fontSize: font_size_12)))).toList(),
                      onChanged: (v) => setState(() => _selectedProfileId = v),
                    )
                  else
                    Container(
                      padding: EdgeInsets.all(12.w),
                      decoration: BoxDecoration(color: ShekayatTheme.primary.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
                      child: Text('کارشناس: ${_profileLabel(profile)}', style: PersianFonts.Shabnam.copyWith(fontSize: font_size_12, fontWeight: FontWeight.bold)),
                    ),
                ],
                SizedBox(height: 12.h),
                Container(
                  padding: EdgeInsets.all(12.w),
                  decoration: BoxDecoration(
                    color: ShekayatTheme.primary.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: ShekayatTheme.primary.withOpacity(0.2)),
                  ),
                  child: TextField(
                    controller: _opinionCtrl,
                    maxLines: 6,
                    decoration: const InputDecoration(
                      labelText: 'نظریه کارشناس *',
                      border: InputBorder.none,
                      alignLabelWithHint: true,
                    ),
                    style: PersianFonts.Shabnam.copyWith(fontSize: font_size_14),
                  ),
                ),
                SizedBox(height: 8.h),
                shekayatField('برآورد خسارت احتمالی (ریال)', '', _damageCtrl),
                SizedBox(height: 4.h),
                ShekayatDateField(label: 'تاریخ کارشناسی *', controller: _dateCtrl),
                SizedBox(height: 8.h),
                Text(
                  'مدارک و مستندات کارشناس',
                  style: PersianFonts.Shabnam.copyWith(fontSize: font_size_12, fontWeight: FontWeight.bold, color: ShekayatTheme.primaryDark),
                ),
                SizedBox(height: 6.h),
                SizedBox(
                  height: 320.h,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ShekayatDocsPage(
                        codeShekayat: widget.codeShekayat,
                        sourceType: 'expert',
                        embedded: true,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 8.h),
                ShekayatBottomButtons(
                  submitLabel: 'ثبت نظریه',
                  onSubmit: _submit,
                  onCancel: () => Navigator.pop(context),
                  loading: _loading,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
