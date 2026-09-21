import 'package:flutter/material.dart';
import 'package:injast_admin/features/inspections/inspection_archive_api.dart';
import 'package:injast_admin/features/inspections/inspection_form_view_page.dart';
import 'package:injast_admin/features/inspections/inspection_outcome_panel.dart';
import 'package:injast_admin/features/shared/admin_ui.dart';
import 'package:injast_admin/file_management/jalali_date_util.dart';

class InspectionParvandePage extends StatefulWidget {
  const InspectionParvandePage({
    super.key,
    required this.codeCo,
    required this.idParvande,
  });

  final String codeCo;
  final String idParvande;

  @override
  State<InspectionParvandePage> createState() => _InspectionParvandePageState();
}

class _InspectionParvandePageState extends State<InspectionParvandePage> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _data = {};
  String? _openFormId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await InspectionArchiveApi.instance.fetchParvande(
        codeCo: widget.codeCo,
        idParvande: widget.idParvande,
      );
      if (!mounted) return;
      setState(() => _data = data);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Map<String, dynamic> get _p =>
      Map<String, dynamic>.from(_data['parvande'] as Map? ?? {});

  List<Map<String, dynamic>> get _groups {
    final list = _data['groups'];
    if (list is! List) return const [];
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final p = _p;
    final title = (p['name_store']?.toString().trim().isNotEmpty == true)
        ? p['name_store'].toString()
        : (p['person_name']?.toString() ?? 'پرونده');
    return AdminPageShell(
      title: title,
      subtitle: 'مشخصات پرونده و بازرسی‌های انجام‌شده',
      icon: Icons.assignment_outlined,
      maxWidth: 1100,
      actions: [
        IconButton(
          onPressed: _loading ? null : _load,
          icon: const Icon(Icons.refresh),
          tooltip: 'بروزرسانی',
        ),
      ],
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : ListView(
                  padding: const EdgeInsets.all(18),
                  children: [
                    _parvandeCard(p),
                    const SizedBox(height: 14),
                    Text(
                      'بازرسی‌ها (${_data['total_fills'] ?? 0})',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AdminUi.ink,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (_groups.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: AdminUi.cardDecoration(),
                        child: const Text('برای این پرونده بازرسی ثبت نشده است.'),
                      )
                    else
                      ..._groups.map(_groupCard),
                    const SizedBox(height: 24),
                  ],
                ),
    );
  }

  Widget _parvandeCard(Map<String, dynamic> p) {
    Widget cell(String k, dynamic v) => Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(k, style: const TextStyle(color: AdminUi.muted, fontSize: 12)),
                const SizedBox(height: 3),
                Text(
                  (v ?? '').toString().trim().isEmpty ? '—' : v.toString().trim(),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        );
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: AdminUi.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('مشخصات کامل پرونده',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AdminUi.ink)),
          const SizedBox(height: 12),
          Row(children: [
            cell('نام واحد', p['name_store']),
            cell('مالک', p['person_name']),
            cell('وضعیت', p['vaziyat']),
          ]),
          Row(children: [
            cell('شناسه صنفی', p['shenase_store']),
            cell('شماره پرونده', p['num_parvande_store']),
            cell('کد ملی', p['code_meli_admin']),
          ]),
          Row(children: [
            cell('همراه', p['mob_admin']),
            cell('تلفن', p['tel_admin']),
            cell('رسته', p['raste_store']),
          ]),
          Row(children: [
            cell('استان', p['state_store']),
            cell('شهرستان', p['city_store']),
            cell('کد پستی', p['code_posti_store']),
          ]),
          Text('آدرس', style: const TextStyle(color: AdminUi.muted, fontSize: 12)),
          const SizedBox(height: 3),
          Text(
            (p['address_store']?.toString().trim().isEmpty ?? true)
                ? '—'
                : p['address_store'].toString(),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _groupCard(Map<String, dynamic> g) {
    final formId = g['form_id']?.toString() ?? '';
    final name = g['form_name']?.toString() ?? 'فرم بازرسی';
    final count = g['count'] ?? ((g['items'] as List?)?.length ?? 0);
    final open = _openFormId == formId;
    final items = ((g['items'] as List?) ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: AdminUi.cardDecoration(),
        child: Column(
          children: [
            ListTile(
              leading: CircleAvatar(
                backgroundColor: const Color(0xFF1565C0).withValues(alpha: 0.12),
                child: Text(
                  '$count',
                  style: const TextStyle(
                    color: Color(0xFF1565C0),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              title: Text(name, style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text('$count بازرسی انجام‌شده — برای دیدن فهرست کلیک کنید'),
              trailing: Icon(open ? Icons.expand_less : Icons.expand_more),
              onTap: () => setState(() => _openFormId = open ? null : formId),
            ),
            if (open)
              ...items.map((item) {
                final inspector = item['inspector_name']?.toString().trim();
                final date = JalaliDateUtil.serverToDisplay(
                  (item['date_label'] ?? item['created_at'])?.toString(),
                );
                final outcome = item['outcome'] is Map
                    ? Map<String, dynamic>.from(item['outcome'] as Map)
                    : null;
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 2),
                  leading: const Icon(Icons.person_outline, color: AdminUi.ink),
                  title: Text(
                    (inspector == null || inspector.isEmpty) ? 'بازرس نامشخص' : inspector,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    [
                      'تاریخ انجام: ${date.isEmpty ? '—' : date}',
                      outcomeSummary(outcome),
                    ].join('\n'),
                  ),
                  isThreeLine: true,
                  trailing: const Icon(Icons.chevron_left),
                  onTap: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => InspectionFormViewPage(
                          codeCo: widget.codeCo,
                          item: item,
                          formName: name,
                          parvande: _p,
                        ),
                      ),
                    );
                    if (mounted) _load();
                  },
                );
              }),
          ],
        ),
      ),
    );
  }
}
