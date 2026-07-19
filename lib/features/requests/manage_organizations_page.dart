import 'package:flutter/material.dart';
import 'package:injast_admin/features/requests/dade_darkhast.dart';
import 'package:injast_admin/features/requests/servis_api_admin.dart';
import 'package:injast_admin/features/shared/admin_ui.dart';

class ManageOrganizationsPage extends StatefulWidget {
  const ManageOrganizationsPage({super.key, required this.codeCo});
  final String codeCo;

  @override
  State<ManageOrganizationsPage> createState() =>
      _ManageOrganizationsPageState();
}

class _ManageOrganizationsPageState extends State<ManageOrganizationsPage> {
  final _search = TextEditingController();
  List<DadeOrganization> _items = [];
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
        await ServisApiAdmin.gereftanOrganizationsAdmin(codeCo: widget.codeCo);
    if (!mounted) return;
    setState(() {
      _items = result ?? [];
      _loading = false;
    });
    if (result == null) {
      showAdminSnack(context, 'دریافت ارگان‌ها ناموفق بود', error: true);
    }
  }

  Future<void> _edit([DadeOrganization? item]) async {
    final name = TextEditingController(text: item?.name);
    final description = TextEditingController(text: item?.description);
    final logo = TextEditingController(text: item?.logo);
    final phone =
        TextEditingController(text: item?.contactInfo?['phone']?.toString());
    final email =
        TextEditingController(text: item?.contactInfo?['email']?.toString());
    final order = TextEditingController(text: '${item?.sortOrder ?? 0}');
    bool active = item?.isActive != 0;
    final key = GlobalKey<FormState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (_, setLocal) => AlertDialog(
          title: Text(item == null ? 'ارگان جدید' : 'ویرایش ارگان'),
          content: SizedBox(
            width: 520,
            child: Form(
              key: key,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                        controller: name,
                        decoration: AdminUi.fieldDecoration('نام ارگان'),
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
                        controller: logo,
                        decoration: AdminUi.fieldDecoration('نشانی لوگو')),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(
                          child: TextFormField(
                              controller: phone,
                              decoration: AdminUi.fieldDecoration('تلفن'))),
                      const SizedBox(width: 12),
                      Expanded(
                          child: TextFormField(
                              controller: email,
                              decoration: AdminUi.fieldDecoration('ایمیل'))),
                    ]),
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
    final contact = <String, dynamic>{
      if (phone.text.trim().isNotEmpty) 'phone': phone.text.trim(),
      if (email.text.trim().isNotEmpty) 'email': email.text.trim(),
    };
    final value = DadeOrganization(
      id: item?.id ?? 0,
      name: name.text.trim(),
      codeCo: widget.codeCo,
      description: description.text.trim(),
      logo: logo.text.trim().isEmpty ? null : logo.text.trim(),
      contactInfo: contact,
      isActive: active ? 1 : 0,
      sortOrder: int.tryParse(order.text) ?? 0,
    );
    final result = item == null
        ? await ServisApiAdmin.sakhtOrganization(value, 0)
        : await ServisApiAdmin.virayeshOrganization(item.id, value);
    if (!mounted) return;
    showAdminSnack(context,
        result.message ?? (result.success ? 'ذخیره شد' : 'ذخیره ناموفق بود'),
        error: !result.success);
    if (result.success) _load();
  }

  void _delete(DadeOrganization item) => showAdminConfirm(
        context: context,
        title: 'حذف ارگان',
        message: '«${item.name}» حذف شود؟',
        confirmLabel: 'حذف',
        onConfirm: () async {
          final result = await ServisApiAdmin.hazfOrganization(item.id);
          if (!mounted) return;
          showAdminSnack(context,
              result.message ?? (result.success ? 'حذف شد' : 'حذف ناموفق بود'),
              error: !result.success);
          if (result.success) _load();
        },
      );

  @override
  Widget build(BuildContext context) {
    final q = _search.text.trim().toLowerCase();
    final shown = _items
        .where((e) =>
            q.isEmpty ||
            e.name.toLowerCase().contains(q) ||
            (e.description ?? '').toLowerCase().contains(q))
        .toList();
    return AdminPageShell(
      title: 'ارگان‌های مقصد',
      icon: Icons.account_balance_outlined,
      floatingActionButton: FloatingActionButton.extended(
          onPressed: _edit,
          icon: const Icon(Icons.add),
          label: const Text('ارگان جدید')),
      child: Column(
        children: [
          AdminToolbar(
              searchController: _search,
              searchHint: 'نام ارگان',
              onSearchChanged: (_) => setState(() {}),
              trailing: [
                IconButton(onPressed: _load, icon: const Icon(Icons.refresh))
              ]),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : shown.isEmpty
                    ? const AdminEmptyState(message: 'ارگانی یافت نشد')
                    : GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 430,
                                mainAxisExtent: 180,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12),
                        itemCount: shown.length,
                        itemBuilder: (_, i) {
                          final item = shown[i];
                          return Container(
                            padding: const EdgeInsets.all(16),
                            decoration: AdminUi.cardDecoration(),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(children: [
                                    const CircleAvatar(
                                        child: Icon(
                                            Icons.account_balance_outlined)),
                                    const SizedBox(width: 12),
                                    Expanded(
                                        child: Text(item.name,
                                            style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold))),
                                    AdminStatusChip(
                                        label: item.isActive == 0
                                            ? 'غیرفعال'
                                            : 'فعال',
                                        active: item.isActive != 0),
                                  ]),
                                  const SizedBox(height: 12),
                                  Expanded(
                                      child: Text(
                                          item.description?.isNotEmpty == true
                                              ? item.description!
                                              : 'بدون توضیحات',
                                          maxLines: 3,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                              color: AdminUi.muted))),
                                  Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        TextButton.icon(
                                            onPressed: () => _edit(item),
                                            icon:
                                                const Icon(Icons.edit_outlined),
                                            label: const Text('ویرایش')),
                                        TextButton.icon(
                                            onPressed: () => _delete(item),
                                            icon: const Icon(
                                                Icons.delete_outline),
                                            label: const Text('حذف'),
                                            style: TextButton.styleFrom(
                                                foregroundColor: Colors.red)),
                                      ]),
                                ]),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
