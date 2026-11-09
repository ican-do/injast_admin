import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:injast_admin/injast_http.dart' as http;
import 'package:injast_admin/features/parvande_new/location_pick_dialog.dart';
import 'package:injast_admin/features/parvande_new/parvande_register_mode.dart';
import 'package:injast_admin/features/parvande_new/place_api.dart';
import 'package:injast_admin/features/parvande_new/searchable_place_field.dart';
import 'package:injast_admin/features/shared/admin_ui.dart';
import 'package:injast_admin/file_management/map_ir_geocoding.dart';
import 'package:injast_admin/file_management/parvande_api.dart';
import 'package:injast_admin/file_management/province_geo_fence.dart';
import 'package:injast_admin/server_config.dart';
import 'package:persian_datetimepickers/persian_datetimepickers.dart';
import 'package:shamsi_date/shamsi_date.dart';

const List<String> _kParvandeStatusLabels = [
  'دردست اقدام',
  'فعال/صادر شده',
  'منقضی شده',
  'ابطال',
  'ابطال متقاضی',
  'تعلیق',
  'فاقد اعتبار',
  'تغییر نشانی',
  'فاقد پروانه',
  'پلمپ',
];

String _codeForVaziyatLabel(String label) {
  switch (label.trim()) {
    case 'دردست اقدام':
    case 'در دست اقدام':
      return '1';
    case 'فعال/صادر شده':
      return '2';
    case 'منقضی شده':
      return '3';
    case 'تغییر نشانی':
      return '4';
    case 'ابطال متقاضی':
      return '6';
    case 'ابطال':
      return '8';
    case 'فاقد اعتبار':
      return '10';
    case 'تعلیق':
      return '11';
    case 'فاقد پروانه':
      return '13';
    case 'پلمپ':
      return '14';
    default:
      return '1';
  }
}

class NewParvandePage extends StatefulWidget {
  const NewParvandePage({
    super.key,
    required this.codeCo,
    required this.idUser,
    this.unionInfo,
    this.registerMode = ParvandeRegisterMode.full,
  });

  final String codeCo;
  final String idUser;
  final Map<String, dynamic>? unionInfo;
  final ParvandeRegisterMode registerMode;

  @override
  State<NewParvandePage> createState() => _NewParvandePageState();
}

class _NewParvandePageState extends State<NewParvandePage> {
  final _formKey = GlobalKey<FormState>();
  final _controllers = <String, TextEditingController>{};
  List<String> _raste = [];
  List<String> _states = [];
  List<String> _cities = [];
  String? _selectedRaste;
  String? _selectedState;
  String? _selectedCity;
  String _sex = 'مرد';
  String _ownership = 'ملکی';
  String _licenseValidity = 'پنج ساله';
  String _vaziyatLabel = 'فاقد پروانه';
  bool _loadingRaste = true;
  bool _loadingStates = true;
  bool _loadingCities = false;
  bool _saving = false;
  double? _defaultLat;
  double? _defaultLng;

  TextEditingController _c(String key) =>
      _controllers.putIfAbsent(key, TextEditingController.new);

  String get _unionState =>
      widget.unionInfo?['state_co']?.toString().trim() ?? '';
  String get _unionCity =>
      widget.unionInfo?['city_co']?.toString().trim() ?? '';

  String get _biasQuery {
    final parts = <String>[
      if ((_selectedState ?? _unionState).isNotEmpty)
        (_selectedState ?? _unionState),
      if ((_selectedCity ?? _unionCity).isNotEmpty)
        (_selectedCity ?? _unionCity),
    ];
    return parts.join('، ');
  }

  @override
  void initState() {
    super.initState();
    _loadRaste();
    _loadStates().then((_) => _applyUnionPlaceDefaults());
    _fillNextParvandeNumber();
  }

  /// شماره پروندهٔ پیشنهادی = بزرگ‌ترین شمارهٔ عددی موجود + ۱. اگر کاربر قبلاً چیزی نوشته باشد عوض نمی‌شود.
  Future<void> _fillNextParvandeNumber() async {
    try {
      final rows = await ParvandeApi.instance.fetchAll(widget.codeCo);
      var maxNum = 0;
      for (final row in rows) {
        final raw = _englishDigits(row['num_parvande_store']?.toString() ?? '').trim();
        final n = int.tryParse(raw);
        if (n != null && n > maxNum) maxNum = n;
      }
      final ctrl = _c('num_parvande_store');
      if (!mounted || ctrl.text.trim().isNotEmpty) return;
      ctrl.text = '${maxNum + 1}';
      setState(() {});
    } catch (_) {}
  }

