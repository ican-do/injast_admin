import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:injast_admin/features/shekayat/compat/screen_util_shim.dart';
import 'package:image_picker/image_picker.dart';
import 'package:injast_admin/features/shekayat/compat/class_controler.dart';
import 'package:injast_admin/features/shekayat/compat/upload_image.dart';
import 'package:injast_admin/features/shekayat/shekayat_api.dart';
import 'package:injast_admin/features/shekayat/shekayat_constants.dart';
import 'package:injast_admin/features/shekayat/compat/shekayat_basic.dart';
import 'package:injast_admin/features/shekayat/compat/server_config_shim.dart';
import 'package:injast_admin/features/shekayat/compat/motion_toast_shim.dart';
import 'package:injast_admin/features/shekayat/compat/persian_fonts_shim.dart';
import 'package:injast_admin/features/shekayat/compat/shekayat_layout.dart';
import 'package:url_launcher/url_launcher.dart';

/// گالری یکپارچه مدارک — سه تب با ظاهر یکسان، تفاوت فقط در سطح دسترسی
class ShekayatDocsGallery extends StatefulWidget {
  final String codeShekayat;
  final String sourceType;
  final bool readOnly;
  final bool embedded;
  final bool pendingMode;
  final List<Map<String, dynamic>>? initialPending;
  final void Function(List<Map<String, dynamic>> docs)? onPendingSave;

  const ShekayatDocsGallery({
    Key? key,
    required this.codeShekayat,
    this.sourceType = 'complainant',
    this.readOnly = false,
    this.embedded = false,
    this.pendingMode = false,
    this.initialPending,
    this.onPendingSave,
  }) : super(key: key);

  @override
  State<ShekayatDocsGallery> createState() => _ShekayatDocsGalleryState();
}

class _ShekayatDocsGalleryState extends State<ShekayatDocsGallery> {
  List<Map<String, dynamic>> _docs = [];
  List<Map<String, dynamic>> _savedSnapshot = [];
  bool _loading = true;
  bool _saving = false;
  bool _dirty = false;
  final _picker = ImagePicker();

  bool get _editable => !widget.readOnly;

  int get _maxDocs {
    if (widget.sourceType == 'complainant') return ShekayatConstants.maxComplainantDocs;
    if (widget.sourceType == 'expert') return ShekayatConstants.maxExpertDocs;
    return ShekayatConstants.maxOfficerDocs;
  }

  @override
  void initState() {
    super.initState();
    if (widget.pendingMode) {
      _docs = List.from(widget.initialPending ?? []);
      _savedSnapshot = _snapshot(_docs);
      _loading = false;
    } else {
      _load();
    }
  }

