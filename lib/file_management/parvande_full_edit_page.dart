import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:injast_admin/file_management/jalali_date_util.dart';
import 'package:injast_admin/file_management/parvande_api.dart';
import 'package:injast_admin/file_management/parvande_map_dialog.dart';
import 'package:injast_admin/file_management/parvande_vaziyat.dart';
import 'package:persian_datetimepickers/persian_datetimepickers.dart';

enum _DateField { tavalod, sodor, expiry }

/// فرم ویرایش کامل پرونده
class ParvandeFullEditPage extends StatefulWidget {
  const ParvandeFullEditPage({
    super.key,
    required this.codeCo,
    required this.parvande,
    required this.allParvandes,
    this.currentUserId,
    this.currentUserName,
    this.currentUserRole,
  });

  final String codeCo;
  final Map<String, dynamic> parvande;
  final List<Map<String, dynamic>> allParvandes;
  final String? currentUserId;
  final String? currentUserName;
  final String? currentUserRole;

  static Future<bool?> open(
    BuildContext context, {
    required String codeCo,
    required Map<String, dynamic> parvande,
    required List<Map<String, dynamic>> allParvandes,
    String? currentUserId,
    String? currentUserName,
    String? currentUserRole,
  }) {
    return Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ParvandeFullEditPage(
          codeCo: codeCo,
          parvande: parvande,
          allParvandes: allParvandes,
          currentUserId: currentUserId,
          currentUserName: currentUserName,
          currentUserRole: currentUserRole,
        ),
      ),
    );
  }

  @override
  State<ParvandeFullEditPage> createState() => _ParvandeFullEditPageState();
}

class _ParvandeFullEditPageState extends State<ParvandeFullEditPage> {
  static const _accent = Color(0xFFEF6C00);
  static const _surface = Color(0xFFF4F6F9);
  static const _cardBg = Colors.white;
  static const _border = Color(0xFFE2E8F0);

  final _familyCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _sadereCtrl = TextEditingController();
  final _namePedarCtrl = TextEditingController();
  final _shenasnameCtrl = TextEditingController();
  final _codeMeliCtrl = TextEditingController();
  final _mobCtrl = TextEditingController();
  final _telCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _codePostiCtrl = TextEditingController();
  final _mantagheCtrl = TextEditingController();
  final _stateCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _nameStoreCtrl = TextEditingController();
  final _shenaseCtrl = TextEditingController();
  final _masahatCtrl = TextEditingController();
  final _darajeCtrl = TextEditingController();
  final _numPersonCtrl = TextEditingController();
  final _captionCtrl = TextEditingController();
  final _numParvandeCtrl = TextEditingController();

  String _sex = 'آقا';
  String _madrak = 'لیسانس';
  String _din = 'اسلام - شیعه';
  String _sarbazi = 'پایان خدمت';
  String _taahol = 'مجرد';
  String _typeMelki = 'استیجاری';
  String _dateEtebar = 'پنج ساله';
  String _raste = '';
  String _vaziyatLabel = ParvandeVaziyat.options.first;
  String _dateTavalod = '';
  String _dateSodor = '';
  String _dateExp = '';
  String _lat = '';
  String _lng = '';

  List<String> _rasteOptions = [];
  bool _loadingRaste = true;
  bool _saving = false;

