import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:injast_admin/file_management/image_pick_compress.dart';
import 'package:injast_admin/file_management/media_file_urls.dart';
import 'package:injast_admin/file_management/parvande_api.dart';
import 'package:injast_admin/file_management/store_image_logger.dart';
import 'package:injast_admin/file_management/store_image_service.dart';
import 'package:injast_admin/local_cache/parvande_local_db.dart';

enum _PickSource { cancel, gallery, camera }

enum _SlotStatus { empty, selected, uploaded }

/// انتخاب و آپلود ۴ تصویر واحد صنفی
class ParvandeStoreImagesSheet extends StatefulWidget {
  const ParvandeStoreImagesSheet({
    super.key,
    required this.codeCo,
    required this.parvande,
    required this.offline,
    required this.onPersistDirty,
  });

  final String codeCo;
  final Map<String, dynamic> parvande;
  final bool offline;
  final Future<void> Function() onPersistDirty;

  static Future<void> show(
    BuildContext context, {
    required String codeCo,
    required Map<String, dynamic> parvande,
    required bool offline,
    required Future<void> Function() onPersistDirty,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ParvandeStoreImagesSheet(
        codeCo: codeCo,
        parvande: parvande,
        offline: offline,
        onPersistDirty: onPersistDirty,
      ),
    );
  }

  @override
  State<ParvandeStoreImagesSheet> createState() => _ParvandeStoreImagesSheetState();
}

class _ParvandeStoreImagesSheetState extends State<ParvandeStoreImagesSheet> {
  static const _accent = Color(0xFF1E3A5F);
  static const _accentLight = Color(0xFF2D5A8E);
  static const _surface = Color(0xFFF4F7FB);

  final _svc = StoreImageService.instance;

  final _pickedPaths = List<String?>.filled(StoreImageService.slotCount, null);
  final _localPaths = List<String?>.filled(StoreImageService.slotCount, null);
  final _uploaded = List<bool>.filled(StoreImageService.slotCount, false);
  final _uploading = List<bool>.filled(StoreImageService.slotCount, false);
  final _picking = List<bool>.filled(StoreImageService.slotCount, false);

  String get _id => widget.parvande.idParvandeh;

  int get _uploadedCount => _uploaded.where((u) => u).length;

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  Future<void> _loadExisting() async {
    final media = await ParvandeLocalDb.instance.listMedia(widget.codeCo, _id);
    for (var i = 1; i <= StoreImageService.slotCount; i++) {
      final key = _svc.fieldKeyForSlot(i);
      final path = await _svc.localPath(widget.codeCo, _id, i);
      final row = media.where((m) => m.fieldKey == key).toList();
      var uploaded = row.isNotEmpty && row.first.downloadStatus == 'uploaded';

      if (!uploaded && !widget.offline) {
        uploaded = await MediaFileUrls.storeImageExists(
          codeCo: widget.codeCo,
          idParvandeh: _id,
          index: i,
        );
      }

      if (mounted) {
        setState(() {
          _localPaths[i - 1] = path;
          _uploaded[i - 1] = uploaded;
        });
      }
    }
  }

  String? _effectivePath(int index) {
    final i = index - 1;
    return _pickedPaths[i] ?? _localPaths[i];
  }

  bool _hasSelection(int index) => _effectivePath(index) != null;

  _SlotStatus _status(int index) {
    final i = index - 1;
    if (_uploaded[i]) return _SlotStatus.uploaded;
    if (_hasSelection(index)) return _SlotStatus.selected;
    return _SlotStatus.empty;
  }

