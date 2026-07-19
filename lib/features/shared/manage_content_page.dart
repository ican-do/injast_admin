import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:injast_admin/features/shared/admin_ui.dart';
import 'package:url_launcher/url_launcher.dart';

class ManagedContentItem {
  const ManagedContentItem({
    required this.id,
    required this.title,
    required this.content,
    required this.imageUrl,
    required this.publishLink,
    required this.isActive,
  });

  final int? id;
  final String title;
  final String content;
  final String? imageUrl;
  final String? publishLink;
  final bool isActive;
}

typedef SaveManagedContent = Future<void> Function({
  int? id,
  required String title,
  required String content,
  String? imageUrl,
  String? publishLink,
  required bool isActive,
});

class ManageContentPage extends StatefulWidget {
  const ManageContentPage({
    super.key,
    required this.title,
    required this.subtitle,
    required this.singularName,
    required this.icon,
    required this.emptyMessage,
    required this.load,
    required this.save,
    required this.delete,
    this.placeholderColor = const Color(0xFFEAF2FF),
  });

  final String title;
  final String subtitle;
  final String singularName;
  final IconData icon;
  final String emptyMessage;
  final Future<List<ManagedContentItem>> Function() load;
  final SaveManagedContent save;
  final Future<void> Function(int id) delete;
  final Color placeholderColor;

  @override
  State<ManageContentPage> createState() => _ManageContentPageState();
}

