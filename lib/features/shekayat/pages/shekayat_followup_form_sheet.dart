import 'package:flutter/material.dart';
import 'package:injast_admin/features/shekayat/compat/screen_util_shim.dart';
import 'package:injast_admin/features/shekayat/shekayat_api.dart';
import 'package:injast_admin/features/shekayat/shekayat_constants.dart';
import 'package:injast_admin/features/shekayat/compat/shekayat_basic.dart';
import 'package:injast_admin/features/shekayat/pages/shekayat_widgets.dart';
import 'package:injast_admin/features/shekayat/compat/motion_toast_shim.dart';
import 'package:injast_admin/features/shekayat/compat/persian_fonts_shim.dart';

/// فرم ثبت پیگیری جدید — مسئول پیگیری = کاربر فعلی
class ShekayatFollowupFormSheet extends StatefulWidget {
  final String codeShekayat;
  final String codeCo;

  const ShekayatFollowupFormSheet({
    Key? key,
    required this.codeShekayat,
    required this.codeCo,
  }) : super(key: key);

  @override
  State<ShekayatFollowupFormSheet> createState() => _ShekayatFollowupFormSheetState();
}

class _ShekayatFollowupFormSheetState extends State<ShekayatFollowupFormSheet> {
  final _dateCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  bool _loading = false;

  String get _currentUserName {
    if (list_user.isEmpty) return 'کاربر سیستم';
    return '${list_user.first['name_user'] ?? ''} ${list_user.first['family_user'] ?? ''}'.trim();
  }

  @override
  void dispose() {
    _dateCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_dateCtrl.text.isEmpty || _descCtrl.text.trim().isEmpty) {
      MotionToast.warning(title: const Text('توجه'), description: const Text('تاریخ و شرح پیگیری الزامی است')).show(context);
      return;
    }

    setState(() => _loading = true);
    try {
      await ShekayatApi.saveFollowup({
        'code_shekayat': widget.codeShekayat,
        'id_user': list_user.isNotEmpty ? list_user.first['id_user'] : null,
        'user_name': _currentUserName,
        'followup_date': _dateCtrl.text,
        'description': _descCtrl.text.trim(),
      });
      if (!mounted) return;
      MotionToast.success(title: const Text('ثبت شد'), description: const Text('پیگیری جدید ثبت شد')).show(context);
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) MotionToast.error(title: const Text('خطا'), description: Text('$e')).show(context);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
          ),
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 24.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 40.w,
                    height: 4.h,
                    decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(4)),
                  ),
                ),
                SizedBox(height: 12.h),
                Text(
                  'ثبت پیگیری جدید',
                  style: PersianFonts.Shabnam.copyWith(fontSize: font_size_18, fontWeight: FontWeight.bold, color: ShekayatTheme.primaryDark),
                ),
                SizedBox(height: 16.h),
                Container(
                  padding: EdgeInsets.all(12.w),
                  decoration: BoxDecoration(
                    color: ShekayatTheme.primary.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.person, color: ShekayatTheme.primary),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: Text(
                          'مسئول پیگیری: $_currentUserName',
                          style: PersianFonts.Shabnam.copyWith(fontSize: font_size_12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
                ShekayatDateField(label: 'تاریخ پیگیری *', controller: _dateCtrl),
                Padding(
                  padding: EdgeInsets.all(8.w),
                  child: TextField(
                    controller: _descCtrl,
                    maxLines: 6,
                    decoration: InputDecoration(
                      labelText: 'شرح پیگیری *',
                      floatingLabelBehavior: FloatingLabelBehavior.always,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      alignLabelWithHint: true,
                    ),
                    style: PersianFonts.Shabnam.copyWith(fontSize: font_size_14),
                  ),
                ),
                SizedBox(height: 8.h),
                ShekayatBottomButtons(
                  submitLabel: 'ثبت پیگیری',
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
