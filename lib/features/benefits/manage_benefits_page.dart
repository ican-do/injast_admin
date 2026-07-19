import 'package:flutter/material.dart';
import 'package:injast_admin/features/benefits/mazaya.dart';
import 'package:injast_admin/features/benefits/servis_mazaya_admin.dart';
import 'package:injast_admin/features/shared/admin_ui.dart';

class ManageBenefitsPage extends StatefulWidget {
  const ManageBenefitsPage({super.key, required this.codeCo});
  final String codeCo;

  @override
  State<ManageBenefitsPage> createState() => _ManageBenefitsPageState();
}

class _ManageBenefitsPageState extends State<ManageBenefitsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _search = TextEditingController();
  List<DasteMazaya> _categories = [];
  List<MazayaItem> _benefits = [];
  int? _categoryFilter;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final values = await Future.wait([
        ServisMazayaAdmin.gereftanDasteha(codeCo: widget.codeCo),
        ServisMazayaAdmin.gereftanMazaya(
            codeCo: widget.codeCo, categoryId: _categoryFilter),
      ]);
      if (!mounted) return;
      setState(() {
        _categories = values[0] as List<DasteMazaya>;
        _benefits = values[1] as List<MazayaItem>;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      showAdminSnack(context, 'ارتباط با سرور ناموفق بود', error: true);
    }
  }

  Future<void> _editCategory([DasteMazaya? item]) async {
    final title = TextEditingController(text: item?.title);
    final description = TextEditingController(text: item?.description);
    final key = GlobalKey<FormState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(item == null ? 'دسته جدید' : 'ویرایش دسته'),
        content: SizedBox(
          width: 460,
          child: Form(
            key: key,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextFormField(
                  controller: title,
                  decoration: AdminUi.fieldDecoration('عنوان'),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'عنوان الزامی است'
                      : null),
              const SizedBox(height: 12),
              TextFormField(
                  controller: description,
                  decoration: AdminUi.fieldDecoration('توضیحات'),
                  minLines: 3,
                  maxLines: 5),
            ]),
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
    );
    if (ok != true) return;
    try {
      final success = item == null
          ? await ServisMazayaAdmin.sakhtDaste(
              codeCo: widget.codeCo,
              title: title.text.trim(),
              description: description.text.trim())
          : await ServisMazayaAdmin.virayeshDaste(item.id,
              title: title.text.trim(), description: description.text.trim());
      if (!mounted) return;
      showAdminSnack(context, success ? 'ذخیره شد' : 'ذخیره ناموفق بود',
          error: !success);
      if (success) _load();
    } catch (_) {
      if (mounted) {
        showAdminSnack(context, 'ارتباط با سرور ناموفق بود', error: true);
      }
    }
  }

  Future<void> _editBenefit([MazayaItem? item]) async {
    if (_categories.isEmpty) {
      showAdminSnack(context, 'ابتدا یک دسته ایجاد کنید', error: true);
      return;
    }
    int categoryId = item?.categoryId ?? _categories.first.id;
    final title = TextEditingController(text: item?.title);
    final short = TextEditingController(text: item?.shortDesc);
    final full = TextEditingController(text: item?.fullDescRaw);
    final icon = TextEditingController(text: item?.iconName);
    final key = GlobalKey<FormState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (_, setLocal) => AlertDialog(
          title: Text(item == null ? 'مزیت جدید' : 'ویرایش مزیت'),
          content: SizedBox(
            width: 560,
            child: Form(
              key: key,
              child: SingleChildScrollView(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  DropdownButtonFormField<int>(
                    initialValue: categoryId,
                    decoration: AdminUi.fieldDecoration('دسته'),
                    items: _categories
                        .map((e) =>
                            DropdownMenuItem(value: e.id, child: Text(e.title)))
                        .toList(),
                    onChanged: (v) => setLocal(() => categoryId = v!),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                      controller: title,
                      decoration: AdminUi.fieldDecoration('عنوان'),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'عنوان الزامی است'
                          : null),
                  const SizedBox(height: 12),
                  TextFormField(
                      controller: short,
                      decoration: AdminUi.fieldDecoration('توضیح کوتاه'),
                      minLines: 2,
                      maxLines: 3),
                  const SizedBox(height: 12),
                  TextFormField(
                      controller: full,
                      decoration: AdminUi.fieldDecoration('شرح کامل'),
                      minLines: 5,
                      maxLines: 9,
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'شرح کامل الزامی است'
                          : null),
                  const SizedBox(height: 12),
                  TextFormField(
                      controller: icon,
                      decoration: AdminUi.fieldDecoration('نام آیکن')),
                ]),
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
    try {
      final success = item == null
          ? await ServisMazayaAdmin.sakhtMazaya(
                codeCo: widget.codeCo,
                categoryId: categoryId,
                title: title.text.trim(),
                shortDesc: short.text.trim(),
                fullDesc: full.text.trim(),
                iconName: icon.text.trim(),
              ) !=
              null
          : await ServisMazayaAdmin.virayeshMazaya(
              item.id,
              categoryId: categoryId,
              title: title.text.trim(),
              shortDesc: short.text.trim(),
              fullDesc: full.text.trim(),
              iconName: icon.text.trim(),
            );
      if (!mounted) return;
      showAdminSnack(context, success ? 'ذخیره شد' : 'ذخیره ناموفق بود',
          error: !success);
      if (success) _load();
    } catch (_) {
      if (mounted) {
        showAdminSnack(context, 'ارتباط با سرور ناموفق بود', error: true);
      }
    }
  }

  Future<void> _deleteCategory(DasteMazaya item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف دسته'),
        content: Text('دسته «${item.title}» و مزایای مرتبط حذف شوند؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('انصراف')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      final success = await ServisMazayaAdmin.hazfDaste(item.id);
      if (!mounted) return;
      showAdminSnack(context, success ? 'حذف شد' : 'این دسته قابل حذف نیست',
          error: !success);
      if (success) {
        setState(() {
          _categories.removeWhere((e) => e.id == item.id);
          _benefits.removeWhere((e) => e.categoryId == item.id);
        });
        await _load();
      }
    } catch (_) {
      if (mounted) showAdminSnack(context, 'حذف ناموفق بود', error: true);
    }
  }

  Future<void> _deleteBenefit(MazayaItem item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف مزیت'),
        content: Text('مزیت «${item.title}» حذف شود؟ این عمل قابل بازگشت نیست.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('انصراف')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      final success = await ServisMazayaAdmin.hazfMazaya(item.id);
      if (!mounted) return;
      showAdminSnack(context, success ? 'حذف شد' : 'حذف ناموفق بود',
          error: !success);
      if (success) {
        setState(() => _benefits.removeWhere((e) => e.id == item.id));
        await _load();
        if (mounted) {
          setState(() => _benefits.removeWhere((e) => e.id == item.id));
        }
      }
    } catch (_) {
      if (mounted) showAdminSnack(context, 'حذف ناموفق بود', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminPageShell(
      title: 'مدیریت مزایا',
      icon: Icons.workspace_premium_outlined,
      actions: [
        IconButton(
            onPressed: _load,
            tooltip: 'بازخوانی',
            icon: const Icon(Icons.refresh))
      ],
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Container(
            decoration: AdminUi.cardDecoration(),
            child: TabBar(
              controller: _tabs,
              tabs: const [
                Tab(icon: Icon(Icons.card_giftcard), text: 'مزایا'),
                Tab(icon: Icon(Icons.category_outlined), text: 'دسته‌ها')
              ],
            ),
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(
                  controller: _tabs,
                  children: [_benefitsTab(), _categoriesTab()]),
        ),
      ]),
    );
  }

  Widget _benefitsTab() {
    final q = _search.text.trim().toLowerCase();
    final shown = _benefits
        .where((e) =>
            q.isEmpty ||
            e.title.toLowerCase().contains(q) ||
            (e.shortDesc ?? '').toLowerCase().contains(q))
        .toList();
    return Column(children: [
      AdminToolbar(
        searchController: _search,
        searchHint: 'جستجوی مزایا',
        onSearchChanged: (_) => setState(() {}),
        filters: [
          SizedBox(
            width: 210,
            child: DropdownButtonFormField<int?>(
              initialValue: _categoryFilter,
              decoration: AdminUi.fieldDecoration('دسته'),
              items: [
                const DropdownMenuItem(value: null, child: Text('همه دسته‌ها')),
                ..._categories.map(
                    (e) => DropdownMenuItem(value: e.id, child: Text(e.title)))
              ],
              onChanged: (v) {
                setState(() => _categoryFilter = v);
                _load();
              },
            ),
          ),
        ],
        trailing: [
          FilledButton.icon(
              onPressed: _editBenefit,
              icon: const Icon(Icons.add),
              label: const Text('مزیت جدید'))
        ],
      ),
      Expanded(
        child: shown.isEmpty
            ? const AdminEmptyState(message: 'مزیتی یافت نشد')
            : GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 420,
                    mainAxisExtent: 205,
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
                                child: Icon(Icons.card_giftcard_outlined)),
                            const SizedBox(width: 10),
                            Expanded(
                                child: Text(item.title,
                                    style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold))),
                          ]),
                          const SizedBox(height: 10),
                          Text(item.categoryTitle,
                              style: const TextStyle(
                                  color: Colors.blue,
                                  fontWeight: FontWeight.w600)),
                          const SizedBox(height: 6),
                          Expanded(
                              child: Text(
                                  item.shortDesc?.isNotEmpty == true
                                      ? item.shortDesc!
                                      : 'بدون توضیح کوتاه',
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style:
                                      const TextStyle(color: AdminUi.muted))),
                          Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton.icon(
                                    onPressed: () => _editBenefit(item),
                                    icon: const Icon(Icons.edit_outlined),
                                    label: const Text('ویرایش')),
                                IconButton(
                                    onPressed: () => _deleteBenefit(item),
                                    icon: const Icon(Icons.delete_outline,
                                        color: Colors.red)),
                              ]),
                        ]),
                  );
                },
              ),
      ),
    ]);
  }

  Widget _categoriesTab() => Column(children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
                onPressed: _editCategory,
                icon: const Icon(Icons.add),
                label: const Text('دسته جدید')),
          ),
        ),
        Expanded(
          child: _categories.isEmpty
              ? const AdminEmptyState(message: 'دسته‌ای ثبت نشده است')
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: _categories.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final item = _categories[i];
                    final count =
                        _benefits.where((e) => e.categoryId == item.id).length;
                    return Container(
                      decoration: AdminUi.cardDecoration(),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 10),
                        leading: CircleAvatar(child: Text('$count')),
                        title: Text(item.title,
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(item.description?.isNotEmpty == true
                            ? item.description!
                            : 'بدون توضیحات'),
                        trailing: Wrap(children: [
                          IconButton(
                              onPressed: () => _editCategory(item),
                              icon: const Icon(Icons.edit_outlined)),
                          IconButton(
                              onPressed: () => _deleteCategory(item),
                              icon: const Icon(Icons.delete_outline,
                                  color: Colors.red)),
                        ]),
                      ),
                    );
                  },
                ),
        ),
      ]);
}
