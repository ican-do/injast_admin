import 'dart:async';

import 'package:flutter/material.dart';
import 'package:injast_admin/features/laws/dade_ghavanin.dart';
import 'package:injast_admin/features/requests/servis_api_admin.dart';
import 'package:injast_admin/features/shared/admin_ui.dart';
import 'package:injast_admin/file_management/jalali_date_util.dart';
import 'package:persian_datetimepickers/persian_datetimepickers.dart';

class ManageLawsPage extends StatefulWidget {
  const ManageLawsPage({super.key, required this.codeCo});
  final String codeCo;

  @override
  State<ManageLawsPage> createState() => _ManageLawsPageState();
}

class _ManageLawsPageState extends State<ManageLawsPage> {
  final _search = TextEditingController();
  List<DadeGhavanin> _items = [];
  List<DadeCategory> _categories = [];
  PaginationInfo? _pagination;
  String? _category;
  bool _loading = true;
  int _page = 1;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _load();
    ServisApiAdmin.gereftanCategoriesAdmin(codeCo: widget.codeCo).then((value) {
      if (mounted) setState(() => _categories = value ?? []);
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load({int? page}) async {
    if (page != null) _page = page;
    setState(() => _loading = true);
    final result = await ServisApiAdmin.gereftanListeGhavaninAdmin(
      codeCo: widget.codeCo,
      categoryLaw: _category,
      search: _search.text.trim(),
      page: _page,
    );
    if (!mounted) return;
    setState(() {
      _loading = false;
      _items = result?.laws ?? [];
      _pagination = result?.pagination;
    });
    if (result == null) {
      showAdminSnack(context, 'دریافت قوانین ناموفق بود', error: true);
    }
  }

  void _searchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () => _load(page: 1));
  }

  Future<void> _pickPublishDate(
    BuildContext dialogContext,
    TextEditingController dateCtrl,
    void Function(VoidCallback) setLocal,
  ) async {
    final picked = await showPersianDatePicker(
      context: dialogContext,
      initialDate:
          JalaliDateUtil.parseToGregorian(dateCtrl.text) ?? DateTime.now(),
    );
    if (picked == null) return;
    setLocal(() {
      dateCtrl.text = JalaliDateUtil.formatFromDateTime(picked);
    });
  }

