import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:injast_admin/file_management/jalali_date_util.dart';
import 'package:injast_admin/file_management/parvande_api.dart';
import 'package:injast_admin/file_management/parvande_sharik_api.dart';
import 'package:injast_admin/file_management/sharik_field_limits.dart';
import 'package:injast_admin/file_management/sharik_type_fard_options.dart';
import 'package:persian_datetimepickers/persian_datetimepickers.dart';

/// فرم ثبت / ویرایش شریک
class ParvandeSharikFormSheet extends StatefulWidget {
  const ParvandeSharikFormSheet({
    super.key,
    required this.codeCo,
    required this.parvande,
    required this.userId,
    this.editData,
    this.idSharik,
  });

  final String codeCo;
  final Map<String, dynamic> parvande;
  final String userId;
  final Map<String, dynamic>? editData;
  final String? idSharik;

  static Future<bool?> show(
    BuildContext context, {
    required String codeCo,
    required Map<String, dynamic> parvande,
    required String userId,
    Map<String, dynamic>? editData,
    String? idSharik,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ParvandeSharikFormSheet(
        codeCo: codeCo,
        parvande: parvande,
        userId: userId,
        editData: editData,
        idSharik: idSharik,
      ),
    );
  }

  @override
  State<ParvandeSharikFormSheet> createState() => _ParvandeSharikFormSheetState();
}

class _ParvandeSharikFormSheetState extends State<ParvandeSharikFormSheet> {
  static const _accent = Color(0xFF7B1FA2);

  final _nameCtrl = TextEditingController();
  final _familyCtrl = TextEditingController();
  final _mobCtrl = TextEditingController();
  final _codeMeliCtrl = TextEditingController();
  final _shenasnameCtrl = TextEditingController();
  final _namePedarCtrl = TextEditingController();
  final _telCtrl = TextEditingController();
  final _sadereCtrl = TextEditingController();
  final _captionCtrl = TextEditingController();

  String _sex = 'آقا';
  String _madrak = 'لیسانس';
  String _din = 'اسلام';
  String _sarbazi = 'پایان خدمت';
  String _taahol = 'مجرد';
  String _typeFard = SharikTypeFardOptions.all.first;
  String _dateSodor = '';
  String _dateExp = '';
  String _dateTavalod = '';
  bool _saving = false;

  bool get _isEdit => widget.idSharik != null && widget.editData != null;

  @override
  void initState() {
    super.initState();
    final e = widget.editData;
    if (e != null) {
      _nameCtrl.text = e['name_sharik']?.toString() ?? '';
      _familyCtrl.text = e['family_sharik']?.toString() ?? '';
      _mobCtrl.text = e['mob_sharik']?.toString() ?? '';
      _codeMeliCtrl.text = e['code_meli_sharik']?.toString() ?? '';
      _shenasnameCtrl.text = e['num_shenasname_sharik']?.toString() ?? '';
      _namePedarCtrl.text = e['name_pedar_sharik']?.toString() ?? '';
      _telCtrl.text = e['tel_sharik']?.toString() ?? '';
      _sadereCtrl.text = e['sadere_sharik']?.toString() ?? '';
      _captionCtrl.text = e['caption_sharik']?.toString() ?? '';
      _sex = _pick(e['sex_sharik'], 'آقا');
      _madrak = _pick(e['madrak_sharik'], 'لیسانس');
      _din = _pick(e['din_sharik'], 'اسلام');
      _sarbazi = _pick(e['sarbazi_sharik'], 'پایان خدمت');
      _taahol = _pick(e['taahol_sharik'], 'مجرد');
      _typeFard = SharikTypeFardOptions.normalize(e['type_fard']?.toString());
      _dateSodor = _pick(e['date_sodor_sharik'], '');
      _dateExp = _pick(e['date_exp_sharik'], '');
      _dateTavalod = SharikFieldLimits.displayTavalod(_pick(e['tavalod_sharik'], ''));
    }
  }

  String _pick(dynamic v, String fallback) {
    final t = v?.toString().trim() ?? '';
    if (t.isEmpty || t == 'null') return fallback;
    return t;
  }

