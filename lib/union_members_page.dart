import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:injast_admin/server_config.dart';
import 'package:url_launcher/url_launcher.dart';

class UnionMembersPage extends StatefulWidget {
  const UnionMembersPage({
    super.key,
    required this.codeCo,
  });

  final String codeCo;

  @override
  State<UnionMembersPage> createState() => _UnionMembersPageState();
}

class _UnionMembersPageState extends State<UnionMembersPage> {
  final TextEditingController _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _all = [];
  bool _loading = true;
  String _mode = 'active'; // all | active | trash

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final uri = Uri.parse(getApiUrl('select/select_parvande_full/${Uri.encodeComponent(widget.codeCo)}'));
      final res = await http.get(uri);
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        if (body is List) {
          _all = body.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        }
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _s(Map<String, dynamic> m, String k) => m[k]?.toString().trim() ?? '';
  bool _isTrash(Map<String, dynamic> m) => _s(m, 'act_parvande') == '2';
  bool _isActive(Map<String, dynamic> m) => !_isTrash(m);

  List<Map<String, dynamic>> get _list {
    final q = _searchCtrl.text.trim().toLowerCase();
    return _all.where((m) {
      if (_mode == 'active' && !_isActive(m)) return false;
      if (_mode == 'trash' && !_isTrash(m)) return false;
      if (q.isEmpty) return true;
      final bag = [
        _s(m, 'name_admin'),
        _s(m, 'family_admin'),
        _s(m, 'name_store'),
        _s(m, 'mob_admin'),
        _s(m, 'code_meli_admin'),
        _s(m, 'raste_store'),
      ].join(' ').toLowerCase();
      return bag.contains(q);
    }).toList();
  }