  Future<_PickSource> _askSource() async {
    final choice = await showDialog<_PickSource>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('منبع تصویر'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(FluentIcons.image_24_regular),
              title: const Text('گالری'),
              onTap: () => Navigator.pop(ctx, _PickSource.gallery),
            ),
            ListTile(
              leading: const Icon(FluentIcons.camera_24_regular),
              title: const Text('دوربین'),
              onTap: () => Navigator.pop(ctx, _PickSource.camera),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, _PickSource.cancel), child: const Text('انصراف')),
        ],
      ),
    );
    return choice ?? _PickSource.cancel;
  }

  Future<void> _pick(int index) async {
    if (ImagePickCompress.isDesktop) {
      await _pickAndSave(index, useCamera: false);
      return;
    }

    final source = await _askSource();
    if (source == _PickSource.cancel) return;

    await _pickAndSave(index, useCamera: source == _PickSource.camera);
  }

  Future<void> _pickAndSave(int index, {required bool useCamera}) async {
    setState(() => _picking[index - 1] = true);
    try {
      await Future<void>.delayed(const Duration(milliseconds: 80));
      logStoreImage('pick slot=$index camera=$useCamera');
      final result = await ImagePickCompress.pick(useCamera: useCamera).timeout(
        const Duration(seconds: 90),
        onTimeout: () => throw TimeoutException('انتخاب یا فشرده‌سازی تصویر بیش از حد طول کشید.'),
      );
      if (result == null) return;

      await _svc.saveLocalCopy(
        codeCo: widget.codeCo,
        idParvandeh: _id,
        index: index,
        sourcePath: result.path,
      );
      if (widget.offline) await widget.onPersistDirty();
      if (mounted) {
        setState(() {
          _pickedPaths[index - 1] = result.path;
          _localPaths[index - 1] = result.path;
          _uploaded[index - 1] = false;
        });
        _showToast(
          'تصویر $index آماده شد (${ImagePickCompress.formatSize(result.compressedBytes)})',
          success: true,
        );
      }
    } on TimeoutException catch (e) {
      if (mounted) _showToast(e.message ?? '$e');
    } catch (e, st) {
      logStoreImage('pick error: $e\n$st');
      if (mounted) _showToast('خطا: $e');
    } finally {
      if (mounted) setState(() => _picking[index - 1] = false);
    }
  }

  Future<void> _upload(int index) async {
    if (widget.offline) {
      _showToast('در حالت آفلاین آپلود به سرور ممکن نیست.');
      return;
    }
    final path = _effectivePath(index);
    if (path == null || !File(path).existsSync()) {
      _showToast('ابتدا تصویر $index را انتخاب کنید.');
      return;
    }

    setState(() => _uploading[index - 1] = true);
    logStoreImage('upload slot=$index path=$path');
    try {
      await _svc.uploadToServer(
        codeCo: widget.codeCo,
        idParvandeh: _id,
        index: index,
        localPath: path,
      ).timeout(
        const Duration(seconds: 90),
        onTimeout: () => throw TimeoutException('آپلود بیش از حد طول کشید.'),
      );
      if (mounted) {
        setState(() {
          _uploaded[index - 1] = true;
          _localPaths[index - 1] = path;
        });
        _showToast('تصویر $index با موفقیت آپلود شد.', success: true);
      }
    } on TimeoutException catch (e) {
      if (mounted) _showToast('$e');
    } catch (e, st) {
      logStoreImage('upload error: $e\n$st');
      if (mounted) _showToast('خطا: $e');
    } finally {
      if (mounted) setState(() => _uploading[index - 1] = false);
    }
  }

  void _showToast(String message, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        backgroundColor: success ? const Color(0xFF2E7D32) : _accent,
        content: Text(message),
      ),
    );
  }

  void _preview(int index) {
    final local = _effectivePath(index);
    final hasLocal = local != null && File(local).existsSync();
    final serverUrl = MediaFileUrls.storeImageUrl(
      codeCo: widget.codeCo,
      idParvandeh: _id,
      index: index,
    );
    showDialog<void>(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(24),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 520, maxHeight: 520),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(color: Color(0x40000000), blurRadius: 24, offset: Offset(0, 8)),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
                    child: Row(
                      children: [
                        Text(
                          'پیش‌نمایش تصویر $index',
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                  Flexible(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: hasLocal
                            ? Image.file(File(local), fit: BoxFit.contain)
                            : (_uploaded[index - 1] || !widget.offline)
                                ? Image.network(
                                    serverUrl,
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, __, ___) => _emptyPreview(),
                                  )
                                : _emptyPreview(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _emptyPreview() {
    return Container(
      height: 280,
      color: _surface,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(FluentIcons.image_off_24_regular, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 8),
          Text('تصویر موجود نیست', style: TextStyle(color: Colors.grey.shade600)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.sizeOf(context).height;
    final name = widget.parvande.fullName;

    return SafeArea(
      child: Container(
        constraints: BoxConstraints(maxHeight: h * 0.88),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFD0D8E4),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            _header(name),
            _summaryBar(),
            if (widget.offline) _offlineBanner(),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  childAspectRatio: 0.82,
                ),
                itemCount: StoreImageService.slotCount,
                itemBuilder: (_, i) => _SlotCard(
                  index: i + 1,
                  status: _status(i + 1),
                  path: _effectivePath(i + 1),
                  serverUrl: MediaFileUrls.storeImageUrl(
                    codeCo: widget.codeCo,
                    idParvandeh: _id,
                    index: i + 1,
                  ),
                  picking: _picking[i],
                  uploading: _uploading[i],
                  offline: widget.offline,
                  onPick: () => _pick(i + 1),
                  onUpload: () => _upload(i + 1),
                  onPreview: () => _preview(i + 1),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(String name) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_accent, _accentLight],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Color(0x301E3A5F), blurRadius: 12, offset: Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(FluentIcons.image_multiple_24_filled, color: Colors.white, size: 26),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'تصاویر واحد صنفی',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  name.isEmpty ? widget.parvande.idParvandeh : name,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(Icons.close, color: Colors.white.withValues(alpha: 0.9)),
          ),
        ],
      ),
    );
  }

  Widget _summaryBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      child: Row(
        children: [
          _StatChip(
            icon: FluentIcons.cloud_checkmark_24_regular,
            label: 'آپلود شده',
            value: '$_uploadedCount/${StoreImageService.slotCount}',
            color: const Color(0xFF2E7D32),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _StatChip(
              icon: FluentIcons.resize_image_24_regular,
              label: 'حداکثر حجم',
              value: '۵۰۰ KB',
              color: _accent,
            ),
          ),
        ],
      ),
    );
  }

  Widget _offlineBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFFCC80)),
      ),
      child: Row(
        children: [
          Icon(FluentIcons.wifi_off_24_regular, size: 18, color: Colors.orange.shade800),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'حالت آفلاین — تصاویر محلی ذخیره می‌شوند؛ آپلود پس از اتصال.',
              style: TextStyle(fontSize: 11.5, color: Colors.orange.shade900, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 10, color: color.withValues(alpha: 0.8))),
              Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color)),
            ],
          ),
        ],
      ),
    );
  }
}