  Map<String, String> _fields() => {
        'name_sharik': _nameCtrl.text.trim(),
        'family_sharik': _familyCtrl.text.trim(),
        'mob_sharik': _mobCtrl.text.trim(),
        'code_meli_sharik': _codeMeliCtrl.text.trim(),
        'num_shenasname_sharik': _shenasnameCtrl.text.trim(),
        'name_pedar_sharik': _namePedarCtrl.text.trim(),
        'tel_sharik': _telCtrl.text.trim(),
        'sadere_sharik': _sadereCtrl.text.trim(),
        'tavalod_sharik': _dateTavalod,
        'caption_sharik': _captionCtrl.text.trim(),
        'sex_sharik': _sex,
        'madrak_sharik': _madrak,
        'din_sharik': _din,
        'sarbazi_sharik': _sarbazi,
        'taahol_sharik': _taahol,
        'type_fard': _typeFard,
        'date_sodor_sharik': _dateSodor,
        'date_exp_sharik': _dateExp,
      };

  Future<void> _pickJalaliDate(_SharikDateField field) async {
    final current = switch (field) {
      _SharikDateField.tavalod => _dateTavalod,
      _SharikDateField.sodor => _dateSodor,
      _SharikDateField.expiry => _dateExp,
    };
    final picked = await showPersianDatePicker(
      context: context,
      initialDate: JalaliDateUtil.parseToGregorian(current) ?? DateTime.now(),
    );
    if (picked == null) return;
    setState(() {
      switch (field) {
        case _SharikDateField.tavalod:
          _dateTavalod = JalaliDateUtil.formatYearFromDateTime(picked);
        case _SharikDateField.sodor:
          _dateSodor = JalaliDateUtil.formatFromDateTime(picked);
        case _SharikDateField.expiry:
          _dateExp = JalaliDateUtil.formatFromDateTime(picked);
      }
    });
  }

