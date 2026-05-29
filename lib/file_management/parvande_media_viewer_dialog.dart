import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:injast_admin/file_management/store_image_logger.dart';
import 'package:injast_admin/local_cache/cached_media_item.dart';
import 'package:url_launcher/url_launcher.dart';

/// نمایش یک فایل محلی یا URL سرور (تصویر / PDF / HTML) در دیالگ.
class ParvandeMediaViewerDialog extends StatelessWidget {
  const ParvandeMediaViewerDialog({
    super.key,
    required this.item,
  });

  final CachedMediaItem item;

  static Future<void> show(BuildContext context, CachedMediaItem item) {
    logMediaUrl('viewer open ${item.label} urls=${item.networkUrls} local=${item.localPath}');
    return showDialog<void>(
      context: context,
      builder: (_) => ParvandeMediaViewerDialog(item: item),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 900,
          maxHeight: MediaQuery.sizeOf(context).height * 0.88,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      item.label,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
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
            Expanded(child: _buildPreview()),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: FilledButton.icon(
                onPressed: () => _openExternally(item),
                icon: const Icon(Icons.open_in_new),
                label: const Text('باز کردن با برنامهٔ پیش‌فرض'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreview() {
    if (item.hasLocal && item.isPdf) {
      return _PdfPreview(path: item.localPath!);
    }

    if (item.isHtml || (item.hasNetwork && item.isPdf == false && item.isImage == false)) {
      if (item.hasNetwork) {
        return _WebPreview(url: item.networkUrls.first);
      }
    }

    if (item.isImage) {
      if (item.hasLocal) {
        return InteractiveViewer(
          child: Center(
            child: Image.file(
              File(item.localPath!),
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => _NetworkPreview(urls: item.networkUrls),
            ),
          ),
        );
      }
      if (item.hasNetwork) {
        return _NetworkPreview(urls: item.networkUrls);
      }
    }

    if (item.hasNetwork && item.isPdf) {
      return _WebPreview(url: item.networkUrls.first);
    }

    if (item.hasLocal) {
      return _UnknownFileBody(path: item.localPath!);
    }

    return _UnknownFileBody(path: item.networkUrls.join('\n'));
  }

  static Future<void> _openExternally(CachedMediaItem item) async {
    final url = item.networkUrl;
    if (item.hasLocal) {
      final uri = Uri.file(item.localPath!);
      if (await canLaunchUrl(uri)) await launchUrl(uri);
      return;
    }
    if (url != null) {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }
}

class _NetworkPreview extends StatefulWidget {
  const _NetworkPreview({required this.urls});
  final List<String> urls;

  @override
  State<_NetworkPreview> createState() => _NetworkPreviewState();
}

class _NetworkPreviewState extends State<_NetworkPreview> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    if (widget.urls.isEmpty) {
      return const _ErrorBody(message: 'آدرس تصویر موجود نیست.');
    }
    if (_index >= widget.urls.length) {
      return _ErrorBody(message: 'بارگذاری ناموفق:\n${widget.urls.join('\n')}');
    }
    final url = widget.urls[_index];
    logMediaUrl('viewer try image $_index/$url');
    return InteractiveViewer(
      child: Center(
        child: Image.network(
          url,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) {
            if (_index + 1 < widget.urls.length) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) setState(() => _index++);
              });
            }
            return _ErrorBody(
              message: _index + 1 < widget.urls.length
                  ? 'تلاش URL بعدی…'
                  : 'بارگذاری ناموفق:\n$url',
            );
          },
        ),
      ),
    );
  }
}

class _WebPreview extends StatelessWidget {
  const _WebPreview({required this.url});
  final String url;

  @override
  Widget build(BuildContext context) {
    logMediaUrl('viewer webview $url');
    return InAppWebView(
      initialUrlRequest: URLRequest(url: WebUri(url)),
      initialSettings: InAppWebViewSettings(
        transparentBackground: true,
        allowsInlineMediaPlayback: true,
        javaScriptEnabled: true,
      ),
    );
  }
}

class _PdfPreview extends StatelessWidget {
  const _PdfPreview({required this.path});
  final String path;

  @override
  Widget build(BuildContext context) {
    return InAppWebView(
      initialUrlRequest: URLRequest(url: WebUri(Uri.file(path).toString())),
      initialSettings: InAppWebViewSettings(transparentBackground: true),
    );
  }
}

class _UnknownFileBody extends StatelessWidget {
  const _UnknownFileBody({required this.path});
  final String path;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SelectableText(path, textAlign: TextAlign.center),
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({this.message = 'بارگذاری فایل ناموفق بود.'});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: SelectableText(message, textAlign: TextAlign.center),
    );
  }
}
