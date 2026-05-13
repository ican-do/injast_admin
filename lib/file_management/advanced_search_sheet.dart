import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:injast_admin/file_management/parvande_api.dart';

/// مدل فیلترهای جستجوی حرفه‌ای؛ همگی in-memory روی نتیجهٔ اولیه API اعمال می‌شود.
class AdvancedFilters {
  AdvancedFilters({
    this.name = '',
    this.family = '',
    this.codeMeli = '',
    this.storeName = '',
    this.shenase = '',
    this.codePosti = '',
    this.numParvande = '',
    this.cityOrMantaghe = '',
    this.mobile = '',
    this.statusVaziyat = '',
    this.rasteSet = const <String>{},
    this.duplicateCodeMeli = false,
    this.duplicateCodePosti = false,
    this.sameRaste = false,
    this.withoutLocation = false,
  });

  String name;
  String family;
  String codeMeli;
  String storeName;
  String shenase;
  String codePosti;
  String numParvande;
  String cityOrMantaghe;
  String mobile;
  String statusVaziyat;
  Set<String> rasteSet;
  bool duplicateCodeMeli;
  bool duplicateCodePosti;
  bool sameRaste;
  bool withoutLocation;

  bool get isEmpty =>
      name.isEmpty &&
      family.isEmpty &&
      codeMeli.isEmpty &&
      storeName.isEmpty &&
      shenase.isEmpty &&
      codePosti.isEmpty &&
      numParvande.isEmpty &&
      cityOrMantaghe.isEmpty &&
      mobile.isEmpty &&
      statusVaziyat.isEmpty &&
      rasteSet.isEmpty &&
      !duplicateCodeMeli &&
      !duplicateCodePosti &&
      !sameRaste &&
      !withoutLocation;

  AdvancedFilters copy() => AdvancedFilters(
        name: name,
        family: family,
        codeMeli: codeMeli,
        storeName: storeName,
        shenase: shenase,
        codePosti: codePosti,
        numParvande: numParvande,
        cityOrMantaghe: cityOrMantaghe,
        mobile: mobile,
        statusVaziyat: statusVaziyat,
        rasteSet: {...rasteSet},
        duplicateCodeMeli: duplicateCodeMeli,
        duplicateCodePosti: duplicateCodePosti,
        sameRaste: sameRaste,
        withoutLocation: withoutLocation,
      );

  /// اعمال فیلترها روی لیست پرونده‌ها
  List<Map<String, dynamic>> apply(List<Map<String, dynamic>> source) {
    Iterable<Map<String, dynamic>> r = source;

    bool match(String haystack, String needle) {
      if (needle.trim().isEmpty) return true;
      return haystack.toLowerCase().contains(needle.trim().toLowerCase());
    }

    r = r.where((p) {
      if (!match(p.s('name_admin'), name)) return false;
      if (!match(p.s('family_admin'), family)) return false;
      if (!match(p.codeMeli, codeMeli)) return false;
      if (!match(p.storeName, storeName)) return false;
      if (!match(p.shenase, shenase)) return false;
      if (!match(p.codePosti, codePosti)) return false;
      if (!match(p.numParvande, numParvande)) return false;
      if (cityOrMantaghe.isNotEmpty &&
          !match('${p.city} ${p.mantaghe}', cityOrMantaghe)) {
        return false;
      }
      if (!match(p.mob, mobile)) return false;
      if (statusVaziyat.isNotEmpty && p.vaziyat != statusVaziyat) return false;
      if (rasteSet.isNotEmpty && !rasteSet.contains(p.raste)) return false;
      if (withoutLocation && p.hasLocation) return false;
      return true;
    });

    final list = r.toList();

    if (duplicateCodeMeli) {
      final counts = <String, int>{};
      for (final p in source) {
        if (p.codeMeli.isNotEmpty) {
          counts[p.codeMeli] = (counts[p.codeMeli] ?? 0) + 1;
        }
      }
      list.removeWhere((p) => p.codeMeli.isEmpty || (counts[p.codeMeli] ?? 0) < 2);
    }

    if (duplicateCodePosti) {
      final counts = <String, int>{};
      for (final p in source) {
        if (p.codePosti.isNotEmpty) {
          counts[p.codePosti] = (counts[p.codePosti] ?? 0) + 1;
        }
      }
      list.removeWhere((p) => p.codePosti.isEmpty || (counts[p.codePosti] ?? 0) < 2);
    }

    if (sameRaste && rasteSet.length == 1) {
      final raste = rasteSet.first;
      list.removeWhere((p) => p.raste != raste);
    }

    return list;
  }
}

