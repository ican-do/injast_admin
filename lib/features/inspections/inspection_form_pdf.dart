import 'dart:typed_data';

import 'package:injast_admin/file_management/jalali_date_util.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class InspectionFormPdf {
  InspectionFormPdf._();

  static pw.Font? _font;
  static pw.Font? _fontBold;

  static Future<void> _loadFonts() async {
    if (_font != null) return;
    _font = await PdfGoogleFonts.vazirmatnRegular();
    _fontBold = await PdfGoogleFonts.vazirmatnBold();
  }

  static pw.TextStyle _style({double size = 11, bool bold = false, PdfColor? color}) {
    return pw.TextStyle(
      font: bold ? _fontBold : _font,
      fontSize: size,
      color: color ?? PdfColors.black,
    );
  }

  static String _s(dynamic v) => (v ?? '').toString().trim();

  static String _date(dynamic raw) {
    final t = _s(raw);
    if (t.isEmpty) return '—';
    final shown = JalaliDateUtil.serverToDisplay(t);
    return shown.isEmpty ? t : shown;
  }

  static List<MapEntry<String, String>> _fieldsFrom(Map<String, dynamic> data) {
    final out = <MapEntry<String, String>>[];
    final fields = data['fields'];
    if (fields is List) {
      for (final f in fields) {
        if (f is! Map) continue;
        final title = _s(f['title']);
        final value = _s(f['value']);
        if (title.isEmpty) continue;
        out.add(MapEntry(title, value.isEmpty ? '—' : value));
      }
    }
    if (out.isNotEmpty) return out;
    final map = data['field_map'];
    if (map is Map) {
      for (final e in map.entries) {
        final title = _s(e.key);
        if (title.isEmpty) continue;
        final value = _s(e.value);
        out.add(MapEntry(title, value.isEmpty ? '—' : value));
      }
    }
    return out;
  }

  static Future<Uint8List> generate(Map<String, dynamic> data) async {
    await _loadFonts();
    final p = Map<String, dynamic>.from(data['parvande'] as Map? ?? {});
    final formName = _s(data['form_name']).isEmpty ? 'فرم بازرسی' : _s(data['form_name']);
    final inspector = _s(data['inspector_name']);
    final created = _date(data['created_at'] ?? data['date_label']);
    final fields = _fieldsFrom(data);

    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        textDirection: pw.TextDirection.rtl,
        build: (ctx) {
          return [
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.blueGrey800,
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(formName, style: _style(size: 16, bold: true, color: PdfColors.white)),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'بازرس: ${inspector.isEmpty ? '—' : inspector}',
                        style: _style(size: 10, color: PdfColors.white),
                      ),
                    ],
                  ),
                  pw.Text('تاریخ: $created', style: _style(size: 10, color: PdfColors.white)),
                ],
              ),
            ),
            pw.SizedBox(height: 12),
            pw.Text('مشخصات پرونده', style: _style(size: 13, bold: true, color: PdfColors.blueGrey800)),
            pw.SizedBox(height: 6),
            pw.TableHelper.fromTextArray(
              headers: const ['عنوان', 'مقدار'],
              data: [
                ['نام واحد', _s(p['name_store'])],
                ['مالک', '${_s(p['name_admin'])} ${_s(p['family_admin'])}'.trim()],
                ['شناسه صنفی', _s(p['shenase_store'])],
                ['کد ملی', _s(p['code_meli_admin'])],
                ['همراه', _s(p['mob_admin'])],
                ['رسته', _s(p['raste_store'])],
                ['آدرس', _s(p['address_store'])],
              ].map((r) => [r[0], r[1].isEmpty ? '—' : r[1]]).toList(),
              headerStyle: _style(size: 10, bold: true, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey600),
              cellStyle: _style(size: 10),
              cellAlignment: pw.Alignment.centerRight,
              headerAlignment: pw.Alignment.centerRight,
            ),
            pw.SizedBox(height: 16),
            pw.Text('پاسخ‌های فرم', style: _style(size: 13, bold: true, color: PdfColors.blueGrey800)),
            pw.SizedBox(height: 6),
            if (fields.isEmpty)
              pw.Text('موردی برای چاپ ثبت نشده است.', style: _style(size: 11))
            else
              pw.TableHelper.fromTextArray(
                headers: const ['فیلد', 'پاسخ'],
                data: fields.map((e) => [e.key, e.value]).toList(),
                headerStyle: _style(size: 10, bold: true, color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.teal700),
                cellStyle: _style(size: 10),
                cellAlignment: pw.Alignment.centerRight,
                headerAlignment: pw.Alignment.centerRight,
              ),
          ];
        },
      ),
    );
    return pdf.save();
  }

  static Future<void> print(Map<String, dynamic> data) async {
    final bytes = await generate(data);
    final name = _s(data['form_name']).isEmpty ? 'bazrasi' : _s(data['form_name']);
    await Printing.layoutPdf(
      onLayout: (_) async => bytes,
      name: name,
    );
  }
}
