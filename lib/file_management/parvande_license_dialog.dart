import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:http/http.dart' as http;
import 'package:injast_admin/file_management/media_file_urls.dart';
import 'package:injast_admin/file_management/parvande_api.dart';
import 'package:injast_admin/file_management/parvande_license_html.dart';
import 'package:injast_admin/local_cache/local_cache_paths.dart';
import 'package:injast_admin/local_cache/local_image_store.dart';
import 'package:injast_admin/server_config.dart';
import 'package:path/path.dart' as p;

/// نمایش پروانه — HTML قالب، PDF، یا تصویر (بدون apinovin)
class ParvandeLicenseDialog extends StatefulWidget {
  const ParvandeLicenseDialog({
    super.key,
    required this.parvande,
    required this.codeCo,
  });

  final Map<String, dynamic> parvande;
  final String codeCo;

  static Future<void> show(
    BuildContext context, {
    required String codeCo,
    required Map<String, dynamic> parvande,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ParvandeLicenseDialog(parvande: parvande, codeCo: codeCo),
    );
  }

  @override
  State<ParvandeLicenseDialog> createState() => _ParvandeLicenseDialogState();
}

class _ParvandeLicenseDialogState extends State<ParvandeLicenseDialog> {
  bool _loading = true;
  String? _error;
  String? _localPath;
  String? _htmlContent;
  String? _htmlBaseUrl;
  ParvanehContentKind? _kind;
  final _attemptLogs = <String>[];

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  Future<String?> _profileImageDataUri() async {
    final id = widget.parvande.idParvandeh;
    if (id.isEmpty) return null;

    var local = await LocalImageStore.instance.resolveLocalPath(
      codeCo: widget.codeCo,
      idParvandeh: id,
      fieldKey: 'image_profile',
    );

    if (local == null) {
      local = await LocalImageStore.instance.localPathForField(
        widget.codeCo,
        id,
        'image_profile',
      );
    }

    final raw = widget.parvande.imageProfile.trim();
    if (local == null && raw.isNotEmpty && raw.toLowerCase() != 'null') {
      local = await LocalImageStore.instance.downloadToFile(
        codeCo: widget.codeCo,
        idParvandeh: id,
        fieldKey: 'image_profile',
        remoteUrl: raw,
        fastMode: true,
      );
    }

    if (local == null && raw.isNotEmpty) {
      local = await _downloadProfileFromServer(raw, id);
    }

    if (local == null) return null;
    final file = File(local);
    if (!await file.exists()) return null;

    final bytes = await file.readAsBytes();
    if (!bytesLookLikeImage(bytes)) return null;

    logParvanehDebug('profile photo: $local');
    return ParvandeLicenseHtml.dataUriFromImageBytes(bytes, local);
  }

