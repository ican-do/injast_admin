import 'package:flutter/material.dart';
import 'package:injast_admin/file_management/jalali_date_util.dart';
import 'package:injast_admin/server_config.dart';

export 'package:injast_admin/server_config.dart' show getStaticFileUrl;

class UnionPrintLogo extends StatelessWidget {
  const UnionPrintLogo({
    super.key,
    required this.data,
    this.size = 44,
    this.fileUrl,
    this.color = const Color(0xFF2B6CB0),
  });

  final Map<String, dynamic> data;
  final double size;
  final String Function(String path)? fileUrl;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final raw = data['union_logo']?.toString().trim() ?? '';
    final url = raw.isEmpty ? '' : (fileUrl ?? getStaticFileUrl)(raw);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 1.3),
        color: Colors.white,
      ),
      clipBehavior: Clip.antiAlias,
      child: url.isEmpty
          ? Icon(Icons.account_balance, color: color, size: size * 0.48)
          : Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  Icon(Icons.account_balance, color: color, size: size * 0.48),
            ),
    );
  }
}

String bazrasiJalali(dynamic value) {
  if (value == null) return '';
  if (value is DateTime) return JalaliDateUtil.formatFromDateTime(value);
  final shown = JalaliDateUtil.serverToDisplay(value.toString());
  return shown.isEmpty ? value.toString() : shown;
}
