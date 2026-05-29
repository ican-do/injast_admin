import 'package:flutter/material.dart';

/// جداکنندهٔ جهت چپ‌به‌راست برای عبارت‌های لاتین داخل متن فارسی.
const _lri = '\u2066';
const _pdi = '\u2069';

/// عبارت‌های لاتین، عدد، مسیر فایل و علائم فنی را در بلوک LTR جدا می‌کند.
String isolateLatinForRtl(String text) {
  if (text.isEmpty) return text;
  return text.replaceAllMapped(
    RegExp(r'[\u0020-\u007E]+'),
    (m) => '$_lri${m[0]}$_pdi',
  );
}

/// متن فارسی با تراز راست و مدیریت صحیح کلمات انگلیسی.
class BackupRtlText extends StatelessWidget {
  const BackupRtlText(
    this.text, {
    super.key,
    this.style,
    this.maxLines,
    this.overflow,
    this.textAlign = TextAlign.right,
    this.isolateLatin = true,
  });

  final String text;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign textAlign;
  final bool isolateLatin;

  @override
  Widget build(BuildContext context) {
    final content = isolateLatin ? isolateLatinForRtl(text) : text;
    return Text(
      content,
      textDirection: TextDirection.rtl,
      textAlign: textAlign,
      style: style,
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}

/// برچسب کوتاه لاتین (CSV، JSON، …) همیشه چپ‌به‌راست.
class BackupLatinBadge extends StatelessWidget {
  const BackupLatinBadge(
    this.label, {
    super.key,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}