class AdvancedSearchSheet extends StatefulWidget {
  const AdvancedSearchSheet({
    super.key,
    required this.initial,
    required this.allRasteOptions,
    required this.allVaziyatOptions,
  });

  final AdvancedFilters initial;
  final List<String> allRasteOptions;
  final List<String> allVaziyatOptions;

  @override
  State<AdvancedSearchSheet> createState() => _AdvancedSearchSheetState();
}

class _AdvancedSearchSheetState extends State<AdvancedSearchSheet> {
  late AdvancedFilters _f;
  final _ctrlName = TextEditingController();
  final _ctrlFamily = TextEditingController();
  final _ctrlCodeMeli = TextEditingController();
  final _ctrlStoreName = TextEditingController();
  final _ctrlShenase = TextEditingController();
  final _ctrlCodePosti = TextEditingController();
  final _ctrlNumParvande = TextEditingController();
  final _ctrlCityMantaghe = TextEditingController();
  final _ctrlMobile = TextEditingController();

  @override
  void initState() {
    super.initState();
    _f = widget.initial.copy();
    _ctrlName.text = _f.name;
    _ctrlFamily.text = _f.family;
    _ctrlCodeMeli.text = _f.codeMeli;
    _ctrlStoreName.text = _f.storeName;
    _ctrlShenase.text = _f.shenase;
    _ctrlCodePosti.text = _f.codePosti;
    _ctrlNumParvande.text = _f.numParvande;
    _ctrlCityMantaghe.text = _f.cityOrMantaghe;
    _ctrlMobile.text = _f.mobile;
  }

  @override
  void dispose() {
    _ctrlName.dispose();
    _ctrlFamily.dispose();
    _ctrlCodeMeli.dispose();
    _ctrlStoreName.dispose();
    _ctrlShenase.dispose();
    _ctrlCodePosti.dispose();
    _ctrlNumParvande.dispose();
    _ctrlCityMantaghe.dispose();
    _ctrlMobile.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height;
    return SafeArea(
      child: Container(
        constraints: BoxConstraints(maxHeight: h * 0.92),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _header(),
            const Divider(height: 1),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _section('فیلدهای متنی', _textFields()),
                    _section('وضعیت پروانه', _vaziyatChips()),
                    _section('رسته (چندانتخابی)', _rasteChips()),
                    _section('موارد خاص', _flagSwitches()),
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _clear,
                      icon: const Icon(Icons.cleaning_services_outlined),
                      label: const Text('پاک کردن'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _apply,
                      icon: const Icon(Icons.check),
                      label: const Text('اعمال فیلتر'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      child: Row(
        children: [
          const Icon(FluentIcons.filter_24_regular, color: Color(0xFF1E3A5F)),
          const SizedBox(width: 8),
          const Expanded(
            child: Text('جستجوی حرفه‌ای',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }

  Widget _section(String title, List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(title,
                style: const TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF1E3A5F))),
          ),
          ...children,
        ],
      ),
    );
  }

  List<Widget> _textFields() {
    InputDecoration dec(String label, IconData icon) => InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 18),
          isDense: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        );

    Widget wrap(List<Widget> w) =>
        Wrap(spacing: 8, runSpacing: 8, children: w.map((e) => SizedBox(width: 220, child: e)).toList());

    return [
      wrap([
        TextField(controller: _ctrlName, decoration: dec('نام', FluentIcons.person_24_regular)),
        TextField(controller: _ctrlFamily, decoration: dec('خانوادگی', FluentIcons.person_24_regular)),
        TextField(
            controller: _ctrlCodeMeli,
            decoration: dec('کد ملی', FluentIcons.person_passkey_24_regular)),
        TextField(controller: _ctrlMobile, decoration: dec('موبایل', FluentIcons.call_24_regular)),
        TextField(
            controller: _ctrlStoreName,
            decoration: dec('نام واحد', FluentIcons.building_shop_24_regular)),
        TextField(
            controller: _ctrlShenase,
            decoration: dec('شناسه صنفی', FluentIcons.tag_24_regular)),
        TextField(
            controller: _ctrlCodePosti,
            decoration: dec('کد پستی', FluentIcons.mail_24_regular)),
        TextField(
            controller: _ctrlNumParvande,
            decoration: dec('شماره پرونده', FluentIcons.document_24_regular)),
        TextField(
            controller: _ctrlCityMantaghe,
            decoration: dec('شهر/منطقه', FluentIcons.location_24_regular)),
      ]),
    ];
  }

