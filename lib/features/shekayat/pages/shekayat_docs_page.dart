import 'package:flutter/material.dart';
import 'package:injast_admin/features/shekayat/compat/shekayat_layout.dart';
import 'package:injast_admin/features/shekayat/pages/shekayat_docs_gallery.dart';
import 'package:injast_admin/features/shekayat/pages/shekayat_widgets.dart';

/// مدارک و مستندات — wrapper گالری یکپارچه
class ShekayatDocsPage extends StatelessWidget {
  final String codeShekayat;
  final String sourceType;
  final bool readOnly;
  final bool pendingMode;
  final bool embedded;
  final List<Map<String, dynamic>>? initialPending;
  final void Function(List<Map<String, dynamic>> docs)? onPendingSave;

  const ShekayatDocsPage({
    Key? key,
    required this.codeShekayat,
    this.sourceType = 'complainant',
    this.readOnly = false,
    this.pendingMode = false,
    this.embedded = false,
    this.initialPending,
    this.onPendingSave,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final gallery = ShekayatDocsGallery(
      codeShekayat: codeShekayat,
      sourceType: sourceType,
      readOnly: readOnly,
      embedded: embedded,
      pendingMode: pendingMode,
      initialPending: initialPending,
      onPendingSave: onPendingSave,
    );

    if (embedded) {
      return Directionality(textDirection: TextDirection.rtl, child: gallery);
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        appBar: const ShekayatAppBar(title: 'مدارک و مستندات'),
        body: ShekayatLayout.constrain(
          maxWidth: ShekayatLayout.docsMaxWidth,
          child: gallery,
        ),
      ),
    );
  }
}
