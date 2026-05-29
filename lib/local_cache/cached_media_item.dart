import 'dart:io';

/// یک فایل محلی یا URL سرور (تصویر پرونده / سند / store).
class CachedMediaItem {
  CachedMediaItem({
    required this.fieldKey,
    required this.label,
    this.localPath,
    String? networkUrl,
    List<String>? networkUrls,
    this.idDoc,
    this.isOnServerOnly = false,
  }) : networkUrls = networkUrls ?? (networkUrl != null ? [networkUrl] : const []);

  final String fieldKey;
  final String label;
  final String? localPath;
  final List<String> networkUrls;
  final String? idDoc;
  final bool isOnServerOnly;

  String? get networkUrl => networkUrls.isNotEmpty ? networkUrls.first : null;

  bool get hasLocal => localPath != null && localPath!.trim().isNotEmpty;

  bool get hasNetwork => networkUrls.isNotEmpty;

  String get _pathHint => (localPath ?? networkUrl ?? '').toLowerCase();

  /// فقط قالب HTML پروانه — نه مدارک JPG زیر مسیر pic_injast/parvande/...
  bool get isHtml {
    if (_pathHint.endsWith('.html')) return true;
    if (fieldKey == 'image_parvaneh' || fieldKey == 'licence_file') {
      return !_pathHint.endsWith('.jpg') &&
          !_pathHint.endsWith('.jpeg') &&
          !_pathHint.endsWith('.png');
    }
    return false;
  }

  bool get isPdf => _pathHint.endsWith('.pdf');

  bool get isImage {
    if (isHtml || isPdf) return false;
    return _pathHint.endsWith('.jpg') ||
        _pathHint.endsWith('.jpeg') ||
        _pathHint.endsWith('.png') ||
        _pathHint.endsWith('.webp') ||
        _pathHint.endsWith('.gif') ||
        (hasNetwork && !isPdf);
  }

  Future<bool> get exists async {
    if (hasLocal) return File(localPath!).exists();
    return hasNetwork;
  }
}
