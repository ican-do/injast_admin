import 'package:flutter/material.dart';
import 'package:injast_admin/file_management/parvande_api.dart';
import 'package:injast_admin/file_management/parvande_sharik_api.dart';
import 'package:injast_admin/file_management/parvande_sharik_form_sheet.dart';
import 'package:shamsi_date/shamsi_date.dart';

/// لیست شرکای یک پرونده
class ParvandeSharikListSheet extends StatefulWidget {
  const ParvandeSharikListSheet({
    super.key,
    required this.codeCo,
    required this.parvande,
    required this.userId,
  });

  final String codeCo;
  final Map<String, dynamic> parvande;
  final String userId;

  static Future<void> show(
    BuildContext context, {
    required String codeCo,
    required Map<String, dynamic> parvande,
    required String userId,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ParvandeSharikListSheet(
        codeCo: codeCo,
        parvande: parvande,
        userId: userId,
      ),
    );
  }

  @override
  State<ParvandeSharikListSheet> createState() => _ParvandeSharikListSheetState();
}

class _ParvandeSharikListSheetState extends State<ParvandeSharikListSheet> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _items = const [];

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
      final rows = await ParvandeSharikApi.instance.fetchByParvande(widget.parvande.idParvandeh);
      if (mounted) setState(() => _items = rows);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool _isExpired(String exp) {
    if (exp.isEmpty || exp == 'null') return false;
    try {
      final parts = exp.replaceAll('-', '/').split('/');
      if (parts.length != 3) return false;
      final j = Jalali(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
      final today = Jalali.now();
      return j.compareTo(today) < 0;
    } catch (_) {
      return false;
    }
  }

  Future<void> _delete(Map<String, dynamic> row) async {
    final id = row['id_sharik']?.toString() ?? '';
    if (id.isEmpty) return;
    final name = '${row['name_sharik'] ?? ''} ${row['family_sharik'] ?? ''}'.trim();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف شریک'),
        content: Text('«$name» حذف شود؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('انصراف')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFB71C1C)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ParvandeSharikApi.instance.delete(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('شریک حذف شد.')));
        _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطا: $e')));
      }
    }
  }

  Future<void> _edit(Map<String, dynamic> row) async {
    final id = row['id_sharik']?.toString();
    if (id == null || id.isEmpty) return;
    final saved = await ParvandeSharikFormSheet.show(
      context,
      codeCo: widget.codeCo,
      parvande: widget.parvande,
      userId: widget.userId,
      editData: row,
      idSharik: id,
    );
    if (saved == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.sizeOf(context).height;
    return Container(
      constraints: BoxConstraints(maxHeight: h * 0.88),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'لیست شرکا',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                ),
                IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(_error!, textAlign: TextAlign.center),
                              const SizedBox(height: 12),
                              FilledButton(onPressed: _load, child: const Text('تلاش مجدد')),
                            ],
                          ),
                        ),
                      )
                    : _items.isEmpty
                        ? const Center(child: Text('شریکی ثبت نشده است.'))
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: _items.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (_, i) => _card(_items[i]),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _card(Map<String, dynamic> row) {
    final name = '${row['name_sharik'] ?? ''} ${row['family_sharik'] ?? ''}'.trim();
    final mob = row['mob_sharik']?.toString() ?? '—';
    final meli = row['code_meli_sharik']?.toString() ?? '—';
    final code = row['code_sharik']?.toString() ?? row['id_sharik']?.toString() ?? '—';
    final type = row['type_fard']?.toString() ?? '';
    final exp = row['date_exp_sharik']?.toString() ?? '';
    final expired = _isExpired(exp);
    final statusColor = expired ? const Color(0xFFC62828) : const Color(0xFF2E7D32);
    final statusText = exp.isEmpty || exp == 'null'
        ? 'بدون تاریخ انقضا'
        : expired
            ? 'منقضی شده'
            : 'معتبر تا $exp';

    return Card(
      elevation: 0,
      color: const Color(0xFFF5F5F5),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name.isEmpty ? '—' : name, style: const TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text('موبایل: $mob', style: const TextStyle(fontSize: 12.5)),
                      Text('کد ملی: $meli', style: const TextStyle(fontSize: 12.5)),
                      Text('کد شریک: $code', style: const TextStyle(fontSize: 12.5)),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'عکس',
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('آپلود عکس به زودی')),
                    );
                  },
                  icon: const Icon(Icons.photo_outlined),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(statusText, style: const TextStyle(color: Colors.white, fontSize: 11)),
                ),
                if (type.isNotEmpty && type != 'null')
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade700,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(type, style: const TextStyle(color: Colors.white, fontSize: 11)),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => _edit(row),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('ویرایش'),
                ),
                TextButton.icon(
                  onPressed: () => _delete(row),
                  icon: const Icon(Icons.delete_outline, size: 18, color: Color(0xFFB71C1C)),
                  label: const Text('حذف', style: TextStyle(color: Color(0xFFB71C1C))),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
