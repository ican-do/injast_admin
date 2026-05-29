import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:injast_admin/file_management/hagh_ozviat_member_index.dart';
import 'package:injast_admin/file_management/parvande_api.dart';
import 'package:injast_admin/local_cache/parvande_profile_image.dart';
import 'package:injast_admin/local_cache/sync_status.dart';
import 'package:shamsi_date/shamsi_date.dart';

/// کارت نمایش هر پرونده در شبکهٔ مدیریت پرونده‌ها.
class ParvandeCard extends StatelessWidget {
  const ParvandeCard({
    super.key,
    required this.codeCo,
    required this.parvande,
    required this.onDetails,
    required this.onMembership,
    required this.onMap,
    required this.onSoftDelete,
    required this.onRestore,
    required this.onHardDelete,
    required this.onNewInspection,
    required this.onInspectionHistory,
    required this.onImages,
    required this.onLicense,
    required this.onDocuments,
    required this.onPartners,
    required this.onComplaint,
    required this.onEdit,
    this.showEdit = true,
    this.isSendingToServer = false,
    this.onSendToServer,
    this.onDeleteFromCache,
    this.preferServerImages = false,
    this.membershipIndex,
    this.membershipIndexLoaded = false,
  });

  final String codeCo;
  final Map<String, dynamic> parvande;
  final bool isSendingToServer;
  final bool preferServerImages;
  final VoidCallback? onSendToServer;
  final VoidCallback? onDeleteFromCache;
  final VoidCallback onDetails;
  final VoidCallback onMembership;
  final VoidCallback onMap;
  final VoidCallback onSoftDelete;
  final VoidCallback onRestore;
  final VoidCallback onHardDelete;
  final VoidCallback onNewInspection;
  final VoidCallback onInspectionHistory;
  final VoidCallback onImages;
  final VoidCallback onLicense;
  final VoidCallback onDocuments;
  final VoidCallback onPartners;
  final VoidCallback onComplaint;
  final VoidCallback onEdit;
  final bool showEdit;
  final HaghOzviatMemberIndex? membershipIndex;
  final bool membershipIndexLoaded;

  static const _accent = Color(0xFF1E3A5F);
  static const _membershipActive = Color(0xFF6A1B9A);