  String _englishDigits(String input) {
    const fa = '۰۱۲۳۴۵۶۷۸۹';
    const ar = '٠١٢٣٤٥٦٧٨٩';
    var out = input;
    for (var i = 0; i < 10; i++) {
      out = out.replaceAll(fa[i], '$i').replaceAll(ar[i], '$i');
    }
    return out;
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadRaste() async {
    try {
      final response = await http.get(Uri.parse(getApiUrl(
          'select/select_raste/${Uri.encodeComponent(widget.codeCo)}')));
      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }
      final body = jsonDecode(response.body);
      if (body is List) {
        _raste = body
            .whereType<Map>()
            .map((e) => e['name_raste']?.toString().trim() ?? '')
            .where((e) => e.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
      }
    } catch (e) {
      if (mounted) {
        showAdminSnack(context, 'خطا در دریافت فهرست رسته‌ها: $e', error: true);
      }
    } finally {
      if (mounted) setState(() => _loadingRaste = false);
    }
  }

  Future<void> _loadStates() async {
    setState(() => _loadingStates = true);
    try {
      final states = await PlaceApi.readStates();
      if (!mounted) return;
      setState(() => _states = states);
    } catch (e) {
      if (mounted) {
        showAdminSnack(context, 'خطا در دریافت فهرست استان‌ها: $e', error: true);
      }
    } finally {
      if (mounted) setState(() => _loadingStates = false);
    }
  }

  Future<void> _applyUnionPlaceDefaults() async {
    final state = _unionState;
    final city = _unionCity;

    String? pickMatch(List<String> options, String target) {
      if (target.isEmpty) return null;
      for (final option in options) {
        if (option == target ||
            option.contains(target) ||
            target.contains(option)) {
          return option;
        }
      }
      return target;
    }

    if (state.isNotEmpty) {
      final stateValue = pickMatch(_states, state) ?? state;
      await _onStateSelected(stateValue);
      if (city.isNotEmpty && mounted) {
        setState(() => _selectedCity = pickMatch(_cities, city) ?? city);
      }
      await _resolveDefaultLocation(
        state: stateValue,
        city: _selectedCity ?? city,
      );
      return;
    }

    await _resolveDefaultLocation(state: state, city: city);
  }

  Future<void> _resolveDefaultLocation({
    required String state,
    required String city,
  }) async {
    // اولویت: geocode استان+شهرستان اتحادیه
    final query = [
      if (state.isNotEmpty) state,
      if (city.isNotEmpty) city,
    ].join('، ');
    if (query.isNotEmpty) {
      final hit = await MapIrGeocoding.instance.searchAddress(query);
      if (hit != null && mounted) {
        setState(() {
          _defaultLat = hit.latitude;
          _defaultLng = hit.longitude;
          if (_c('lat_store').text.trim().isEmpty) {
            _c('lat_store').text = hit.latitude.toStringAsFixed(6);
            _c('long_store').text = hit.longitude.toStringAsFixed(6);
          }
        });
        return;
      }
    }

    // پشتیبان: مرکز تقریبی استان از geo fence
    final fence = ProvinceGeoFence.fromState(state);
    if (fence != null && mounted) {
      setState(() {
        _defaultLat = fence.centerLat;
        _defaultLng = fence.centerLng;
        if (_c('lat_store').text.trim().isEmpty) {
          _c('lat_store').text = fence.centerLat.toStringAsFixed(6);
          _c('long_store').text = fence.centerLng.toStringAsFixed(6);
        }
      });
    }
  }

  Future<void> _onStateSelected(String state) async {
    setState(() {
      _selectedState = state;
      _selectedCity = null;
      _cities = [];
      _loadingCities = true;
    });
    try {
      final cities = await PlaceApi.readCities(state);
      if (!mounted) return;
      setState(() => _cities = cities);
    } catch (e) {
      if (mounted) {
        showAdminSnack(context, 'خطا در دریافت شهرستان‌ها: $e', error: true);
      }
    } finally {
      if (mounted) setState(() => _loadingCities = false);
    }
  }

  Future<void> _openMapPicker() async {
    final lat = double.tryParse(_c('lat_store').text.trim()) ?? _defaultLat;
    final lng = double.tryParse(_c('long_store').text.trim()) ?? _defaultLng;
    final result = await LocationPickDialog.show(
      context,
      initialLat: lat,
      initialLng: lng,
      initialAddress: _c('address_store').text.trim(),
      biasQuery: _biasQuery,
    );
    if (result == null || !mounted) return;
    setState(() {
      _c('lat_store').text = result.latitude.toStringAsFixed(6);
      _c('long_store').text = result.longitude.toStringAsFixed(6);
      if (result.address.isNotEmpty) {
        _c('address_store').text = result.address;
      }
    });
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'این فیلد الزامی است' : null;

  Widget _field(
    String key,
    String label, {
    bool required = false,
    int lines = 1,
    TextInputType? keyboard,
    bool date = false,
    bool readOnly = false,
    Widget? suffix,
  }) =>
      SizedBox(
        width: lines > 1 ? 760 : 350,
        child: TextFormField(
          controller: _c(key),
          validator: required ? _required : null,
          maxLines: lines,
          keyboardType: keyboard,
          readOnly: date || readOnly,
          onTap: date ? () => _pickDate(key) : null,
          decoration: AdminUi.fieldDecoration(
            label,
            required: required,
            suffix: suffix ?? (date ? const Icon(Icons.date_range) : null),
          ),
        ),
      );

  Widget _section(String title, IconData icon, List<Widget> fields) =>
      Container(
        padding: const EdgeInsets.all(18),
        decoration: AdminUi.cardDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, color: AdminUi.ink),
                const SizedBox(width: 8),
                Text(title,
                    style: const TextStyle(
                        color: AdminUi.ink,
                        fontSize: 17,
                        fontWeight: FontWeight.w800)),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(spacing: 14, runSpacing: 14, children: fields),
          ],
        ),
      );

  Future<void> _pickDate(String key) async {
    final picked = await showPersianDatePicker(
      context: context,
      initialDate: DateTime.now(),
    );
    if (picked == null) return;
    final jalali = Gregorian(picked.year, picked.month, picked.day).toJalali();
    _c(key).text =
        '${jalali.year}/${jalali.month.toString().padLeft(2, '0')}/${jalali.day.toString().padLeft(2, '0')}';
  }

  String _toGregorianDate(String value) {
    final parts = value.split('/');
    if (parts.length != 3) return value.trim();
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (year == null || month == null || day == null) return value.trim();
    try {
      final date = Jalali(year, month, day).toGregorian();
      return '${date.year.toString().padLeft(4, '0')}-'
          '${date.month.toString().padLeft(2, '0')}-'
          '${date.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return value.trim();
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedRaste == null) {
      showAdminSnack(context, 'رسته واحد صنفی را انتخاب کنید', error: true);
      return;
    }
    if (_selectedState == null || _selectedCity == null) {
      showAdminSnack(context, 'استان و شهرستان را انتخاب کنید', error: true);
      return;
    }
    if (_c('lat_store').text.trim().isEmpty ||
        _c('long_store').text.trim().isEmpty) {
      showAdminSnack(context, 'موقعیت روی نقشه را مشخص کنید', error: true);
      return;
    }
    setState(() => _saving = true);
    final body = <String, dynamic>{
      'code_co': widget.codeCo,
      'name_admin': _c('name_admin').text.trim(),
      'family_admin': _c('family_admin').text.trim(),
      'sex_admin': _sex,
      'sadere_admin': _c('sadere_admin').text.trim(),
      'tavalod_admin': _c('tavalod_admin').text.trim(),
      'name_pedar_admin': _c('name_pedar_admin').text.trim(),
      'num_shenasname_admin': _c('num_shenasname_admin').text.trim(),
      'code_meli_admin': _c('code_meli_admin').text.trim(),
      'mob_admin': _c('mob_admin').text.trim(),
      'tel_admin': _c('tel_admin').text.trim(),
      'madrak_admin': _c('madrak_admin').text.trim(),
      'din_admin': _c('din_admin').text.trim(),
      'sarbazi_admin': _c('sarbazi_admin').text.trim(),
      'taahol_admin': _c('taahol_admin').text.trim(),
      'name_store': _c('name_store').text.trim(),
      'shenase_store': _c('shenase_store').text.trim(),
      'raste_store': _selectedRaste,
      'masahat_store': _c('masahat_store').text.trim(),
      'type_melki_store': _ownership,
      'address_store': _c('address_store').text.trim(),
      'code_posti_store': _c('code_posti_store').text.trim(),
      'mantaghe_store': _c('mantaghe_store').text.trim(),
      'lat_store': _c('lat_store').text.trim(),
      'long_store': _c('long_store').text.trim(),
      'state_store': _selectedState,
      'city_store': _selectedCity,
      'date_sodor_store': _toGregorianDate(_c('date_sodor_store').text.trim()),
      'date_exp_store': _toGregorianDate(_c('date_exp_store').text.trim()),
      'date_etebar_store': _licenseValidity,
      'daraje_store': _c('daraje_store').text.trim(),
      'num_parvande_store': _c('num_parvande_store').text.trim(),
      'vaziyat_store': _codeForVaziyatLabel(_vaziyatLabel),
      'lbl_vaziyat_store': _vaziyatLabel,
      'num_person_store': _c('num_person_store').text.trim(),
      'caption_parvande': _c('caption_parvande').text.trim(),
      'id_user': widget.idUser,
      'act_parvande': '1',
    };
    try {
      final response = await http.post(
        Uri.parse(getApiUrl('insert/insert_parvande')),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
        body: jsonEncode(body),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
      if (!mounted) return;
      showAdminSnack(context, 'پرونده جدید با موفقیت ثبت شد');
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        showAdminSnack(context, 'خطا در ثبت پرونده: $e', error: true);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  bool get _isQuick => widget.registerMode == ParvandeRegisterMode.quick;

  Widget _vaziyatField() => SizedBox(
        width: 350,
        child: DropdownButtonFormField<String>(
          key: ValueKey('vaziyat-$_vaziyatLabel'),
          initialValue: _kParvandeStatusLabels.contains(_vaziyatLabel)
              ? _vaziyatLabel
              : _kParvandeStatusLabels.first,
          isExpanded: true,
          validator: (value) =>
              value == null || value.trim().isEmpty ? 'وضعیت پرونده الزامی است' : null,
          decoration: AdminUi.fieldDecoration('وضعیت پرونده', required: true),
          items: _kParvandeStatusLabels
              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
              .toList(),
          onChanged: (value) {
            if (value == null) return;
            setState(() => _vaziyatLabel = value);
          },
        ),
      );

  Widget _rasteField() => SizedBox(
        width: 350,
        child: DropdownButtonFormField<String>(
          key: ValueKey('raste-$_selectedRaste-${_raste.length}'),
          initialValue: _selectedRaste,
          isExpanded: true,
          validator: (value) => value == null ? 'انتخاب رسته الزامی است' : null,
          decoration: AdminUi.fieldDecoration(
            'رسته',
            required: true,
            suffix: _loadingRaste
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : null,
          ),
          items: _raste
              .map(
                (e) => DropdownMenuItem(
                  value: e,
                  child: Text(e, overflow: TextOverflow.ellipsis, maxLines: 1),
                ),
              )
              .toList(),
          onChanged: _loadingRaste
              ? null
              : (value) => setState(() => _selectedRaste = value),
        ),
      );

  Widget _mapFields() => SizedBox(
        width: 724,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 14,
              runSpacing: 14,
              children: [
                _field('lat_store', 'عرض جغرافیایی', required: true, readOnly: true),
                _field('long_store', 'طول جغرافیایی', required: true, readOnly: true),
              ],
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonalIcon(
                onPressed: _openMapPicker,
                icon: const Icon(Icons.map_outlined),
                label: const Text('انتخاب موقعیت روی نقشه *'),
              ),
            ),
          ],
        ),
      );

  List<Widget> _quickFields() => [
        _section('ثبت سریع پرونده', Icons.flash_on_outlined, [
          _field('num_parvande_store', 'شماره پرونده',
              keyboard: TextInputType.number),
          _vaziyatField(),
          _field('name_admin', 'نام', required: true),
          _field('family_admin', 'نام خانوادگی', required: true),
          _field('code_meli_admin', 'کد ملی',
              required: true, keyboard: TextInputType.number),
          _field('mob_admin', 'شماره همراه',
              required: true, keyboard: TextInputType.phone),
          _field('name_store', 'نام واحد صنفی', required: true),
          _rasteField(),
          SearchablePlaceField(
            label: 'استان',
            options: _states,
            value: _selectedState,
            loading: _loadingStates,
            requiredField: true,
            onSelected: _onStateSelected,
          ),
          SearchablePlaceField(
            label: 'شهرستان',
            options: _cities,
            value: _selectedCity,
            enabled: _selectedState != null,
            loading: _loadingCities,
            requiredField: true,
            onSelected: (city) => setState(() => _selectedCity = city),
          ),
          _mapFields(),
          _field('address_store', 'آدرس کامل', required: true, lines: 3),
        ]),
      ];

  List<Widget> _fullFields() => [
        _section('اطلاعات مالک', Icons.person_outline, [
          _vaziyatField(),
          _field('name_admin', 'نام', required: true),
          _field('family_admin', 'نام خانوادگی', required: true),
          SizedBox(
            width: 350,
            child: DropdownButtonFormField<String>(
              initialValue: _sex,
              isExpanded: true,
              decoration: AdminUi.fieldDecoration('جنسیت'),
              items: const [
                DropdownMenuItem(value: 'مرد', child: Text('مرد')),
                DropdownMenuItem(value: 'زن', child: Text('زن')),
              ],
              onChanged: (value) => setState(() => _sex = value ?? _sex),
            ),
          ),
          _field('name_pedar_admin', 'نام پدر'),
          _field('code_meli_admin', 'کد ملی',
              required: true, keyboard: TextInputType.number),
          _field('num_shenasname_admin', 'شماره شناسنامه',
              keyboard: TextInputType.number),
          _field('sadere_admin', 'محل صدور'),
          _field('tavalod_admin', 'تاریخ تولد', date: true),
          _field('mob_admin', 'شماره همراه',
              required: true, keyboard: TextInputType.phone),
          _field('tel_admin', 'تلفن ثابت', keyboard: TextInputType.phone),
          _field('madrak_admin', 'مدرک تحصیلی'),
          _field('din_admin', 'دین'),
          _field('sarbazi_admin', 'وضعیت نظام وظیفه'),
          _field('taahol_admin', 'وضعیت تأهل'),
        ]),
        const SizedBox(height: 14),
        _section('اطلاعات واحد صنفی', Icons.store_outlined, [
          _field('name_store', 'نام واحد صنفی', required: true),
          _field('shenase_store', 'شناسه واحد'),
          _rasteField(),
          _field('masahat_store', 'مساحت', keyboard: TextInputType.number),
          SizedBox(
            width: 350,
            child: DropdownButtonFormField<String>(
              initialValue: _ownership,
              isExpanded: true,
              decoration: AdminUi.fieldDecoration('نوع مالکیت'),
              items: const [
                DropdownMenuItem(value: 'ملکی', child: Text('ملکی')),
                DropdownMenuItem(value: 'استیجاری', child: Text('استیجاری')),
              ],
              onChanged: (value) =>
                  setState(() => _ownership = value ?? _ownership),
            ),
          ),
          _field('num_person_store', 'تعداد کارکنان',
              keyboard: TextInputType.number),
          _field('daraje_store', 'درجه واحد'),
          _field('num_parvande_store', 'شماره پرونده'),
        ]),
        const SizedBox(height: 14),
        _section('نشانی واحد صنفی', Icons.location_on_outlined, [
          SearchablePlaceField(
            label: 'استان',
            options: _states,
            value: _selectedState,
            loading: _loadingStates,
            requiredField: true,
            onSelected: _onStateSelected,
          ),
          SearchablePlaceField(
            label: 'شهرستان',
            options: _cities,
            value: _selectedCity,
            enabled: _selectedState != null,
            loading: _loadingCities,
            requiredField: true,
            onSelected: (city) => setState(() => _selectedCity = city),
          ),
          _field('mantaghe_store', 'منطقه'),
          _field('code_posti_store', 'کد پستی', keyboard: TextInputType.number),
          _mapFields(),
          _field('address_store', 'آدرس کامل', required: true, lines: 3),
        ]),
        const SizedBox(height: 14),
        _section('اطلاعات پروانه', Icons.badge_outlined, [
          _field('date_sodor_store', 'تاریخ صدور', date: true),
          _field('date_exp_store', 'تاریخ انقضا', date: true),
          SizedBox(
            width: 350,
            child: DropdownButtonFormField<String>(
              initialValue: _licenseValidity,
              isExpanded: true,
              decoration: AdminUi.fieldDecoration('اعتبار پروانه'),
              items: const [
                DropdownMenuItem(value: 'ده ساله', child: Text('ده ساله')),
                DropdownMenuItem(value: 'پنج ساله', child: Text('پنج ساله')),
                DropdownMenuItem(value: 'یک ساله', child: Text('یک ساله')),
              ],
              onChanged: (value) =>
                  setState(() => _licenseValidity = value ?? _licenseValidity),
            ),
          ),
          _field('caption_parvande', 'توضیحات پرونده', lines: 3),
        ]),
      ];

  @override
  Widget build(BuildContext context) {
    return AdminPageShell(
      title: _isQuick ? 'ثبت سریع پرونده' : 'پرونده جدید',
      subtitle: _isQuick
          ? 'فقط فیلدهای ستاره‌دار / اجباری'
          : 'ثبت مالک و واحد صنفی — فیلدهای ستاره‌دار الزامی هستند',
      icon: _isQuick ? Icons.flash_on_outlined : Icons.create_new_folder_outlined,
      maxWidth: 1100,
      child: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            ...(_isQuick ? _quickFields() : _fullFields()),
            const SizedBox(height: 18),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                onPressed: _saving ? null : _submit,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(_isQuick ? 'ثبت سریع' : 'ثبت پرونده'),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
