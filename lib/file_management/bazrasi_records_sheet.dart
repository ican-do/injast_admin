import 'package:flutter/material.dart';
import 'package:injast_admin/file_management/bazrasi_local_store.dart';
import 'package:injast_admin/file_management/edit_bazrasi_sheet.dart';
import 'package:injast_admin/file_management/new_bazrasi_sheet.dart';
import 'package:injast_admin/file_management/parvande_bazrasi_api.dart';
import 'package:injast_admin/file_management/parvande_api.dart';

enum _BazrasiSort { dateDesc, dateAsc, shenase, vaziyat }

/// سوابق بازرسی با جستجو، مرتب‌سازی، ویرایش و حذف
class BazrasiRecordsSheet extends StatefulWidget {
  const BazrasiRecordsSheet({
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

  static Future<void> show(
    BuildContext context, {
    required String codeCo,
    required Map<String, dynamic> parvande,
    required bool offline,
    String? userId,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BazrasiRecordsSheet(
        codeCo: codeCo,
        parvande: parvande,
        offline: offline,
        userId: userId,
      ),
    );
  }

  @override
  State<BazrasiRecordsSheet> createState() => _BazrasiRecordsSheetState();
}

class _BazrasiRecordsSheetState extends State<BazrasiRecordsSheet> {
  final _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _rows = [];
  bool _loading = true;
  String? _loadError;
  _BazrasiSort _sort = _BazrasiSort.dateDesc;
  String _filterVaziyat = '';

  @override
  void initState() {
    super.initState();
    _load();
    _searchCtrl.addListener(() => setState(() {}));
  }

  BazrasiLocalStore get _store => BazrasiLocalStore(widget.codeCo);

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      List<Map<String, dynamic>> server = const [];
      if (!widget.offline) {
        server = await ParvandeBazrasiApi.instance.fetchByParvande(widget.parvande.idParvandeh);
      }
      final merged = await _store.mergeWithServer(widget.parvande.idParvandeh, server);
      if (mounted) setState(() => _rows = merged);
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadError = e.toString();
          _rows = [];
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _visible {
    var list = [..._rows];
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((item) {
        final bag = [
          item['shenase_bazrasi'],
          item['date_sodor'],
          item['vaziyat_bazrasi'],
          item['caption_bazrasi'],
          item['last_result_bazrasi'],
          item['tozihat_bazrasi'],
        ].join(' ').toLowerCase();
        return bag.contains(q);
      }).toList();
    }
    if (_filterVaziyat.isNotEmpty) {
      list = list.where((e) => e['vaziyat_bazrasi']?.toString() == _filterVaziyat).toList();
    }
    list.sort((a, b) {
      switch (_sort) {
        case _BazrasiSort.dateAsc:
          return (a['date_sodor'] ?? '').toString().compareTo((b['date_sodor'] ?? '').toString());
        case _BazrasiSort.shenase:
          return (a['shenase_bazrasi'] ?? '').toString().compareTo((b['shenase_bazrasi'] ?? '').toString());
        case _BazrasiSort.vaziyat:
          return (a['vaziyat_bazrasi'] ?? '').toString().compareTo((b['vaziyat_bazrasi'] ?? '').toString());
        case _BazrasiSort.dateDesc:
          return (b['date_sodor'] ?? '').toString().compareTo((a['date_sodor'] ?? '').toString());
      }
    });
    return list;
  }

  Future<void> _delete(Map<String, dynamic> item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف بازرسی'),
        content: const Text('آیا از حذف این سابقه بازرسی مطمئن هستید؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('انصراف')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final id = item['id_bazrasi']?.toString() ?? '';
    final isLocal = item['_local_only'] == true || id.startsWith('local_');
    try {
      if (widget.offline || isLocal) {
        await _store.markDeleted(widget.parvande.idParvandeh, id, isLocalOnly: isLocal);
      } else {
        await ParvandeBazrasiApi.instance.delete(id);
      }
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطا: $e')));
      }
    }
  }

  Future<void> _edit(Map<String, dynamic> item) async {
    final changed = await EditBazrasiSheet.show(
      context,
      codeCo: widget.codeCo,
      parvande: widget.parvande,
      record: item,
      offline: widget.offline,
    );
    if (changed == true) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.sizeOf(context).height;
    final visible = _visible;
    return SafeArea(
      child: Container(
        constraints: BoxConstraints(maxHeight: h * 0.92),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'سوابق بازرسی — ${widget.parvande.storeName.isEmpty ? widget.parvande.fullName : widget.parvande.storeName}',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      decoration: InputDecoration(
                        hintText: 'جستجو…',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        isDense: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.tonal(
                    onPressed: () => NewBazrasiSheet.show(
                      context,
                      codeCo: widget.codeCo,
                      parvande: widget.parvande,
                      offline: widget.offline,
                      userId: widget.userId,
                    ).then((v) {
                      if (v == true) _load();
                    }),
                    child: const Text('بازرسی'),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: Row(
                children: [
                  DropdownButton<_BazrasiSort>(
                    value: _sort,
                    items: const [
                      DropdownMenuItem(value: _BazrasiSort.dateDesc, child: Text('تاریخ ↓')),
                      DropdownMenuItem(value: _BazrasiSort.dateAsc, child: Text('تاریخ ↑')),
                      DropdownMenuItem(value: _BazrasiSort.shenase, child: Text('شناسه')),
                      DropdownMenuItem(value: _BazrasiSort.vaziyat, child: Text('وضعیت')),
                    ],
                    onChanged: (v) => setState(() => _sort = v ?? _sort),
                  ),
                  const Spacer(),
                  Text('${visible.length} مورد', style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
            const Divider(height: 1),
            if (_loading) const LinearProgressIndicator(minHeight: 2),
            if (_loadError != null)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'خطا در دریافت سوابق:\n$_loadError',
                      style: const TextStyle(fontSize: 12, color: Color(0xFFC62828)),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _load,
                      icon: const Icon(Icons.refresh),
                      label: const Text('تلاش مجدد'),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: visible.isEmpty && !_loading && _loadError == null
                  ? const Center(child: Text('سابقه‌ای یافت نشد.'))
                  : visible.isEmpty
                      ? const SizedBox.shrink()
                      : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: visible.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) => _row(visible[i]),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(Map<String, dynamic> item) {
    final pending = item['_pending'] == true;
    return Container(
      decoration: BoxDecoration(
        color: pending ? const Color(0xFFFFF8E1) : const Color(0xFFF5F8FC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDDE5EF)),
      ),
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'شناسه: ${item['shenase_bazrasi'] ?? '—'}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              if (pending)
                const Text('در انتظار ارسال', style: TextStyle(fontSize: 10, color: Color(0xFFEF6C00))),
            ],
          ),
          Text('تاریخ: ${item['date_sodor'] ?? '—'} • وضعیت: ${item['vaziyat_bazrasi'] ?? '—'}'),
          if ((item['caption_bazrasi']?.toString() ?? '').isNotEmpty &&
              item['caption_bazrasi']?.toString() != '0')
            Text(item['caption_bazrasi'].toString(), maxLines: 2, overflow: TextOverflow.ellipsis),
          if ((item['type_takhalof']?.toString() ?? '').isNotEmpty &&
              item['type_takhalof']?.toString() != '0')
            Text(
              'تخلفات: ${item['type_takhalof']}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11.5, color: Colors.grey.shade800),
            ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(onPressed: () => _edit(item), child: const Text('ویرایش')),
              TextButton(
                onPressed: () => _delete(item),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('حذف'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
