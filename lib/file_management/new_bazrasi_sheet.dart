import 'package:flutter/material.dart';
import 'package:injast_admin/file_management/bazrasi_local_store.dart';
import 'package:injast_admin/file_management/bazrasi_violations.dart';
import 'package:injast_admin/file_management/local_calendar_store.dart';
import 'package:injast_admin/file_management/parvande_bazrasi_api.dart';
import 'package:injast_admin/file_management/parvande_api.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:uuid/uuid.dart';

/// فرم ثبت بازرسی جدید — bottom sheet فشرد
class NewBazrasiSheet extends StatefulWidget {
  const NewBazrasiSheet({
    super.key,
    required this.codeCo,
    required this.parvande,
    required this.offline,
    this.userId,
  });

  final String codeCo;
  final Map<String, dynamic> parvande;
  final bool offline;
  final String? userId;

  static Future<bool?> show(
    BuildContext context, {
    required String codeCo,
    required Map<String, dynamic> parvande,
    required bool offline,
    String? userId,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => NewBazrasiSheet(
        codeCo: codeCo,
        parvande: parvande,
        offline: offline,
        userId: userId,
      ),
    );
  }

  @override
  State<NewBazrasiSheet> createState() => _NewBazrasiSheetState();
}

class _NewBazrasiSheetState extends State<NewBazrasiSheet> {
  static const _accent = Color(0xFF1E3A5F);

  final _shenaseCtrl = TextEditingController();
  final _dayCtrl = TextEditingController();
  final _captionCtrl = TextEditingController();

  static const _vaziyatOptions = [
    'دردست اقدام',
    'فعال/صادر شده',
    'منقضی شده',
    'ابطال',
    'تغییر نشانی',
    'فاقد پروانه',
    'دارای پروانه',
  ];