  InputDecoration _decoration(String label, {Widget? suffix, bool readOnly = false}) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: readOnly ? const Color(0xFFF1F5F9) : _cardBg,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _border)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _accent, width: 1.5),
      ),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      suffixIcon: suffix,
      counterText: '',
    );
  }

  @override
  void initState() {
    super.initState();
    _loadFromParvande();
    _loadRaste();
  }

  void _loadFromParvande() {
    final p = widget.parvande;
    _numParvandeCtrl.text = p.s('num_parvande_store');
    _familyCtrl.text = p.s('family_admin');
    _nameCtrl.text = p.s('name_admin');
    _sadereCtrl.text = p.s('sadere_admin');
    _dateTavalod = JalaliDateUtil.serverToDisplayYear(p.s('tavalod_admin'));
    _namePedarCtrl.text = p.s('name_pedar_admin');
    _shenasnameCtrl.text = p.s('num_shenasname_admin');
    _codeMeliCtrl.text = p.s('code_meli_admin');
    _mobCtrl.text = p.s('mob_admin');
    _telCtrl.text = p.s('tel_admin');
    _addressCtrl.text = p.s('address_store');
    _codePostiCtrl.text = p.s('code_posti_store');
    _mantagheCtrl.text = p.s('mantaghe_store');
    _stateCtrl.text = p.s('state_store');
    _cityCtrl.text = p.s('city_store');
    _nameStoreCtrl.text = p.s('name_store');
    _shenaseCtrl.text = p.s('shenase_store');
    _masahatCtrl.text = p.s('masahat_store');
    _darajeCtrl.text = p.s('daraje_store');
    _numPersonCtrl.text = p.s('num_person_store');
    _captionCtrl.text = p.s('caption_parvande');
    _sex = _pick(p.s('sex_admin'), 'آقا');
    _madrak = _pick(p.s('madrak_admin'), 'لیسانس');
    _din = _pick(p.s('din_admin'), 'اسلام - شیعه');
    _sarbazi = _pick(p.s('sarbazi_admin'), 'پایان خدمت');
    _taahol = _pick(p.s('taahol_admin'), 'مجرد');
    _typeMelki = _pick(p.s('type_melki_store'), 'استیجاری');
    _dateEtebar = _pick(p.s('date_etebar_store'), 'پنج ساله');
    _raste = p.s('raste_store');
    _vaziyatLabel = ParvandeVaziyat.labelForRow(p);
    _dateSodor = JalaliDateUtil.serverToDisplay(p.s('date_sodor_store'));
    _dateExp = JalaliDateUtil.serverToDisplay(p.s('date_exp_store'));
    _lat = p.s('lat_store');
    _lng = p.s('long_store');
  }

  String _pick(String v, String fallback) {
    final t = v.trim();
    if (t.isEmpty || t == 'null') return fallback;
    return t;
  }

  Future<void> _loadRaste() async {
    try {
      final names = await ParvandeApi.instance.fetchRasteNames(widget.codeCo);
      if (!mounted) return;
      setState(() {
        _rasteOptions = names;
        if (_raste.isNotEmpty && !names.contains(_raste)) {
          _rasteOptions = [_raste, ...names];
        } else if (_raste.isEmpty && names.isNotEmpty) {
          _raste = names.first;
        }
        _loadingRaste = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loadingRaste = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطا در بارگذاری رسته‌ها: $e')),
        );
      }
    }
  }

  Future<void> _pickDate(_DateField field) async {
    final current = switch (field) {
      _DateField.tavalod => _dateTavalod,
      _DateField.sodor => _dateSodor,
      _DateField.expiry => _dateExp,
    };
    final initial = field == _DateField.tavalod
        ? (JalaliDateUtil.parseToGregorian('${current.isEmpty ? '1370' : current}/01/01') ?? DateTime(1990))
        : (JalaliDateUtil.parseToGregorian(current) ?? DateTime.now());

    final picked = await showPersianDatePicker(
      context: context,
      initialDate: initial,
    );
    if (picked == null) return;

    setState(() {
      switch (field) {
        case _DateField.tavalod:
          _dateTavalod = JalaliDateUtil.formatYearFromDateTime(picked);
        case _DateField.sodor:
          _dateSodor = JalaliDateUtil.formatFromDateTime(picked);
        case _DateField.expiry:
          _dateExp = JalaliDateUtil.formatFromDateTime(picked);
      }
    });
  }

  Future<void> _openMap() async {
    final draft = Map<String, dynamic>.from(widget.parvande);
    draft['address_store'] = _addressCtrl.text.trim();
    draft['lat_store'] = _lat;
    draft['long_store'] = _lng;

    await ParvandeMapDialog.show(
      context,
      parvande: draft,
      unionParvandes: widget.allParvandes,
      currentUserName: widget.currentUserName,
      currentUserRole: widget.currentUserRole,
      lastEditorFuture: ParvandeApi.instance.fetchLocationEditor(widget.parvande.idParvandeh),
      onSave: ({
        required bool addressChanged,
        required String address,
        required bool locationChanged,
        required double lat,
        required double lng,
      }) async {
        setState(() {
          if (addressChanged) _addressCtrl.text = address;
          if (locationChanged) {
            _lat = lat.toString();
            _lng = lng.toString();
          }
        });
      },
    );
  }

  String? _validate() {
    if (_familyCtrl.text.trim().isEmpty) return 'نام خانوادگی الزامی است.';
    if (_addressCtrl.text.trim().isEmpty) return 'آدرس الزامی است.';
    if (_nameStoreCtrl.text.trim().isEmpty) return 'نام واحد صنفی الزامی است.';
    if (_shenaseCtrl.text.trim().isEmpty) return 'شناسه صنفی الزامی است.';
    if (_codeMeliCtrl.text.trim().isEmpty) return 'کد ملی الزامی است.';
    if (_mobCtrl.text.trim().isEmpty) return 'شماره موبایل الزامی است.';
    if (_raste.trim().isEmpty) return 'رسته الزامی است.';
    if (_lat.trim().isEmpty || _lng.trim().isEmpty || _lat == '0' || _lng == '0') {
      return 'مختصات نقشه الزامی است — روی نقشه نقطه انتخاب کنید.';
    }
    return null;
  }

  Map<String, String> _buildOverrides() {
    return {
      'name_admin': _nameCtrl.text.trim(),
      'family_admin': _familyCtrl.text.trim(),
      'sex_admin': _sex,
      'sadere_admin': _sadereCtrl.text.trim(),
      'tavalod_admin': _dateTavalod,
      'name_pedar_admin': _namePedarCtrl.text.trim(),
      'num_shenasname_admin': _shenasnameCtrl.text.trim(),
      'code_meli_admin': _codeMeliCtrl.text.trim(),
      'mob_admin': _mobCtrl.text.trim(),
      'tel_admin': _telCtrl.text.trim(),
      'madrak_admin': _madrak,
      'din_admin': _din,
      'sarbazi_admin': _sarbazi,
      'taahol_admin': _taahol,
      'name_store': _nameStoreCtrl.text.trim(),
      'shenase_store': _shenaseCtrl.text.trim(),
      'raste_store': _raste,
      'masahat_store': _masahatCtrl.text.trim(),
      'type_melki_store': _typeMelki,
      'address_store': _addressCtrl.text.trim(),
      'code_posti_store': _codePostiCtrl.text.trim(),
      'mantaghe_store': _mantagheCtrl.text.trim(),
      'lat_store': _lat,
      'long_store': _lng,
      'state_store': _stateCtrl.text.trim(),
      'city_store': _cityCtrl.text.trim(),
      'date_sodor_store': JalaliDateUtil.displayToServer(_dateSodor),
      'date_exp_store': JalaliDateUtil.displayToServer(_dateExp),
      'date_etebar_store': _dateEtebar,
      'daraje_store': _darajeCtrl.text.trim(),
      'num_parvande_store': _numParvandeCtrl.text.trim(),
      'vaziyat_store': ParvandeVaziyat.codeForLabel(_vaziyatLabel),
      'lbl_vaziyat_store': _vaziyatLabel,
      'num_person_store': _numPersonCtrl.text.trim(),
      'caption_parvande': _captionCtrl.text.trim(),
    };
  }

  Future<void> _save() async {
    if (_loadingRaste || _rasteOptions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لیست رسته‌ها نباید خالی باشد.')),
      );
      return;
    }
    final err = _validate();
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      return;
    }

    setState(() => _saving = true);
    try {
      final overrides = _buildOverrides();
      await ParvandeApi.instance.updateParvandeh(widget.parvande, overrides: overrides);

      if (_lat != widget.parvande.s('lat_store') || _lng != widget.parvande.s('long_store')) {
        await ParvandeApi.instance.updateStoreLocation(
          idParvandeh: widget.parvande.idParvandeh,
          lat: _lat,
          lng: _lng,
          idUser: widget.currentUserId,
          keepEditLocation: true,
        );
      }

      if (mounted) Navigator.pop(context, true);
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
    _familyCtrl.dispose();
    _nameCtrl.dispose();
    _sadereCtrl.dispose();
    _namePedarCtrl.dispose();
    _shenasnameCtrl.dispose();
    _codeMeliCtrl.dispose();
    _mobCtrl.dispose();
    _telCtrl.dispose();
    _addressCtrl.dispose();
    _codePostiCtrl.dispose();
    _mantagheCtrl.dispose();
    _stateCtrl.dispose();
    _cityCtrl.dispose();
    _nameStoreCtrl.dispose();
    _shenaseCtrl.dispose();
    _masahatCtrl.dispose();
    _darajeCtrl.dispose();
    _numPersonCtrl.dispose();
    _captionCtrl.dispose();
    _numParvandeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.parvande;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _surface,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: _accent,
          foregroundColor: Colors.white,
          title: const Text('ویرایش پرونده'),
        ),
        body: _loadingRaste
            ? const Center(child: CircularProgressIndicator(color: _accent))
            : Column(
                children: [
                  _summaryBanner(p),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                      children: [
                        _sectionCard(
                          icon: Icons.assignment_outlined,
                          title: 'وضعیت پرونده',
                          children: [
                            _dropdown('وضعیت *', _vaziyatLabel, ParvandeVaziyat.options, (v) => _vaziyatLabel = v),
                            _readOnlyField('شماره پرونده', _numParvandeCtrl),
                          ],
                        ),
                        _sectionCard(
                          icon: Icons.person_outline,
                          title: 'اطلاعات صاحب',
                          children: [
                            _row2(
                              _field(_familyCtrl, 'نام خانوادگی *'),
                              _field(_nameCtrl, 'نام'),
                            ),
                            _row2(
                              _dropdown('جنسیت', _sex, const ['خانم', 'آقا'], (v) => _sex = v),
                              _dateTile('سال تولد (شمسی)', _dateTavalod, () => _pickDate(_DateField.tavalod), hint: 'انتخاب از تقویم'),
                            ),
                            _row2(
                              _field(_sadereCtrl, 'صادره'),
                              _field(_namePedarCtrl, 'نام پدر'),
                            ),
                            _row2(
                              _field(_shenasnameCtrl, 'شناسنامه', digitsOnly: true, maxLength: 10),
                              _field(_codeMeliCtrl, 'کد ملی *', digitsOnly: true, maxLength: 10),
                            ),
                            _row2(
                              _dropdown('تحصیلات', _madrak,
                                  const ['سیکل', 'دیپلم', 'فوق دیپلم', 'لیسانس', 'فوق لیسانس', 'دکتری'], (v) => _madrak = v),
                              _dropdown('تأهل', _taahol, const ['مجرد', 'متأهل'], (v) => _taahol = v),
                            ),
                            _row2(
                              _dropdown('دین', _din,
                                  const ['اسلام - شیعه', 'اسلام - سنی', 'مسیحی', 'سایر'], (v) => _din = v),
                              _dropdown('نظام وظیفه', _sarbazi,
                                  const ['پایان خدمت', 'معاف', 'مشمول خدمت', 'ندارد'], (v) => _sarbazi = v),
                            ),
                          ],
                        ),
                        _sectionCard(
                          icon: Icons.phone_outlined,
                          title: 'تماس',
                          children: [
                            _row2(
                              _field(_mobCtrl, 'موبایل *', digitsOnly: true, maxLength: 11),
                              _field(_telCtrl, 'تلفن محل کار', digitsOnly: true, maxLength: 11),
                            ),
                          ],
                        ),
                        _sectionCard(
                          icon: Icons.storefront_outlined,
                          title: 'واحد صنفی و مکان',
                          children: [
                            _row2(
                              _field(_stateCtrl, 'استان'),
                              _field(_cityCtrl, 'شهر'),
                            ),
                            _field(_addressCtrl, 'آدرس *', maxLines: 2),
                            _mapTile(),
                            _row2(
                              _field(_codePostiCtrl, 'کد پستی', digitsOnly: true, maxLength: 10),
                              _field(_mantagheCtrl, 'منطقه شهرداری', maxLength: 2),
                            ),
                            _dropdown('رسته *', _raste, _rasteOptions, (v) => _raste = v),
                            _row2(
                              _field(_nameStoreCtrl, 'نام واحد صنفی *'),
                              _field(_shenaseCtrl, 'شناسه صنفی *', digitsOnly: true, maxLength: 10),
                            ),
                          ],
                        ),
                        _sectionCard(
                          icon: Icons.badge_outlined,
                          title: 'پروانه و مشخصات',
                          children: [
                            _row2(
                              _dateTile('تاریخ صدور (شمسی)', _dateSodor, () => _pickDate(_DateField.sodor)),
                              _dateTile('تاریخ انقضا (شمسی)', _dateExp, () => _pickDate(_DateField.expiry)),
                            ),
                            _dropdown('اعتبار پروانه', _dateEtebar,
                                const ['ده ساله', 'پنج ساله', 'یک ساله', 'فاقد اعتبار'], (v) => _dateEtebar = v),
                            _row2(
                              _field(_darajeCtrl, 'درجه', maxLength: 2),
                              _field(_masahatCtrl, 'مساحت', digitsOnly: true, maxLength: 5),
                            ),
                            _row2(
                              _dropdown('نوع مالکیت', _typeMelki, const ['دائم', 'استیجاری'], (v) => _typeMelki = v),
                              _field(_numPersonCtrl, 'تعداد شاغلین', digitsOnly: true, maxLength: 3),
                            ),
                          ],
                        ),
                        _sectionCard(
                          icon: Icons.notes_outlined,
                          title: 'توضیحات',
                          children: [
                            _field(_captionCtrl, 'توضیحات پرونده', maxLines: 3),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: _cardBg,
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, -2))],
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: _accent,
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.check_circle_outline),
                label: Text(_saving ? 'در حال ثبت…' : 'ثبت تغییرات'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _summaryBanner(Map<String, dynamic> p) {
    final name = p.fullName.isEmpty ? '—' : p.fullName;
    final store = p.storeName.isEmpty ? '—' : p.storeName;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_accent, _accent.withValues(alpha: 0.85)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
          const SizedBox(height: 4),
          Text(
            '$store • شماره ${p.numParvande.isEmpty ? '—' : p.numParvande}',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({
    required IconData icon,
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: _accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 18, color: _accent),
              ),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _row2(Widget a, Widget b) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: a),
            const SizedBox(width: 10),
            Expanded(child: b),
          ],
        ),
      );

  Widget _field(
    TextEditingController c,
    String label, {
    int maxLines = 1,
    int? maxLength,
    bool digitsOnly = false,
  }) {
    return TextField(
      controller: c,
      maxLines: maxLines,
      maxLength: maxLength,
      keyboardType: digitsOnly ? TextInputType.number : null,
      inputFormatters: digitsOnly ? [FilteringTextInputFormatter.digitsOnly] : null,
      decoration: _decoration(label),
    );
  }

  Widget _readOnlyField(String label, TextEditingController c) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: c,
        readOnly: true,
        decoration: _decoration(label, readOnly: true),
      ),
    );
  }

  Widget _dropdown(
    String label,
    String value,
    List<String> items,
    ValueChanged<String> onChanged,
  ) {
    final list = items.where((e) => e.isNotEmpty).toList();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InputDecorator(
        decoration: _decoration(label),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            isExpanded: true,
            isDense: true,
            value: list.contains(value) ? value : (list.isNotEmpty ? list.first : null),
            items: list.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 13)))).toList(),
            onChanged: (v) {
              if (v == null) return;
              setState(() => onChanged(v));
            },
          ),
        ),
      ),
    );
  }

  Widget _dateTile(String label, String value, VoidCallback onTap, {String hint = 'انتخاب تاریخ'}) {
    final hasValue = value.isNotEmpty;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: _decoration(
          label,
          suffix: Icon(Icons.calendar_month_outlined, size: 20, color: hasValue ? _accent : Colors.grey),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                hasValue ? value : hint,
                style: TextStyle(
                  fontSize: 13,
                  color: hasValue ? Colors.black87 : Colors.grey.shade600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _mapTile() {
    final hasLoc = _lat.isNotEmpty && _lng.isNotEmpty && _lat != '0' && _lng != '0';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: hasLoc ? _accent.withValues(alpha: 0.06) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: _openMap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: hasLoc ? _accent.withValues(alpha: 0.35) : _border),
            ),
            child: Row(
              children: [
                Icon(Icons.location_on_outlined, color: hasLoc ? _accent : Colors.grey.shade600),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hasLoc ? 'موقعیت روی نقشه ثبت شده' : 'انتخاب نقطه روی نقشه *',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: hasLoc ? _accent : Colors.black87,
                        ),
                      ),
                      if (hasLoc)
                        Text(
                          'عرض: $_lat  •  طول: $_lng',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                        ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_left, color: Colors.grey.shade500),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
