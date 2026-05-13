import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:injast_admin/file_management/parvande_api.dart';
import 'package:shamsi_date/shamsi_date.dart';

/// کارت نمایش هر پرونده در شبکهٔ مدیریت پرونده‌ها.
class ParvandeCard extends StatelessWidget {
  const ParvandeCard({
    super.key,
    required this.parvande,
    required this.onDetails,
    required this.onCall,
    required this.onSms,
    required this.onMap,
    required this.onSoftDelete,
    required this.onRestore,
    required this.onHardDelete,
    required this.onInspections,
    required this.onImages,
    required this.onLicense,
    required this.onDocuments,
    required this.onPartners,
    required this.onComplaint,
    required this.onEdit,
  });

  final Map<String, dynamic> parvande;
  final VoidCallback onDetails;
  final VoidCallback onCall;
  final VoidCallback onSms;
  final VoidCallback onMap;
  final VoidCallback onSoftDelete;
  final VoidCallback onRestore;
  final VoidCallback onHardDelete;
  final VoidCallback onInspections;
  final VoidCallback onImages;
  final VoidCallback onLicense;
  final VoidCallback onDocuments;
  final VoidCallback onPartners;
  final VoidCallback onComplaint;
  final VoidCallback onEdit;

  static const _accent = Color(0xFF1E3A5F);
  static const _imageBase = 'https://apinovin.iranianasnaf.ir/';

