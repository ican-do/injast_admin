import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:injast_admin/features/shekayat/manage_shekayat_page.dart';
import 'package:injast_admin/features/shekayat/pages/shekayat_case_view_page.dart';
import 'package:injast_admin/features/shekayat/register_shekayat_page.dart';
import 'package:injast_admin/features/shekayat/shekayat_constants.dart';
import 'package:injast_admin/file_management/parvande_api.dart';

/// نمایش لیست شکایات متصل به یک پرونده
Future<void> showParvandeShekayatDialog({
  required BuildContext context,
  required String codeCo,
  required Map<String, dynamic> parvande,
  required List<Map<String, dynamic>> complaints,
  String? currentUserId,
  Map<String, dynamic>? currentUser,
}) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => _ParvandeShekayatDialog(
      codeCo: codeCo,
      parvande: parvande,
      complaints: complaints,
      currentUserId: currentUserId,
      currentUser: currentUser,
    ),
  );
}

class _ParvandeShekayatDialog extends StatelessWidget {
  const _ParvandeShekayatDialog({
    required this.codeCo,
    required this.parvande,
    required this.complaints,
    this.currentUserId,
    this.currentUser,
  });

  final String codeCo;
  final Map<String, dynamic> parvande;
  final List<Map<String, dynamic>> complaints;
  final String? currentUserId;
  final Map<String, dynamic>? currentUser;

  static const _accent = Color(0xFFD32F2F);

  Future<void> _openRegister(BuildContext context) async {
    Navigator.pop(context);
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RegisterShekayatPage(
          codeCo: codeCo,
          currentUserId: currentUserId,
          currentUser: currentUser,
          prefillStore: parvande,
        ),
      ),
    );
  }

  Future<void> _openManage(BuildContext context, {String? search}) async {
    Navigator.pop(context);
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ManageShekayatPage(
          codeCo: codeCo,
          currentUserId: currentUserId,
          currentUser: currentUser,
          initialSearch: search,
        ),
      ),
    );
  }

  Future<void> _openCase(BuildContext context, Map<String, dynamic> c) async {
    if (c['_aggregate_only'] == true) {
      await _openManage(context);
      return;
    }
    Navigator.pop(context);
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ShekayatCaseViewPage(
          codeCo: codeCo,
          complaint: c,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = parvande.fullName.isEmpty ? 'واحد صنفی' : parvande.fullName;
    final store = parvande.storeName.trim();
    final title = store.isNotEmpty ? store : name;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 560),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
              decoration: const BoxDecoration(
                color: _accent,
                borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
              ),
              child: Row(
                children: [
                  const Icon(FluentIcons.warning_24_regular, color: Colors.white, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'شکایات پرونده',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
              child: Row(
                children: [
                  Text(
                    '${complaints.length} شکایت متصل',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E3A5F),
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => _openManage(context),
                    icon: const Icon(Icons.open_in_new, size: 16),
                    label: const Text('مدیریت شکایات'),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: complaints.isEmpty
                  ? const Center(child: Text('شکایتی برای این پرونده یافت نشد'))
                  : ListView.separated(
                      padding: const EdgeInsets.all(10),
                      itemCount: complaints.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 6),
                      itemBuilder: (_, i) {
                        final c = complaints[i];
                        final no = c['complaint_number']?.toString() ?? '-';
                        final lbl = c['lbl_shekayat']?.toString().trim().isNotEmpty == true
                            ? c['lbl_shekayat'].toString()
                            : 'بدون عنوان';
                        final status = c['status_shekayat']?.toString() ?? '-';
                        final date = c['date_shekayat']?.toString() ?? '';
                        final statusColor = ShekayatConstants.statusColor(status);
                        return Material(
                          color: const Color(0xFFF7F9FC),
                          borderRadius: BorderRadius.circular(10),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () => _openCase(context, c),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              child: Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: _accent.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '#$no',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 11,
                                        color: _accent,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          lbl,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          [
                                            if (date.isNotEmpty) date,
                                            status,
                                          ].join('  •  '),
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            color: statusColor,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.chevron_left, color: Colors.black38),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('بستن'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _openRegister(context),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('شکایت جدید'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _accent,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