  Future<void> _pickTypeFard() async {
    final selected = await SharikTypeFardOptions.pick(context, current: _typeFard);
    if (selected == null) return;
    setState(() => _typeFard = selected);
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty || _mobCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('نام و شماره موبایل الزامی است.')),
      );
      return;
    }

    final fields = SharikFieldLimits.normalizeForApi(_fields());
    final validationError = SharikFieldLimits.validate(fields);
    if (validationError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(validationError)),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      if (_isEdit) {
        await ParvandeSharikApi.instance.update(
          idSharik: widget.idSharik!,
          fields: fields,
        );
      } else {
        await ParvandeSharikApi.instance.insert(
          codeCo: widget.codeCo,
          idParvandeh: widget.parvande.idParvandeh,
          idUser: widget.userId,
          fields: fields,
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_isEdit ? 'شریک ویرایش شد.' : 'شریک ثبت شد.')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطا: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _familyCtrl.dispose();
    _mobCtrl.dispose();
    _codeMeliCtrl.dispose();
    _shenasnameCtrl.dispose();
    _namePedarCtrl.dispose();
    _telCtrl.dispose();
    _sadereCtrl.dispose();
    _captionCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.92),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _isEdit ? 'ویرایش شریک' : 'ثبت شریک جدید',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                    ),
                  ),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _row2(
                    _field(_nameCtrl, 'نام *', maxLength: SharikFieldLimits.nameMax),
                    _field(_familyCtrl, 'نام خانوادگی', maxLength: SharikFieldLimits.familyMax),
                  ),
                  _row2(
                    _field(
                      _mobCtrl,
                      'شماره موبایل *',
                      keyboard: TextInputType.phone,
                      maxLength: SharikFieldLimits.mobMax,
                      digitsOnly: true,
                    ),
                    _field(
                      _telCtrl,
                      'تلفن',
                      keyboard: TextInputType.phone,
                      maxLength: SharikFieldLimits.telMax,
                      digitsOnly: true,
                    ),
                  ),
                  _row2(
                    _field(
                      _codeMeliCtrl,
                      'کد ملی (۱۰ رقم)',
                      keyboard: TextInputType.number,
                      maxLength: SharikFieldLimits.codeMeliMax,
                      digitsOnly: true,
                    ),
                    _field(
                      _shenasnameCtrl,
                      'شماره شناسنامه',
                      keyboard: TextInputType.number,
                      maxLength: SharikFieldLimits.shenasnameMax,
                      digitsOnly: true,
                    ),
                  ),
                  _row2(
                    _field(_namePedarCtrl, 'نام پدر', maxLength: SharikFieldLimits.namePedarMax),
                    _field(_sadereCtrl, 'صادره', maxLength: SharikFieldLimits.sadereMax),
                  ),
                  _row2(
                    _dateTile(
                      'سال تولد (شمسی)',
                      _dateTavalod,
                      () => _pickJalaliDate(_SharikDateField.tavalod),
                      hint: 'مثلاً 1370',
                    ),
                    _dropdown('جنسیت', _sex, const ['خانم', 'آقا'], (v) => _sex = v),
                  ),
                  _typeFardTile(),
                  _row2(
                    _dateTile('تاریخ صدور', _dateSodor, () => _pickJalaliDate(_SharikDateField.sodor)),
                    _dateTile('تاریخ انقضا', _dateExp, () => _pickJalaliDate(_SharikDateField.expiry)),
                  ),
                  _dropdown(
                    'تحصیلات',
                    _madrak,
                    const ['بی‌سواد', 'سیکل', 'دیپلم', 'فوق دیپلم', 'لیسانس', 'فوق لیسانس', 'دکتری'],
                    (v) => _madrak = v,
                  ),
                  _row2(
                    _dropdown('دین', _din, const ['اسلام', 'مسیحیت', 'یهودیت', 'زرتشت', 'سایر'], (v) => _din = v),
                    _dropdown('وضعیت تأهل', _taahol, const ['مجرد', 'متأهل'], (v) => _taahol = v),
                  ),
                  _dropdown(
                    'نظام وظیفه',
                    _sarbazi,
                    const ['پایان خدمت', 'معاف', 'مشمول خدمت', 'ندارد'],
                    (v) => _sarbazi = v,
                  ),
                  _field(_captionCtrl, 'توضیحات', maxLines: 3, maxLength: SharikFieldLimits.captionMax),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('آپلود عکس به زودی')),
                      );
                    },
                    icon: const Icon(Icons.photo_camera_outlined),
                    label: const Text('عکس شریک (به زودی)'),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: _accent,
                  minimumSize: const Size.fromHeight(46),
                ),
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(_isEdit ? 'ذخیره تغییرات' : 'ثبت شریک'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row2(Widget a, Widget b) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: a),
          const SizedBox(width: 8),
          Expanded(child: b),
        ],
      ),
    );
  }

  Widget _field(
    TextEditingController c,
    String label, {
    TextInputType? keyboard,
    int maxLines = 1,
    int? maxLength,
    bool digitsOnly = false,
  }) {
    return TextField(
      controller: c,
      keyboardType: keyboard,
      maxLines: maxLines,
      maxLength: maxLength,
      inputFormatters: digitsOnly ? [FilteringTextInputFormatter.digitsOnly] : null,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        counterText: '',
      ),
    );
  }

  Widget _dropdown(
    String label,
    String value,
    List<String> items,
    ValueChanged<String> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            isExpanded: true,
            value: items.contains(value) ? value : items.first,
            items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
            onChanged: (v) {
              if (v == null) return;
              setState(() => onChanged(v));
            },
          ),
        ),
      ),
    );
  }

  Widget _typeFardTile() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: _pickTypeFard,
        borderRadius: BorderRadius.circular(4),
        child: InputDecorator(
          decoration: const InputDecoration(
            labelText: 'نوع فرد / نقش',
            border: OutlineInputBorder(),
            isDense: true,
            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 14),
            suffixIcon: Icon(Icons.search),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _typeFard,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dateTile(String label, String value, VoidCallback onTap, {String? hint}) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
          suffixIcon: const Icon(Icons.calendar_month_outlined, size: 20),
        ),
        child: Text(
          value.isEmpty ? (hint ?? 'انتخاب تاریخ شمسی') : value,
          style: TextStyle(
            fontSize: 13,
            color: value.isEmpty ? Colors.grey.shade600 : null,
          ),
        ),
      ),
    );
  }
}

enum _SharikDateField { tavalod, sodor, expiry }
