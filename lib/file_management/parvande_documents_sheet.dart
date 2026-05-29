import 'dart:io';

import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:injast_admin/file_management/parvande_api.dart';
import 'package:injast_admin/file_management/parvande_media_viewer_dialog.dart';
import 'package:injast_admin/local_cache/cached_media_item.dart';
import 'package:injast_admin/local_cache/local_media_catalog.dart';
import 'package:injast_admin/local_cache/parvande_cache_list_service.dart';

/// لیست مدارک و تصاویر کش‌شدهٔ یک پرونده + باز کردن در دیالگ.
class ParvandeDocumentsSheet extends StatefulWidget {
  const ParvandeDocumentsSheet({
    super.key,
    required this.codeCo,
    required this.parvande,
    this.onlineMode = false,
  });

  final String codeCo;
  final Map<String, dynamic> parvande;
  final bool onlineMode;

  static Future<void> show(
    BuildContext context, {
    required String codeCo,
    required Map<String, dynamic> parvande,
    bool onlineMode = false,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ParvandeDocumentsSheet(
        codeCo: codeCo,
        parvande: parvande,
        onlineMode: onlineMode,
      ),
    );
  }

  @override
  State<ParvandeDocumentsSheet> createState() => _ParvandeDocumentsSheetState();
}

class _ParvandeDocumentsSheetState extends State<ParvandeDocumentsSheet> {
  List<CachedMediaItem> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final id = widget.parvande.idParvandeh;
    final fromRow = widget.parvande
        .map((k, v) => MapEntry(k.toString(), v?.toString() ?? ''));
    Map<String, String>? payload = fromRow;
    List<Map<String, dynamic>>? serverDocs;

    if (widget.onlineMode) {
      try {
        serverDocs =
            await ParvandeApi.instance.fetchDocuments(widget.codeCo, id);
        if (serverDocs.isEmpty) {
          final num = widget.parvande.numParvande.trim();
          if (num.isNotEmpty && num != id) {
            serverDocs =
                await ParvandeApi.instance.fetchDocuments(widget.codeCo, num);
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('خطا در دریافت مدارک از سرور: $e')),
          );
        }
      }
    } else if (fromRow['_docs_json']?.trim().isEmpty != false) {
      final records = await ParvandeCacheListService.instance
          .fetchAllFromCache(widget.codeCo);
      final match =
          records.where((r) => (r['id_parvandeh'] ?? '') == id).toList();
      if (match.isNotEmpty) {
        payload = match.first
            .map((k, v) => MapEntry(k.toString(), v?.toString() ?? ''));
      }
    }

    final items = await LocalMediaCatalog.instance.listForParvandeh(
      codeCo: widget.codeCo,
      idParvandeh: id,
      payload: payload,
      includeServerUrls: widget.onlineMode,
      serverDocRows: serverDocs,
    );
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.parvande.fullName;
    return SafeArea(
      child: Container(
        height: MediaQuery.sizeOf(context).height * 0.72,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
              child: Row(
                children: [
                  const Icon(FluentIcons.document_folder_24_regular,
                      color: Color(0xFF6D4C41)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.onlineMode
                              ? 'مدارک و تصاویر (سرور)'
                              : 'مدارک و تصاویر ذخیره‌شده',
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 15),
                        ),
                        Text(
                          name.isEmpty ? widget.parvande.idParvandeh : name,
                          style: const TextStyle(
                              fontSize: 12, color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _items.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              widget.onlineMode
                                  ? 'فایلی روی سرور یا حافظهٔ محلی یافت نشد.'
                                  : 'فایلی در حافظهٔ محلی یافت نشد.\n'
                                      'پس از بکاپ یا همگام‌سازی از سرور اصلی، مدارک اینجا نمایش داده می‌شوند.',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                          itemCount: _items.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (_, i) => _MediaTile(
                            item: _items[i],
                            onTap: () => ParvandeMediaViewerDialog.show(
                                context, _items[i]),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MediaTile extends StatelessWidget {
  const _MediaTile({required this.item, required this.onTap});
  final CachedMediaItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF6F8FB),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              _Thumb(item: item),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.label,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 13.5),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.isOnServerOnly
                          ? 'روی سرور'
                          : item.isPdf
                              ? 'PDF'
                              : item.isImage
                                  ? 'تصویر'
                                  : 'فایل',
                      style: const TextStyle(
                          fontSize: 11.5, color: Colors.black54),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_left),
            ],
          ),
        ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.item});
  final CachedMediaItem item;

  @override
  Widget build(BuildContext context) {
    const size = 52.0;
    if (item.isImage) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: size,
          height: size,
          child: item.hasLocal
              ? Image.file(
                  File(item.localPath!),
                  width: size,
                  height: size,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      _NetworkThumb(urls: item.networkUrls, size: size),
                )
              : _NetworkThumb(urls: item.networkUrls, size: size),
        ),
      );
    }
    return _iconBox(
      size,
      item.isPdf
          ? Icons.picture_as_pdf_outlined
          : Icons.insert_drive_file_outlined,
      color: item.isPdf ? const Color(0xFFC62828) : const Color(0xFF1E3A5F),
    );
  }

  Widget _iconBox(double size, IconData icon, {Color? color}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE0E7F0)),
      ),
      child: Icon(icon, color: color ?? const Color(0xFF1E3A5F)),
    );
  }
}

class _NetworkThumb extends StatefulWidget {
  const _NetworkThumb({required this.urls, required this.size});

  final List<String> urls;
  final double size;

  @override
  State<_NetworkThumb> createState() => _NetworkThumbState();
}

class _NetworkThumbState extends State<_NetworkThumb> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    if (widget.urls.isEmpty || _index >= widget.urls.length) {
      return _brokenBox(widget.size);
    }
    return Image.network(
      widget.urls[_index],
      width: widget.size,
      height: widget.size,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) {
        if (_index + 1 < widget.urls.length) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _index++);
          });
        }
        return _brokenBox(widget.size);
      },
    );
  }

  Widget _brokenBox(double size) {
    return Container(
      width: size,
      height: size,
      color: Colors.white,
      child: const Icon(Icons.broken_image_outlined,
          color: Color(0xFF1E3A5F), size: 22),
    );
  }
}
