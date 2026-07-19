import 'dart:typed_data';

import 'package:injast_admin/features/shekayat/shekayat_constants.dart';
import 'package:injast_admin/features/shekayat/pages/shekayat_form_mapper.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// تولید PDF فرم شکایت — A4
class ShekayatFormPdf {
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

  static pw.Widget _field(String label, String value, {int flex = 1}) {
    return pw.Expanded(
      flex: flex,
      child: pw.Container(
        margin: const pw.EdgeInsets.all(4),
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey400, width: 0.6),
          borderRadius: pw.BorderRadius.circular(4),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(label, style: _style(size: 9, color: PdfColors.grey700)),
            pw.SizedBox(height: 3),
            pw.Text(value.isEmpty ? '—' : value, style: _style(size: 10)),
          ],
        ),
      ),
    );
  }

  static pw.Widget _row(List<pw.Widget> children) {
    return pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: children);
  }

  static pw.Widget _sectionTitle(String title) {
    return pw.Container(
      width: double.infinity,
      margin: const pw.EdgeInsets.only(top: 10, bottom: 4),
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: const pw.BoxDecoration(
        color: PdfColors.teal50,
        border: pw.Border(left: pw.BorderSide(color: PdfColors.teal, width: 3)),
      ),
      child: pw.Text(title, style: _style(size: 12, bold: true, color: PdfColors.teal800)),
    );
  }

  static Future<Uint8List> generate({
    required Map<String, dynamic> complaint,
    required String codeCo,
    String? unionName,
  }) async {
    await _loadFonts();

    final mot = ShekayatFormMapper.respondentFields(complaint);
    final typeLabel = ShekayatConstants.typeLabel(complaint['type_shekayat']?.toString());
    final complaintNo = complaint['complaint_number']?.toString() ?? '-';
    final date = complaint['date_shekayat']?.toString() ?? '';
    final linked = ShekayatFormMapper.isLinked(complaint);

    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        textDirection: pw.TextDirection.rtl,
        build: (ctx) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColors.teal,
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('فرم شکایت', style: _style(size: 18, bold: true, color: PdfColors.white)),
                        pw.SizedBox(height: 4),
                        pw.Text(unionName ?? codeCo, style: _style(size: 11, color: PdfColors.white)),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('شماره: $complaintNo', style: _style(size: 11, bold: true, color: PdfColors.white)),
                        pw.Text('تاریخ: $date', style: _style(size: 10, color: PdfColors.white)),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 8),
              _row([
                _field('عنوان شکایت', complaint['lbl_shekayat']?.toString() ?? '', flex: 2),
                _field('نوع شکایت', typeLabel),
              ]),
              pw.Container(
                margin: const pw.EdgeInsets.all(4),
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey400, width: 0.6),
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('متن شکایت', style: _style(size: 9, color: PdfColors.grey700)),
                    pw.SizedBox(height: 4),
                    pw.Text(complaint['caption']?.toString() ?? '—', style: _style(size: 10)),
                  ],
                ),
              ),
              _sectionTitle('اطلاعات شاکی'),
              _row([
                _field('نام', complaint['name_shaki']?.toString() ?? ''),
                _field('نام خانوادگی', complaint['family_shaki']?.toString() ?? ''),
              ]),
              _row([
                _field('نام پدر', complaint['name_pedar_shaki']?.toString() ?? ''),
                _field('کد ملی', complaint['code_meli_shaki']?.toString() ?? ''),
              ]),
              _row([
                _field('شماره تماس', complaint['mob_shaki']?.toString() ?? '', flex: 1),
                _field('آدرس', complaint['address_shaki']?.toString() ?? '', flex: 2),
              ]),
              _sectionTitle('اطلاعات متشاکی${linked ? ' (واحد متصل)' : ''}'),
              if (linked)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 4, right: 4, left: 4),
                  child: pw.Text(
                    mot['linkedNote'] ?? '',
                    style: _style(size: 9, color: PdfColors.teal700),
                  ),
                ),
              _row([
                _field('نام', mot['motName'] ?? ''),
                _field('نام خانوادگی', mot['motFamily'] ?? ''),
              ]),
              _row([
                _field('کد ملی', mot['motMeli'] ?? ''),
                _field('نام واحد صنفی', mot['motStore'] ?? ''),
              ]),
              _row([
                _field('شماره تماس', mot['motMob'] ?? '', flex: 1),
                _field('آدرس', mot['motAddr'] ?? '', flex: 2),
              ]),
              if (linked) ...[
                _row([
                  _field('شناسه واحد', complaint['linked_parvandeh_shenase']?.toString() ?? ''),
                  _field('شماره پرونده', complaint['linked_parvandeh_num']?.toString() ?? ''),
                ]),
                _row([_field('رسته', complaint['linked_parvandeh_raste']?.toString() ?? '')]),
              ],
              pw.Spacer(),
              pw.Divider(color: PdfColors.grey400),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('وضعیت: ${complaint['status_shekayat'] ?? '-'}', style: _style(size: 9, color: PdfColors.grey700)),
                  pw.Text('مرجع: ${complaint['source_shekayat'] ?? '-'}', style: _style(size: 9, color: PdfColors.grey700)),
                ],
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }
}
