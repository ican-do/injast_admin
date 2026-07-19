import 'package:flutter/material.dart';
import 'package:injast_admin/features/raste/raste_api.dart';
import 'package:injast_admin/features/shared/admin_ui.dart';

class ManageRastePage extends StatefulWidget {
  const ManageRastePage({
    super.key,
    required this.codeCo,
    required this.idUser,
  });

  final String codeCo;
  final String idUser;

  @override
  State<ManageRastePage> createState() => _ManageRastePageState();
}

class _ManageRastePageState extends State<ManageRastePage> {
  static const _types = ['توزیعی', 'تولیدی', 'خدماتی', 'خدمات فنی'];

  final _searchController = TextEditingController();
  final _tableScrollController = ScrollController();
  List<Map<String, dynamic>> _items = [];
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
    _tableScrollController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filtered {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return _items;
    return _items.where((item) {
      return [
        item['name_raste'],
        item['code_raste'],
        item['type_raste'],
      ].any((value) => (value?.toString().toLowerCase() ?? '').contains(query));
    }).toList();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await getRasteList(widget.codeCo);
      if (!mounted) return;
      setState(() => _items = items);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openForm([Map<String, dynamic>? item]) async {
    final isEdit = item != null;
    final nameController =
        TextEditingController(text: item?['name_raste']?.toString() ?? '');
    final codeController =
        TextEditingController(text: item?['code_raste']?.toString() ?? '');
    var type = item?['type_raste']?.toString() ?? _types.first;
    if (!_types.contains(type)) type = _types.first;

    final submitted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEdit ? 'ویرایش رسته' : 'افزودن رسته'),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  autofocus: true,
                  decoration: AdminUi.fieldDecoration('نام رسته'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: codeController,
                  decoration: AdminUi.fieldDecoration('کد رسته'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: type,
                  decoration: AdminUi.fieldDecoration('نوع رسته'),
                  items: _types
                      .map((value) =>
                          DropdownMenuItem(value: value, child: Text(value)))
                      .toList(),
                  onChanged: (value) =>
                      setDialogState(() => type = value ?? _types.first),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('انصراف'),
            ),
            FilledButton(
              onPressed: () {
                if (nameController.text.trim().isEmpty ||
                    codeController.text.trim().isEmpty) {
                  showAdminSnack(
                    context,
                    'نام و کد رسته را وارد کنید',
                    error: true,
                  );
                  return;
                }
                Navigator.pop(dialogContext, true);
              },
              child: const Text('ذخیره'),
            ),
          ],
        ),
      ),
    );

    if (submitted != true || !mounted) {
      nameController.dispose();
      codeController.dispose();
      return;
    }

    final name = nameController.text.trim();
    final code = codeController.text.trim();
    nameController.dispose();
    codeController.dispose();

    try {
      final ok = isEdit
          ? await updateRaste(
              idRaste: item['id_raste'].toString(),
              name: name,
              code: code,
              type: type,
            )
          : await createRaste(
              codeCo: widget.codeCo,
              name: name,
              code: code,
              type: type,
              idUser: widget.idUser,
            );
      if (!mounted) return;
      showAdminSnack(
        context,
        ok ? 'رسته با موفقیت ذخیره شد' : 'ذخیره رسته ناموفق بود',
        error: !ok,
      );
      if (ok) await _load();
    } catch (error) {
      if (mounted) showAdminSnack(context, error.toString(), error: true);
    }
  }

  void _confirmDelete(Map<String, dynamic> item) {
    final name = item['name_raste']?.toString() ?? '';
    showAdminConfirm(
      context: context,
      title: 'حذف رسته',
      message: 'رسته «$name» حذف شود؟',
      confirmLabel: 'حذف',
      onConfirm: () async {
        try {
          final ok = await deleteRaste(item['id_raste'].toString());
          if (!mounted) return;
          showAdminSnack(
            context,
            ok ? 'رسته حذف شد' : 'حذف رسته ناموفق بود',
            error: !ok,
          );
          if (ok) await _load();
        } catch (error) {
          if (mounted) showAdminSnack(context, error.toString(), error: true);
        }
      },
    );
  }

  Widget _actions(Map<String, dynamic> item) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'ویرایش',
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            onPressed: () => _openForm(item),
            icon: const Icon(Icons.edit_outlined),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'حذف',
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            color: Colors.red.shade700,
            onPressed: () => _confirmDelete(item),
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      );

  Widget _table(List<Map<String, dynamic>> items) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Scrollbar(
          controller: _tableScrollController,
          thumbVisibility: true,
          child: SingleChildScrollView(
            controller: _tableScrollController,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: constraints.maxWidth - 32),
                child: Container(
                  decoration: AdminUi.cardDecoration(),
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('کد')),
                      DataColumn(label: Text('نام رسته')),
                      DataColumn(label: Text('نوع')),
                      DataColumn(label: Text('عملیات')),
                    ],
                    rows: items
                        .map(
                          (item) => DataRow(
                            cells: [
                              DataCell(
                                  Text(item['code_raste']?.toString() ?? '—')),
                              DataCell(
                                  Text(item['name_raste']?.toString() ?? '—')),
                              DataCell(
                                  Text(item['type_raste']?.toString() ?? '—')),
                              DataCell(_actions(item)),
                            ],
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _cards(List<Map<String, dynamic>> items) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final item = items[index];
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: AdminUi.cardDecoration(),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: AdminUi.ink.withValues(alpha: 0.1),
                child: const Icon(Icons.category_outlined, color: AdminUi.ink),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['name_raste']?.toString() ?? 'بدون نام',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'کد: ${item['code_raste'] ?? '—'}  •  ${item['type_raste'] ?? '—'}',
                      style: const TextStyle(color: AdminUi.muted),
                    ),
                  ],
                ),
              ),
              _actions(item),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = _filtered;
    return AdminPageShell(
      title: 'مدیریت رسته‌ها',
      subtitle: '${items.length} رسته',
      icon: Icons.category_outlined,
      actions: [
        IconButton(
          tooltip: 'بازخوانی',
          onPressed: _loading ? null : _load,
          icon: const Icon(Icons.refresh),
        ),
      ],
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add),
        label: const Text('رسته جدید'),
      ),
      child: Column(
        children: [
          AdminToolbar(
            searchController: _searchController,
            searchHint: 'نام، کد یا نوع رسته',
            onSearchChanged: (_) => setState(() {}),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? AdminEmptyState(message: _error!)
                    : items.isEmpty
                        ? const AdminEmptyState(message: 'رسته‌ای یافت نشد')
                        : LayoutBuilder(
                            builder: (context, constraints) =>
                                constraints.maxWidth >= 760
                                    ? _table(items)
                                    : _cards(items),
                          ),
          ),
        ],
      ),
    );
  }
}
