import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:injast_admin/features/inspections/print/bazrasi_preset_print_sheet.dart';
import 'package:injast_admin/features/inspections/print/bazrasi_print_layout_view.dart';
import 'package:injast_admin/features/inspections/print/bazrasi_print_presets.dart';
import 'package:injast_admin/features/inspections/print/print_bridge.dart';
import 'package:persian_fonts/persian_fonts.dart';

const _ink = Color(0xFF1A1A1A);
const _muted = Color(0xFF4A4A4A);
const _cardBorder = Color(0xFF6E7F7F);
const _titleRed = Color(0xFFC0392B);
const _tableHeader = Color(0xFFE8A05A);
const _tableGrid = Color(0xFFB8C0C0);
const _dotted = Color(0xFF9AA3A3);
const _footer = Color(0xFF2E9B8C);
const _logoRing = Color(0xFF2B6CB0);

class BazrasiOfficialPrintSheet extends StatelessWidget {
  const BazrasiOfficialPrintSheet({super.key, required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    if (BazrasiPrintPresets.resolveId(data).isNotEmpty) {
      return BazrasiPresetPrintSheet(data: data);
    }
    final layout = data['print_layout'];
    if (layout is Map &&
        layout.isNotEmpty &&
        (layout['layout'] != null || layout['canvas'] != null)) {
      return BazrasiPrintLayoutView(
        layout: Map<String, dynamic>.from(layout),
        data: data,
        formatDate: bazrasiJalali,
        fileUrl: getStaticFileUrl,
      );
    }
    return LayoutBuilder(
      builder: (context, c) {
        final pageW = math.min(c.maxWidth, 820.0);
        return Center(
          child: SizedBox(
            width: pageW,
            child: _A4Page(data: data, width: pageW),
          ),
        );
      },
    );
  }
}

class _A4Page extends StatelessWidget {
  const _A4Page({required this.data, required this.width});

  final Map<String, dynamic> data;
  final double width;

  Map<String, dynamic> get _p =>
      Map<String, dynamic>.from(data['parvande'] as Map? ?? {});

  String _s(dynamic v) => (v ?? '').toString().trim();

  bool _truthy(dynamic v) {
    if (v == true || v == 1) return true;
    final t = v?.toString().trim().toLowerCase() ?? '';
    return t == 'true' || t == '1' || t == 'بله' || t == 'checked';
  }

  List<_Reason> _reasons() {
    final out = <_Reason>[];
    final items = (data['items'] as List?) ?? [];
    var n = 1;
    void addRow(String title, bool checked) {
      final t = title.trim();
      if (t.isEmpty) return;
      out.add(_Reason(n++, t, checked));
    }

    for (final raw in items) {
      if (raw is! Map) continue;
      final type = _s(raw['type']);
      final title = _s(raw['title']).isEmpty ? _s(raw['id']) : _s(raw['title']);
      final value = raw['value'];
      if (type == 'checkbox' || (type.isEmpty && value is bool)) {
        addRow(title, _truthy(value));
      } else if (type == 'checkboxGroup' ||
          type == 'tableSelect' ||
          (type.isEmpty && value is List)) {
        if (value is List) {
          for (final o in value) {
            if (o is! Map) continue;
            final lab = _s(o['title'] ?? o['label'] ?? o['id']);
            final on = _truthy(o['selected'] ?? o['checked'] ?? o['value']);
            addRow(lab, on);
          }
        }
      }
    }
    if (out.isEmpty) {
      for (final raw in (data['fields'] as List?) ?? []) {
        if (raw is! Map) continue;
        final v = _s(raw['value']);
        if (v == 'بله' || v == 'خیر') {
          addRow(_s(raw['title']), v == 'بله');
        }
      }
    }
    return out;
  }