  List<Map<String, dynamic>> _snapshot(List<Map<String, dynamic>> list) {
    return list.map((d) => Map<String, dynamic>.from(d)).toList();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await ShekayatApi.getAttachments(widget.codeShekayat, source: widget.sourceType);
      _docs = data
          .map((e) => Map<String, dynamic>.from(e as Map))
          .where((d) => (d['file_path'] ?? '').toString().isNotEmpty)
          .toList();
      _savedSnapshot = _snapshot(_docs);
      _dirty = false;
    } catch (_) {
      _docs = [];
      _savedSnapshot = [];
    }
    if (mounted) setState(() => _loading = false);
  }

  int _gridColumns(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    if (w >= 1400) return 5;
    if (w >= 1100) return 4;
    if (w >= 800) return 3;
    return 2;
  }

  Future<void> _openDocSheet({Map<String, dynamic>? doc, int? index}) async {
    if (!_editable) return;
    final wide = ShekayatLayout.isWide(context, min: 900);
    final form = _DocFormSheet(
      initial: doc,
      codeShekayat: widget.codeShekayat,
      sourceType: widget.sourceType,
      picker: _picker,
    );

    final Map<String, dynamic>? result;
    if (wide) {
      result = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (ctx) => Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480, maxHeight: 640),
            child: form,
          ),
        ),
      );
    } else {
      result = await showModalBottomSheet<Map<String, dynamic>>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16.r))),
        builder: (ctx) => form,
      );
    }
    if (result == null) return;
    setState(() {
      if (index != null && index < _docs.length) {
        _docs[index] = result!;
      } else {
        result!['sort_order'] = _docs.length + 1;
        _docs.add(result);
      }
      _dirty = true;
    });
  }

  bool _canAdd() => _editable && _docs.length < _maxDocs;

  Future<void> _deleteDoc(int index) async {
    final doc = _docs[index];
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('حذف مدرک', style: PersianFonts.Shabnam.copyWith(fontWeight: FontWeight.bold)),
        content: Text('آیا از حذف این مدرک اطمینان دارید؟', style: PersianFonts.Shabnam),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('انصراف', style: PersianFonts.Shabnam)),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('حذف', style: PersianFonts.Shabnam.copyWith(color: ShekayatTheme.accentRed)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    if (!widget.pendingMode && doc['id'] != null) {
      try {
        await ShekayatApi.deleteAttachment(doc['id']);
      } catch (e) {
        if (mounted) {
          MotionToast.error(title: const Text('خطا'), description: Text('$e')).show(context);
        }
        return;
      }
    }

    setState(() {
      _docs.removeAt(index);
      if (widget.pendingMode) _dirty = true;
    });
    if (!widget.pendingMode) _load();
  }

  Future<void> _saveChanges() async {
    if (!_dirty || _saving) return;
    setState(() => _saving = true);
    try {
      if (widget.pendingMode) {
        final prepared = <Map<String, dynamic>>[];
        for (int i = 0; i < _docs.length; i++) {
          final doc = Map<String, dynamic>.from(_docs[i]);
          var path = doc['file_path']?.toString() ?? '';
          if (path.isEmpty) continue;
          if (_isLocalPath(path) || doc['_localPending'] == true) {
            final uploaded = await _uploadLocal(path, i);
            if (uploaded == null || uploaded.isEmpty) {
              throw Exception('خطا در آپلود فایل');
            }
            path = uploaded;
            doc['file_path'] = path;
            doc.remove('_localPending');
          }
          doc['sort_order'] = prepared.length + 1;
          prepared.add(doc);
        }
        widget.onPendingSave?.call(prepared);
        if (mounted) Navigator.pop(context);
        return;
      }

      for (int i = 0; i < _docs.length; i++) {
        final doc = _docs[i];
        var path = doc['file_path']?.toString() ?? '';
        if (path.isEmpty) continue;

        if (_isLocalPath(path) || doc['_localPending'] == true) {
          final uploaded = await _uploadLocal(path, i);
          if (uploaded == null || uploaded.isEmpty) {
            throw Exception('خطا در آپلود فایل');
          }
          path = uploaded;
          doc['file_path'] = path;
          doc.remove('_localPending');
        }

        final payload = {
          'code_shekayat': widget.codeShekayat,
          'source_type': widget.sourceType,
          'title': doc['title'] ?? '',
          'file_path': path,
          'file_date': doc['file_date'] ?? '',
          'sort_order': i + 1,
          if (doc['id'] != null) 'id': doc['id'],
        };
        final res = await ShekayatApi.saveAttachmentResult(payload);
        if (res['success'] != true) throw Exception('خطا در ذخیره مدرک');
        if (doc['id'] == null && res['data']?['id'] != null) {
          doc['id'] = res['data']['id'];
        }
      }

      _savedSnapshot = _snapshot(_docs);
      if (mounted) {
        setState(() => _dirty = false);
        MotionToast.success(title: const Text('ثبت شد'), description: const Text('تغییرات ذخیره شد')).show(context);
      }
    } catch (e) {
      if (mounted) {
        MotionToast.error(title: const Text('خطا'), description: Text('$e')).show(context);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<String?> _uploadLocal(String path, int index) async {
    var localPath = path;
    if (localPath.startsWith('file://')) {
      localPath = Uri.parse(localPath).toFilePath();
    }
    final ext = localPath.contains('.') ? localPath.split('.').last.toLowerCase() : 'jpg';
    final safeExt = ext.length <= 5 ? ext : 'jpg';
    final name =
        '${widget.codeShekayat}_${widget.sourceType}_${DateTime.now().millisecondsSinceEpoch}_$index';
    if (_isImagePath(localPath)) {
      return uploadImageToServer(XFile(localPath), 'shekayat', '$name.$safeExt');
    }
    return uploadFileToServer(localPath, 'shekayat', '$name.$safeExt');
  }

  void _viewDoc(Map<String, dynamic> doc) {
    final path = doc['file_path']?.toString() ?? '';
    if (path.isEmpty) return;
    final title = doc['title']?.toString() ?? 'مدرک';

    if (_isLocalPath(path)) {
      final local = path.startsWith('file://') ? Uri.parse(path).toFilePath() : path;
      if (_isImagePath(local)) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => Directionality(
              textDirection: TextDirection.rtl,
              child: Scaffold(
                appBar: AppBar(
                  title: Text(title, style: PersianFonts.Shabnam.copyWith(fontSize: font_size_14)),
                  backgroundColor: ShekayatTheme.primary,
                  foregroundColor: Colors.white,
                ),
                body: InteractiveViewer(child: Center(child: Image.file(File(local), fit: BoxFit.contain))),
              ),
            ),
          ),
        );
      } else {
        MotionToast.info(title: const Text('پیش‌نمایش'), description: Text(_fileName(local))).show(context);
      }
      return;
    }

    final url = getStaticFileUrl(path);
    if (_isImagePath(path)) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              appBar: AppBar(
                title: Text(title, style: PersianFonts.Shabnam.copyWith(fontSize: font_size_14)),
                backgroundColor: ShekayatTheme.primary,
                foregroundColor: Colors.white,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.open_in_browser),
                    onPressed: () async {
                      final uri = Uri.parse(url);
                      if (await canLaunchUrl(uri)) launchUrl(uri, mode: LaunchMode.externalApplication);
                    },
                  ),
                ],
              ),
              body: InteractiveViewer(
                child: Center(
                  child: Image.network(
                    url,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Text('خطا در نمایش تصویر', style: PersianFonts.Shabnam),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      return;
    }

    launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  String _docStatus(Map<String, dynamic> doc) {
    if (doc['_isNew'] == true) return 'جدید';
    if (_dirty && _hasLocalChanges(doc)) return 'در انتظار بررسی';
    return 'تأیید شده';
  }

  bool _hasLocalChanges(Map<String, dynamic> doc) {
    if (doc['_localPending'] == true) return true;
    if (_isLocalPath(doc['file_path']?.toString() ?? '')) return true;
    final id = doc['id'];
    if (id == null) return true;
    final original = _savedSnapshot.cast<Map<String, dynamic>?>().firstWhere(
          (d) => d?['id'] == id,
          orElse: () => null,
        );
    if (original == null) return true;
    return (original['title'] ?? '') != (doc['title'] ?? '') || (original['file_date'] ?? '') != (doc['file_date'] ?? '');
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Center(child: CircularProgressIndicator(color: ShekayatTheme.primary));
    }

    final columns = _gridColumns(context);
    final itemCount = _docs.length + (_canAdd() ? 1 : 0);
    final countText = _docs.isEmpty ? 'مدرکی ثبت نشده است' : '${_docs.length} مدرک ثبت شده';
    final gridPadding = EdgeInsets.fromLTRB(4, 4, 4, _dirty && _editable ? 72 : 8);

    Widget gridBody() {
      if (_docs.isEmpty && !_canAdd()) {
        return ListView(
          physics: widget.embedded ? const NeverScrollableScrollPhysics() : null,
          shrinkWrap: widget.embedded,
          children: [
            const SizedBox(height: 24),
            Center(
              child: Column(
                children: [
                  Icon(Icons.description_outlined, size: 40, color: Colors.grey.shade400),
                  const SizedBox(height: 8),
                  Text('مدرکی ثبت نشده است', style: PersianFonts.Shabnam.copyWith(color: Colors.grey, fontSize: font_size_10)),
                ],
              ),
            ),
          ],
        );
      }
      return GridView.builder(
        physics: widget.embedded ? const NeverScrollableScrollPhysics() : null,
        shrinkWrap: widget.embedded,
        padding: gridPadding,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 0.95,
        ),
        itemCount: itemCount,
        itemBuilder: (_, i) {
          if (_canAdd() && i == _docs.length) {
            return _AddDocCard(onTap: () => _openDocSheet(), compact: true);
          }
          return _DocCard(
            doc: _docs[i],
            readOnly: widget.readOnly,
            status: _docStatus(_docs[i]),
            compact: true,
            onView: () => _viewDoc(_docs[i]),
            onEdit: () => _openDocSheet(doc: _docs[i], index: i),
            onDelete: () => _deleteDoc(i),
          );
        },
      );
    }

    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
              child: Text(
                countText,
                style: PersianFonts.Shabnam.copyWith(
                  fontSize: font_size_12,
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (widget.embedded)
              Expanded(child: SingleChildScrollView(child: gridBody()))
            else
              Expanded(
                child: RefreshIndicator(
                  onRefresh: widget.pendingMode ? () async {} : _load,
                  child: gridBody(),
                ),
              ),
          ],
        ),
        if (_dirty && _editable)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Material(
              elevation: 6,
              color: Colors.white,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: ElevatedButton(
                    onPressed: _saving ? null : _saveChanges,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ShekayatTheme.primary,
                      minimumSize: const Size(double.infinity, 40),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text('ذخیره تغییرات', style: PersianFonts.Shabnam.copyWith(color: Colors.white, fontSize: font_size_12)),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _DocCard extends StatelessWidget {
  final Map<String, dynamic> doc;
  final bool readOnly;
  final String status;
  final bool compact;
  final VoidCallback onView;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _DocCard({
    required this.doc,
    required this.readOnly,
    required this.status,
    this.compact = false,
    required this.onView,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final path = doc['file_path']?.toString() ?? '';
    final title = (doc['title']?.toString().isNotEmpty == true) ? doc['title'].toString() : 'بدون عنوان';
    final date = doc['file_date']?.toString() ?? '';
    final fileType = _fileTypeLabel(path);
    final titleSize = compact ? font_size_10 : font_size_12;
    final metaSize = compact ? font_size_8 : font_size_10;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: compact ? 5 : 7,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _DocPreview(path: path, compact: compact),
                Positioned(
                  top: 6.h,
                  right: 6.w,
                  child: _StatusBadge(status: status),
                ),
              ],
            ),
          ),
          Expanded(
            flex: compact ? 4 : 3,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: compact ? 4.h : 6.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.topRight,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(maxWidth: constraints.maxWidth),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  title,
                                  style: PersianFonts.Shabnam.copyWith(fontSize: titleSize, fontWeight: FontWeight.bold),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (!compact && date.isNotEmpty)
                                  Text(
                                    date,
                                    style: PersianFonts.Shabnam.copyWith(fontSize: metaSize, color: Colors.grey.shade600),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                if (!compact)
                                  Text(
                                    fileType,
                                    style: PersianFonts.Shabnam.copyWith(fontSize: metaSize, color: ShekayatTheme.primary),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  _ActionBar(readOnly: readOnly, onView: onView, onEdit: onEdit, onDelete: onDelete),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddDocCard extends StatelessWidget {
  final VoidCallback onTap;
  final bool compact;

  const _AddDocCard({required this.onTap, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: ShekayatTheme.primary.withOpacity(0.35), width: 1.5),
      ),
      child: InkWell(
        onTap: onTap,
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(8.w),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add_circle_outline, size: compact ? 28.sp : 40.sp, color: ShekayatTheme.primary),
                  SizedBox(height: compact ? 4.h : 8.h),
                  Text(
                    'افزودن مدرک',
                    style: PersianFonts.Shabnam.copyWith(
                      fontSize: compact ? font_size_10 : font_size_12,
                      color: ShekayatTheme.primary,
                      fontWeight: FontWeight.w600,
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
}

class _DocPreview extends StatelessWidget {
  final String path;
  final bool compact;

  const _DocPreview({required this.path, this.compact = false});

  @override
  Widget build(BuildContext context) {
    if (path.isEmpty) {
      return Container(
        color: Colors.grey.shade100,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.description_outlined, size: compact ? 24.sp : 36.sp, color: Colors.grey.shade400),
            if (!compact) ...[
              SizedBox(height: 4.h),
              Text('مدرکی انتخاب نشده است', style: PersianFonts.Shabnam.copyWith(fontSize: font_size_10, color: Colors.grey.shade500)),
            ],
          ],
        ),
      );
    }

    if (_isPdfPath(path)) {
      return Container(
        color: Colors.grey.shade100,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.picture_as_pdf, size: 40.sp, color: ShekayatTheme.accentRed),
            SizedBox(height: 6.h),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 8.w),
              child: Text(
                _fileName(path),
                style: PersianFonts.Shabnam.copyWith(fontSize: font_size_10, color: Colors.grey.shade700),
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }

    if (_isLocalPath(path)) {
      final local = path.startsWith('file://') ? Uri.parse(path).toFilePath() : path;
      return Image.file(
        File(local),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _brokenPreview(),
      );
    }

    return Image.network(
      getStaticFileUrl(path),
      fit: BoxFit.cover,
      loadingBuilder: (_, child, progress) {
        if (progress == null) return child;
        return Center(child: CircularProgressIndicator(color: ShekayatTheme.primary, strokeWidth: 2));
      },
      errorBuilder: (_, __, ___) => _brokenPreview(),
    );
  }

  Widget _brokenPreview() {
    return Container(
      color: Colors.grey.shade200,
      child: Icon(Icons.broken_image, size: 36.sp, color: Colors.grey),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    switch (status) {
      case 'تأیید شده':
        bg = ShekayatTheme.accentGreen.withOpacity(0.15);
        fg = ShekayatTheme.accentGreen;
        break;
      case 'در انتظار بررسی':
        bg = ShekayatTheme.accentOrange.withOpacity(0.15);
        fg = ShekayatTheme.accentOrange;
        break;
      default:
        bg = Colors.grey.shade200;
        fg = Colors.grey.shade700;
    }
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(status, style: PersianFonts.Shabnam.copyWith(fontSize: font_size_10, color: fg, fontWeight: FontWeight.w600)),
    );
  }
}

class _ActionBar extends StatelessWidget {
  final bool readOnly;
  final VoidCallback onView;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ActionBar({
    required this.readOnly,
    required this.onView,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        _actionIcon(Icons.visibility_outlined, ShekayatTheme.primary, onView),
        if (!readOnly) ...[
          SizedBox(width: 4.w),
          _actionIcon(Icons.edit_outlined, ShekayatTheme.accentOrange, onEdit),
          SizedBox(width: 4.w),
          _actionIcon(Icons.delete_outline, ShekayatTheme.accentRed, onDelete),
        ],
      ],
    );
  }

  Widget _actionIcon(IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: EdgeInsets.all(4.w),
        child: Icon(icon, size: 20.sp, color: color),
      ),
    );
  }
}

class _DocFormSheet extends StatefulWidget {
  final Map<String, dynamic>? initial;
  final String codeShekayat;
  final String sourceType;
  final ImagePicker picker;

  const _DocFormSheet({
    this.initial,
    required this.codeShekayat,
    required this.sourceType,
    required this.picker,
  });

  @override
  State<_DocFormSheet> createState() => _DocFormSheetState();
}

class _DocFormSheetState extends State<_DocFormSheet> {
  late final TextEditingController _titleCtrl;
  String _filePath = '';
  String _fileDate = '';
  String _pickMode = 'gallery';

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.initial?['title']?.toString() ?? '');
    _filePath = widget.initial?['file_path']?.toString() ?? '';
    _fileDate = widget.initial?['file_date']?.toString() ?? '';
    if (_fileDate.isEmpty) _fileDate = convert_date_persian2(DateTime.now());
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    String? path;
    if (_pickMode == 'camera') {
      final img = await widget.picker.pickImage(source: ImageSource.camera, imageQuality: 85);
      path = img?.path;
    } else if (_pickMode == 'gallery') {
      final img = await widget.picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
      path = img?.path;
    } else {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowMultiple: false,
        withData: false,
        allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png', 'webp', 'bmp'],
      );
      if (result != null && result.files.isNotEmpty) {
        path = result.files.single.path;
      }
    }
    if (path == null || path.isEmpty) {
      if (mounted) {
        MotionToast.warning(
          title: const Text('توجه'),
          description: const Text('فایلی انتخاب نشد'),
        ).show(context);
      }
      return;
    }
    setState(() => _filePath = path!);
  }

  void _submit() {
    if (_titleCtrl.text.trim().isEmpty) {
      MotionToast.warning(title: const Text('توجه'), description: const Text('عنوان مدرک را وارد کنید')).show(context);
      return;
    }
    if (_filePath.isEmpty) {
      MotionToast.warning(title: const Text('توجه'), description: const Text('فایل مدرک را انتخاب کنید')).show(context);
      return;
    }
    if (!_isRemoteOrServerPath(_filePath) && !_isLocalPath(_filePath)) {
      MotionToast.error(
        title: const Text('خطا'),
        description: const Text('فایل انتخاب‌شده قابل دسترسی نیست'),
      ).show(context);
      return;
    }
    final doc = Map<String, dynamic>.from(widget.initial ?? {});
    doc['title'] = _titleCtrl.text.trim();
    doc['file_path'] = _filePath;
    doc['file_date'] = _fileDate;
    if (widget.initial == null) doc['_isNew'] = true;
    if (_isLocalPath(_filePath)) doc['_localPending'] = true;
    Navigator.pop(context, doc);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(4)),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              widget.initial == null ? 'ثبت مدرک' : 'ویرایش مدرک',
              style: PersianFonts.Shabnam.copyWith(fontSize: font_size_14, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _titleCtrl,
              decoration: InputDecoration(
                labelText: 'عنوان مدرک',
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              style: PersianFonts.Shabnam.copyWith(fontSize: font_size_12),
            ),
            const SizedBox(height: 10),
            Text('نوع فایل', style: PersianFonts.Shabnam.copyWith(fontSize: font_size_12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Row(
              children: [
                _modeChip('دوربین', 'camera', Icons.camera_alt_outlined),
                const SizedBox(width: 8),
                _modeChip('گالری', 'gallery', Icons.photo_library_outlined),
                const SizedBox(width: 8),
                _modeChip('فایل', 'file', Icons.attach_file),
              ],
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _pickFile,
              icon: const Icon(Icons.upload_file, size: 18),
              label: Text('انتخاب فایل', style: PersianFonts.Shabnam.copyWith(fontSize: font_size_12)),
              style: OutlinedButton.styleFrom(
                foregroundColor: ShekayatTheme.primary,
                side: const BorderSide(color: ShekayatTheme.primary),
                padding: const EdgeInsets.symmetric(vertical: 10),
                minimumSize: const Size(0, 40),
              ),
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(height: 120, child: _DocPreview(path: _filePath, compact: true)),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: ShekayatTheme.primary,
                minimumSize: const Size(double.infinity, 40),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text('ذخیره', style: PersianFonts.Shabnam.copyWith(color: Colors.white, fontSize: font_size_12)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _modeChip(String label, String value, IconData icon) {
    final selected = _pickMode == value;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _pickMode = value),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 8.h),
          decoration: BoxDecoration(
            color: selected ? ShekayatTheme.primary.withOpacity(0.1) : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: selected ? ShekayatTheme.primary : Colors.grey.shade300),
          ),
          child: Column(
            children: [
              Icon(icon, size: 18.sp, color: selected ? ShekayatTheme.primary : Colors.grey.shade600),
              SizedBox(height: 2.h),
              Text(label, style: PersianFonts.Shabnam.copyWith(fontSize: font_size_10, color: selected ? ShekayatTheme.primary : Colors.grey.shade700)),
            ],
          ),
        ),
      ),
    );
  }
}