  Future<void> _setAct(Map<String, dynamic> m, int act) async {
    final id = _s(m, 'id_parvandeh');
    if (id.isEmpty) return;
    final uri = Uri.parse(getApiUrl('update/update_act_parvande/${Uri.encodeComponent(id)}/$act'));
    final res = await http.get(uri);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      await _load();
    }
  }

  Future<void> _deleteForever(Map<String, dynamic> m) async {
    final id = _s(m, 'id_parvandeh');
    if (id.isEmpty) return;
    final uri = Uri.parse(getApiUrl('delete/delete_parvande/${Uri.encodeComponent(id)}'));
    final res = await http.get(uri);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      await _load();
    }
  }

  Future<void> _launchTel(String phone) async {
    if (phone.trim().isEmpty) return;
    await launchUrl(Uri.parse('tel:${phone.trim()}'));
  }

  Future<void> _launchSms(String phone) async {
    if (phone.trim().isEmpty) return;
    await launchUrl(Uri.parse('sms:${phone.trim()}'));
  }

  Future<void> _launchMap(Map<String, dynamic> m) async {
    final lat = _s(m, 'lat_store');
    final lng = _s(m, 'long_store');
    final address = _s(m, 'address_store');
    final q = (lat.isNotEmpty && lng.isNotEmpty) ? '$lat,$lng' : address;
    if (q.trim().isEmpty) return;
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(q)}');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _showDetails(Map<String, dynamic> m) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('جزئیات عضو'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _row('نام', '${_s(m, 'name_admin')} ${_s(m, 'family_admin')}'),
                _row('نام واحد', _s(m, 'name_store')),
                _row('رسته', _s(m, 'raste_store')),
                _row('شماره همراه', _s(m, 'mob_admin')),
                _row('کد ملی', _s(m, 'code_meli_admin')),
                _row('شناسه پرونده', _s(m, 'id_parvandeh')),
                _row('وضعیت پروانه', _s(m, 'lbl_vaziyat_store')),
                _row('آدرس', _s(m, 'address_store')),
              ],
            ),
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('بستن'))],
      ),
    );
  }

  Widget _row(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 110, child: Text(k, style: const TextStyle(color: Colors.black54))),
          Expanded(child: Text(v.isEmpty ? '—' : v)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeCount = _all.where(_isActive).length;
    final trashCount = _all.where(_isTrash).length;
    final total = _all.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('اعضاء اتحادیه'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: _stat('کل', total, const Color(0xFF455A64))),
                          const SizedBox(width: 8),
                          Expanded(child: _stat('فعال', activeCount, const Color(0xFF2E7D32))),
                          const SizedBox(width: 8),
                          Expanded(child: _stat('سطل زباله', trashCount, const Color(0xFFC62828))),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _searchCtrl,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: 'جستجو بر اساس نام، واحد، رسته، موبایل...',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _modeBtn('active', 'اعضای فعال'),
                          const SizedBox(width: 6),
                          _modeBtn('all', 'همه'),
                          const SizedBox(width: 6),
                          _modeBtn('trash', 'سطل زباله'),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _list.isEmpty
                      ? const Center(child: Text('موردی یافت نشد'))
                      : LayoutBuilder(
                          builder: (context, c) {
                            final count = c.maxWidth > 1200 ? 3 : c.maxWidth > 700 ? 2 : 1;
                            return GridView.builder(
                              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: count,
                                mainAxisSpacing: 10,
                                crossAxisSpacing: 10,
                                childAspectRatio: 1.55,
                              ),
                              itemCount: _list.length,
                              itemBuilder: (context, i) => _memberCard(_list[i]),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _modeBtn(String mode, String text) {
    final active = _mode == mode;
    return Expanded(
      child: FilledButton.tonal(
        onPressed: () => setState(() => _mode = mode),
        style: FilledButton.styleFrom(
          backgroundColor: active ? const Color(0xFF1E3A5F) : null,
          foregroundColor: active ? Colors.white : null,
        ),
        child: Text(text),
      ),
    );
  }

  Widget _stat(String t, int v, Color c) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          Expanded(child: Text(t, style: const TextStyle(fontWeight: FontWeight.w700))),
          Text(v.toString(), style: TextStyle(fontWeight: FontWeight.w800, color: c)),
        ],
      ),
    );
  }

  Widget _memberCard(Map<String, dynamic> m) {
    final isTrash = _isTrash(m);
    final fullName = '${_s(m, 'name_admin')} ${_s(m, 'family_admin')}'.trim();
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDDE5EF)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    fullName.isEmpty ? '—' : fullName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isTrash ? Colors.red.shade50 : Colors.green.shade50,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(isTrash ? 'سطل زباله' : 'فعال', style: TextStyle(fontSize: 11, color: isTrash ? Colors.red.shade700 : Colors.green.shade700)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text('واحد: ${_s(m, 'name_store')}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5)),
            Text('رسته: ${_s(m, 'raste_store')}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5)),
            Text('موبایل: ${_s(m, 'mob_admin')}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5)),
            const Spacer(),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _actBtn('جزئیات', Icons.info_outline, () => _showDetails(m)),
                _actBtn('تماس', Icons.call_outlined, () => _launchTel(_s(m, 'mob_admin'))),
                _actBtn('پیامک', Icons.sms_outlined, () => _launchSms(_s(m, 'mob_admin'))),
                _actBtn('نقشه', Icons.map_outlined, () => _launchMap(m)),
                _actBtn(isTrash ? 'بازیابی' : 'حذف منطقی', isTrash ? Icons.restore : Icons.delete_outline,
                    () => _setAct(m, isTrash ? 1 : 2)),
                if (isTrash) _actBtn('حذف دائم', Icons.delete_forever_outlined, () => _deleteForever(m), danger: true),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _actBtn(String t, IconData i, VoidCallback onTap, {bool danger = false}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: danger ? const Color(0xFFFFEBEE) : const Color(0xFFEFF3FA),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(i, size: 15, color: danger ? const Color(0xFFC62828) : const Color(0xFF1E3A5F)),
            const SizedBox(width: 4),
            Text(t, style: TextStyle(fontSize: 11.5, color: danger ? const Color(0xFFC62828) : const Color(0xFF1E3A5F), fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