  String _notes() {
    final buf = <String>[];
    for (final raw in (data['items'] as List?) ?? []) {
      if (raw is! Map) continue;
      final type = _s(raw['type']);
      if (type != 'longText' && type != 'shortText') continue;
      final title = _s(raw['title']);
      if (title.contains('مخاطب') ||
          title.contains('نشانی') ||
          title.contains('تلفن') ||
          title.contains('کد ملی') ||
          title.contains('کد پستی') ||
          title.contains('واحد')) {
        continue;
      }
      final v = _s(raw['value']);
      if (v.isEmpty) continue;
      if (type == 'longText') {
        buf.add(v);
      } else if (title.contains('توضیح') || title.contains('یادداشت')) {
        buf.add(v);
      }
    }
    if (buf.isEmpty) {
      for (final raw in (data['fields'] as List?) ?? []) {
        if (raw is! Map) continue;
        final title = _s(raw['title']);
        final v = _s(raw['value']);
        if (v.isEmpty || v == 'بله' || v == 'خیر') continue;
        if (title.contains('توضیح') || title.contains('یادداشت') || v.length > 40) {
          buf.add(v);
        }
      }
    }
    return buf.join('  ');
  }

  String _person() {
    final n = '${_s(_p['name_admin'])} ${_s(_p['family_admin'])}'.trim();
    return n;
  }

  String _phone() {
    final t = _s(_p['tel_admin']);
    final m = _s(_p['mob_admin']);
    if (t.isNotEmpty && m.isNotEmpty && t != m) return '$t  /  $m';
    return t.isNotEmpty ? t : m;
  }

  @override
  Widget build(BuildContext context) {
    final union = _s(data['union_name']).isEmpty
        ? 'اتحادیه صنفی'
        : _s(data['union_name']);
    final formName = _s(data['form_name']);
    final created = bazrasiJalali(data['created_at']);
    final inspector = _s(data['inspector_name']);
    final sigPath = _s(data['signature_png_path']);
    final sigUrl = sigPath.isEmpty ? '' : getStaticFileUrl(sigPath);
    final reasons = _reasons();
    final notes = _notes();
    final docNo = _s(_p['num_parvande_store']);
    final unionAddr = _s(data['union_address']);
    final unionTel = _s(data['union_tel']);
    final unionMob = _s(data['union_mobile']);
    final city = [_s(data['union_city']), _s(data['union_state'])]
        .where((e) => e.isNotEmpty)
        .join('، ');

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        width: width,
        color: Colors.white,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(36, 22, 36, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                    Text(
                      'بسمه تعالی',
                      textAlign: TextAlign.center,
                      style: PersianFonts.Shabnam.copyWith(
                        fontSize: 13,
                        color: _muted,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _HeaderCard(
                      union: union,
                      formName: formName,
                      docNo: docNo,
                      date: created,
                      person: _person(),
                      unit: _s(_p['name_store']),
                      address: _s(_p['address_store']),
                      nationalId: _s(_p['code_meli_admin']),
                      phone: _phone(),
                      postal: _s(_p['code_posti_store']),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'بدین‌وسیله به اطلاع می‌رساند واحد صنفی فوق مورد بازرسی قرار گرفت '
                      'و موارد مشروحه در جدول زیر احراز گردید.',
                      textAlign: TextAlign.justify,
                      style: PersianFonts.Shabnam.copyWith(
                        fontSize: 13.5,
                        height: 1.55,
                        color: _ink,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _ReasonsTable(rows: reasons, formName: formName),
                    const SizedBox(height: 16),
                    _NotesBlock(text: notes),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          flex: 4,
                          child: _DottedField(label: 'کد بازرس', value: inspector),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 6,
                          child: _DottedField(
                            label: 'اصل برگ تحویل',
                            value: _person(),
                            suffix: 'گردید',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    Row(
                      children: [
                        Expanded(
                          child: _SignBlock(
                            caption: 'امضاء بازرس',
                            name: inspector,
                          ),
                        ),
                        Expanded(
                          child: _SignBlock(
                            caption: 'امضاء',
                            imageUrl: sigUrl,
                            name: _person(),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            _FooterBand(
              address: unionAddr.isEmpty ? city : unionAddr,
              tel: unionTel,
              mobile: unionMob,
            ),
          ],
        ),
      ),
    );
  }
}

class _Reason {
  _Reason(this.no, this.title, this.checked);
  final int no;
  final String title;
  final bool checked;
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.union,
    required this.formName,
    required this.docNo,
    required this.date,
    required this.person,
    required this.unit,
    required this.address,
    required this.nationalId,
    required this.phone,
    required this.postal,
  });

  final String union;
  final String formName;
  final String docNo;
  final String date;
  final String person;
  final String unit;
  final String address;
  final String nationalId;
  final String phone;
  final String postal;

  @override
  Widget build(BuildContext context) {
    final parts = union.split(' ');
    final line1 = parts.isEmpty ? union : parts.first;
    final line2 = parts.length <= 1 ? '' : parts.sublist(1).join(' ');
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _cardBorder, width: 1.2),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 22,
                child: Column(
                  children: [
                    _DottedField(label: 'شماره', value: docNo),
                    const SizedBox(height: 8),
                    _DottedField(label: 'تاریخ', value: date),
                  ],
                ),
              ),
              Expanded(
                flex: 46,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: const Color(0xFFC44A3A),
                          width: 1.4,
                        ),
                      ),
                      child: Text(
                        formName.isEmpty ? 'فرم بازرسی' : formName,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: PersianFonts.Shabnam.copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: _titleRed,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 32,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            line1,
                            textAlign: TextAlign.right,
                            style: PersianFonts.Shabnam.copyWith(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: _ink,
                            ),
                          ),
                          if (line2.isNotEmpty)
                            Text(
                              line2,
                              textAlign: TextAlign.right,
                              style: PersianFonts.Shabnam.copyWith(
                                fontSize: 11,
                                color: _muted,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: _logoRing, width: 1.4),
                      ),
                      child: const Icon(
                        Icons.account_balance,
                        color: _logoRing,
                        size: 22,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _idRow('مخاطب', person, 'نام واحد / تابلو', unit),
          const SizedBox(height: 10),
          _idRow('نشانی / واقع در', address, 'کد ملی', nationalId),
          const SizedBox(height: 10),
          _idRow('تلفن', phone, 'کد پستی', postal),
        ],
      ),
    );
  }

