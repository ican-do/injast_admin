import 'package:flutter/material.dart';
import 'package:injast_admin/features/shekayat/compat/screen_util_shim.dart';
import 'package:injast_admin/features/shekayat/shekayat_api.dart';
import 'package:injast_admin/features/shekayat/shekayat_constants.dart';
import 'package:injast_admin/features/shekayat/compat/shekayat_basic.dart';
import 'package:injast_admin/features/shekayat/pages/shekayat_widgets.dart';
import 'package:injast_admin/features/shekayat/compat/motion_toast_shim.dart';
import 'package:injast_admin/features/shekayat/compat/persian_fonts_shim.dart';

/// فرم ثبت زمان جلسه کمیسیون (بدون صورتجلسه — صورتجلسه بعداً ثبت می‌شود)
class ShekayatCommissionFormSheet extends StatefulWidget {
  final String codeShekayat;

  const ShekayatCommissionFormSheet({Key? key, required this.codeShekayat}) : super(key: key);

  @override
  State<ShekayatCommissionFormSheet> createState() => _ShekayatCommissionFormSheetState();
}

class _ShekayatCommissionFormSheetState extends State<ShekayatCommissionFormSheet> {
  final _dateCtrl = TextEditingController();
  final _timeCtrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _dateCtrl.dispose();
    _timeCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_dateCtrl.text.isEmpty) {
      MotionToast.warning(title: const Text('توجه'), description: const Text('تاریخ جلسه الزامی است')).show(context);
      return;
    }
    setState(() => _loading = true);
    try {
      await ShekayatApi.saveSession({
        'code_shekayat': widget.codeShekayat,
        'session_date': _dateCtrl.text,
        'session_time': _timeCtrl.text,
        'description': '',
        'update_status': 'جلسه کمیسیون',
      });
      if (!mounted) return;
      MotionToast.success(title: const Text('ثبت شد'), description: const Text('زمان جلسه کمیسیون ثبت شد')).show(context);
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) MotionToast.error(title: const Text('خطا'), description: Text('$e')).show(context);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _sendSmsPlaceholder() {
    MotionToast.info(
      title: const Text('پیامک'),
      description: const Text('در انتظار اتصال به سامانه پیامکی'),
    ).show(context);
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
                  'ثبت زمان جلسه کمیسیون',
                  style: PersianFonts.Shabnam.copyWith(fontSize: font_size_18, fontWeight: FontWeight.bold, color: ShekayatTheme.primaryDark),
                ),
                SizedBox(height: 8.h),
                Text(
                  'پس از برگزاری جلسه، صورتجلسه را از لیست جلسات ثبت کنید.',
                  style: PersianFonts.Shabnam.copyWith(fontSize: font_size_12, color: Colors.grey.shade600),
                ),
                SizedBox(height: 16.h),
                ShekayatFieldRow(
                  left: ShekayatDateField(label: 'تاریخ جلسه *', controller: _dateCtrl),
                  right: shekayatField('ساعت جلسه', 'مثال: ۱۰:۰۰', _timeCtrl),
                ),
                SizedBox(height: 8.h),
                OutlinedButton.icon(
                  onPressed: _sendSmsPlaceholder,
                  icon: const Icon(Icons.sms_outlined),
                  label: Text('ارسال SMS', style: PersianFonts.Shabnam),
                  style: OutlinedButton.styleFrom(foregroundColor: ShekayatTheme.primary, padding: EdgeInsets.symmetric(vertical: 12.h)),
                ),
                ShekayatBottomButtons(
                  submitLabel: 'ثبت جلسه',
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

/// فرم ثبت صورتجلسه پس از برگزاری جلسه
class ShekayatCommissionMinutesSheet extends StatefulWidget {
  final Map<String, dynamic> session;
  final String codeShekayat;

  const ShekayatCommissionMinutesSheet({
    Key? key,
    required this.session,
    required this.codeShekayat,
  }) : super(key: key);

  @override
  State<ShekayatCommissionMinutesSheet> createState() => _ShekayatCommissionMinutesSheetState();
}

class _ShekayatCommissionMinutesSheetState extends State<ShekayatCommissionMinutesSheet> {
  late final TextEditingController _descCtrl;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _descCtrl = TextEditingController(text: widget.session['description']?.toString() ?? '');
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _loading = true);
    try {
      await ShekayatApi.saveSession({
        'id': widget.session['id'],
        'code_shekayat': widget.codeShekayat,
        'session_date': widget.session['session_date'],
        'session_time': widget.session['session_time'],
        'description': _descCtrl.text.trim(),
      });
      if (!mounted) return;
      MotionToast.success(title: const Text('ثبت شد'), description: const Text('صورتجلسه ثبت شد')).show(context);
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
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20.r))),
          padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 24.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('ثبت صورتجلسه', style: PersianFonts.Shabnam.copyWith(fontSize: font_size_18, fontWeight: FontWeight.bold, color: ShekayatTheme.primaryDark)),
              SizedBox(height: 8.h),
              Text(
                'جلسه: ${widget.session['session_date']} — ساعت ${widget.session['session_time'] ?? '-'}',
                style: PersianFonts.Shabnam.copyWith(fontSize: font_size_12, color: Colors.grey.shade700),
              ),
              SizedBox(height: 12.h),
              TextField(
                controller: _descCtrl,
                maxLines: 8,
                decoration: InputDecoration(
                  labelText: 'صورتجلسه',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  alignLabelWithHint: true,
                ),
                style: PersianFonts.Shabnam.copyWith(fontSize: font_size_14),
              ),
              SizedBox(height: 12.h),
              ShekayatBottomButtons(submitLabel: 'ثبت صورتجلسه', onSubmit: _submit, onCancel: () => Navigator.pop(context), loading: _loading),
            ],
          ),
        ),
      ),
    );
  }
}
