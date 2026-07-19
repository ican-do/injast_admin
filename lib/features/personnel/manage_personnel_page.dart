import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:injast_admin/features/personnel/personnel_api.dart';
import 'package:injast_admin/features/shared/admin_ui.dart';

class ManagePersonnelPage extends StatefulWidget {
  const ManagePersonnelPage({
    super.key,
    required this.codeCo,
    this.currentUserId,
  });

  final String codeCo;
  final String? currentUserId;

  @override
  State<ManagePersonnelPage> createState() => _ManagePersonnelPageState();
}

class _ManagePersonnelPageState extends State<ManagePersonnelPage> {
  List<Personnel> _items = const [];
  List<String> _categories = const [];
  String? _category;
  bool _loading = true;
  String? _error;

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
      final result = await Future.wait([
        getPersonnelList(codeCo: widget.codeCo),
        getPersonnelCategories(widget.codeCo),
      ]);
      if (!mounted) return;
      setState(() {
        _items = result[0] as List<Personnel>;
        _categories = result[1] as List<String>;
        if (!_categories.contains(_category)) _category = null;
      });
    } catch (_) {
      if (mounted) setState(() => _error = 'دریافت اطلاعات پرسنل انجام نشد.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _edit([Personnel? item]) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _PersonnelDialog(
        codeCo: widget.codeCo,
        currentUserId: widget.currentUserId,
        categories: _categories,
        item: item,
      ),
    );
    if (saved == true && mounted) {
      showAdminSnack(
          context, item == null ? 'پرسنل افزوده شد.' : 'اطلاعات ویرایش شد.');
      await _load();
    }
  }

  Future<void> _delete(Personnel item) async {
    try {
      await deletePersonnel(item.id!);
      if (!mounted) return;
      showAdminSnack(context, 'پرسنل حذف شد.');
      await _load();
    } catch (_) {
      if (mounted) showAdminSnack(context, 'حذف پرسنل انجام نشد.', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = _category == null
        ? _items
        : _items.where((item) => item.category == _category).toList();
    return AdminPageShell(
      title: 'مدیریت پرسنل',
      subtitle: 'ثبت و ویرایش اعضای مجموعه',
      icon: FluentIcons.people_team_24_regular,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(),
        icon: const Icon(FluentIcons.add_24_regular),
        label: const Text('افزودن پرسنل'),
      ),
      actions: [
        IconButton(
          tooltip: 'تازه‌سازی',
          onPressed: _loading ? null : _load,
          icon: const Icon(FluentIcons.arrow_clockwise_24_regular),
        ),
      ],
      child: Column(
        children: [
          AdminToolbar(
            filters: [
              SizedBox(
                width: 220,
                child: DropdownButtonFormField<String?>(
                  initialValue: _category,
                  decoration: AdminUi.fieldDecoration('دسته‌بندی'),
                  items: [
                    const DropdownMenuItem(
                        value: null, child: Text('همه دسته‌ها')),
                    ..._categories.map(
                      (value) =>
                          DropdownMenuItem(value: value, child: Text(value)),
                    ),
                  ],
                  onChanged: (value) => setState(() => _category = value),
                ),
              ),
            ],
          ),
          Expanded(child: _body(visible)),
        ],
      ),
    );
  }

  Widget _body(List<Personnel> items) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return AdminEmptyState(
        message: _error!,
        icon: FluentIcons.error_circle_24_regular,
      );
    }
    if (items.isEmpty) {
      return const AdminEmptyState(message: 'پرسنلی برای نمایش وجود ندارد.');
    }
    return LayoutBuilder(
      builder: (_, constraints) {
        final columns = constraints.maxWidth >= 1000
            ? 3
            : constraints.maxWidth >= 650
                ? 2
                : 1;
        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            mainAxisExtent: 220,
          ),
          itemCount: items.length,
          itemBuilder: (_, index) {
            final item = items[index];
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: AdminUi.cardDecoration(
                color: item.isActive ? Colors.white : const Color(0xFFF8FAFC),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.fullName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AdminUi.ink,
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              item.roleTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      AdminStatusChip(
                        label: item.isActive ? 'فعال' : 'غیرفعال',
                        active: item.isActive,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    children: [
                      Chip(
                        visualDensity: VisualDensity.compact,
                        label: Text(item.category),
                      ),
                      Chip(
                        visualDensity: VisualDensity.compact,
                        label: Text('ترتیب ${item.displayOrder}'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Expanded(
                    child: Text(
                      item.bio?.trim().isNotEmpty == true
                          ? item.bio!
                          : 'بدون توضیحات',
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AdminUi.muted, height: 1.5),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      IconButton(
                        tooltip: 'ویرایش',
                        onPressed: () => _edit(item),
                        icon: const Icon(FluentIcons.edit_24_regular),
                      ),
                      IconButton(
                        tooltip: 'حذف',
                        color: Colors.red.shade700,
                        onPressed: item.id == null
                            ? null
                            : () => showAdminConfirm(
                                  context: context,
                                  title: 'حذف پرسنل',
                                  message: '«${item.fullName}» حذف شود؟',
                                  confirmLabel: 'حذف',
                                  onConfirm: () => _delete(item),
                                ),
                        icon: const Icon(FluentIcons.delete_24_regular),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _PersonnelDialog extends StatefulWidget {
  const _PersonnelDialog({
    required this.codeCo,
    required this.currentUserId,
    required this.categories,
    this.item,
  });

  final String codeCo;
  final String? currentUserId;
  final List<String> categories;
  final Personnel? item;

  @override
  State<_PersonnelDialog> createState() => _PersonnelDialogState();
}

class _PersonnelDialogState extends State<_PersonnelDialog> {
  final _formKey = GlobalKey<FormState>();
  late final List<TextEditingController> _controllers;
  late bool _active;
  bool _saving = false;
  String? _error;

  TextEditingController get _name => _controllers[0];
  TextEditingController get _role => _controllers[1];
  TextEditingController get _category => _controllers[2];
  TextEditingController get _bio => _controllers[3];
  TextEditingController get _phone => _controllers[4];
  TextEditingController get _email => _controllers[5];
  TextEditingController get _photo => _controllers[6];
  TextEditingController get _order => _controllers[7];

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _controllers = [
      TextEditingController(text: item?.fullName ?? ''),
      TextEditingController(text: item?.roleTitle ?? ''),
      TextEditingController(text: item?.category ?? ''),
      TextEditingController(text: item?.bio ?? ''),
      TextEditingController(text: item?.phone ?? ''),
      TextEditingController(text: item?.email ?? ''),
      TextEditingController(text: item?.photoUrl ?? ''),
      TextEditingController(text: '${item?.displayOrder ?? 0}'),
    ];
    _active = item?.isActive ?? true;
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'این فیلد الزامی است.' : null;

  String? _optional(String value) => value.trim().isEmpty ? null : value.trim();

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final values = (
        fullName: _name.text.trim(),
        roleTitle: _role.text.trim(),
        category: _category.text.trim(),
        bio: _optional(_bio.text),
        phone: _optional(_phone.text),
        email: _optional(_email.text),
        photoUrl: _optional(_photo.text),
        isActive: _active,
        displayOrder: int.tryParse(_order.text.trim()) ?? 0,
      );
      if (widget.item == null) {
        await createPersonnel(
          codeCo: widget.codeCo,
          fullName: values.fullName,
          roleTitle: values.roleTitle,
          category: values.category,
          bio: values.bio,
          phone: values.phone,
          email: values.email,
          photoUrl: values.photoUrl,
          isActive: values.isActive,
          displayOrder: values.displayOrder,
          idUser: int.tryParse(widget.currentUserId ?? ''),
        );
      } else {
        await updatePersonnel(
          id: widget.item!.id!,
          fullName: values.fullName,
          roleTitle: values.roleTitle,
          category: values.category,
          bio: values.bio,
          phone: values.phone,
          email: values.email,
          photoUrl: values.photoUrl,
          isActive: values.isActive,
          displayOrder: values.displayOrder,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'ذخیره اطلاعات انجام نشد.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget field(
      TextEditingController controller,
      String label, {
      bool required = false,
      int lines = 1,
      TextInputType? keyboard,
    }) {
      return TextFormField(
        controller: controller,
        maxLines: lines,
        keyboardType: keyboard,
        validator: required ? _required : null,
        decoration: AdminUi.fieldDecoration(label),
      );
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760, maxHeight: 820),
          child: Column(
            children: [
              ListTile(
                title: Text(
                  widget.item == null ? 'افزودن پرسنل' : 'ویرایش پرسنل',
                  style: const TextStyle(
                    color: AdminUi.ink,
                    fontWeight: FontWeight.w800,
                    fontSize: 19,
                  ),
                ),
                trailing: IconButton(
                  onPressed: _saving ? null : () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: LayoutBuilder(
                      builder: (_, constraints) {
                        final width = constraints.maxWidth >= 620
                            ? (constraints.maxWidth - 12) / 2
                            : constraints.maxWidth;
                        return Wrap(
                          spacing: 12,
                          runSpacing: 14,
                          children: [
                            SizedBox(
                              width: width,
                              child: field(_name, 'نام و نام خانوادگی',
                                  required: true),
                            ),
                            SizedBox(
                              width: width,
                              child: field(_role, 'عنوان سمت', required: true),
                            ),
                            SizedBox(
                              width: width,
                              child: Autocomplete<String>(
                                initialValue:
                                    TextEditingValue(text: _category.text),
                                optionsBuilder: (value) =>
                                    widget.categories.where(
                                  (option) => option.contains(value.text),
                                ),
                                onSelected: (value) => _category.text = value,
                                fieldViewBuilder:
                                    (_, controller, focusNode, __) =>
                                        TextFormField(
                                  controller: controller,
                                  focusNode: focusNode,
                                  onChanged: (value) => _category.text = value,
                                  validator: _required,
                                  decoration:
                                      AdminUi.fieldDecoration('دسته‌بندی'),
                                ),
                              ),
                            ),
                            SizedBox(
                              width: width,
                              child: field(
                                _order,
                                'ترتیب نمایش',
                                keyboard: TextInputType.number,
                              ),
                            ),
                            SizedBox(
                              width: width,
                              child: field(_phone, 'تلفن',
                                  keyboard: TextInputType.phone),
                            ),
                            SizedBox(
                              width: width,
                              child: field(_email, 'ایمیل',
                                  keyboard: TextInputType.emailAddress),
                            ),
                            SizedBox(
                                width: width,
                                child: field(_photo, 'نشانی تصویر')),
                            SizedBox(
                              width: width,
                              child: SwitchListTile(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: const BorderSide(
                                      color: AdminUi.cardBorder),
                                ),
                                title: const Text('فعال'),
                                value: _active,
                                onChanged: (value) =>
                                    setState(() => _active = value),
                              ),
                            ),
                            SizedBox(
                              width: constraints.maxWidth,
                              child: field(_bio, 'معرفی کوتاه', lines: 4),
                            ),
                            if (_error != null)
                              Text(_error!,
                                  style: const TextStyle(color: Colors.red)),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _saving ? null : () => Navigator.pop(context),
                      child: const Text('انصراف'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(FluentIcons.save_24_regular),
                      label: const Text('ذخیره'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