  Widget _idRow(String rLabel, String rVal, String lLabel, String lVal) {
    return Row(
      children: [
        Expanded(child: _DottedField(label: rLabel, value: rVal)),
        const SizedBox(width: 28),
        Expanded(child: _DottedField(label: lLabel, value: lVal)),
      ],
    );
  }
}

class _DottedField extends StatelessWidget {
  const _DottedField({
    required this.label,
    required this.value,
    this.suffix = '',
  });

  final String label;
  final String value;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          '$label : ',
          style: PersianFonts.Shabnam.copyWith(fontSize: 12.5, color: _ink),
        ),
        Expanded(
          child: CustomPaint(
            painter: _DottedLinePainter(),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 3, right: 4, left: 4),
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: PersianFonts.Shabnam.copyWith(
                  fontSize: 12.5,
                  color: _ink,
                ),
              ),
            ),
          ),
        ),
        if (suffix.isNotEmpty)
          Text(
            ' $suffix',
            style: PersianFonts.Shabnam.copyWith(fontSize: 12.5, color: _ink),
          ),
      ],
    );
  }
}

class _DottedLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const dash = 2.0;
    const gap = 2.2;
    var x = 0.0;
    final y = size.height - 1;
    final p = Paint()
      ..color = _dotted
      ..strokeWidth = 0.8;
    while (x < size.width) {
      canvas.drawLine(
        Offset(x, y),
        Offset(math.min(x + dash, size.width), y),
        p,
      );
      x += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ReasonsTable extends StatelessWidget {
  const _ReasonsTable({required this.rows, required this.formName});

  final List<_Reason> rows;
  final String formName;

  @override
  Widget build(BuildContext context) {
    final shown = rows.isEmpty
        ? [_Reason(1, 'موردی ثبت نشده است', false)]
        : rows;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _cardBorder, width: 1.2),
      ),
      clipBehavior: Clip.antiAlias,
      child: Table(
        border: TableBorder(
          horizontalInside: const BorderSide(color: _tableGrid, width: 0.6),
          verticalInside: const BorderSide(color: _tableGrid, width: 0.6),
        ),
        columnWidths: const {
          0: FlexColumnWidth(1.1),
          1: FlexColumnWidth(7.2),
          2: FlexColumnWidth(1.7),
        },
        children: [
          TableRow(
            decoration: const BoxDecoration(color: _tableHeader),
            children: [
              _th('ردیف'),
              _th(formName.isEmpty ? 'موارد بازرسی' : formName),
              _th(''),
            ],
          ),
          for (final r in shown)
            TableRow(
              children: [
                _td('${r.no}', center: true),
                _td(r.title),
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(2),
                        border: Border.all(color: const Color(0xFF5A5A5A)),
                      ),
                      child: r.checked
                          ? const Icon(Icons.check, size: 13, color: _ink)
                          : null,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _th(String t) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        child: Text(
          t,
          textAlign: TextAlign.center,
          style: PersianFonts.Shabnam.copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      );

  Widget _td(String t, {bool center = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 8),
        child: Text(
          t,
          textAlign: center ? TextAlign.center : TextAlign.center,
          style: PersianFonts.Shabnam.copyWith(fontSize: 12.5, color: _ink),
        ),
      );
}

class _NotesBlock extends StatelessWidget {
  const _NotesBlock({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'توضیحات : ',
              style: PersianFonts.Shabnam.copyWith(fontSize: 13, color: _ink),
            ),
            Expanded(
              child: CustomPaint(
                painter: _DottedLinePainter(),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(
                    text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: PersianFonts.Shabnam.copyWith(fontSize: 12.5),
                  ),
                ),
              ),
            ),
          ],
        ),
        for (var i = 0; i < 3; i++)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: CustomPaint(
              painter: _DottedLinePainter(),
              child: const SizedBox(height: 14, width: double.infinity),
            ),
          ),
      ],
    );
  }
}

