import 'package:flutter/material.dart';
import 'package:injast_admin/features/shekayat/compat/screen_util_shim.dart';
import 'package:injast_admin/features/shekayat/compat/get_nav.dart';
import 'package:injast_admin/features/shekayat/compat/class_controler.dart';
import 'package:injast_admin/features/shekayat/shekayat_api.dart';
import 'package:injast_admin/features/shekayat/shekayat_constants.dart';
import 'package:injast_admin/features/shekayat/compat/shekayat_basic.dart';
import 'package:injast_admin/features/shekayat/pages/shekayat_docs_page.dart';
import 'package:injast_admin/features/shekayat/pages/shekayat_form_mapper.dart';
import 'package:injast_admin/features/shekayat/pages/shekayat_form_pdf.dart';
import 'package:injast_admin/features/shekayat/pages/shekayat_widgets.dart';
import 'package:injast_admin/features/shekayat/compat/motion_toast_shim.dart';
import 'package:injast_admin/features/shekayat/compat/persian_fonts_shim.dart';
import 'package:injast_admin/features/shekayat/compat/shekayat_layout.dart';
import 'package:printing/printing.dart';

/// فرم ثبت شکایت یکپارچه — مطابق ماکاپ
class ShekayatRegisterForm extends StatefulWidget {
  final String codeCo;
  final String? unionName;
  final Map<String, dynamic>? prefillStore;
  final Map<String, dynamic>? complaint;
  final String registerSource;
  final bool readOnly;

  const ShekayatRegisterForm({
    Key? key,
    required this.codeCo,
    this.unionName,
    this.prefillStore,
    this.complaint,
    this.registerSource = 'app',
    this.readOnly = false,
  }) : super(key: key);

  @override
  State<ShekayatRegisterForm> createState() => _ShekayatRegisterFormState();
}

class _ShekayatRegisterFormState extends State<ShekayatRegisterForm> {
  final _dateCtrl = TextEditingController();
  final _titleCtrl = TextEditingController();
  final _captionCtrl = TextEditingController();
  final _shakiNameCtrl = TextEditingController();
  final _shakiFamilyCtrl = TextEditingController();
  final _shakiPedarCtrl = TextEditingController();
  final _shakiMeliCtrl = TextEditingController();
  final _shakiMobCtrl = TextEditingController();
  final _shakiAddrCtrl = TextEditingController();
  final _motNameCtrl = TextEditingController();
  final _motFamilyCtrl = TextEditingController();
  final _motMeliCtrl = TextEditingController();
  final _motStoreCtrl = TextEditingController();
  final _motMobCtrl = TextEditingController();
  final _motAddrCtrl = TextEditingController();

  String _typeShekayat = '1';
  bool _loading = false;
  bool _pdfLoading = false;
  Map<String, dynamic>? _complaintData;
  String? _pendingCode;
  final List<Map<String, dynamic>> _pendingDocs = [];

  @override
  void initState() {
    super.initState();
    if (widget.readOnly && widget.complaint != null) {
      _complaintData = Map<String, dynamic>.from(widget.complaint!);
      _loadComplaintDetail();
    } else {
      _dateCtrl.text = convert_date_persian(DateTime.now());
      _prefillFromStore();
    }
  }

