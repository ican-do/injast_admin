import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:injast_admin/features/parvande_new/location_pick_dialog.dart';
import 'package:injast_admin/features/parvande_new/place_api.dart';
import 'package:injast_admin/features/parvande_new/searchable_place_field.dart';
import 'package:injast_admin/features/shared/admin_ui.dart';
import 'package:injast_admin/features/union_settings/union_settings_api.dart';
import 'package:injast_admin/server_config.dart';

class UnionSettingsPage extends StatefulWidget {
  const UnionSettingsPage({super.key, required this.codeCo});

  final String codeCo;

  @override
  State<UnionSettingsPage> createState() => _UnionSettingsPageState();
}

class _UnionSettingsPageState extends State<UnionSettingsPage> {
  final _name = TextEditingController();
  final _type = TextEditingController();
  final _tel1 = TextEditingController();
  final _tel2 = TextEditingController();
  final _mob1 = TextEditingController();
  final _mob2 = TextEditingController();
  final _moaref = TextEditingController();
  final _address = TextEditingController();
  final _lat = TextEditingController();
  final _lng = TextEditingController();
  final _note = TextEditingController();
  final _managerName = TextEditingController();
  final _managerFamily = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  bool _loadingStates = true;
  bool _loadingCities = false;
  String? _error;
  String _logoPath = '';
  List<String> _states = [];
  List<String> _cities = [];
  String? _selectedState;
  String? _selectedCity;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in [
      _name, _type, _tel1, _tel2, _mob1, _mob2,
      _moaref, _address, _lat, _lng, _note, _managerName, _managerFamily,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  String _t(dynamic v) {
    final s = v?.toString().trim() ?? '';
    if (s == 'null' || s == '0') return '';
    return s;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await UnionSettingsApi.instance.fetch(widget.codeCo);
      _name.text = _t(data['name_co']);
      _type.text = _t(data['lbl_type']);
      _tel1.text = _t(data['tel1_co']);
      _tel2.text = _t(data['tel2_co']);
      _mob1.text = _t(data['mob1_co']);
      _mob2.text = _t(data['mob2_co']);
      _moaref.text = _t(data['code_moaref_co']);
      _address.text = _t(data['address_co']);
      _lat.text = _t(data['lat_co']);
      _lng.text = _t(data['long_co']);
      _note.text = _t(data['shekayat_form_note']);
      _managerName.text = _t(data['manager_name']);
      _managerFamily.text = _t(data['manager_family']);
      _logoPath = _t(data['logo_url']);
      await _loadPlaces(_t(data['state_co']), _t(data['city_co']));
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _pickLogo() async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 88,
      );
      if (picked == null) return;
      setState(() => _saving = true);
      _logoPath = await UnionSettingsApi.instance.uploadLogo(widget.codeCo, picked);
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لوگو بارگذاری شد. برای اعمال، ذخیره کنید.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('نام اتحادیه را وارد کنید')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final saved = await UnionSettingsApi.instance.save(widget.codeCo, {
        'name_co': _name.text.trim(),
        'lbl_type': _type.text.trim(),
        'state_co': (_selectedState ?? '').trim(),
        'city_co': (_selectedCity ?? '').trim(),
        'tel1_co': _tel1.text.trim(),
        'tel2_co': _tel2.text.trim(),
        'mob1_co': _mob1.text.trim(),
        'mob2_co': _mob2.text.trim(),
        'code_moaref_co': _moaref.text.trim(),
        'address_co': _address.text.trim(),
        'lat_co': _lat.text.trim(),
        'long_co': _lng.text.trim(),
        'shekayat_form_note': _note.text.trim(),
        'logo_url': _logoPath,
        'manager_name': _managerName.text.trim(),
        'manager_family': _managerFamily.text.trim(),
      });
      _logoPath = _t(saved['logo_url']);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اطلاعات اتحادیه ذخیره شد')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
    if (mounted) setState(() => _saving = false);
  }

  String? _matchPlace(String raw, List<String> options) {
    final t = raw.trim();
    if (t.isEmpty) return null;
    for (final o in options) {
      if (o == t || o.contains(t) || t.contains(o)) return o;
    }
    return t;
  }

  Future<void> _loadPlaces(String state, String city) async {
    setState(() => _loadingStates = true);
    try {
      _states = await PlaceApi.readStates();
      final matchedState = _matchPlace(state, _states);
      _selectedState = matchedState;
      if (matchedState != null && matchedState.isNotEmpty) {
        _cities = await PlaceApi.readCities(matchedState);
        _selectedCity = _matchPlace(city, _cities);
      }
    } catch (e) {
      if (mounted) {
        showAdminSnack(context, 'خطا در دریافت استان/شهرستان: $e', error: true);
      }
    }
    if (mounted) setState(() => _loadingStates = false);
  }

