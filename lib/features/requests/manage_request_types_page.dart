import 'package:flutter/material.dart';
import 'package:injast_admin/features/requests/dade_darkhast.dart';
import 'package:injast_admin/features/requests/servis_api_admin.dart';
import 'package:injast_admin/features/shared/admin_ui.dart';

class ManageRequestTypesPage extends StatefulWidget {
  const ManageRequestTypesPage({super.key, required this.codeCo});
  final String codeCo;

  @override
  State<ManageRequestTypesPage> createState() => _ManageRequestTypesPageState();
}

class _ManageRequestTypesPageState extends State<ManageRequestTypesPage> {
  final _search = TextEditingController();
  List<DadeRequestType> _items = [];
  bool _loading = true;

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

  Future<void> _load() async {
    setState(() => _loading = true);
    final result =
        await ServisApiAdmin.gereftanRequestTypesAdmin(codeCo: widget.codeCo);
    if (!mounted) return;
    setState(() {
      _items = result ?? [];
      _loading = false;
    });
    if (result == null) {
      showAdminSnack(context, 'دریافت انواع درخواست ناموفق بود', error: true);
    }
  }

  Future<void> _edit([DadeRequestType? item]) async {
    final name = TextEditingController(text: item?.name);
    final description = TextEditingController(text: item?.description);
    final fields = TextEditingController(text: item?.fields.join('، '));
    final order = TextEditingController(text: '${item?.sortOrder ?? 0}');
    bool active = item?.isActiveBool ?? true;
    final key = GlobalKey<FormState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (_, setLocal) => AlertDialog(
          title: Text(item == null ? 'نوع درخواست جدید' : 'ویرایش نوع درخواست'),
          content: SizedBox(
            width: 500,
            child: Form(
              key: key,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                      controller: name,
                      decoration: AdminUi.fieldDecoration('نام'),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'نام الزامی است'
                          : null),
                  const SizedBox(height: 12),
                  TextFormField(
                      controller: description,
                      decoration: AdminUi.fieldDecoration('توضیحات'),
                      minLines: 2,
                      maxLines: 4),
                  const SizedBox(height: 12),
                  TextFormField(
                      controller: fields,
                      decoration: AdminUi.fieldDecoration('فیلدها',
                          hint: 'کد ملی، شماره پروانه')),
                  const SizedBox(height: 12),
                  TextFormField(
                      controller: order,
                      keyboardType: TextInputType.number,
                      decoration: AdminUi.fieldDecoration('ترتیب نمایش')),
                  SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('فعال'),
                      value: active,
                      onChanged: (v) => setLocal(() => active = v)),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('انصراف')),
            FilledButton(
                onPressed: () {
                  if (key.currentState!.validate()) Navigator.pop(ctx, true);
                },
                child: const Text('ذخیره')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    final value = DadeRequestType(
      id: item?.id ?? 0,
      name: name.text.trim(),
      description: description.text.trim(),
      fields: fields.text
          .split(RegExp(r'[,،\n]'))
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList(),
      codeCo: widget.codeCo,
      isActive: active ? 1 : 0,
      sortOrder: int.tryParse(order.text) ?? 0,
    );
    final result = item == null
        ? await ServisApiAdmin.sakhtRequestType(value, 0)
        : await ServisApiAdmin.virayeshRequestType(item.id, value);
    if (!mounted) return;
    showAdminSnack(context,
        result.message ?? (result.success ? 'ذخیره شد' : 'ذخیره ناموفق بود'),
        error: !result.success);
    if (result.success) _load();
  }

  void _delete(DadeRequestType item) => showAdminConfirm(
        context: context,
        title: 'حذف نوع درخواست',
        message: '«${item.name}» حذف شود؟',
        confirmLabel: 'حذف',
        onConfirm: () async {
          final result = await ServisApiAdmin.hazfRequestType(item.id);
          if (!mounted) return;
          showAdminSnack(context,
              result.message ?? (result.success ? 'حذف شد' : 'حذف ناموفق بود'),
              error: !result.success);
          if (result.success) _load();
        },
      );

  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim().toLowerCase();
    final shown = _items
        .where((e) =>
            query.isEmpty ||
            e.name.toLowerCase().contains(query) ||
            (e.description ?? '').toLowerCase().contains(query))
        .toList();
    return AdminPageShell(
      title: 'انواع درخواست',
      icon: Icons.category_outlined,
      floatingActionButton: FloatingActionButton.extended(
          onPressed: _edit,
          icon: const Icon(Icons.add),
          label: const Text('نوع جدید')),
      child: Column(
        children: [
          AdminToolbar(
              searchController: _search,
              searchHint: 'نام نوع درخواست',
              onSearchChanged: (_) => setState(() {}),
              trailing: [
                IconButton(onPressed: _load, icon: const Icon(Icons.refresh))
              ]),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : shown.isEmpty
                    ? const AdminEmptyState(message: 'نوع درخواستی یافت نشد')
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: shown.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) {
                          final item = shown[i];
                          return Container(
                            decoration: AdminUi.cardDecoration(),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 18, vertical: 10),
                              title: Text(item.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                              subtitle: Text([
                                if ((item.description ?? '').isNotEmpty)
                                  item.description!,
                                if (item.fields.isNotEmpty)
                                  'فیلدها: ${item.fields.join('، ')}'
                              ].join('\n')),
                              trailing: Wrap(
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    AdminStatusChip(
                                        label: item.isActiveBool
                                            ? 'فعال'
                                            : 'غیرفعال',
                                        active: item.isActiveBool),
                                    IconButton(
                                        onPressed: () => _edit(item),
                                        icon: const Icon(Icons.edit_outlined)),
                                    IconButton(
                                        onPressed: () => _delete(item),
                                        icon: const Icon(Icons.delete_outline,
                                            color: Colors.red)),
                                  ]),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