  List<Widget> _vaziyatChips() {
    final options = ['', ...widget.allVaziyatOptions.where((e) => e.trim().isNotEmpty)];
    return [
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: options.map((o) {
          final selected = _f.statusVaziyat == o;
          return ChoiceChip(
            label: Text(o.isEmpty ? 'همه' : o),
            selected: selected,
            onSelected: (_) => setState(() => _f.statusVaziyat = o),
          );
        }).toList(),
      ),
    ];
  }

  List<Widget> _rasteChips() {
    final options = widget.allRasteOptions.where((e) => e.trim().isNotEmpty).toList()..sort();
    if (options.isEmpty) {
      return [const Text('—', style: TextStyle(color: Colors.black54))];
    }
    return [
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: options.map((o) {
          final selected = _f.rasteSet.contains(o);
          return FilterChip(
            label: Text(o),
            selected: selected,
            onSelected: (v) {
              setState(() {
                if (v) {
                  _f.rasteSet.add(o);
                } else {
                  _f.rasteSet.remove(o);
                }
              });
            },
          );
        }).toList(),
      ),
    ];
  }

  List<Widget> _flagSwitches() {
    return [
      _switch('کدملی تکراری', _f.duplicateCodeMeli, (v) => _f.duplicateCodeMeli = v),
      _switch('کدپستی تکراری', _f.duplicateCodePosti, (v) => _f.duplicateCodePosti = v),
      _switch('فقط رستهٔ یکسان (نیاز به انتخاب یک رسته)', _f.sameRaste, (v) => _f.sameRaste = v),
      _switch('بدون لوکیشن', _f.withoutLocation, (v) => _f.withoutLocation = v),
    ];
  }

  Widget _switch(String label, bool value, ValueChanged<bool> onChange) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      value: value,
      title: Text(label, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
      onChanged: (v) => setState(() => onChange(v)),
    );
  }

  void _clear() {
    setState(() {
      _ctrlName.clear();
      _ctrlFamily.clear();
      _ctrlCodeMeli.clear();
      _ctrlStoreName.clear();
      _ctrlShenase.clear();
      _ctrlCodePosti.clear();
      _ctrlNumParvande.clear();
      _ctrlCityMantaghe.clear();
      _ctrlMobile.clear();
      _f = AdvancedFilters();
    });
  }

  void _apply() {
    _f.name = _ctrlName.text;
    _f.family = _ctrlFamily.text;
    _f.codeMeli = _ctrlCodeMeli.text;
    _f.storeName = _ctrlStoreName.text;
    _f.shenase = _ctrlShenase.text;
    _f.codePosti = _ctrlCodePosti.text;
    _f.numParvande = _ctrlNumParvande.text;
    _f.cityOrMantaghe = _ctrlCityMantaghe.text;
    _f.mobile = _ctrlMobile.text;
    Navigator.pop(context, _f);
  }
}