  Future<String?> _downloadProfileFromServer(String raw, String id) async {
    var path = raw.replaceAll('\\', '/');
    if (path.startsWith('http://') || path.startsWith('https://')) {
      if (path.contains('apinovin.iranianasnaf.ir')) return null;
      path = Uri.tryParse(path)?.path ?? '';
    }
    if (path.isEmpty) return null;
    if (!path.startsWith('/')) path = '/$path';

    for (final base in [serverApiBaseUrl, MediaFileUrls.mediaHost]) {
      try {
        final url = '$base$path';
        final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 30));
        if (res.statusCode < 200 || res.statusCode >= 300) continue;
        final bytes = res.bodyBytes;
        if (bytes.length < 80 || !bytesLookLikeImage(bytes)) continue;

        final dirPath = await LocalCachePaths.parvandeMediaDir(widget.codeCo, id);
        if (dirPath == null) continue;
        final out = p.join(dirPath, 'image_profile.jpg');
        await File(out).writeAsBytes(bytes);
        return out;
      } catch (_) {}
    }
    return null;
  }

  Future<void> _setHtmlForDisplay(String rawHtml, {String? fromUrl}) async {
    _htmlBaseUrl = fromUrl != null
        ? MediaFileUrls.baseUrlForParvanehFetch(fromUrl)
        : '${MediaFileUrls.mediaHost}/';
    final profileUri = await _profileImageDataUri();
    _htmlContent = ParvandeLicenseHtml.prepare(rawHtml, profileDataUri: profileUri);
    logParvanehDebug('html ready baseUrl=$_htmlBaseUrl profile=${profileUri != null}');
  }

  Future<bool> _applyFromBytes({
    required List<int> bytes,
    required String dirPath,
    required String baseName,
    required ParvanehContentKind kind,
    required String source,
    String? fromUrl,
  }) async {
    final ext = MediaFileUrls.extensionForKind(kind);
    final filePath = p.join(dirPath, '$baseName$ext');
    await File(filePath).writeAsBytes(bytes);

    _kind = kind;
    _localPath = filePath;

    if (kind == ParvanehContentKind.html) {
      await _setHtmlForDisplay(utf8.decode(bytes, allowMalformed: true), fromUrl: fromUrl);
    } else if (kind == ParvanehContentKind.pdf) {
      logParvanehDebug('pdf: $filePath');
    } else {
      logParvanehDebug('image: $filePath');
    }
    return true;
  }

  Future<bool> _applyLocalFile(String path, {required String source, String? fromUrl}) async {
    final file = File(path);
    if (!await file.exists()) return false;
    final bytes = await file.readAsBytes();

    ParvanehContentKind? kind;
    if (bytesLookLikeParvanehHtml(bytes)) {
      kind = ParvanehContentKind.html;
    } else if (bytesLookLikePdf(bytes)) {
      kind = ParvanehContentKind.pdf;
    } else if (bytesLookLikeImage(bytes)) {
      kind = ParvanehContentKind.image;
    } else {
      logParvanehDebug('invalid ($source): $path');
      _attemptLogs.add('فایل نامعتبر: $path');
      return false;
    }

    final raw = widget.parvande.s('image_parvaneh');
    final baseName = MediaFileUrls.parvanehLocalBaseName(raw) ??
        p.basenameWithoutExtension(p.basename(path));

    final dirPath = p.dirname(path);
    final ext = MediaFileUrls.extensionForKind(kind);
    final targetPath = p.join(dirPath, '$baseName$ext');

    if (path != targetPath) {
      await File(targetPath).writeAsBytes(bytes);
      if (path.toLowerCase().endsWith('.jpg') && kind != ParvanehContentKind.image) {
        try {
          await file.delete();
        } catch (_) {}
      }
    }

    return _applyFromBytes(
      bytes: bytes,
      dirPath: dirPath,
      baseName: baseName,
      kind: kind,
      source: source,
      fromUrl: fromUrl ?? _guessUrlFromPath(raw),
    );
  }

  String? _guessUrlFromPath(String raw) {
    if (raw.isEmpty) return null;
    final urls = MediaFileUrls.parvanehDownloadUrls(raw);
    return urls.isNotEmpty ? urls.first : null;
  }

  Future<void> _prepare() async {
    final id = widget.parvande.idParvandeh;
    logParvanehDebug('start id=$id codeCo=${widget.codeCo}');

    try {
      final rawParvaneh = widget.parvande.s('image_parvaneh');
      final serverBase = MediaFileUrls.parvanehLocalBaseName(rawParvaneh);
      final dirPath = await LocalCachePaths.parvandeMediaDir(widget.codeCo, id);

      if (dirPath != null && serverBase != null) {
        for (final ext in ['.html', '.pdf', '.jpg']) {
          final f = File(p.join(dirPath, '$serverBase$ext'));
          if (await f.exists() && await _applyLocalFile(f.path, source: 'cache:$serverBase$ext')) {
            return;
          }
        }
      }

      for (final field in ['image_parvaneh', 'licence_file']) {
        final local = await LocalImageStore.instance.resolveLocalPath(
          codeCo: widget.codeCo,
          idParvandeh: id,
          fieldKey: field,
        );
        if (local != null && await _applyLocalFile(local, source: 'cache:$field')) {
          return;
        }
      }

      final fields = <String, String>{
        'image_parvaneh': rawParvaneh,
        'licence_file': widget.parvande.s('licence_file'),
      };
      fields.removeWhere((_, v) => v.isEmpty);

      if (fields.isEmpty) {
        _error = 'فیلدهای image_parvaneh و licence_file در پرونده خالی هستند.';
        return;
      }

      if (dirPath == null) {
        _error = 'مسیر ذخیرهٔ محلی در دسترس نیست.';
        return;
      }
      final dir = Directory(dirPath);
      if (!await dir.exists()) await dir.create(recursive: true);

      for (final entry in fields.entries) {
        final field = entry.key;
        final raw = entry.value;

        final result = await MediaFileUrls.fetchParvanehContent(
          raw,
          onAttempt: (msg) => _attemptLogs.add('[$field] $msg'),
        );

        if (result == null) continue;

        if (await _applyFromBytes(
          bytes: result.bytes,
          dirPath: dirPath,
          baseName: result.baseName,
          kind: result.kind,
          source: 'download:$field',
          fromUrl: result.url,
        )) {
          return;
        }
      }

      _error = 'فایل پروانه از هیچ مسیر محتمل بارگذاری نشد.\n\n'
          '${fields.entries.map((e) => '${e.key}: ${e.value}').join('\n')}\n\n'
          '${_attemptLogs.join('\n')}';
    } catch (e) {
      logParvanehDebug('fatal: $e');
      _error = 'خطا: $e\n\n${_attemptLogs.join('\n')}';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 920,
          maxHeight: MediaQuery.sizeOf(context).height * 0.78,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 4, 6),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'پروانه کسب',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF94A3B8), width: 1.5),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6.5),
                    child: _loading
                        ? const Center(child: CircularProgressIndicator())
                        : _error != null
                            ? SingleChildScrollView(
                                padding: const EdgeInsets.all(16),
                                child: SelectableText(
                                  _error!,
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(fontSize: 12.5, height: 1.5),
                                ),
                              )
                            : _buildPreview(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreview() {
    if (_kind == ParvanehContentKind.html && _htmlContent != null) {
      return InAppWebView(
        initialData: InAppWebViewInitialData(
          data: _htmlContent!,
          baseUrl: WebUri(_htmlBaseUrl ?? '${MediaFileUrls.mediaHost}/'),
          mimeType: 'text/html',
          encoding: 'utf-8',
        ),
        initialSettings: InAppWebViewSettings(
          supportZoom: false,
          builtInZoomControls: false,
          displayZoomControls: false,
          useWideViewPort: true,
          transparentBackground: true,
          javaScriptEnabled: true,
          verticalScrollBarEnabled: false,
          horizontalScrollBarEnabled: false,
        ),
      );
    }

    final path = _localPath!;
    if (_kind == ParvanehContentKind.pdf) {
      return InAppWebView(
        initialUrlRequest: URLRequest(url: WebUri(Uri.file(path).toString())),
        initialSettings: InAppWebViewSettings(
          transparentBackground: true,
          supportZoom: true,
        ),
      );
    }

    return InteractiveViewer(
      child: Center(
        child: Image.file(
          File(path),
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const Text('نمایش تصویر ناموفق بود.'),
        ),
      ),
    );
  }
}
