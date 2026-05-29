import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:injast_admin/file_management/parvande_api.dart';

/// دیالوگ نمایش جزئیات کامل پرونده.
class ParvandeDetailsDialog extends StatelessWidget {
  const ParvandeDetailsDialog({
    super.key,
    required this.parvande,
    required this.onCall,
    required this.onSms,
    required this.onMap,
    required this.onNewInspection,
    required this.onInspectionHistory,
    required this.onImages,
    required this.onLicense,
    required this.onDocuments,
    required this.onPartners,
    required this.onComplaint,
    required this.onEdit,
    this.showEdit = true,
  });

  final Map<String, dynamic> parvande;
  final VoidCallback onCall;
  final VoidCallback onSms;
  final VoidCallback onMap;
  final VoidCallback onNewInspection;
  final VoidCallback onInspectionHistory;
  final VoidCallback onImages;
  final VoidCallback onLicense;
  final VoidCallback onDocuments;
  final VoidCallback onPartners;
  final VoidCallback onComplaint;
  final VoidCallback onEdit;
  final bool showEdit;

  static const _accent = Color(0xFF1E3A5F);

  @override
  Widget build(BuildContext context) {
    final p = parvande;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640, maxHeight: 720),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _header(context, p),
            const Divider(height: 1),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _section('اطلاعات عضو', [
                      _row('نام', p.fullName),
                      _row('کد ملی', p.codeMeli),
                      _row('شماره همراه', p.mob),
                    ]),
                    _section('اطلاعات واحد صنفی', [
                      _row('نام واحد', p.storeName),
                      _row('رسته', p.raste),
                      _row('شناسه صنفی', p.shenase),
                      _row('شماره پرونده', p.numParvande),
                      _row('کد پستی', p.codePosti),
                      _row('وضعیت پروانه', p.vaziyat),
                    ]),
                    _section('آدرس و موقعیت', [
                      _row('استان', p.state),
                      _row('شهر', p.city),
                      _row('منطقه', p.mantaghe),
                      _row('آدرس', p.address),
                      if (p.hasLocation) _row('مختصات', '${p.lat}, ${p.lng}'),
                    ]),
                    const SizedBox(height: 8),
                    _opsBar(context),
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  TextButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                    label: const Text('بستن'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context, Map<String, dynamic> p) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFF1B2A41), Color(0xFF2C4A75)],
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(FluentIcons.document_24_regular, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.fullName.isEmpty ? '—' : p.fullName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
                ),
                const SizedBox(height: 2),
                Text(
                  p.storeName.isEmpty ? '—' : p.storeName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'بستن',
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _section(String title, List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w800, color: _accent, fontSize: 13.5),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF6F8FB),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE5EAF1)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
          ),
        ],
      ),
    );
  }

  Widget _row(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(k, style: const TextStyle(color: Colors.black54, fontSize: 12.5)),
          ),
          Expanded(
            child: Text(
              v.isEmpty ? '—' : v,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _opsBar(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        _opBtn('تماس', FluentIcons.call_24_regular, onCall, const Color(0xFF2E7D32)),
        _opBtn('پیامک', FluentIcons.chat_24_regular, onSms, const Color(0xFF1565C0)),
        _opBtn('نقشه', FluentIcons.location_24_regular, () {
          Navigator.of(context).pop();
          onMap();
        }, const Color(0xFFEF6C00)),
        _opBtn('بازرسی', FluentIcons.clipboard_pulse_24_regular, () {
          Navigator.of(context).pop();
          onNewInspection();
        }, const Color(0xFF2E7D32)),
        _opBtn('سوابق بازرسی', FluentIcons.clipboard_search_24_regular, () {
          Navigator.of(context).pop();
          onInspectionHistory();
        }, const Color(0xFF3949AB)),
        _opBtn('تصاویر', FluentIcons.image_multiple_24_regular, () {
          Navigator.of(context).pop();
          onImages();
        }, const Color(0xFF7B1FA2)),
        _opBtn('پروانه', FluentIcons.document_24_regular, () {
          Navigator.of(context).pop();
          onLicense();
        }, const Color(0xFF00695C)),
        _opBtn('مدارک', FluentIcons.document_folder_24_regular, () {
          Navigator.of(context).pop();
          onDocuments();
        }, const Color(0xFF6D4C41)),
        _opBtn('شریک', FluentIcons.people_team_24_regular, () {
          Navigator.of(context).pop();
          onPartners();
        }, const Color(0xFF455A64)),
        _opBtn('ثبت شکایت', FluentIcons.warning_24_regular, () {
          Navigator.of(context).pop();
          onComplaint();
        }, const Color(0xFFD32F2F)),
        if (showEdit)
          _opBtn('ویرایش', FluentIcons.edit_24_regular, () {
            Navigator.of(context).pop();
            onEdit();
          }, const Color(0xFFEF6C00)),
      ],
    );
  }

  Widget _opBtn(String text, IconData icon, VoidCallback onTap, Color color) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 5),
            Text(text, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}