  @override
  Widget build(BuildContext context) {
    final p = parvande;
    final isTrash = p.isTrash;
    final fullName = p.fullName.isEmpty ? '—' : p.fullName;
    final sync = p.cacheSyncStatus;
    final inCache = sync != null;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFDDE5EF)),
        boxShadow: const [
          BoxShadow(
              color: Color(0x10000000), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _header(fullName, isTrash),
            if (inCache) ...[
              const SizedBox(height: 4),
              _syncStatusRow(sync, isSendingToServer),
            ],
            const SizedBox(height: 5),
            _statusStrip(p),
            const SizedBox(height: 4),
            _debtStrip(p),
            const SizedBox(height: 6),
            _infoRow(FluentIcons.building_shop_24_regular, 'واحد', p.storeName),
            _infoRow(FluentIcons.tag_24_regular, 'رسته', p.raste),
            _infoRow(FluentIcons.call_24_regular, 'موبایل', p.mob),
            if (p.numParvande.isNotEmpty)
              _infoRow(
                FluentIcons.document_24_regular,
                'شماره پرونده',
                p.numParvande,
              ),
            _infoRow(
              FluentIcons.person_board_24_regular,
              'کد ملی',
              p.codeMeli.isEmpty ? '—' : p.codeMeli,
            ),
            _infoRow(
              FluentIcons.number_symbol_24_regular,
              'شناسه صنفی',
              p.shenase.isEmpty ? '—' : p.shenase,
            ),
            if (inCache) ...[
              const SizedBox(height: 6),
              _cacheSyncActions(sync, isSendingToServer),
            ],
            const SizedBox(height: 6),
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
                style: const TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 14.5),
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
                color:
                    isTrash ? const Color(0xFFC62828) : const Color(0xFF2E7D32),
              ),
              const SizedBox(width: 4),
              Text(
                isTrash ? 'سطل زباله' : 'فعال',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isTrash
                      ? const Color(0xFFC62828)
                      : const Color(0xFF2E7D32),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _syncStatusRow(ParvandeSyncStatus sync, bool sending) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: sync.backgroundColor,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: sync.color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(
            sending ? Icons.cloud_upload : Icons.cloud_outlined,
            size: 15,
            color: sync.color,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              sending
                  ? 'در حال ارسال به سرور…'
                  : 'وضعیت ارسال: ${sync.labelFaCard}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: sync.color,
              ),
            ),
          ),
          if (sending)
            SizedBox(
              width: 14,
              height: 14,
              child:
                  CircularProgressIndicator(strokeWidth: 2, color: sync.color),
            ),
        ],
      ),
    );
  }

  Widget _cacheSyncActions(ParvandeSyncStatus sync, bool sending) {
    final canSend =
        parvande.needsSyncSend && onSendToServer != null && !sending;
    return Row(
      children: [
        Expanded(
          child: FilledButton.tonalIcon(
            onPressed: canSend ? onSendToServer : null,
            icon: sending
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(FluentIcons.cloud_arrow_up_24_regular, size: 18),
            label: Text(sending ? 'در حال ارسال…' : 'ارسال به سرور'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 4),
              textStyle: const TextStyle(fontSize: 11),
              backgroundColor: const Color(0xFF1565C0).withValues(alpha: 0.12),
              foregroundColor: const Color(0xFF1565C0),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: sending ? null : onDeleteFromCache,
            icon: const Icon(FluentIcons.delete_24_regular, size: 18),
            label: const Text('حذف از حافظه'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 4),
              textStyle: const TextStyle(fontSize: 11),
              foregroundColor: const Color(0xFFC62828),
              side: const BorderSide(color: Color(0xFFC62828)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _profileImage() {
    return ParvandeProfileImage(
      codeCo: codeCo,
      parvande: parvande,
      width: 46,
      height: 46,
      fallbackIcon: FluentIcons.person_24_regular,
      preferServer: preferServerImages,
    );
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
              style: TextStyle(
                  fontSize: 11.8, fontWeight: FontWeight.w700, color: s.fg),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'اعتبار: $expText',
            style: TextStyle(
                fontSize: 11.2, color: s.fg, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _debtStrip(Map<String, dynamic> p) {
    final idx = membershipIndex;
    final useHagh = membershipIndexLoaded && idx != null && idx.hasRecords;

    late final bool hasDebt;
    late final String label;
    late final String amountText;

    if (useHagh) {
      hasDebt = idx.hasPendingDebt;
      label = hasDebt
          ? 'وضعیت بدهی: دارای بدهی (حق عضویت)'
          : 'وضعیت بدهی: تسویه حق عضویت';
      amountText = '${_formatMoney(idx.pendingRial.toDouble())} ریال';
    } else if (membershipIndexLoaded &&
        (idx == null || !idx.hasRecords)) {
      hasDebt = false;
      label = 'وضعیت بدهی: بدون سابقه حق عضویت';
      amountText = '۰';
    } else {
      final amount = _moneyValue(p.s('money'));
      hasDebt = amount > 0;
      label =
          hasDebt ? 'وضعیت بدهی: دارای بدهی' : 'وضعیت بدهی: تسویه / بدون بدهی';
      amountText = _formatMoney(amount);
    }

    final fg = hasDebt ? const Color(0xFFC62828) : const Color(0xFF2E7D32);
    final bg = hasDebt ? const Color(0xFFFFEBEE) : const Color(0xFFE8F5E9);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: fg.withValues(alpha: 0.24)),
      ),
      child: Row(
        children: [
          Icon(
            hasDebt ? FluentIcons.money_hand_24_regular : Icons.check_circle,
            size: 15,
            color: fg,
          ),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.4,
                fontWeight: FontWeight.w700,
                color: fg,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            amountText,
            style: TextStyle(
              fontSize: 11.2,
              fontWeight: FontWeight.w800,
              color: fg,
            ),
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
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.black45),
          const SizedBox(width: 6),
          Text('$label: ',
              style: const TextStyle(fontSize: 12, color: Colors.black54)),
          Expanded(
            child: Text(
              value.isEmpty ? '—' : value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  bool get _membershipHasRecords =>
      membershipIndexLoaded && (membershipIndex?.hasRecords ?? false);

  Color get _membershipColor {
    if (!membershipIndexLoaded) return _membershipActive;
    return _membershipHasRecords ? _membershipActive : Colors.grey;
  }

  Widget _membershipRowFullWidth() {
    final color = _membershipColor;
    final idx = membershipIndex;
    final enabled = !membershipIndexLoaded || _membershipHasRecords;

    return Material(
      color: color.withValues(alpha: enabled ? 0.1 : 0.06),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: enabled ? onMembership : null,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: double.infinity,
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: color.withValues(alpha: enabled ? 0.35 : 0.2),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(FluentIcons.wallet_24_regular, size: 18, color: color),
              const SizedBox(width: 8),
              Text(
                'حق عضویت',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
              if (enabled && idx != null && idx.hasPendingDebt) ...[
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    'بدهی: ${_formatMoney(idx.pendingRial.toDouble())} ریال',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFFC62828),
                    ),
                  ),
                ),
              ] else if (membershipIndexLoaded && !_membershipHasRecords) ...[
                const SizedBox(width: 8),
                Text(
                  '— بدون رکورد',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionsTwoRows(bool isTrash) {
    if (isTrash) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _membershipRowFullWidth(),
          const SizedBox(height: 6),
          _actionRow(5, [
            _compactBtn(
                'جزئیات', FluentIcons.info_24_regular, onDetails, _accent),
            _compactBtn('نقشه', FluentIcons.location_24_regular, onMap,
                const Color(0xFFEF6C00)),
            _compactBtn('بازیابی', FluentIcons.arrow_undo_24_regular, onRestore,
                const Color(0xFF2E7D32)),
            _compactBtn('حذف دائم', FluentIcons.delete_dismiss_24_regular,
                onHardDelete, const Color(0xFFB71C1C)),
            null,
          ]),
          const SizedBox(height: 3),
          _secondaryRow(),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _membershipRowFullWidth(),
        const SizedBox(height: 6),
        _actionRow(6, [
          _compactBtn(
              'جزئیات', FluentIcons.info_24_regular, onDetails, _accent),
          _compactBtn('نقشه', FluentIcons.location_24_regular, onMap,
              const Color(0xFFEF6C00)),
          _compactBtn('حذف نرم', FluentIcons.delete_24_regular, onSoftDelete,
              const Color(0xFFC62828)),
          _compactBtn('بازرسی', FluentIcons.clipboard_pulse_24_regular,
              onNewInspection, const Color(0xFF2E7D32)),
          _compactBtn('سوابق', FluentIcons.clipboard_search_24_regular,
              onInspectionHistory, const Color(0xFF3949AB)),
          null,
        ]),
        const SizedBox(height: 3),
        _secondaryRow(),
      ],
    );
  }

  Widget _secondaryRow() {
    final items = <Widget?>[
      _compactBtn('تصاویر', FluentIcons.image_multiple_24_regular, onImages,
          const Color(0xFF7B1FA2)),
      _compactBtn('پروانه', FluentIcons.document_24_regular, onLicense,
          const Color(0xFF00695C)),
      _compactBtn('مدارک', FluentIcons.document_folder_24_regular, onDocuments,
          const Color(0xFF6D4C41)),
      _compactBtn('شریک', FluentIcons.people_team_24_regular, onPartners,
          const Color(0xFF455A64)),
      _compactBtn('شکایت', FluentIcons.warning_24_regular, onComplaint,
          const Color(0xFFD32F2F)),
      if (showEdit)
        _compactBtn('ویرایش', FluentIcons.edit_24_regular, onEdit,
            const Color(0xFFEF6C00)),
    ];
    return _actionRow(items.length, items);
  }

  Widget _actionRow(int columns, List<Widget?> items) {
    return Row(
      children: List.generate(columns, (i) {
        final child = i < items.length ? items[i] : null;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: child ?? const SizedBox(height: 34),
          ),
        );
      }),
    );
  }

  Widget _compactBtn(
      String text, IconData icon, VoidCallback onTap, Color color) {
    return Material(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 1, vertical: 1),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.22)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 13, color: color),
              Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 8.5,
                  fontWeight: FontWeight.w700,
                  color: color,
                  height: 1.05,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  double _moneyValue(String raw) {
    final normalized = raw.replaceAll(',', '').trim();
    if (normalized.isEmpty ||
        normalized == '0' ||
        normalized.toLowerCase() == 'null') {
      return 0;
    }
    return double.tryParse(normalized) ?? 0;
  }

  String _formatMoney(double amount) {
    final value = amount.round();
    final digits = value.toString();
    final pattern = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    final formatted = digits.replaceAllMapped(pattern, (m) => '${m[1]},');
    return value <= 0 ? '۰' : formatted;
  }
}

class _StatusStyle {
  const _StatusStyle({required this.fg, required this.bg, required this.icon});
  final Color fg;
  final Color bg;
  final IconData icon;
}
