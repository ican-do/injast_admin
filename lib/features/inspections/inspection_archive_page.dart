import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:injast_admin/features/inspections/inspection_archive_api.dart';
import 'package:injast_admin/features/inspections/inspection_parvande_page.dart';
import 'package:injast_admin/features/shared/admin_ui.dart';
import 'package:injast_admin/file_management/jalali_date_util.dart';
import 'package:persian_datetimepickers/persian_datetimepickers.dart';

class InspectionArchivePage extends StatefulWidget {
  const InspectionArchivePage({
    super.key,
    required this.codeCo,
  });

  final String codeCo;

  @override
  State<InspectionArchivePage> createState() => _InspectionArchivePageState();
}

class _InspectionArchivePageState extends State<InspectionArchivePage> {
  final _search = TextEditingController();
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _forms = [];
  List<String> _rastes = [];
  List<Map<String, dynamic>> _inspectors = [];
  String _formId = '';
  String _raste = '';
  String _inspectorId = '';
  DateTime? _from;
  DateTime? _to;
  int _totalInspections = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  String? _ymd(DateTime? d) =>
      d == null ? null : JalaliDateUtil.formatGregorian(d);

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await InspectionArchiveApi.instance.fetchArchive(
        codeCo: widget.codeCo,
        q: _search.text,
        raste: _raste,
        formId: _formId,
        inspectorId: _inspectorId,
        from: _ymd(_from) ?? '',
        to: _ymd(_to) ?? '',
      );
      if (!mounted) return;
      setState(() {
        _items = ((data['parvandes'] as List?) ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _forms = ((data['forms'] as List?) ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _rastes = ((data['rastes'] as List?) ?? [])
            .map((e) => e.toString())
            .where((e) => e.isNotEmpty)
            .toList();
        _inspectors = ((data['inspectors'] as List?) ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _totalInspections = int.tryParse('${data['total_inspections'] ?? 0}') ?? 0;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickDate({required bool from}) async {
    final picked = await showPersianDatePicker(
      context: context,
      initialDate: DateTime.now(),
    );
    if (picked == null) return;
    setState(() {
      if (from) {
        _from = picked;
      } else {
        _to = picked;
      }
    });
    _load();
  }

  String _jalaliOf(DateTime? d) {
    if (d == null) return '';
    return JalaliDateUtil.formatFromDateTime(d);
  }

  @override
  Widget build(BuildContext context) {
    return AdminPageShell(
      title: 'آرشیو بازرسی‌ها',
      subtitle: '${_items.length} پرونده • $_totalInspections بازرسی',
      icon: FluentIcons.clipboard_search_24_regular,
      maxWidth: 1280,
      actions: [
        IconButton(
          onPressed: _loading ? null : _load,
          icon: const Icon(Icons.refresh),
          tooltip: 'بروزرسانی',
        ),
      ],
      child: Column(
        children: [
          _filters(),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Text(_error!))
                    : _items.isEmpty
                        ? const Center(child: Text('بازرسی یا پرونده‌ای مطابق فیلتر یافت نشد'))
                        : LayoutBuilder(
                            builder: (context, c) {
                              final cols = c.maxWidth >= 1200
                                  ? 3
                                  : c.maxWidth >= 800
                                      ? 2
                                      : 1;
                              return GridView.builder(
                                padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
                                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: cols,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                  childAspectRatio: 1.55,
                                ),
                                itemCount: _items.length,
                                itemBuilder: (_, i) => _card(_items[i]),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }

  Widget _filters() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: AdminUi.cardDecoration(),
        child: Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 280,
              child: TextField(
                controller: _search,
                onSubmitted: (_) => _load(),
                decoration: AdminUi.fieldDecoration(
                  'جستجوی پرونده',
                  hint: 'شناسه صنفی، نام، نام خانوادگی، کد ملی، همراه...',
                  suffix: IconButton(
                    onPressed: _load,
                    icon: const Icon(Icons.search),
                  ),
                ),
              ),
            ),
            SizedBox(
              width: 220,
              child: DropdownButtonFormField<String>(
                initialValue: _raste.isEmpty ? '' : _raste,
                isExpanded: true,
                decoration: AdminUi.fieldDecoration('رسته'),
                items: [
                  const DropdownMenuItem(value: '', child: Text('همه رسته‌ها')),
                  ..._rastes.map((e) => DropdownMenuItem(value: e, child: Text(e))),
                ],
                onChanged: (v) {
                  setState(() => _raste = v ?? '');
                  _load();
                },
              ),
            ),
            SizedBox(
              width: 220,
              child: DropdownButtonFormField<String>(
                initialValue: _formId.isEmpty ? '' : _formId,
                isExpanded: true,
                decoration: AdminUi.fieldDecoration('نوع بازرسی'),
                items: [
                  const DropdownMenuItem(value: '', child: Text('همه انواع')),
                  ..._forms.map(
                    (e) => DropdownMenuItem(
                      value: e['id']?.toString() ?? '',
                      child: Text(e['name']?.toString() ?? 'فرم'),
                    ),
                  ),
                ],
                onChanged: (v) {
                  setState(() => _formId = v ?? '');
                  _load();
                },
              ),
            ),
            SizedBox(
              width: 220,
              child: DropdownButtonFormField<String>(
                initialValue: _inspectorId.isEmpty ? '' : _inspectorId,
                isExpanded: true,
                decoration: AdminUi.fieldDecoration('بازرس'),
                items: [
                  const DropdownMenuItem(value: '', child: Text('همه بازرسان')),
                  ..._inspectors.map(
                    (e) => DropdownMenuItem(
                      value: e['id']?.toString() ?? '',
                      child: Text(e['name']?.toString() ?? 'بازرس'),
                    ),
                  ),
                ],
                onChanged: (v) {
                  setState(() => _inspectorId = v ?? '');
                  _load();
                },
              ),
            ),
            OutlinedButton.icon(
              onPressed: () => _pickDate(from: true),
              icon: const Icon(Icons.date_range),
              label: Text(_from == null ? 'از تاریخ' : _jalaliOf(_from)),
            ),
            OutlinedButton.icon(
              onPressed: () => _pickDate(from: false),
              icon: const Icon(Icons.event),
              label: Text(_to == null ? 'تا تاریخ' : _jalaliOf(_to)),
            ),
            if (_from != null || _to != null || _raste.isNotEmpty || _formId.isNotEmpty || _inspectorId.isNotEmpty || _search.text.isNotEmpty)
              TextButton(
                onPressed: () {
                  _search.clear();
                  setState(() {
                    _from = null;
                    _to = null;
                    _raste = '';
                    _formId = '';
                    _inspectorId = '';
                  });
                  _load();
                },
                child: const Text('پاک کردن فیلتر'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _card(Map<String, dynamic> p) {
    final forms = ((p['by_form'] as List?) ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final name = (p['name_store']?.toString().trim().isNotEmpty == true)
        ? p['name_store'].toString()
        : (p['person_name']?.toString() ?? '—');
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => InspectionParvandePage(
                codeCo: widget.codeCo,
                idParvande: p['id_parvande']?.toString() ?? '',
              ),
            ),
          );
        },
        child: Ink(
          decoration: AdminUi.cardDecoration(),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: AdminUi.ink,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1565C0).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${p['total_fills'] ?? 0} بازرسی',
                        style: const TextStyle(
                          color: Color(0xFF1565C0),
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  p['person_name']?.toString() ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    if ((p['shenase_store']?.toString() ?? '').isNotEmpty)
                      'شناسه ${p['shenase_store']}',
                    if ((p['raste_store']?.toString() ?? '').isNotEmpty) p['raste_store'],
                  ].join(' • '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AdminUi.muted, fontSize: 12.5),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: forms.take(6).map((f) {
                      return Chip(
                        visualDensity: VisualDensity.compact,
                        label: Text(
                          '${f['form_name'] ?? 'فرم'} (${f['count'] ?? 0})',
                          style: const TextStyle(fontSize: 11),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'مشاهده جزئیات و فرم‌ها',
                    style: TextStyle(color: Color(0xFF1565C0), fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