  Future<void> _edit([DadeGhavanin? law]) async {
    final title = TextEditingController(text: law?.titleLaw);
    final category = TextEditingController(text: law?.categoryLaw);
    final content = TextEditingController(text: law?.contentLaw);
    final version = TextEditingController(text: law?.versionLaw ?? '1.0');
    final initialDate = law == null
        ? JalaliDateUtil.formatFromDateTime(DateTime.now())
        : JalaliDateUtil.serverToDisplay(law.datePublish);
    final date = TextEditingController(text: initialDate);
    final attachment = TextEditingController(text: law?.attachmentUrl);
    bool active = law?.isActiveBool ?? true;
    final key = GlobalKey<FormState>();
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(law == null ? 'افزودن قانون' : 'ویرایش قانون'),
          content: SizedBox(
            width: 560,
            child: Form(
              key: key,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: title,
                      decoration: AdminUi.fieldDecoration('عنوان'),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'عنوان را وارد کنید'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: category,
                      decoration: AdminUi.fieldDecoration('دسته‌بندی'),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'دسته‌بندی را وارد کنید'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                            child: TextFormField(
                                controller: version,
                                decoration: AdminUi.fieldDecoration('نسخه'))),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: date,
                            readOnly: true,
                            onTap: () =>
                                _pickPublishDate(ctx, date, setLocal),
                            decoration: AdminUi.fieldDecoration(
                              'تاریخ انتشار',
                              hint: 'انتخاب تاریخ',
                              suffix: IconButton(
                                tooltip: 'انتخاب تاریخ',
                                icon: const Icon(Icons.calendar_month_outlined),
                                onPressed: () =>
                                    _pickPublishDate(ctx, date, setLocal),
                              ),
                            ),
                            validator: (v) => v == null || v.trim().isEmpty
                                ? 'تاریخ را وارد کنید'
                                : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: content,
                      decoration: AdminUi.fieldDecoration('متن قانون'),
                      minLines: 4,
                      maxLines: 8,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                        controller: attachment,
                        decoration: AdminUi.fieldDecoration('نشانی پیوست')),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('فعال'),
                      value: active,
                      onChanged: (v) => setLocal(() => active = v),
                    ),
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
              child: const Text('ذخیره'),
            ),
          ],
        ),
      ),
    );
    if (saved != true || !mounted) return;
    final publishForDb = JalaliDateUtil.toPathSafeJalali(date.text.trim());
    final value = DadeGhavanin(
      idLaw: law?.idLaw ?? 0,
      codeCo: widget.codeCo,
      titleLaw: title.text.trim(),
      categoryLaw: category.text.trim(),
      contentLaw: content.text.trim(),
      versionLaw: version.text.trim(),
      datePublish: publishForDb.isNotEmpty ? publishForDb : date.text.trim(),
      attachmentUrl:
          attachment.text.trim().isEmpty ? null : attachment.text.trim(),
      isActive: active ? 1 : 0,
    );
    final result = law == null
        ? await ServisApiAdmin.sakhtGhavanin(value)
        : await ServisApiAdmin.virayeshGhavanin(law.idLaw, value);
    if (!mounted) return;
    showAdminSnack(
        context,
        result.message ??
            (result.success ? 'با موفقیت ذخیره شد' : 'ذخیره ناموفق بود'),
        error: !result.success);
    if (result.success) _load();
  }

  Future<void> _delete(DadeGhavanin law) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف قانون'),
        content: Text('«${law.titleLaw}» حذف شود؟ این عمل قابل بازگشت نیست.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('انصراف'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    final result = await ServisApiAdmin.hazfGhavanin(law.idLaw);
    if (!mounted) return;
    showAdminSnack(
      context,
      result.message ?? (result.success ? 'حذف شد' : 'حذف ناموفق بود'),
      error: !result.success,
    );
    if (result.success) {
      setState(() {
        _items.removeWhere((e) => e.idLaw == law.idLaw);
      });
      await _load();
      // اگر سرور هنوز soft-delete کند، آیتم را از لیست محلی حذف می‌کنیم
      if (mounted) {
        setState(() {
          _items.removeWhere((e) => e.idLaw == law.idLaw);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalPages = _pagination?.totalPages ?? 1;
    return AdminPageShell(
      title: 'مدیریت قوانین',
      subtitle: '${_pagination?.total ?? _items.length} قانون',
      icon: Icons.gavel_outlined,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _edit,
        icon: const Icon(Icons.add),
        label: const Text('قانون جدید'),
      ),
      child: Column(
        children: [
          AdminToolbar(
            searchController: _search,
            searchHint: 'عنوان یا متن قانون',
            onSearchChanged: _searchChanged,
            filters: [
              SizedBox(
                width: 220,
                child: DropdownButtonFormField<String?>(
                  initialValue: _category,
                  decoration: AdminUi.fieldDecoration('دسته‌بندی'),
                  items: [
                    const DropdownMenuItem(
                        value: null, child: Text('همه دسته‌ها')),
                    ..._categories.map((e) => DropdownMenuItem(
                        value: e.categoryLaw,
                        child: Text('${e.categoryLaw} (${e.count})'))),
                  ],
                  onChanged: (v) {
                    setState(() => _category = v);
                    _load(page: 1);
                  },
                ),
              ),
            ],
            trailing: [
              IconButton(
                  onPressed: _load,
                  tooltip: 'بازخوانی',
                  icon: const Icon(Icons.refresh))
            ],
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _items.isEmpty
                    ? const AdminEmptyState(message: 'قانونی یافت نشد')
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        itemCount: _items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, index) {
                          final law = _items[index];
                          final publishDate =
                              JalaliDateUtil.serverToPersianDisplay(
                                  law.datePublish);
                          return Container(
                            decoration: AdminUi.cardDecoration(),
                            padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(child: Text('${law.idLaw}')),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        law.titleLaw,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 15,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 6,
                                        crossAxisAlignment:
                                            WrapCrossAlignment.center,
                                        children: [
                                          Text(
                                            '${law.categoryLaw} • نسخه ${law.versionLaw}',
                                            style: TextStyle(
                                              color: Colors.grey.shade700,
                                              fontSize: 13,
                                            ),
                                          ),
                                          if (publishDate.isNotEmpty)
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 3,
                                              ),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFEEF6F8),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                                border: Border.all(
                                                  color:
                                                      const Color(0xFFB8DCE3),
                                                ),
                                              ),
                                              child: Text(
                                                publishDate,
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                  color: Color(0xFF0F6A7A),
                                                  letterSpacing: 0.2,
                                                ),
                                              ),
                                            ),
                                          AdminStatusChip(
                                            label: law.isActiveBool
                                                ? 'فعال'
                                                : 'غیرفعال',
                                            active: law.isActiveBool,
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  onPressed: () => _edit(law),
                                  tooltip: 'ویرایش',
                                  icon: const Icon(Icons.edit_outlined),
                                ),
                                IconButton(
                                  onPressed: () => _delete(law),
                                  tooltip: 'حذف',
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: Colors.red,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
          if (!_loading && totalPages > 1)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                      onPressed:
                          _page > 1 ? () => _load(page: _page - 1) : null,
                      icon: const Icon(Icons.chevron_right)),
                  Text('صفحه $_page از $totalPages'),
                  IconButton(
                      onPressed: _page < totalPages
                          ? () => _load(page: _page + 1)
                          : null,
                      icon: const Icon(Icons.chevron_left)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
