import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:injast_admin/file_management/parvande_api.dart';

/// نتیجهٔ بسته‌شدن TrashSheet به صفحهٔ والد گزارش می‌دهد چه عملیاتی انجام شده است.
class TrashSheetResult {
  TrashSheetResult({this.changed = false});
  bool changed;
}

class TrashSheet extends StatefulWidget {
  const TrashSheet({
    super.key,
    required this.trashItems,
    required this.onRestore,
    required this.onHardDelete,
  });

  final List<Map<String, dynamic>> trashItems;
  final Future<bool> Function(Map<String, dynamic> p) onRestore;
  final Future<bool> Function(Map<String, dynamic> p) onHardDelete;

  @override
  State<TrashSheet> createState() => _TrashSheetState();
}

class _TrashSheetState extends State<TrashSheet> {
  late List<Map<String, dynamic>> _items;
  final _result = TrashSheetResult();
  bool _busy = false;
  String _q = '';

  @override
  void initState() {
    super.initState();
    _items = [...widget.trashItems];
  }

  List<Map<String, dynamic>> get _filtered {
    if (_q.trim().isEmpty) return _items;
    final q = _q.toLowerCase();
    return _items.where((m) {
      final bag = [
        m.s('name_admin'),
        m.s('family_admin'),
        m.storeName,
        m.mob,
        m.codeMeli,
        m.numParvande,
      ].join(' ').toLowerCase();
      return bag.contains(q);
    }).toList();
  }

  Future<void> _restore(Map<String, dynamic> p) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final ok = await widget.onRestore(p);
      if (ok) {
        _result.changed = true;
        setState(() => _items.remove(p));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _hardDelete(Map<String, dynamic> p) async {
    if (_busy) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف دائم پرونده'),
        content: Text(
            'آیا از حذف دائم پروندهٔ «${p.fullName}» مطمئن هستید؟ این عمل قابل بازگشت نیست.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('انصراف')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف دائم'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      final done = await widget.onHardDelete(p);
      if (done) {
        _result.changed = true;
        setState(() => _items.remove(p));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
              child: TextField(
                onChanged: (v) => setState(() => _q = v),
                decoration: InputDecoration(
                  hintText: 'جستجو در سطل زباله…',
                  prefixIcon: const Icon(Icons.search),
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            Flexible(
              child: _filtered.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(28),
                        child: Text('سطل زباله خالی است.'),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                      itemCount: _filtered.length,
                      separatorBuilder: (_, sepIndex) => const SizedBox(height: 8),
                      itemBuilder: (context, i) => _row(_filtered[i]),
                    ),
            ),
            if (_busy) const LinearProgressIndicator(minHeight: 2),
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
          const Icon(FluentIcons.delete_24_regular, color: Color(0xFFC62828)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'سطل زباله (${_items.length})',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
            ),
          ),
          IconButton(
            tooltip: 'بستن',
            onPressed: () => Navigator.pop(context, _result),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }

  Widget _row(Map<String, dynamic> p) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7F7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFADBDB)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      child: Row(
        children: [
          const Icon(FluentIcons.document_24_regular, color: Color(0xFFC62828)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.fullName.isEmpty ? '—' : p.fullName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                Text(
                  '${p.storeName.isEmpty ? '—' : p.storeName} • ${p.raste.isEmpty ? '—' : p.raste}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.black54, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'بازیابی',
            onPressed: _busy ? null : () => _restore(p),
            icon: const Icon(FluentIcons.arrow_undo_24_regular, color: Color(0xFF2E7D32)),
          ),
          IconButton(
            tooltip: 'حذف دائم',
            onPressed: _busy ? null : () => _hardDelete(p),
            icon: const Icon(FluentIcons.delete_dismiss_24_regular, color: Color(0xFFB71C1C)),
          ),
        ],
      ),
    );
  }
}