class _ManageContentPageState extends State<ManageContentPage> {
  final _searchController = TextEditingController();
  List<ManagedContentItem> _items = const [];
  String _search = '';
  bool? _activeFilter;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await widget.load();
      if (mounted) setState(() => _items = items);
    } catch (_) {
      if (mounted) setState(() => _error = 'دریافت اطلاعات انجام نشد.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _edit([ManagedContentItem? item]) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ContentDialog(
        item: item,
        singularName: widget.singularName,
        save: widget.save,
      ),
    );
    if (saved == true && mounted) {
      showAdminSnack(
        context,
        item == null
            ? '${widget.singularName} افزوده شد.'
            : '${widget.singularName} ویرایش شد.',
      );
      await _load();
    }
  }

  Future<void> _delete(ManagedContentItem item) async {
    try {
      await widget.delete(item.id!);
      if (!mounted) return;
      showAdminSnack(context, '${widget.singularName} حذف شد.');
      await _load();
    } catch (_) {
      if (mounted) {
        showAdminSnack(context, 'حذف ${widget.singularName} انجام نشد.',
            error: true);
      }
    }
  }

  Future<void> _openLink(String value) async {
    final uri = Uri.tryParse(value);
    if (uri == null || !await launchUrl(uri)) {
      if (mounted) showAdminSnack(context, 'پیوند معتبر نیست.', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = _search.trim().toLowerCase();
    final visible = _items.where((item) {
      final status = _activeFilter == null || item.isActive == _activeFilter;
      final text = query.isEmpty ||
          item.title.toLowerCase().contains(query) ||
          item.content.toLowerCase().contains(query);
      return status && text;
    }).toList();
    return AdminPageShell(
      title: widget.title,
      subtitle: widget.subtitle,
      icon: widget.icon,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(),
        icon: const Icon(FluentIcons.add_24_regular),
        label: Text('افزودن ${widget.singularName}'),
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
            searchController: _searchController,
            searchHint: 'عنوان یا متن ${widget.singularName}',
            onSearchChanged: (value) => setState(() => _search = value),
            filters: [
              SizedBox(
                width: 180,
                child: DropdownButtonFormField<bool?>(
                  initialValue: _activeFilter,
                  decoration: AdminUi.fieldDecoration('وضعیت'),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('همه')),
                    DropdownMenuItem(value: true, child: Text('فعال')),
                    DropdownMenuItem(value: false, child: Text('غیرفعال')),
                  ],
                  onChanged: (value) => setState(() => _activeFilter = value),
                ),
              ),
            ],
          ),
          Expanded(child: _body(visible)),
        ],
      ),
    );
  }

  Widget _body(List<ManagedContentItem> items) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return AdminEmptyState(
        message: _error!,
        icon: FluentIcons.error_circle_24_regular,
      );
    }
    if (items.isEmpty) return AdminEmptyState(message: widget.emptyMessage);
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
            mainAxisExtent: 330,
          ),
          itemCount: items.length,
          itemBuilder: (_, index) => _card(items[index]),
        );
      },
    );
  }

  Widget _card(ManagedContentItem item) {
    final image = item.imageUrl?.trim() ?? '';
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: AdminUi.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 120,
            width: double.infinity,
            child: image.isEmpty
                ? ColoredBox(
                    color: widget.placeholderColor,
                    child: Icon(widget.icon, size: 42, color: AdminUi.muted),
                  )
                : Image.network(
                    image,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const ColoredBox(
                      color: Color(0xFFF1F5F9),
                      child: Icon(FluentIcons.image_off_24_regular),
                    ),
                  ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AdminUi.ink,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      AdminStatusChip(
                        label: item.isActive ? 'فعال' : 'غیرفعال',
                        active: item.isActive,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Text(
                      item.content,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AdminUi.muted, height: 1.5),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                if (item.publishLink?.trim().isNotEmpty == true)
                  IconButton(
                    tooltip: 'مشاهده پیوند',
                    onPressed: () => _openLink(item.publishLink!),
                    icon: const Icon(FluentIcons.open_24_regular),
                  ),
                const Spacer(),
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
                            title: 'حذف ${widget.singularName}',
                            message: '«${item.title}» حذف شود؟',
                            confirmLabel: 'حذف',
                            onConfirm: () => _delete(item),
                          ),
                  icon: const Icon(FluentIcons.delete_24_regular),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ContentDialog extends StatefulWidget {
  const _ContentDialog({
    required this.item,
    required this.singularName,
    required this.save,
  });

  final ManagedContentItem? item;
  final String singularName;
  final SaveManagedContent save;

  @override
  State<_ContentDialog> createState() => _ContentDialogState();
}

class _ContentDialogState extends State<_ContentDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _content;
  late final TextEditingController _image;
  late final TextEditingController _link;
  late bool _active;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.item?.title ?? '');
    _content = TextEditingController(text: widget.item?.content ?? '');
    _image = TextEditingController(text: widget.item?.imageUrl ?? '');
    _link = TextEditingController(text: widget.item?.publishLink ?? '');
    _active = widget.item?.isActive ?? true;
  }

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    _image.dispose();
    _link.dispose();
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
      await widget.save(
        id: widget.item?.id,
        title: _title.text.trim(),
        content: _content.text.trim(),
        imageUrl: _optional(_image.text),
        publishLink: _optional(_link.text),
        isActive: _active,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'ذخیره ${widget.singularName} انجام نشد.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720, maxHeight: 760),
          child: Column(
            children: [
              ListTile(
                title: Text(
                  widget.item == null
                      ? 'افزودن ${widget.singularName}'
                      : 'ویرایش ${widget.singularName}',
                  style: const TextStyle(
                    color: AdminUi.ink,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                trailing: IconButton(
                  onPressed: _saving ? null : () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _title,
                          validator: _required,
                          decoration: AdminUi.fieldDecoration('عنوان'),
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _content,
                          validator: _required,
                          minLines: 5,
                          maxLines: 9,
                          decoration: AdminUi.fieldDecoration(
                              'متن ${widget.singularName}'),
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _image,
                          keyboardType: TextInputType.url,
                          decoration: AdminUi.fieldDecoration('نشانی تصویر'),
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _link,
                          keyboardType: TextInputType.url,
                          decoration: AdminUi.fieldDecoration('پیوند انتشار'),
                        ),
                        const SizedBox(height: 14),
                        SwitchListTile(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(color: AdminUi.cardBorder),
                          ),
                          title: const Text('فعال باشد'),
                          value: _active,
                          onChanged: (value) => setState(() => _active = value),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          Text(_error!,
                              style: const TextStyle(color: Colors.red)),
                        ],
                      ],
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
