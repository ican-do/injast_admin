import 'dart:convert';

/// آماده‌سازی HTML پروانه برای نمایش در WebView
class ParvandeLicenseHtml {
  ParvandeLicenseHtml._();

  static const _fitStyleId = 'injast-parvaneh-fit';
  static const _photoStyle =
      'position:relative;top:27mm;right: 200mm;width: 106px;height: 132px;object-fit:cover';

  /// ابعاد تقریبی A4 افقی (px @96dpi)
  static const licenseWidthPx = 1122.0;
  static const licenseHeightPx = 793.0;

  static String prepare(String html, {String? profileDataUri}) {
    var out = html;
    if (profileDataUri != null && profileDataUri.isNotEmpty) {
      out = _replaceProfilePhoto(out, profileDataUri);
    }
    return _injectFitStyles(out);
  }

  static String _replaceProfilePhoto(String html, String dataUri) {
    const style = _photoStyle;
    final replaced = html.replaceAllMapped(
      RegExp(
        r'<img\s+src="/media/uploads/[^"]+"\s+style="[^"]*"[^>]*>',
        caseSensitive: false,
      ),
      (_) => '<img src="$dataUri" style="$style">',
    );
    if (replaced != html) return replaced;

    return html.replaceAllMapped(
      RegExp(
        r'<img[^>]+style="[^"]*top:\s*27mm[^"]*"[^>]*>',
        caseSensitive: false,
      ),
      (_) => '<img src="$dataUri" style="$style">',
    );
  }

  static String _injectFitStyles(String html) {
    if (html.contains('id="$_fitStyleId"')) return html;

    final w = licenseWidthPx.toInt();
    final h = licenseHeightPx.toInt();
    final inject = '''
<style id="$_fitStyleId">
html, body {
  margin: 0;
  padding: 0;
  width: 100%;
  height: 100%;
  overflow: hidden !important;
  background: #eef1f5;
}
body {
  display: flex;
  align-items: center;
  justify-content: center;
}
#license {
  width: 297mm;
  height: 210mm;
  transform: scale(var(--injast-parvaneh-scale, 1));
  transform-origin: center center;
  flex-shrink: 0;
}
</style>
<script>
(function () {
  var W = $w, H = $h;
  function fitParvaneh() {
    var vw = window.innerWidth || document.documentElement.clientWidth;
    var vh = window.innerHeight || document.documentElement.clientHeight;
    var s = Math.min(vw / W, vh / H) * 0.96;
    document.documentElement.style.setProperty('--injast-parvaneh-scale', String(s));
  }
  fitParvaneh();
  window.addEventListener('load', fitParvaneh);
  window.addEventListener('resize', fitParvaneh);
  setTimeout(fitParvaneh, 100);
  setTimeout(fitParvaneh, 350);
})();
</script>
''';

    if (html.contains('<head>')) {
      return html.replaceFirst('<head>', '<head>$inject');
    }
    if (html.contains('<link')) {
      return html.replaceFirst('<link', '$inject<link');
    }
    return '$inject$html';
  }

  static String? dataUriFromImageBytes(List<int> bytes, String filePath) {
    if (bytes.isEmpty) return null;
    final ext = filePath.toLowerCase();
    final mime = ext.endsWith('.png')
        ? 'image/png'
        : ext.endsWith('.webp')
            ? 'image/webp'
            : 'image/jpeg';
    return 'data:$mime;base64,${base64Encode(bytes)}';
  }
}
