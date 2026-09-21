import 'dart:io';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:injast_admin/features/inspections/inspection_archive_api.dart';
import 'package:injast_admin/features/inspections/inspection_outcome_panel.dart';
import 'package:injast_admin/features/inspections/print/bazrasi_official_print_sheet.dart';
import 'package:injast_admin/features/shared/admin_ui.dart';

class InspectionFormViewPage extends StatefulWidget {
  const InspectionFormViewPage({
    super.key,
    required this.codeCo,
    required this.item,
    required this.formName,
    required this.parvande,
  });

  final String codeCo;
  final Map<String, dynamic> item;
  final String formName;
  final Map<String, dynamic> parvande;

  @override
  State<InspectionFormViewPage> createState() => _InspectionFormViewPageState();
}

class _InspectionFormViewPageState extends State<InspectionFormViewPage> {
  final _sheetKey = GlobalKey();
  bool _loading = false;
  bool _saving = false;
  String? _error;
  Map<String, dynamic> _data = {};

  String get _kind => widget.item['kind']?.toString() ?? 'form';
  String get _id => widget.item['id']?.toString() ?? '';

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    if (_kind == 'system') {
      setState(() => _data = _systemPrintData());
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final fill = await InspectionArchiveApi.instance.fetchFill(
        codeCo: widget.codeCo,
        fillId: _id,
      );
      if (!mounted) return;
      setState(() => _data = _mergeFill(fill));
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Map<String, dynamic> _systemPrintData() {
    final fields = widget.item['fields'];
    final items = <Map<String, dynamic>>[];
    if (fields is Map) {
      for (final e in fields.entries) {
        items.add({
          'id': e.key.toString(),
          'title': e.key.toString(),
          'type': 'text',
          'value': e.value,
        });
      }
    }
    return {
      'form_name': widget.formName,
      'inspector_name': widget.item['inspector_name'],
      'created_at': widget.item['created_at'] ?? widget.item['date_label'],
      'parvande': widget.parvande,
      'items': items,
      'fields': items
          .map((e) => {'title': e['title'], 'value': '${e['value'] ?? ''}'})
          .toList(),
    };
  }

  Map<String, dynamic>? _currentOutcome() {
    final a = _data['outcome'];
    if (a is Map && (a['status']?.toString() ?? '').isNotEmpty) {
      return Map<String, dynamic>.from(a);
    }
    final b = widget.item['outcome'];
    if (b is Map && (b['status']?.toString() ?? '').isNotEmpty) {
      return Map<String, dynamic>.from(b);
    }
    return null;
  }

  Map<String, dynamic> _mergeFill(Map<String, dynamic> fill) {
    final form = fill['form'] is Map
        ? Map<String, dynamic>.from(fill['form'] as Map)
        : <String, dynamic>{};
    return {
      ...fill,
      'form_name': (fill['form_name'] ?? form['name'] ?? widget.formName).toString(),
      'template_key': fill['template_key'] ?? form['template_key'],
      'print_layout': fill['print_layout'] ?? form['print_layout'],
      'form_fields': fill['form_fields'] ?? form['fields'],
      'parvande': fill['parvande'] ?? widget.parvande,
      'public_view_token':
          fill['public_view_token'] ?? widget.item['public_view_token'],
    };
  }

  Future<void> _saveImage() async {
    if (_saving || _loading) return;
    setState(() => _saving = true);
    try {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      await WidgetsBinding.instance.endOfFrame;
      final ctx = _sheetKey.currentContext;
      final ro = ctx?.findRenderObject();
      if (ro is! RenderRepaintBoundary) {
        throw Exception('فرم برای تصویر آماده نیست');
      }
      final image = await ro.toImage(pixelRatio: 3.2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (bytes == null) throw Exception('ساخت تصویر انجام نشد');
      final png = bytes.buffer.asUint8List();
      final formName = (_data['form_name'] ?? widget.formName)
          .toString()
          .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final suggested = 'bazrasi_${formName.isEmpty ? 'form' : formName}.png';
      if (kIsWeb) {
        throw Exception('ذخیره تصویر روی وب در این نسخه فعال نیست.');
      }
      final path = await FilePicker.saveFile(
        dialogTitle: 'ذخیره تصویر فرم بازرسی',
        fileName: suggested,
        type: FileType.custom,
        allowedExtensions: const ['png'],
        bytes: png,
      );
      if (path == null || path.trim().isEmpty) return;
      final file = File(path.endsWith('.png') ? path : '$path.png');
      await file.writeAsBytes(png, flush: true);
      if (mounted) {
        showAdminSnack(context, 'تصویر در ${file.path} ذخیره شد');
      }
    } catch (e) {
      if (mounted) {
        showAdminSnack(context, 'خطا در ذخیره تصویر: $e', error: true);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final formName = _data['form_name']?.toString() ?? widget.formName;
    return AdminPageShell(
      title: formName,
      subtitle: 'نمایش با قالب فرم‌ساز — چاپ به صورت تصویر',
      icon: Icons.description_outlined,
      maxWidth: 920,
      actions: [
        FilledButton.tonalIcon(
          onPressed: _saving || _loading || _error != null ? null : _saveImage,
          icon: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.image_outlined),
          label: const Text('چاپ / ذخیره تصویر'),
        ),
      ],
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : ColoredBox(
                  color: const Color(0xFFE8EDF3),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
                    child: Column(
                      children: [
                        InspectionOutcomePanel(
                          codeCo: widget.codeCo,
                          sourceKind: _kind == 'system' ? 'system' : 'form',
                          sourceId: _id,
                          idParvande: (widget.parvande['id_parvande'] ??
                                  _data['id_parvande'] ??
                                  '')
                              .toString(),
                          formId: (_data['form'] is Map
                                  ? (_data['form'] as Map)['id']
                                  : widget.item['form_id'])
                              ?.toString() ??
                              '',
                          formName: formName,
                          initial: _currentOutcome(),
                          onChanged: (o) {
                            setState(() {
                              _data = {..._data, 'outcome': o};
                            });
                          },
                        ),
                        const SizedBox(height: 12),
                        RepaintBoundary(
                          key: _sheetKey,
                          child: ColoredBox(
                            color: Colors.white,
                            child: BazrasiOfficialPrintSheet(data: _data),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }
}