  Future<void> _onStateSelected(String state) async {
    setState(() {
      _selectedState = state;
      _selectedCity = null;
      _loadingCities = true;
      _cities = [];
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
    final lat = double.tryParse(_lat.text.trim());
    final lng = double.tryParse(_lng.text.trim());
    final result = await LocationPickDialog.show(
      context,
      initialLat: lat,
      initialLng: lng,
      initialAddress: _address.text.trim(),
      biasQuery: [
        if ((_selectedState ?? '').isNotEmpty) _selectedState,
        if ((_selectedCity ?? '').isNotEmpty) _selectedCity,
      ].join('، '),
    );
    if (result == null || !mounted) return;
    setState(() {
      _lat.text = result.latitude.toStringAsFixed(6);
      _lng.text = result.longitude.toStringAsFixed(6);
      if (result.address.isNotEmpty) {
        _address.text = result.address;
      }
    });
  }

  Widget _field(TextEditingController c, String label, {int maxLines = 1, bool readOnly = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c,
        maxLines: maxLines,
        readOnly: readOnly,
        decoration: AdminUi.fieldDecoration(label),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final logoUrl = _logoPath.isEmpty ? '' : getStaticFileUrl(_logoPath);
    return AdminPageShell(
      title: 'تنظیمات اتحادیه',
      subtitle: 'ویرایش مشخصات ثبت‌شده اتحادیه — کد غیرقابل تغییر است',
      icon: Icons.apartment_outlined,
      actions: [
        FilledButton.icon(
          onPressed: _saving || _loading ? null : _save,
          icon: const Icon(Icons.save_outlined, size: 18),
          label: const Text('ذخیره'),
        ),
      ],
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!),
                      const SizedBox(height: 12),
                      FilledButton(onPressed: _load, child: const Text('تلاش دوباره')),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: AdminUi.cardDecoration(),
                          child: Column(
                            children: [
                              ClipOval(
                                child: Container(
                                  width: 96,
                                  height: 96,
                                  color: const Color(0xFFE8EEF6),
                                  child: logoUrl.isEmpty
                                      ? const Icon(Icons.apartment, size: 42)
                                      : Image.network(logoUrl, fit: BoxFit.cover),
                                ),
                              ),
                              const SizedBox(height: 10),
                              const Text(
                                'لوگوی اتحادیه برای همه گزارش‌ها — PNG یا JPG مربعی (حدود ۵۱۲ تا ۸۰۰ پیکسل)',
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              OutlinedButton.icon(
                                onPressed: _saving ? null : _pickLogo,
                                icon: const Icon(Icons.image_outlined),
                                label: const Text('انتخاب لوگو'),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        InputDecorator(
                          decoration: AdminUi.fieldDecoration('کد اتحادیه (غیرقابل ویرایش)'),
                          child: Text(widget.codeCo),
                        ),
                        const SizedBox(height: 12),
                        _field(_name, 'نام اتحادیه'),
                        _field(_type, 'دسته / نوع صنف'),
                        _field(_managerName, 'نام مدیر'),
                        _field(_managerFamily, 'نام خانوادگی مدیر'),
                        _field(_tel1, 'تلفن ثابت ۱'),
                        _field(_tel2, 'تلفن ثابت ۲'),
                        _field(_mob1, 'همراه ۱'),
                        _field(_mob2, 'همراه ۲'),
                        Container(
                          padding: const EdgeInsets.all(16),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: AdminUi.cardDecoration(
                            color: const Color(0xFFF0F7FB),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text(
                                'آدرس و موقعیت مکانی',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'استان، شهرستان، آدرس متنی و انتخاب موقعیت روی نقشه',
                                style: TextStyle(color: AdminUi.muted, fontSize: 12),
                              ),
                              const SizedBox(height: 12),
                              SearchablePlaceField(
                                label: 'استان',
                                options: _states,
                                value: _selectedState,
                                loading: _loadingStates,
                                requiredField: true,
                                onSelected: _onStateSelected,
                              ),
                              const SizedBox(height: 12),
                              SearchablePlaceField(
                                label: 'شهرستان',
                                options: _cities,
                                value: _selectedCity,
                                enabled: _selectedState != null,
                                loading: _loadingCities,
                                requiredField: true,
                                onSelected: (city) =>
                                    setState(() => _selectedCity = city),
                              ),
                              const SizedBox(height: 12),
                              _field(_address, 'آدرس کامل', maxLines: 3),
                              Wrap(
                                spacing: 14,
                                runSpacing: 14,
                                children: [
                                  _field(_lat, 'عرض جغرافیایی', readOnly: true),
                                  _field(_lng, 'طول جغرافیایی', readOnly: true),
                                ],
                              ),
                              Align(
                                alignment: Alignment.centerRight,
                                child: FilledButton.tonalIcon(
                                  onPressed: _saving ? null : _openMapPicker,
                                  icon: const Icon(Icons.map_outlined),
                                  label: const Text('انتخاب آدرس و موقعیت روی نقشه'),
                                ),
                              ),
                            ],
                          ),
                        ),
                        _field(_moaref, 'کد معرف'),
                        _field(_note, 'توضیح فرم شکایت', maxLines: 3),
                      ],
                    ),
                  ),
                ),
    );
  }
}