  @override
  Widget build(BuildContext context) {
    final p = parvande;
    final isTrash = p.isTrash;
    final fullName = p.fullName.isEmpty ? '—' : p.fullName;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFDDE5EF)),
        boxShadow: const [
          BoxShadow(color: Color(0x10000000), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _header(fullName, isTrash),
            const SizedBox(height: 7),
            _statusStrip(p),
            const SizedBox(height: 6),
            _infoRow(FluentIcons.building_shop_24_regular, 'واحد', p.storeName),
            _infoRow(FluentIcons.tag_24_regular, 'رسته', p.raste),
            _infoRow(FluentIcons.call_24_regular, 'موبایل', p.mob),
            if (p.numParvande.isNotEmpty)
              _infoRow(FluentIcons.document_24_regular, 'شماره پرونده', p.numParvande),
            const SizedBox(height: 7),
            const Divider(height: 1, color: Color(0xFFEEF1F6)),
            const SizedBox(height: 7),
            _actionsTwoRows(isTrash),
          ],
        ),
      ),
    );
  }

  Widget _header(String fullName, bool isTrash) {
    return Row(
      children: [
        _profileImage(),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                fullName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5),
              ),
              if ((parvande.s('lbl_vaziyat_store')).isNotEmpty)
                Text(
                  parvande.s('lbl_vaziyat_store'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.black54, fontSize: 11.5),
                ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isTrash ? const Color(0xFFFFEBEE) : const Color(0xFFE8F5E9),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isTrash ? Icons.delete_outline : Icons.check_circle_outline,
                size: 14,
                color: isTrash ? const Color(0xFFC62828) : const Color(0xFF2E7D32),
              ),
              const SizedBox(width: 4),
              Text(
                isTrash ? 'سطل زباله' : 'فعال',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isTrash ? const Color(0xFFC62828) : const Color(0xFF2E7D32),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _profileImage() {
    final imageProfile = parvande.imageProfile.trim();
    final hasImg = imageProfile.isNotEmpty && imageProfile.toLowerCase() != 'null';
    final url = _resolveProfileUrl(imageProfile);
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 46,
        height: 46,
        decoration: const BoxDecoration(color: Color(0xFFEFF3FA)),
        child: hasImg
            ? Image.network(
                url ?? '',
                fit: BoxFit.cover,
                webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return const Center(
                    child: SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 1.8),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  if (kDebugMode) {
                    debugPrint(
                      '[ParvandeCard][ImageError] id=${parvande.idParvandeh} name=${parvande.fullName} raw="${parvande.imageProfile}" url="$url" error=$error',
                    );
                  }
                  return const Icon(FluentIcons.person_24_regular, color: _accent);
                },
              )
            : const Icon(FluentIcons.person_24_regular, color: _accent),
      ),
    );
  }

  /// تبدیل مقدار image_profile به یک URL معتبر برای وب.
  /// داده‌های قدیمی ممکن است بک‌اسلش، اسلش اضافه یا فاصله داشته باشند.
  String? _resolveProfileUrl(String rawValue) {
    final raw = rawValue.trim();
    if (raw.isEmpty || raw.toLowerCase() == 'null') return null;

    String normalized = raw.replaceAll('\\', '/').replaceAll(' ', '%20');

    if (normalized.startsWith('http://') || normalized.startsWith('https://')) {
      return Uri.encodeFull(normalized);
    }

    // اگر مسیر با دامنه ذخیره شده باشد ولی بدون پروتکل
    if (normalized.startsWith('apinovin.iranianasnaf.ir')) {
      normalized = normalized.replaceFirst(RegExp(r'^/+'), '');
      return Uri.encodeFull('https://$normalized');
    }

    normalized = normalized.replaceFirst(RegExp(r'^/+'), '');
    final base = _imageBase.endsWith('/') ? _imageBase : '$_imageBase/';
    return Uri.encodeFull('$base$normalized');
  }

  Widget _statusStrip(Map<String, dynamic> p) {
    final s = _statusStyle(p.vaziyatCode);
    final expText = _toJalaliDate(p.dateExp.trim());
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: s.bg,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: s.fg.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: [
          Icon(s.icon, size: 15, color: s.fg),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              'وضعیت اعتبار: ${p.vaziyat.isEmpty ? '—' : p.vaziyat}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11.8, fontWeight: FontWeight.w700, color: s.fg),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'اعتبار: $expText',
            style: TextStyle(fontSize: 11.2, color: s.fg, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  String _toJalaliDate(String raw) {
    if (raw.isEmpty || raw.toLowerCase() == 'null') return '—';
    final normalized = raw.replaceAll('/', '-').split(' ').first.trim();
    final parts = normalized.split('-');
    if (parts.length != 3) return raw;
    final y = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final d = int.tryParse(parts[2]);
    if (y == null || m == null || d == null) return raw;
    final j = Gregorian(y, m, d).toJalali();
    final mm = j.month.toString().padLeft(2, '0');
    final dd = j.day.toString().padLeft(2, '0');
    return '${j.year}/$mm/$dd';
  }

  _StatusStyle _statusStyle(String code) {
    switch (code.trim()) {
      case '2':
        return _StatusStyle(
          fg: const Color(0xFF2E7D32),
          bg: const Color(0xFFE8F5E9),
          icon: Icons.check_circle,
        );
      case '3':
        return _StatusStyle(
          fg: const Color(0xFFF57F17),
          bg: const Color(0xFFFFF8E1),
          icon: Icons.schedule,
        );
      case '8':
      case '6':
        return _StatusStyle(
          fg: const Color(0xFF424242),
          bg: const Color(0xFFF5F5F5),
          icon: Icons.block,
        );
      case '11':
      case '10':
        return _StatusStyle(
          fg: const Color(0xFFC62828),
          bg: const Color(0xFFFFEBEE),
          icon: Icons.cancel,
        );
      default:
        return _StatusStyle(
          fg: const Color(0xFF1E3A5F),
          bg: const Color(0xFFEAF2FF),
          icon: Icons.info,
        );
    }
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.black45),
          const SizedBox(width: 6),
          Text('$label: ', style: const TextStyle(fontSize: 12, color: Colors.black54)),
          Expanded(
            child: Text(
              value.isEmpty ? '—' : value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionsTwoRows(bool isTrash) {
    final row1 = <Widget>[
      _btn('جزئیات', FluentIcons.info_24_regular, onDetails, color: _accent),
      _btn('تماس', FluentIcons.call_24_regular, onCall, color: const Color(0xFF2E7D32)),
      _btn('پیامک', FluentIcons.chat_24_regular, onSms, color: const Color(0xFF1565C0)),
      _btn('نقشه', FluentIcons.location_24_regular, onMap, color: const Color(0xFFEF6C00)),
      if (!isTrash)
        _btn('حذف نرم', FluentIcons.delete_24_regular, onSoftDelete, color: const Color(0xFFC62828)),
      if (isTrash)
        _btn('بازیابی', FluentIcons.arrow_undo_24_regular, onRestore, color: const Color(0xFF2E7D32)),
      if (isTrash)
        _btn('حذف دائم', FluentIcons.delete_dismiss_24_regular, onHardDelete,
            color: const Color(0xFFB71C1C), filled: true),
    ];
    final row2 = <Widget>[
      _miniBtn('بازرسی', FluentIcons.clipboard_search_24_regular, onInspections, const Color(0xFF3949AB)),
      _miniBtn('تصاویر', FluentIcons.image_multiple_24_regular, onImages, const Color(0xFF7B1FA2)),
      _miniBtn('پروانه', FluentIcons.document_24_regular, onLicense, const Color(0xFF00695C)),
      _miniBtn('مدارک', FluentIcons.document_folder_24_regular, onDocuments, const Color(0xFF6D4C41)),
      _miniBtn('شریک', FluentIcons.people_team_24_regular, onPartners, const Color(0xFF455A64)),
      _miniBtn('شکایت', FluentIcons.warning_24_regular, onComplaint, const Color(0xFFD32F2F)),
      _miniBtn('ویرایش', FluentIcons.edit_24_regular, onEdit, const Color(0xFFEF6C00)),
    ];
    return Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: row1.map((e) => Padding(padding: const EdgeInsets.only(left: 6), child: e)).toList()),
        ),
        const SizedBox(height: 6),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: row2.map((e) => Padding(padding: const EdgeInsets.only(left: 6), child: e)).toList()),
        ),
      ],
    );
  }

  Widget _btn(String text, IconData icon, VoidCallback onTap,
      {required Color color, bool filled = false}) {
    final bg = filled ? color : color.withValues(alpha: 0.10);
    final fg = filled ? Colors.white : color;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
          border: filled ? null : Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: fg),
            const SizedBox(width: 4),
            Text(text, style: TextStyle(fontSize: 12, color: fg, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }

  Widget _miniBtn(String text, IconData icon, VoidCallback onTap, Color color) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
            Text(text, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _StatusStyle {
  const _StatusStyle({required this.fg, required this.bg, required this.icon});
  final Color fg;
  final Color bg;
  final IconData icon;
}
