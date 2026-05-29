import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:injast_admin/file_management/media_file_urls.dart';
import 'package:injast_admin/file_management/parvande_api.dart';
import 'package:injast_admin/local_cache/local_image_store.dart';

/// تصویر پروفایل پرونده: آنلاین از سرور، آفلاین از فایل محلی.
class ParvandeProfileImage extends StatelessWidget {
  const ParvandeProfileImage({
    super.key,
    required this.codeCo,
    required this.parvande,
    this.width = 46,
    this.height = 46,
    this.borderRadius = 12,
    this.fallbackIcon = Icons.person_outline,
    this.preferServer = false,
  });

  final String codeCo;
  final Map<String, dynamic> parvande;
  final double width;
  final double height;
  final double borderRadius;
  final IconData fallbackIcon;

  /// در حالت آنلاین اول URL سرور امتحان می‌شود.
  final bool preferServer;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: SizedBox(
        width: width,
        height: height,
        child: FutureBuilder<_ResolvedImage>(
          future: _resolve(),
          builder: (context, snap) {
            final r = snap.data;
            if (r == null) return _fallback();

            if (preferServer && r.networkUrls.isNotEmpty) {
              return _NetworkImageFallback(
                urls: r.networkUrls,
                localFile: r.localFile,
                fallback: _fallback(),
              );
            }

            if (r.localFile != null) {
              return Image.file(
                r.localFile!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) {
                  if (r.networkUrls.isNotEmpty) {
                    return _NetworkImageFallback(
                      urls: r.networkUrls,
                      fallback: _fallback(),
                    );
                  }
                  return _fallback();
                },
              );
            }

            if (r.networkUrls.isNotEmpty) {
              return _NetworkImageFallback(
                urls: r.networkUrls,
                fallback: _fallback(),
              );
            }
            return _fallback();
          },
        ),
      ),
    );
  }

  Widget _fallback() {
    return Container(
      color: const Color(0xFFEFF3FA),
      alignment: Alignment.center,
      child: Icon(fallbackIcon, color: const Color(0xFF1E3A5F)),
    );
  }

  Future<_ResolvedImage> _resolve() async {
    final id = parvande.idParvandeh;
    final raw = parvande.imageProfile.trim();
    final networkUrls = MediaFileUrls.profileImageCandidates(raw);

    File? localFile;
    if (id.isNotEmpty && !kIsWeb && !preferServer) {
      final local = await LocalImageStore.instance.resolveLocalPath(
        codeCo: codeCo,
        idParvandeh: id,
        fieldKey: 'image_profile',
      );
      if (local != null) {
        final f = File(local);
        if (await f.exists()) localFile = f;
      }
    }

    return _ResolvedImage(localFile: localFile, networkUrls: networkUrls);
  }
}

class _NetworkImageFallback extends StatefulWidget {
  const _NetworkImageFallback({
    required this.urls,
    required this.fallback,
    this.localFile,
  });

  final List<String> urls;
  final File? localFile;
  final Widget fallback;

  @override
  State<_NetworkImageFallback> createState() => _NetworkImageFallbackState();
}

class _NetworkImageFallbackState extends State<_NetworkImageFallback> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    if (_index >= widget.urls.length) {
      if (widget.localFile != null) {
        return Image.file(
          widget.localFile!,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => widget.fallback,
        );
      }
      return widget.fallback;
    }

    return Image.network(
      widget.urls[_index],
      fit: BoxFit.cover,
      webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
      errorBuilder: (_, __, ___) {
        if (_index + 1 < widget.urls.length) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _index++);
          });
        }
        return widget.fallback;
      },
    );
  }
}

class _ResolvedImage {
  _ResolvedImage({this.localFile, required this.networkUrls});
  final File? localFile;
  final List<String> networkUrls;
}