class _SlotCard extends StatelessWidget {
  const _SlotCard({
    required this.index,
    required this.status,
    required this.path,
    required this.serverUrl,
    required this.picking,
    required this.uploading,
    required this.offline,
    required this.onPick,
    required this.onUpload,
    required this.onPreview,
  });

  static const _accent = Color(0xFF1E3A5F);
  static const _surface = Color(0xFFF4F7FB);
  static const _border = Color(0xFFDDE5EF);

  final int index;
  final _SlotStatus status;
  final String? path;
  final String serverUrl;
  final bool picking;
  final bool uploading;
  final bool offline;
  final VoidCallback onPick;
  final VoidCallback onUpload;
  final VoidCallback onPreview;

  bool get _hasImage => path != null && File(path!).existsSync();
  bool get _canPreview => _hasImage || status == _SlotStatus.uploaded;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor, width: 1.5),
        boxShadow: const [
          BoxShadow(color: Color(0x0A000000), blurRadius: 10, offset: Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                  child: _buildPreview(),
                ),
                Positioned(top: 8, right: 8, child: _statusBadge()),
                if (picking || uploading)
                  Container(
                    color: Colors.black26,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: _accent),
                        ),
                      ),
                    ),
                  ),
                if (_canPreview && !picking && !uploading)
                  Positioned.fill(
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: onPreview,
                        child: Align(
                          alignment: Alignment.center,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.black45,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.zoom_in, color: Colors.white, size: 16),
                                SizedBox(width: 4),
                                Text('مشاهده', style: TextStyle(color: Colors.white, fontSize: 11)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'تصویر $index',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _ActionButton(
                        label: _hasImage ? 'تغییر' : 'انتخاب',
                        icon: _hasImage ? FluentIcons.arrow_sync_24_regular : FluentIcons.add_24_regular,
                        color: const Color(0xFFE65100),
                        onTap: picking ? null : onPick,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _ActionButton(
                        label: status == _SlotStatus.uploaded ? 'آپلود شد' : 'آپلود',
                        icon: status == _SlotStatus.uploaded
                            ? FluentIcons.checkmark_circle_24_filled
                            : FluentIcons.cloud_arrow_up_24_regular,
                        color: status == _SlotStatus.uploaded
                            ? const Color(0xFF2E7D32)
                            : _accent,
                        filled: status == _SlotStatus.uploaded,
                        onTap: (uploading || offline || status == _SlotStatus.uploaded || !_hasImage)
                            ? null
                            : onUpload,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color get _borderColor {
    switch (status) {
      case _SlotStatus.uploaded:
        return const Color(0xFF81C784);
      case _SlotStatus.selected:
        return const Color(0xFFFFB74D);
      case _SlotStatus.empty:
        return _border;
    }
  }

  Widget _buildPreview() {
    if (_hasImage) {
      return Image.file(File(path!), fit: BoxFit.cover);
    }
    if (status == _SlotStatus.uploaded) {
      return Image.network(
        serverUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _emptySlot(),
      );
    }
    return _emptySlot();
  }

  Widget _emptySlot() {
    return Container(
      color: _surface,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            FluentIcons.image_add_24_regular,
            size: 36,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 6),
          Text(
            'خالی',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _statusBadge() {
    final (label, color, icon) = switch (status) {
      _SlotStatus.uploaded => ('سرور', const Color(0xFF2E7D32), FluentIcons.cloud_checkmark_16_filled),
      _SlotStatus.selected => ('آماده', const Color(0xFFE65100), FluentIcons.clock_16_regular),
      _SlotStatus.empty => ('خالی', const Color(0xFF78909C), FluentIcons.circle_16_regular),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Color(0x30000000), blurRadius: 4, offset: Offset(0, 1))],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    this.filled = false,
    this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final bool filled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Material(
      color: filled ? color : color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: filled ? Colors.white : (enabled ? color : Colors.grey)),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: filled ? Colors.white : (enabled ? color : Colors.grey),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
