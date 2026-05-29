import 'package:flutter/material.dart';
import 'package:injast_admin/file_management/hagh_ozviat_api.dart';
import 'package:injast_admin/file_management/hagh_ozviat_models.dart';

Future<void> showHaghOzviatMemberDialog({
  required BuildContext context,
  required String codeCo,
  required String shenaseStore,
  String memberName = '',
}) async {
  await showDialog<void>(
    context: context,
    builder: (ctx) => _HaghOzviatMemberDialog(
      codeCo: codeCo,
      shenaseStore: shenaseStore,
      memberName: memberName,
    ),
  );
}

class _HaghOzviatMemberDialog extends StatefulWidget {
  const _HaghOzviatMemberDialog({
    required this.codeCo,
    required this.shenaseStore,
    required this.memberName,
  });

  final String codeCo;
  final String shenaseStore;
  final String memberName;

  @override
  State<_HaghOzviatMemberDialog> createState() => _HaghOzviatMemberDialogState();
}

class _HaghOzviatMemberDialogState extends State<_HaghOzviatMemberDialog> {
  bool _loading = true;
  String? _error;
  HaghOzviatMemberSummary? _summary;

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
      final s = await HaghOzviatApi.instance.fetchSummary(
        codeCo: widget.codeCo,
        shenaseStore: widget.shenaseStore,
      );
      if (!mounted) return;
      setState(() {
        _summary = s;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  String _formatRial(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.memberName.trim().isEmpty
        ? 'حق عضویت'
        : 'حق عضویت — ${widget.memberName.trim()}';

    return AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: 560,
        child: _loading
            ? const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            : _error != null
                ? Text(_error!, style: TextStyle(color: Colors.red.shade800))
                : _buildBody(_summary!),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('بستن'),
        ),
        if (_error != null)
          TextButton(onPressed: _load, child: const Text('تلاش مجدد')),
      ],
    );
  }

  Widget _buildBody(HaghOzviatMemberSummary s) {
    if (s.rows.isEmpty) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('کد صنفی: ${widget.shenaseStore}'),
          const SizedBox(height: 12),
          const Text(
            'رکورد حق عضویتی برای این عضو در سرور ثبت نشده است.',
            style: TextStyle(height: 1.6),
          ),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('کد صنفی: ${widget.shenaseStore}'),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _sumCard(
                'در انتظار پرداخت',
                '${_formatRial(s.pendingRial)} ریال',
                const Color(0xFFFFEBEE),
                const Color(0xFFC62828),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _sumCard(
                'تایید شده (پرداخت‌شده)',
                '${_formatRial(s.confirmedRial)} ریال',
                const Color(0xFFE8F5E9),
                const Color(0xFF2E7D32),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 320),
          child: SingleChildScrollView(
            child: DataTable(
              headingRowHeight: 36,
              dataRowMinHeight: 32,
              dataRowMaxHeight: 48,
              columnSpacing: 12,
              columns: const [
                DataColumn(label: Text('سال')),
                DataColumn(label: Text('عنوان')),
                DataColumn(label: Text('مبلغ (ریال)')),
                DataColumn(label: Text('وضعیت')),
              ],
              rows: [
                for (final r in s.rows)
                  DataRow(
                    cells: [
                      DataCell(Text(r.sal.isEmpty ? '—' : r.sal)),
                      DataCell(
                        Text(
                          r.onvan.isEmpty ? '—' : r.onvan,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      DataCell(Text(_formatRial(r.mablaghRial))),
                      DataCell(
                        Text(
                          r.vaziyat.isEmpty ? '—' : r.vaziyat,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: r.isPending
                                ? const Color(0xFFC62828)
                                : r.isConfirmed
                                    ? const Color(0xFF2E7D32)
                                    : null,
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _sumCard(
    String label,
    String value,
    Color bg,
    Color fg,
  ) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: fg.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(label, style: TextStyle(fontSize: 11.5, color: fg)),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(fontWeight: FontWeight.w800, color: fg, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
