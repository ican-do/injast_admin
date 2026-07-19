import 'dart:async';

import 'package:flutter/material.dart';
import 'package:injast_admin/features/laws/dade_ghavanin.dart';
import 'package:injast_admin/features/requests/dade_darkhast.dart';
import 'package:injast_admin/features/requests/servis_api_admin.dart';
import 'package:injast_admin/features/shared/admin_ui.dart';

class ManageRequestsPage extends StatefulWidget {
  const ManageRequestsPage({super.key, required this.codeCo});
  final String codeCo;

  @override
  State<ManageRequestsPage> createState() => _ManageRequestsPageState();
}

class _ManageRequestsPageState extends State<ManageRequestsPage> {
  static const _statuses = [
    'ثبت شد',
    'در حال بررسی',
    'ارجاع شد',
    'تکمیل شد',
    'رد شد',
    'لغو شد'
  ];
  final _search = TextEditingController();
  List<DadeDarkhast> _items = [];
  PaginationInfo? _pagination;
  String? _status;
  bool _loading = true;
  int _page = 1;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _load();
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
    final result = await ServisApiAdmin.gereftanListeDarkhastAdmin(
      codeCo: widget.codeCo,
      statusRequest: _status,
      search: _search.text.trim(),
      page: _page,
    );
    if (!mounted) return;
    setState(() {
      _items = result?.requests ?? [];
      _pagination = result?.pagination;
      _loading = false;
    });
    if (result == null) {
      showAdminSnack(context, 'دریافت درخواست‌ها ناموفق بود', error: true);
    }
  }

  Color _statusColor(String value) {
    if (value.contains('رد') || value.contains('لغو')) return Colors.red;
    if (value.contains('تکمیل')) return Colors.green;
    if (value.contains('بررسی') || value.contains('ارجاع')) {
      return Colors.orange;
    }
    return Colors.blue;
  }

  Future<void> _details(DadeDarkhast summary) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    final details =
        await ServisApiAdmin.gereftanDarkhastAdmin(summary.idRequest);
    if (!mounted) return;
    Navigator.pop(context);
    if (details == null) {
      showAdminSnack(context, 'دریافت جزئیات ناموفق بود', error: true);
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(details.request.titleRequest),
        content: SizedBox(
          width: 720,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(spacing: 8, runSpacing: 8, children: [
                  Chip(label: Text(details.request.typeRequest)),
                  Chip(label: Text(details.request.targetOrg)),
                  Chip(
                      label: Text(details.request.statusRequest),
                      backgroundColor:
                          _statusColor(details.request.statusRequest)
                              .withValues(alpha: .12)),
                  if (details.request.isHighPriority)
                    const Chip(
                        label: Text('فوری'),
                        avatar: Icon(Icons.priority_high, color: Colors.red)),
                ]),
                const SizedBox(height: 12),
                _info('تاریخ ثبت', details.request.dateSubmit),
                _info('کاربر', '${details.request.idUser}'),
                _info('شرح درخواست', details.request.descriptionRequest ?? '—'),
                if (details.request.extraFieldsJson?.isNotEmpty == true) ...[
                  const Divider(height: 28),
                  const Text('اطلاعات تکمیلی',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  ...details.request.extraFieldsJson!.entries
                      .map((e) => _info(e.key, '${e.value}')),
                ],
                if (details.timeline.isNotEmpty) ...[
                  const Divider(height: 28),
                  const Text('تاریخچه وضعیت',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  ...details.timeline.map((e) => ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.history),
                        title: Text(e.statusValue),
                        subtitle: Text([
                          e.datetimeStatus,
                          if ((e.descriptionStatus ?? '').isNotEmpty)
                            e.descriptionStatus!
                        ].join(' • ')),
                      )),
                ],
                if (details.files.isNotEmpty) ...[
                  const Divider(height: 28),
                  Text('${details.files.length} فایل پیوست',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('بستن')),
          FilledButton.icon(
            onPressed: () async {
              Navigator.pop(ctx);
              await _changeStatus(details.request);
            },
            icon: const Icon(Icons.sync),
            label: const Text('تغییر وضعیت'),
          ),
        ],
      ),
    );
  }

  Widget _info(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
              width: 120,
              child: Text(label, style: const TextStyle(color: AdminUi.muted))),
          Expanded(child: Text(value)),
        ]),
      );

  Future<void> _changeStatus(DadeDarkhast request) async {
    String status = _statuses.contains(request.statusRequest)
        ? request.statusRequest
        : _statuses.first;
    final description = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (_, setLocal) => AlertDialog(
          title: const Text('تغییر وضعیت درخواست'),
          content: SizedBox(
            width: 460,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              DropdownButtonFormField<String>(
                initialValue: status,
                decoration: AdminUi.fieldDecoration('وضعیت جدید'),
                items: _statuses
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (v) => setLocal(() => status = v!),
              ),
              const SizedBox(height: 12),
              TextField(
                  controller: description,
                  minLines: 3,
                  maxLines: 5,
                  decoration: AdminUi.fieldDecoration('توضیح وضعیت')),
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('انصراف')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('ثبت وضعیت')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    final result = await ServisApiAdmin.taghireVaziyatDarkhast(
        request.idRequest, status, description.text.trim(), 0);
    if (!mounted) return;
    showAdminSnack(
        context,
        result.message ??
            (result.success ? 'وضعیت تغییر کرد' : 'تغییر وضعیت ناموفق بود'),
        error: !result.success);
    if (result.success) _load();
  }

  @override
  Widget build(BuildContext context) {
    final pages = _pagination?.totalPages ?? 1;
    return AdminPageShell(
      title: 'مدیریت درخواست‌ها',
      subtitle: '${_pagination?.total ?? _items.length} درخواست',
      icon: Icons.inbox_outlined,
      child: Column(children: [
        AdminToolbar(
          searchController: _search,
          searchHint: 'عنوان، نوع یا متقاضی',
          onSearchChanged: (_) {
            _debounce?.cancel();
            _debounce =
                Timer(const Duration(milliseconds: 450), () => _load(page: 1));
          },
          filters: [
            SizedBox(
              width: 200,
              child: DropdownButtonFormField<String?>(
                initialValue: _status,
                decoration: AdminUi.fieldDecoration('وضعیت'),
                items: [
                  const DropdownMenuItem(
                      value: null, child: Text('همه وضعیت‌ها')),
                  ..._statuses
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                ],
                onChanged: (v) {
                  setState(() => _status = v);
                  _load(page: 1);
                },
              ),
            ),
          ],
          trailing: [
            IconButton(onPressed: _load, icon: const Icon(Icons.refresh))
          ],
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _items.isEmpty
                  ? const AdminEmptyState(message: 'درخواستی یافت نشد')
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, i) {
                        final item = _items[i];
                        final color = _statusColor(item.statusRequest);
                        return Container(
                          decoration: AdminUi.cardDecoration(),
                          child: ListTile(
                            onTap: () => _details(item),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 18, vertical: 10),
                            leading: CircleAvatar(
                                backgroundColor: color.withValues(alpha: .12),
                                child: Icon(Icons.description_outlined,
                                    color: color)),
                            title: Text(item.titleRequest,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            subtitle: Text(
                                '${item.typeRequest} • ${item.targetOrg}\n${item.dateSubmit}'),
                            isThreeLine: true,
                            trailing:
                                Row(mainAxisSize: MainAxisSize.min, children: [
                              if (item.isHighPriority)
                                const Icon(Icons.priority_high,
                                    color: Colors.red),
                              const SizedBox(width: 6),
                              Chip(
                                  label: Text(item.statusRequest),
                                  backgroundColor: color.withValues(alpha: .1),
                                  side: BorderSide.none),
                              IconButton(
                                  onPressed: () => _changeStatus(item),
                                  tooltip: 'تغییر وضعیت',
                                  icon: const Icon(Icons.sync)),
                              const Icon(Icons.chevron_left),
                            ]),
                          ),
                        );
                      },
                    ),
        ),
        if (!_loading && pages > 1)
          Padding(
            padding: const EdgeInsets.all(10),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              IconButton(
                  onPressed: _page > 1 ? () => _load(page: _page - 1) : null,
                  icon: const Icon(Icons.chevron_right)),
              Text('صفحه $_page از $pages'),
              IconButton(
                  onPressed:
                      _page < pages ? () => _load(page: _page + 1) : null,
                  icon: const Icon(Icons.chevron_left)),
            ]),
          ),
      ]),
    );
  }
}