bool _isRemoteOrServerPath(String path) {
  final p = path.trim();
  if (p.isEmpty) return false;
  final lower = p.toLowerCase();
  if (lower.startsWith('http://') || lower.startsWith('https://')) return true;
  if (lower.startsWith('/pic_injast') || lower.startsWith('pic_injast/')) return true;
  if (lower.contains('/pic_injast/')) return true;
  if (lower.startsWith('/uploads/') || lower.startsWith('uploads/')) return true;
  return false;
}

/// مسیر فایل روی دیسک محلی (دسکتاپ/موبایل) در مقابل مسیر ذخیره‌شده روی سرور
bool _isLocalPath(String path) {
  final p = path.trim();
  if (p.isEmpty) return false;
  if (_isRemoteOrServerPath(p)) return false;
  if (p.startsWith('file://')) return true;

  // Windows: C:\... یا C:/...
  if (RegExp(r'^[a-zA-Z]:[\\/]').hasMatch(p)) return true;

  // macOS / Linux / Android absolute path
  if (p.startsWith('/')) {
    try {
      return File(p).existsSync();
    } catch (_) {
      return false;
    }
  }

  // مسیر نسبی: اگر روی دیسک باشد محلی است
  try {
    return File(p).existsSync();
  } catch (_) {
    return false;
  }
}

bool _isImagePath(String path) {
  final lower = path.toLowerCase();
  final clean = lower.split('?').first;
  return clean.endsWith('.jpg') ||
      clean.endsWith('.jpeg') ||
      clean.endsWith('.png') ||
      clean.endsWith('.gif') ||
      clean.endsWith('.webp') ||
      clean.endsWith('.bmp') ||
      clean.endsWith('.heic');
}

bool _isPdfPath(String path) => path.toLowerCase().endsWith('.pdf');

String _fileTypeLabel(String path) {
  if (path.isEmpty) return '—';
  if (_isPdfPath(path)) return 'PDF';
  if (_isImagePath(path)) return 'تصویر';
  return 'فایل';
}

String _fileName(String path) {
  if (path.isEmpty) return '';
  final parts = path.split(Platform.pathSeparator);
  if (parts.length == 1) return path.split('/').last;
  return parts.last;
}