  Future<void> _loadComplaintDetail() async {
    setState(() => _loading = true);
    try {
      final code = _complaintData?['code_shekayat']?.toString();
      if (code != null && code.isNotEmpty) {
        final detail = await ShekayatApi.getDetail(code);
        if (detail != null) _complaintData = detail;
      }
      _prefillFromComplaint();
    } catch (_) {
      _prefillFromComplaint();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _prefillFromComplaint() {
    final c = _complaintData ?? widget.complaint!;
    _dateCtrl.text = c['date_shekayat']?.toString() ?? '';
    _titleCtrl.text = c['lbl_shekayat']?.toString() ?? '';
    _captionCtrl.text = c['caption']?.toString() ?? '';
    _typeShekayat = c['type_shekayat']?.toString() ?? '1';
    _shakiNameCtrl.text = c['name_shaki']?.toString() ?? '';
    _shakiFamilyCtrl.text = c['family_shaki']?.toString() ?? '';
    _shakiPedarCtrl.text = c['name_pedar_shaki']?.toString() ?? '';
    _shakiMeliCtrl.text = c['code_meli_shaki']?.toString() ?? '';
    _shakiMobCtrl.text = c['mob_shaki']?.toString() ?? '';
    _shakiAddrCtrl.text = c['address_shaki']?.toString() ?? '';

    final mot = ShekayatFormMapper.respondentFields(c);
    _motNameCtrl.text = mot['motName'] ?? '';
    _motFamilyCtrl.text = mot['motFamily'] ?? '';
    _motMeliCtrl.text = mot['motMeli'] ?? '';
    _motStoreCtrl.text = mot['motStore'] ?? '';
    _motMobCtrl.text = mot['motMob'] ?? '';
    _motAddrCtrl.text = mot['motAddr'] ?? '';
  }

  bool get _isLinked => _complaintData != null && ShekayatFormMapper.isLinked(_complaintData!);

  Future<void> _downloadPdf() async {
    final data = _complaintData ?? widget.complaint;
    if (data == null) return;
    setState(() => _pdfLoading = true);
    try {
      final bytes = await ShekayatFormPdf.generate(
        complaint: data,
        codeCo: widget.codeCo,
        unionName: widget.unionName,
      );
      final no = data['complaint_number']?.toString() ?? 'shekayat';
      await Printing.sharePdf(bytes: bytes, filename: 'shekayat_$no.pdf');
    } catch (e) {
      if (mounted) {
        MotionToast.error(title: const Text('خطا'), description: Text('خطا در ساخت PDF: $e')).show(context);
      }
    } finally {
      if (mounted) setState(() => _pdfLoading = false);
    }
  }

  void _prefillFromStore() {
    final s = widget.prefillStore;
    if (s == null) return;
    _motStoreCtrl.text = s['name_store']?.toString() ?? s['name_parvandeh']?.toString() ?? '';
    _motMobCtrl.text = s['mob_store']?.toString() ?? s['mob_admin']?.toString() ?? '';
    _motAddrCtrl.text = s['address_store']?.toString() ?? '';
    final owner = s['name_malek']?.toString() ?? s['name_malek_store']?.toString() ?? '';
    if (owner.isNotEmpty) {
      final parts = owner.split(' ');
      _motNameCtrl.text = parts.isNotEmpty ? parts.first : '';
      _motFamilyCtrl.text = parts.length > 1 ? parts.sublist(1).join(' ') : '';
    }
  }

  @override
  void dispose() {
    for (final c in [_dateCtrl, _titleCtrl, _captionCtrl, _shakiNameCtrl, _shakiFamilyCtrl,
        _shakiPedarCtrl, _shakiMeliCtrl, _shakiMobCtrl, _shakiAddrCtrl,
        _motNameCtrl, _motFamilyCtrl, _motMeliCtrl, _motStoreCtrl, _motMobCtrl, _motAddrCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  bool _validate() {
    final required = [_titleCtrl, _captionCtrl, _shakiNameCtrl, _shakiFamilyCtrl,
        _shakiPedarCtrl, _shakiMeliCtrl, _shakiMobCtrl, _shakiAddrCtrl,
        _motNameCtrl, _motFamilyCtrl, _motStoreCtrl, _motAddrCtrl];
    if (required.any((c) => c.text.trim().isEmpty)) {
      MotionToast.warning(
        title: const Text('خطا'),
        description: const Text('لطفاً تمام فیلدهای ضروری را تکمیل نمایید'),
      ).show(context);
      return false;
    }
    return true;
  }

  Future<void> _submit() async {
    if (!_validate()) return;
    setState(() => _loading = true);
    try {
      final code = create_new_code();
      final result = await ShekayatApi.createComplaint({
        'code_shekayat': code,
        'code_co': widget.codeCo,
        'date_shekayat': _dateCtrl.text,
        'lbl_shekayat': _titleCtrl.text.trim(),
        'caption': _captionCtrl.text.trim(),
        'type_shekayat': _typeShekayat,
        'source_shekayat': 'اتحادیه',
        'status_shekayat': 'ثبت اولیه',
        'register_source': widget.registerSource,
        'name_shaki': _shakiNameCtrl.text.trim(),
        'family_shaki': _shakiFamilyCtrl.text.trim(),
        'mob_shaki': _shakiMobCtrl.text.trim(),
        'name_pedar_shaki': _shakiPedarCtrl.text.trim(),
        'code_meli_shaki': _shakiMeliCtrl.text.trim(),
        'address_shaki': _shakiAddrCtrl.text.trim(),
        'name_store': _motStoreCtrl.text.trim(),
        'family_store': _motFamilyCtrl.text.trim(),
        'code_meli_store': _motMeliCtrl.text.trim(),
        'mob_store': _motMobCtrl.text.trim(),
        'tel_store': _motMobCtrl.text.trim(),
        'address_store': _motAddrCtrl.text.trim(),
        'name_malek_store': '${_motNameCtrl.text.trim()} ${_motFamilyCtrl.text.trim()}'.trim(),
        'id_store': widget.prefillStore?['id_parvandeh']?.toString() ?? '0',
      });

      final savedCode = result['data']?['code_shekayat']?.toString() ?? code;

      for (final doc in _pendingDocs) {
        await ShekayatApi.saveAttachment({
          'code_shekayat': savedCode,
          'source_type': 'complainant',
          'title': doc['title'],
          'file_path': doc['file_path'],
          'file_date': doc['file_date'],
          'sort_order': doc['sort_order'],
        });
      }

      if (!mounted) return;
      MotionToast.success(
        title: const Text('ثبت شد'),
        description: Text('شماره شکایت: ${result['data']?['complaint_number'] ?? ''}'),
      ).show(context);
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        MotionToast.error(title: const Text('خطا'), description: Text('$e')).show(context);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openDocs() {
    if (widget.readOnly) {
      Get.to(() => ShekayatDocsPage(
        codeShekayat: widget.complaint?['code_shekayat']?.toString() ?? '',
        sourceType: 'complainant',
        readOnly: true,
      ));
      return;
    }
    Get.to(() => ShekayatDocsPage(
      codeShekayat: _pendingCode ?? 'pending',
      sourceType: 'complainant',
      readOnly: false,
      pendingMode: _pendingCode == null,
      onPendingSave: (docs) => setState(() {
        _pendingDocs.clear();
        _pendingDocs.addAll(docs);
      }),
      initialPending: List.from(_pendingDocs),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final editable = !widget.readOnly;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: ShekayatAppBar(
          title: widget.readOnly ? 'فرم شکایت' : 'فرم ثبت شکایت',
          actions: widget.readOnly
              ? [
                  if (_pdfLoading)
                    Padding(
                      padding: EdgeInsets.all(14.w),
                      child: SizedBox(width: 20.w, height: 20.w, child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                    )
                  else
                    IconButton(
                      icon: const Icon(Icons.download_rounded),
                      tooltip: 'دانلود PDF',
                      onPressed: _downloadPdf,
                    ),
                ]
              : null,
        ),
        body: _loading
            ? Center(child: CircularProgressIndicator(color: ShekayatTheme.primary))
            : ShekayatLayout.formScroll(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildHeader(),
                    if (widget.readOnly)
                      Container(
                        margin: const EdgeInsets.only(top: 8, bottom: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        decoration: BoxDecoration(
                          color: ShekayatTheme.primary.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: ShekayatTheme.primary.withOpacity(0.25)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.visibility_outlined, color: ShekayatTheme.primary, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'این فرم فقط جهت مشاهده است و قابل ویرایش نیست.',
                                style: PersianFonts.Shabnam.copyWith(fontSize: font_size_12, color: ShekayatTheme.primaryDark),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 6),
                    Center(
                      child: Text(
                        widget.readOnly ? 'فرم شکایت' : 'فرم ثبت شکایت',
                        style: PersianFonts.Shabnam.copyWith(fontSize: font_size_18, fontWeight: FontWeight.w600, color: ShekayatTheme.primary),
                      ),
                    ),
                    ShekayatFieldRow(
                      left: ShekayatDateField(label: 'تاریخ', controller: _dateCtrl, readOnly: widget.readOnly),
                      right: shekayatField('عنوان شکایت', 'لطفا برای شکایت خود یک عنوان بنویسید', _titleCtrl, enabled: editable),
                    ),
                    shekayatField('متن شکایت', 'متن اصلی شکایت را وارد کنید', _captionCtrl, lines: 4, enabled: editable),
                    ShekayatDropdown(
                      label: 'نوع شکایت',
                      value: ShekayatConstants.typeLabel(_typeShekayat),
                      items: ShekayatConstants.types.map((e) => e['label']!).toList(),
                      onChanged: editable
                          ? (v) {
                              final t = ShekayatConstants.types.firstWhere((e) => e['label'] == v, orElse: () => ShekayatConstants.types.first);
                              setState(() => _typeShekayat = t['value']!);
                            }
                          : null,
                    ),
                    const ShekayatSectionTitle('اطلاعات شاکی'),
                    ShekayatFieldRow(
                      left: shekayatField('نام خانوادگی', 'نام خانوادگی شخص شکایت کننده', _shakiFamilyCtrl, enabled: editable),
                      right: shekayatField('نام', 'نام شخص شکایت کننده', _shakiNameCtrl, enabled: editable),
                    ),
                    ShekayatFieldRow(
                      left: shekayatField('کد ملی', 'کد ملی', _shakiMeliCtrl, enabled: editable),
                      right: shekayatField('نام پدر', '', _shakiPedarCtrl, enabled: editable),
                    ),
                    ShekayatFieldRow(
                      left: shekayatField('شماره تماس', 'شماره تماس شکایت کننده', _shakiMobCtrl, enabled: editable),
                      right: shekayatField('آدرس', 'آدرس', _shakiAddrCtrl, enabled: editable),
                      leftFlex: 1,
                      rightFlex: 2,
                    ),
                    if (widget.readOnly && _isLinked)
                      Container(
                        margin: EdgeInsets.only(top: 8.h, bottom: 4.h),
                        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                        decoration: BoxDecoration(
                          color: Colors.deepPurple.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.deepPurple.withOpacity(0.25)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.link_rounded, color: Colors.deepPurple.shade700, size: 18.sp),
                            SizedBox(width: 8.w),
                            Expanded(
                              child: Text(
                                ShekayatFormMapper.respondentFields(_complaintData ?? widget.complaint!)['linkedNote'] ??
                                    'این شکایت به واحد صنفی متصل است. اطلاعات متشاکی همان مقادیر ثبت‌شده توسط شاکی است و تغییر نمی‌کند.',
                                style: PersianFonts.Shabnam.copyWith(fontSize: font_size_12, color: Colors.deepPurple.shade800),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const ShekayatSectionTitle('اطلاعات متشاکی'),
                    ShekayatFieldRow(
                      left: shekayatField('نام خانوادگی', 'نام خانوادگی', _motFamilyCtrl, enabled: editable),
                      right: shekayatField('نام', 'نام', _motNameCtrl, enabled: editable),
                    ),
                    ShekayatFieldRow(
                      left: shekayatField('کد ملی', 'کد ملی', _motMeliCtrl, enabled: editable),
                      right: shekayatField('شماره تماس', 'شماره تماس', _motMobCtrl, enabled: editable),
                    ),
                    shekayatField('نام واحد صنفی', 'نام واحد صنفی', _motStoreCtrl, enabled: editable),
                    shekayatField('آدرس', 'آدرس', _motAddrCtrl, lines: 2, enabled: editable),
                    Divider(height: 24.h, thickness: 1, color: Colors.grey.shade400),
                    if (widget.readOnly)
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 16.h, horizontal: 4.w),
                        child: Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () => Navigator.pop(context),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: ShekayatTheme.primary,
                                  padding: EdgeInsets.symmetric(vertical: 14.h),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                child: Text('بستن', style: PersianFonts.Shabnam.copyWith(fontSize: font_size_12, color: Colors.white)),
                              ),
                            ),
                            SizedBox(width: 8.w),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _openDocs,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: ShekayatTheme.accentGreen,
                                  padding: EdgeInsets.symmetric(vertical: 14.h),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                child: Text('مدارک شاکی', style: PersianFonts.Shabnam.copyWith(fontSize: font_size_12, color: Colors.white)),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      ShekayatTripleButtons(
                        onCancel: () => Navigator.pop(context),
                        onSubmit: _submit,
                        onDocs: _openDocs,
                        loading: _loading,
                      ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildHeader() {
    final complaintNo = widget.complaint?['complaint_number']?.toString();
    return Container(
      margin: EdgeInsets.only(top: 8.h),
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAF8),
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.unionName ?? widget.codeCo,
                  style: PersianFonts.Shabnam.copyWith(fontSize: font_size_16, fontWeight: FontWeight.w600, color: ShekayatTheme.primaryDark),
                ),
                if (widget.readOnly && complaintNo != null && complaintNo.isNotEmpty)
                  Padding(
                    padding: EdgeInsets.only(top: 4.h),
                    child: Text(
                      'شماره شکایت: $complaintNo',
                      style: PersianFonts.Shabnam.copyWith(fontSize: font_size_12, color: Colors.grey.shade700),
                    ),
                  ),
              ],
            ),
          ),
          Text(_dateCtrl.text, style: PersianFonts.Shabnam.copyWith(fontSize: font_size_14, color: Colors.black87)),
        ],
      ),
    );
  }
}
