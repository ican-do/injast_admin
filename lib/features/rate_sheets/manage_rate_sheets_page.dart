import 'dart:async';

import 'package:flutter/material.dart';
import 'package:injast_admin/features/rate_sheets/rate_sheet_api.dart';
import 'package:injast_admin/features/shared/admin_ui.dart';

class ManageRateSheetsPage extends StatefulWidget {
  const ManageRateSheetsPage({
    super.key,
    required this.codeCo,
    this.updatedBy,
  });

  final String codeCo;
  final int? updatedBy;

  @override
  State<ManageRateSheetsPage> createState() => _ManageRateSheetsPageState();
}

class _ManageRateSheetsPageState extends State<ManageRateSheetsPage> {
  final _searchController = TextEditingController();
  final _tableScrollController = ScrollController();
  Timer? _searchDebounce;
  List<RateSheet> _items = [];
  List<String> _categories = [];
  String? _category;
  bool _loading = true;
  String? _error;
  int _page = 1;
  int _totalPages = 1;
  int _total = 0;

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _load();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _tableScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final values = await getRateSheetCategories(widget.codeCo);
      if (mounted) setState(() => _categories = values);
    } catch (_) {
      // Category filtering is optional; the main list remains usable.
    }
  }

  Future<void> _load({int? page}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final targetPage = page ?? _page;
      final response = await getRateSheetList(
        codeCo: widget.codeCo,
        search: _searchController.text.trim(),
        category: _category,
        page: targetPage,
        limit: 25,
      );
      if (!mounted) return;
      setState(() {
        _items = response.data;
        _page = response.pagination.page;
        _totalPages = response.pagination.totalPages;
        _total = response.pagination.total;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _searchChanged(String _) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 450), () {
      if (mounted) _load(page: 1);
    });
  }

  Future<void> _openForm([RateSheet? rate]) async {
    final title = TextEditingController(text: rate?.title ?? '');
    final category = TextEditingController(text: rate?.category ?? '');
    final unit = TextEditingController(text: rate?.unit ?? '');
    final price = TextEditingController(text: rate?.price ?? '');
    final currency = TextEditingController(text: rate?.currency ?? 'تومان');
    final source = TextEditingController(text: rate?.source ?? '');

    final submitted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(rate == null ? 'نرخ جدید' : 'ویرایش نرخ'),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: title,
                  autofocus: true,
                  decoration: AdminUi.fieldDecoration('عنوان'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: category,
                  decoration: AdminUi.fieldDecoration('دسته‌بندی'),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: unit,
                        decoration: AdminUi.fieldDecoration('واحد'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: price,
                        decoration: AdminUi.fieldDecoration('قیمت / متن نرخ'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: currency,
                        decoration: AdminUi.fieldDecoration('واحد پول'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: source,
                        decoration: AdminUi.fieldDecoration('منبع'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('انصراف'),
          ),
          FilledButton(
            onPressed: () {
              if (title.text.trim().isEmpty ||
                  unit.text.trim().isEmpty ||
                  price.text.trim().isEmpty) {
                showAdminSnack(
                  dialogContext,
                  'عنوان، واحد و قیمت الزامی است',
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
    );

    if (submitted != true || !mounted) {
      for (final controller in [
        title,
        category,
        unit,
        price,
        currency,
        source
      ]) {
        controller.dispose();
      }
      return;
    }

    final values = [
      title.text.trim(),
      category.text.trim(),
      unit.text.trim(),
      price.text.trim(),
      currency.text.trim(),
      source.text.trim(),
    ];
    for (final controller in [title, category, unit, price, currency, source]) {
      controller.dispose();
    }

    try {
      if (rate == null) {
        await createRateSheet(
          codeCo: widget.codeCo,
          title: values[0],
          category: values[1].isEmpty ? null : values[1],
          unit: values[2],
          price: values[3],
          currency: values[4].isEmpty ? 'تومان' : values[4],
          source: values[5].isEmpty ? null : values[5],
          updatedBy: widget.updatedBy,
        );
      } else {
        if (rate.id == null) throw Exception('شناسه نرخ معتبر نیست');
        await updateRateSheet(
          id: rate.id!,
          title: values[0],
          category: values[1],
          unit: values[2],
          price: values[3],
          currency: values[4].isEmpty ? 'تومان' : values[4],
          source: values[5],
          updatedBy: widget.updatedBy,
        );
      }
      if (!mounted) return;
      showAdminSnack(context, 'نرخ با موفقیت ذخیره شد');
      await Future.wait([_load(), _loadCategories()]);
    } catch (error) {
      if (mounted) showAdminSnack(context, error.toString(), error: true);
    }
  }

  void _confirmDelete(RateSheet rate) {
    showAdminConfirm(
      context: context,
      title: 'حذف نرخ',
      message: 'نرخ «${rate.title}» حذف شود؟',
      confirmLabel: 'حذف',
      onConfirm: () async {
        try {
          if (rate.id == null) throw Exception('شناسه نرخ معتبر نیست');
          await deleteRateSheet(rate.id!);
          if (!mounted) return;
          showAdminSnack(context, 'نرخ حذف شد');
          await _load();
        } catch (error) {
          if (mounted) showAdminSnack(context, error.toString(), error: true);
        }
      },
    );
  }

  Widget _actions(RateSheet rate) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'ویرایش',
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            onPressed: () => _openForm(rate),
            icon: const Icon(Icons.edit_outlined),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'حذف',
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            color: Colors.red.shade700,
            onPressed: () => _confirmDelete(rate),
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      );

  Widget _table() => LayoutBuilder(
        builder: (context, constraints) {
          return Scrollbar(
            controller: _tableScrollController,
            thumbVisibility: true,
            child: SingleChildScrollView(
              controller: _tableScrollController,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints:
                      BoxConstraints(minWidth: constraints.maxWidth - 32),
                  child: Container(
                    decoration: AdminUi.cardDecoration(),
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('عنوان')),
                        DataColumn(label: Text('دسته‌بندی')),
                        DataColumn(label: Text('واحد')),
                        DataColumn(label: Text('قیمت')),
                        DataColumn(label: Text('منبع')),
                        DataColumn(label: Text('عملیات')),
                      ],
                      rows: _items
                          .map(
                            (rate) => DataRow(cells: [
                              DataCell(Text(rate.title)),
                              DataCell(Text(rate.category ?? '—')),
                              DataCell(Text(rate.unit)),
                              DataCell(Text('${rate.price} ${rate.currency}')),
                              DataCell(Text(rate.source ?? '—')),
                              DataCell(_actions(rate)),
                            ]),
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

  Widget _cards() => ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        itemCount: _items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final rate = _items[index];
          return Container(
            padding: const EdgeInsets.all(14),
            decoration: AdminUi.cardDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        rate.title,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    _actions(rate),
                  ],
                ),
                Text(
                  '${rate.price} ${rate.currency} / ${rate.unit}',
                  style: const TextStyle(color: AdminUi.ink, fontSize: 16),
                ),
                if ((rate.category ?? '').isNotEmpty)
                  Text(
                    rate.category!,
                    style: const TextStyle(color: AdminUi.muted),
                  ),
              ],
            ),
          );
        },
      );

  Widget _pagination() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              tooltip: 'صفحه قبل',
              onPressed:
                  _page > 1 && !_loading ? () => _load(page: _page - 1) : null,
              icon: const Icon(Icons.chevron_right),
            ),
            Text('صفحه $_page از $_totalPages  •  $_total مورد'),
            IconButton(
              tooltip: 'صفحه بعد',
              onPressed: _page < _totalPages && !_loading
                  ? () => _load(page: _page + 1)
                  : null,
              icon: const Icon(Icons.chevron_left),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return AdminPageShell(
      title: 'مدیریت نرخ‌نامه',
      subtitle: '$_total مورد',
      icon: Icons.price_change_outlined,
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
        label: const Text('نرخ جدید'),
      ),
      child: Column(
        children: [
          AdminToolbar(
            searchController: _searchController,
            searchHint: 'جستجو در نرخ‌نامه',
            onSearchChanged: _searchChanged,
            filters: [
              SizedBox(
                width: 220,
                child: DropdownButtonFormField<String?>(
                  initialValue: _category,
                  decoration: AdminUi.fieldDecoration('دسته‌بندی'),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('همه دسته‌ها'),
                    ),
                    ..._categories.map(
                      (value) => DropdownMenuItem<String?>(
                        value: value,
                        child: Text(value),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() => _category = value);
                    _load(page: 1);
                  },
                ),
              ),
            ],
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? AdminEmptyState(message: _error!)
                    : _items.isEmpty
                        ? const AdminEmptyState(message: 'نرخی یافت نشد')
                        : LayoutBuilder(
                            builder: (context, constraints) =>
                                constraints.maxWidth >= 850
                                    ? _table()
                                    : _cards(),
                          ),
          ),
          if (!_loading && _error == null) _pagination(),
        ],
      ),
    );
  }
}