class _SignBlock extends StatelessWidget {
  const _SignBlock({required this.caption, this.imageUrl = '', this.name = ''});

  final String caption;
  final String imageUrl;
  final String name;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 72,
          child: imageUrl.isEmpty
              ? const SizedBox.shrink()
              : Image.network(imageUrl, fit: BoxFit.contain),
        ),
        Text(
          caption,
          style: PersianFonts.Shabnam.copyWith(fontSize: 13, color: _ink),
        ),
        if (name.isNotEmpty)
          Text(
            name,
            style: PersianFonts.Shabnam.copyWith(fontSize: 11, color: _muted),
          ),
      ],
    );
  }
}

class _FooterBand extends StatelessWidget {
  const _FooterBand({
    required this.address,
    required this.tel,
    required this.mobile,
  });

  final String address;
  final String tel;
  final String mobile;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 92,
      width: double.infinity,
      child: CustomPaint(
        painter: _FooterWavePainter(),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 28, 28, 10),
          child: DefaultTextStyle(
            style: PersianFonts.Shabnam.copyWith(
              fontSize: 11,
              color: Colors.white,
              height: 1.45,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  flex: 5,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (address.isNotEmpty) Text(address, maxLines: 2),
                      if (tel.isNotEmpty) Text('تلفن: $tel'),
                      if (mobile.isNotEmpty) Text('واتساپ: $mobile'),
                    ],
                  ),
                ),
                const Expanded(
                  flex: 3,
                  child: Align(
                    alignment: Alignment.bottomLeft,
                    child: Text(
                      'WWW.INJAST-WEB.IR',
                      style: TextStyle(
                        letterSpacing: 0.6,
                        fontSize: 12,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FooterWavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()..color = _footer;
    final path = Path()
      ..moveTo(0, 22)
      ..quadraticBezierTo(size.width * 0.22, 2, size.width * 0.48, 14)
      ..quadraticBezierTo(size.width * 0.78, 28, size.width, 6)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, fill);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
