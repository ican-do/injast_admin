import 'package:flutter/material.dart';
import 'package:injast_admin/features/shekayat/compat/screen_util_shim.dart';
import 'package:injast_admin/features/shekayat/shekayat_api.dart';
import 'package:injast_admin/features/shekayat/shekayat_constants.dart';
import 'package:injast_admin/features/shekayat/compat/shekayat_basic.dart';
import 'package:injast_admin/features/shekayat/pages/shekayat_widgets.dart';
import 'package:injast_admin/widget/text_fild.dart';
import 'package:injast_admin/features/shekayat/compat/motion_toast_shim.dart';
import 'package:injast_admin/features/shekayat/compat/persian_fonts_shim.dart';
import 'package:injast_admin/features/shekayat/compat/shekayat_layout.dart';

/// ویرایش و نتیجه‌گیری شکایت
class ShekayatEditPage extends StatefulWidget {
  final dynamic complaint;
  final String codeCo;

  const ShekayatEditPage({Key? key, required this.complaint, required this.codeCo}) : super(key: key);

  @override
  State<ShekayatEditPage> createState() => _ShekayatEditPageState();
}

class _ShekayatEditPageState extends State<ShekayatEditPage> {
  late final TextEditingController _complaintNoCtrl;
  late String _status;
  late String _source;
  late String _result;
  final _descCtrl = TextEditingController();
  bool _loading = false;

  static const _closureResults = ['رضایت طرفین', 'توافق', 'عدم پیگیری شاکی', 'مختومه'];

  @override
  void initState() {
    super.initState();
    final c = widget.complaint;
    _complaintNoCtrl = TextEditingController(text: c['complaint_number']?.toString() ?? '');
    _status = c['status_shekayat']?.toString() ?? 'ثبت اولیه';
    _source = c['source_shekayat']?.toString() ?? 'اتحادیه';
    final existingResult = c['result_shekayat']?.toString().trim();
    _result = (existingResult != null && existingResult.isNotEmpty)
        ? existingResult
        : ShekayatConstants.results.first;
    _descCtrl.text = c['final_description']?.toString() ?? '';
  }

  @override
  void dispose() {
    _complaintNoCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  void _onResultChanged(String? v) {
    if (v == null) return;
    setState(() {
      _result = v;
      if (_closureResults.contains(v)) {
        _status = 'مختومه';
      }
    });
  }

  Future<void> _submit() async {
    setState(() => _loading = true);
    try {
      final code = widget.complaint['code_shekayat'].toString();
      final ok = await ShekayatApi.updateComplaint({
        'code_shekayat': code,
        'complaint_number': _complaintNoCtrl.text.trim(),
        'status_shekayat': _status,
        'source_shekayat': _source,
        'result_shekayat': _result,
        'final_description': _descCtrl.text.trim(),
      });

      if (!ok) throw Exception('ثبت ناموفق بود');

      if (!mounted) return;
      MotionToast.success(
        title: const Text('ثبت شد'),
        description: Text('وضعیت: $_status\nنتیجه رسیدگی: $_result'),
      ).show(context);
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) MotionToast.error(title: const Text('خطا'), description: Text('$e')).show(context);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.complaint['lbl_shekayat']?.toString() ?? '';
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        appBar: const ShekayatAppBar(title: 'ویرایش و نتیجه‌گیری'),
        body: ShekayatLayout.formScroll(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (title.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: ShekayatTheme.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(title, style: PersianFonts.Shabnam.copyWith(fontSize: font_size_14, fontWeight: FontWeight.w600)),
                ),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                child: Column(
                  children: [
                    ShekayatDropdown(label: 'وضعیت پرونده', value: _status, items: ShekayatConstants.statuses, onChanged: (v) => setState(() => _status = v ?? _status)),
                    ShekayatFieldRow(
                      left: ShekayatDropdown(label: 'مرجع شکایت', value: _source, items: ShekayatConstants.sources, onChanged: (v) => setState(() => _source = v ?? _source)),
                      right: shekayatField('شماره شکایت', 'شماره', _complaintNoCtrl),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: ShekayatTheme.accentGreen.withOpacity(0.4), width: 1.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('نتیجه رسیدگی', style: PersianFonts.Shabnam.copyWith(fontSize: font_size_14, fontWeight: FontWeight.bold, color: ShekayatTheme.primaryDark)),
                    const SizedBox(height: 6),
                    ShekayatDropdown(
                      label: 'نتیجه نهایی',
                      value: _result,
                      items: ShekayatConstants.results,
                      onChanged: _onResultChanged,
                    ),
                    if (_closureResults.contains(_result))
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          'با این نتیجه، وضعیت پرونده به «مختومه» تغییر می‌کند.',
                          style: PersianFonts.Shabnam.copyWith(fontSize: font_size_10, color: ShekayatTheme.accentGreen),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                child: TextFieldMultiLine(
                  labelText: 'توضیحات و گزارش نهایی',
                  hintText: 'شرح نتیجه‌گیری و اقدامات انجام‌شده',
                  controller: _descCtrl,
                ),
              ),
              const SizedBox(height: 12),
              ShekayatBottomButtons(
                submitLabel: 'ثبت نتیجه',
                onSubmit: _submit,
                loading: _loading,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