  late List<bool> _checkedViolations;
  late String _vaziyat;
  late String _dateJalali;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _checkedViolations = List<bool>.filled(kBazrasiViolationItems.length, false);
    final j = Jalali.now();
    _dateJalali =
        '${j.year}/${j.month.toString().padLeft(2, '0')}/${j.day.toString().padLeft(2, '0')}';
    _vaziyat = 'دارای پروانه';
  }

  @override
  void dispose() {
    _shenaseCtrl.dispose();
    _dayCtrl.dispose();
    _captionCtrl.dispose();
    super.dispose();
  }

  List<String> get _selectedViolations {
    final out = <String>[];
    for (var i = 0; i < kBazrasiViolationItems.length; i++) {
      if (_checkedViolations[i]) out.add(kBazrasiViolationItems[i]);
    }
    return out;
  }

  int get _selectedCount => _checkedViolations.where((e) => e).length;

  String _toMiladi(String jalali) {
    final parts = jalali.replaceAll('-', '/').split('/');
    if (parts.length != 3) return jalali;
    final y = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final d = int.tryParse(parts[2]);
    if (y == null || m == null || d == null) return jalali;
    final g = Jalali(y, m, d).toGregorian();
    return '${g.year}-${g.month.toString().padLeft(2, '0')}-${g.day.toString().padLeft(2, '0')}';
  }

  DateTime? _deadlineDate(String miladiDate, String dayText) {
    final parts = miladiDate.split('-');
    if (parts.length != 3) return null;
    final y = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final d = int.tryParse(parts[2]);
    if (y == null || m == null || d == null) return null;
    final days = int.tryParse(dayText.trim()) ?? 0;
    return DateTime(y, m, d).add(Duration(days: days));
  }

  Future<void> _save() async {
    if (_shenaseCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('شماره/شناسه بازرسی نباید خالی باشد.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final codeBazrasi = const Uuid().v4();
      final idParvandeh = widget.parvande.idParvandeh;
      final dateMiladi = _toMiladi(_dateJalali);
      final typeTakhalof = encodeBazrasiTypeTakhalof(_selectedViolations);
      final shenase = _shenaseCtrl.text.trim();
      final dayText = _dayCtrl.text.trim();
      final caption = _captionCtrl.text.trim();

      final record = {
        'id_bazrasi': widget.offline ? BazrasiLocalStore(widget.codeCo).newLocalId() : codeBazrasi,
        'id_parvandeh': idParvandeh,
        'shenase_bazrasi': shenase,
        'date_sodor': dateMiladi,
        'vaziyat_bazrasi': _vaziyat,
        'day_bazrasi': dayText,
        'caption_bazrasi': caption,
        'type_takhalof': typeTakhalof,
      };

      if (widget.offline) {
        await BazrasiLocalStore(widget.codeCo).addPending(record);
      } else {
        await ParvandeBazrasiApi.instance.insert(
          codeCo: widget.codeCo,
          codeBazrasi: codeBazrasi,
          idParvandeh: idParvandeh,
          shenaseBazrasi: shenase,
          dateSodor: dateMiladi,
          vaziyatBazrasi: _vaziyat,
          dayBazrasi: dayText.isEmpty ? '0' : dayText,
          captionBazrasi: caption.isEmpty ? '0' : caption,
          dateAmaken: '0',
          numAmaken: '0',
          dateEjrayi: '0',
          numEjrayi: '0',
          idUser: widget.userId ?? '0',
          typeTakhalof: typeTakhalof,
        );
        await BazrasiLocalStore(widget.codeCo).addCached(record);
      }

      final deadline = _deadlineDate(dateMiladi, dayText);
      if (deadline != null) {
        await LocalCalendarStore.instance.addBazrasiReminder(
          codeCo: widget.codeCo,
          idParvandeh: idParvandeh,
          codeBazrasi: codeBazrasi,
          title: codeBazrasi,
          description: bazrasiReminderDescription(
            shenase: shenase,
            typeTakhalof: typeTakhalof,
          ),
          dueDate: deadline,
        );
      }

      if (!mounted) return;
      final msg = widget.offline
          ? 'بازرسی در حافظهٔ محلی ثبت شد.'
          : 'بازرسی ثبت شد${deadline != null ? '؛ یادآور تقویم ایجاد شد.' : '.'}';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطا: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickDate() async {
    final now = Jalali.now();
    final g = now.toGregorian();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(g.year, g.month, g.day),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      final j = Gregorian(picked.year, picked.month, picked.day).toJalali();
      setState(() {
        _dateJalali =
            '${j.year}/${j.month.toString().padLeft(2, '0')}/${j.day.toString().padLeft(2, '0')}';
      });
    }
  }

  InputDecoration _fieldDeco(String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      border: const OutlineInputBorder(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.parvande;
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottom),
        child: Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.88),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 8),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'ثبت بازرسی',
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                          ),
                          Text(
                            p.storeName.isNotEmpty ? p.storeName : p.fullName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: _saving ? null : () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              if (widget.offline)
                Container(
                  width: double.infinity,
                  color: Colors.orange.shade50,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  child: Text(
                    'آفلاین — در حافظهٔ محلی ذخیره می‌شود.',
                    style: TextStyle(fontSize: 11, color: Colors.orange.shade900),
                  ),
                ),
              Flexible(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
                  shrinkWrap: true,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: _pickDate,
                            child: InputDecorator(
                              decoration: _fieldDeco('تاریخ'),
                              child: Text(_dateJalali, style: const TextStyle(fontSize: 13)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: _vaziyat,
                            decoration: _fieldDeco('وضعیت پروانه'),
                            items: _vaziyatOptions
                                .map((e) => DropdownMenuItem(
                                      value: e,
                                      child: Text(e, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                                    ))
                                .toList(),
                            onChanged: (v) => setState(() => _vaziyat = v ?? _vaziyat),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextField(
                            controller: _shenaseCtrl,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(fontSize: 13),
                            decoration: _fieldDeco('شناسه بازرسی *'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: _dayCtrl,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(fontSize: 13),
                            decoration: _fieldDeco('مدت (روز)'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Theme(
                      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        title: Text(
                          'موارد بازرسی${_selectedCount > 0 ? ' ($_selectedCount)' : ''}',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                        ),
                        children: [
                          ...List.generate(kBazrasiViolationItems.length, (i) {
                            return CheckboxListTile(
                              value: _checkedViolations[i],
                              onChanged: (v) => setState(() => _checkedViolations[i] = v ?? false),
                              title: Text(
                                kBazrasiViolationItems[i],
                                style: const TextStyle(fontSize: 12),
                              ),
                              controlAffinity: ListTileControlAffinity.leading,
                              dense: true,
                              visualDensity: VisualDensity.compact,
                              contentPadding: EdgeInsets.zero,
                            );
                          }),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    TextField(
                      controller: _captionCtrl,
                      maxLines: 2,
                      minLines: 2,
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontSize: 13),
                      decoration: _fieldDeco('شرح تخلف', hint: 'توضیحات…'),
                    ),
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 4, 14, 10),
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: _accent,
                      minimumSize: const Size.fromHeight(42),
                    ),
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('ثبت بازرسی'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
