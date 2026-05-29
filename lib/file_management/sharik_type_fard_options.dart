import 'package:flutter/material.dart';

/// نقش‌های متداول شریک / پرسنل در واحد صنفی، فروشگاه، مغازه یا شرکت
class SharikTypeFardOptions {
  SharikTypeFardOptions._();

  static const all = [
    'مباشر',
    'مدیر',
    'مدیر عامل',
    'صاحب واحد',
    'مالک',
    'شریک',
    'شریک تجاری',
    'نماینده',
    'نماینده فروش',
    'مسئول واحد',
    'سرپرست',
    'کارگر',
    'کارمند',
    'فروشنده',
    'اپراتور',
    'انباردار',
    'حسابدار',
    'منشی',
    'مسئول فنی',
    'تحویلگیرنده',
    'راننده',
    'پیک',
    'نگهبان',
    'تعمیرکار',
    'مشاور',
    'سایر',
  ];

  static List<String> filter(String query) {
    final q = query.trim();
    if (q.isEmpty) return all;
    return all.where((e) => e.contains(q)).toList();
  }

  static String normalize(String? value) {
    final t = value?.trim() ?? '';
    if (t.isEmpty || t == 'null') return all.first;
    return t;
  }

  static Future<String?> pick(BuildContext context, {required String current}) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RoleSearchSheet(current: normalize(current)),
    );
  }
}

class _RoleSearchSheet extends StatefulWidget {
  const _RoleSearchSheet({required this.current});
  final String current;

  @override
  State<_RoleSearchSheet> createState() => _RoleSearchSheetState();
}

class _RoleSearchSheetState extends State<_RoleSearchSheet> {
  final _searchCtrl = TextEditingController();
  late List<String> _filtered;

  @override
  void initState() {
    super.initState();
    _filtered = SharikTypeFardOptions.all;
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearch(String q) {
    setState(() => _filtered = SharikTypeFardOptions.filter(q));
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.72),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _searchCtrl,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'جستجوی نقش (مباشر، مدیر، فروشنده…)',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchCtrl.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchCtrl.clear();
                            _onSearch('');
                          },
                        ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  isDense: true,
                ),
                onChanged: _onSearch,
              ),
            ),
            Expanded(
              child: _filtered.isEmpty
                  ? const Center(child: Text('نقشی یافت نشد'))
                  : ListView.separated(
                      itemCount: _filtered.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final role = _filtered[i];
                        final selected = role == widget.current;
                        return ListTile(
                          title: Text(role),
                          trailing: selected ? const Icon(Icons.check, color: Color(0xFF7B1FA2)) : null,
                          onTap: () => Navigator.pop(context, role),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
