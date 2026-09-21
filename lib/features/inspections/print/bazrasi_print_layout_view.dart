import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:persian_fonts/persian_fonts.dart';

/// نمایش فرم بر اساس قالب JSON (A4/A5، فونت، مناطق و بایند فیلدها).
class BazrasiPrintLayoutView extends StatelessWidget {
  const BazrasiPrintLayoutView({
    super.key,
    required this.layout,
    required this.data,
    this.formatDate,
    this.fileUrl,
    this.maxFitWidth = 820,
  });

  final Map<String, dynamic> layout;
  final Map<String, dynamic> data;
  final String Function(dynamic value)? formatDate;
  final String Function(String path)? fileUrl;
  final double maxFitWidth;

  @override
  Widget build(BuildContext context) {
    final spec = _PrintSpec.parse(layout);
    return LayoutBuilder(
      builder: (context, c) {
        final avail = c.maxWidth.isFinite && c.maxWidth > 0
            ? c.maxWidth
            : maxFitWidth;
        final fit = math.min(avail, maxFitWidth) / 210.0;
        final pageW = spec.widthMm * fit;
        final pageH = spec.heightMm * fit;
        final scale = _Scale(mmUnit: fit, ptUnit: fit * 25.4 / 72.0);
        final ctx = _PrintCtx(
          spec: spec,
          data: data,
          scale: scale,
          formatDate: formatDate,
          fileUrl: fileUrl,
        );
        return Center(
          child: Container(
            width: pageW,
            constraints: BoxConstraints(minHeight: pageH),
            decoration: BoxDecoration(
              color: spec.bg,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: DefaultTextStyle(
                style: PersianFonts.Shabnam.copyWith(
                  fontSize: scale.pt(spec.basePt),
                  height: spec.lineHeight,
                  color: spec.ink,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        scale.mm(spec.marginL),
                        scale.mm(spec.marginT),
                        scale.mm(spec.marginR),
                        scale.mm(4),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final region in spec.bodyRegions) ...[
                            _region(ctx, region),
                            SizedBox(height: scale.mm(spec.gapMm)),
                          ],
                        ],
                      ),
                    ),
                    if (spec.footer != null) _region(ctx, spec.footer!),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Scale {
  const _Scale({required this.mmUnit, required this.ptUnit});
  final double mmUnit;
  final double ptUnit;
  double mm(num n) => n * mmUnit;
  double pt(num n) => n * ptUnit;
}

class _PrintSpec {
  _PrintSpec({
    required this.widthMm,
    required this.heightMm,
    required this.marginT,
    required this.marginR,
    required this.marginB,
    required this.marginL,
    required this.basePt,
    required this.lineHeight,
    required this.gapMm,
    required this.ink,
    required this.bg,
    required this.colors,
    required this.bodyRegions,
    this.footer,
  });

  final double widthMm;
  final double heightMm;
  final double marginT;
  final double marginR;
  final double marginB;
  final double marginL;
  final double basePt;
  final double lineHeight;
  final double gapMm;
  final Color ink;
  final Color bg;
  final Map<String, Color> colors;
  final List<Map<String, dynamic>> bodyRegions;
  final Map<String, dynamic>? footer;

  static _PrintSpec parse(Map<String, dynamic> layout) {
    final meta = _map(layout['meta']);
    final canvas = _map(layout['canvas']);
    final size = _map(canvas['size']);
    final margin = _map(canvas['safe_margin_mm']);
    final tokens = _map(layout['tokens']);
    final colorTok = _map(tokens['color']);
    final pageHint =
        '${layout['paper'] ?? meta['page'] ?? ''}'.toUpperCase();
    var w = _num(size['width_mm'], 0);
    var h = _num(size['height_mm'], 0);
    if (w <= 0 || h <= 0) {
      if (pageHint.contains('A5')) {
        w = 148;
        h = 210;
      } else {
        w = 210;
        h = 297;
      }
    }
    final colors = <String, Color>{};
    colorTok.forEach((k, v) {
      final c = _color(v);
      if (c != null) colors[k] = c;
    });
    final regions = (_list(_map(layout['layout'])['regions']))
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    Map<String, dynamic>? footer;
    final body = <Map<String, dynamic>>[];
    for (final r in regions) {
      if (_str(r['type']).contains('footer')) {
        footer = r;
      } else {
        body.add(r);
      }
    }
    return _PrintSpec(
      widthMm: w,
      heightMm: h,
      marginT: _num(margin['top'], 12),
      marginR: _num(margin['right'], 14),
      marginB: _num(margin['bottom'], 10),
      marginL: _num(margin['left'], 14),
      basePt: _num(canvas['base_font_size_pt'], 11),
      lineHeight: _num(canvas['line_height'], 1.55),
      gapMm: _num(_map(layout['layout'])['gap_mm'], 5),
      ink: _color(canvas['text_color']) ?? const Color(0xFF1A1A1A),
      bg: _color(canvas['background']) ?? Colors.white,
      colors: colors,
      bodyRegions: body,
      footer: footer,
    );
  }
}

class _PrintCtx {
  _PrintCtx({
    required this.spec,
    required this.data,
    required this.scale,
    this.formatDate,
    this.fileUrl,
  });

  final _PrintSpec spec;
  final Map<String, dynamic> data;
  final _Scale scale;
  final String Function(dynamic value)? formatDate;
  final String Function(String path)? fileUrl;

  Color color(dynamic key, Color fallback) {
    if (key is Color) return key;
    final s = _str(key);
    if (s.startsWith('#')) return _color(s) ?? fallback;
    return spec.colors[s] ?? fallback;
  }

  Map<String, dynamic> get parvande => _map(data['parvande']);

  String text(dynamic v) => _str(v);

  String date(dynamic v) {
    if (formatDate != null) return formatDate!(v);
    final s = _str(v);
    return s.length >= 10 ? s.substring(0, 10) : s;
  }

  String resolve(Map<String, dynamic> node, {String fallback = ''}) {
    final bind = _str(node['bind']).isEmpty ? _str(node['source']) : _str(node['bind']);
    final role = _str(node['role']);
    final id = _str(node['id']);
    final fieldId = _str(node['field_id']);
    if (bind.isNotEmpty) {
      final fromBind = _byBind(bind);
      if (fromBind.isNotEmpty) return fromBind;
    }
    if (fieldId.isNotEmpty) {
      final v = _itemValue(fieldId);
      if (v.isNotEmpty) return v;
    }
    if (role.isNotEmpty) {
      final v = _byRole(role);
      if (v.isNotEmpty) return v;
    }
    switch (id) {
      case 'doc_no':
      case 'f_doc_no':
        return _str(parvande['num_parvande_store']);
      case 'doc_date':
        return date(data['created_at']);
      case 'doc_title_badge':
        return _str(data['form_name']);
      case 'addr':
        return _str(data['union_address']);
      case 'phone':
        return _str(data['union_tel']);
      case 'whatsapp':
        return _str(data['union_mobile']);
      case 'website':
        return 'WWW.INJAST-WEB.IR';
    }
    final ph = _str(
      node['placeholder'] ??
          _map(node['text'])['placeholder'] ??
          node['label'] ??
          node['label_placeholder'] ??
          node['placeholder_label'],
    );
    if (fallback.isNotEmpty) return fallback;
    if (_isSamplePlaceholder(ph)) return '';
    return ph;
  }

  bool _isSamplePlaceholder(String s) {
    return s.contains('نمونه') ||
        s.contains('قابل تعویض') ||
        s.contains('placeholder') ||
        s.contains('EXAMPLE');
  }

  String _byBind(String bind) {
    switch (bind) {
      case 'form_name':
        return _str(data['form_name']);
      case 'union_name':
        return _str(data['union_name']);
      case 'inspector_name':
        return _str(data['inspector_name']);
      case 'created_at':
        return date(data['created_at']);
      case 'doc_no':
        return _str(parvande['num_parvande_store']);
    }
    if (bind.startsWith('parvande.')) {
      return _str(parvande[bind.substring(9)]);
    }
    if (bind.startsWith('field:')) {
      return _itemValue(bind.substring(6));
    }
    final fromItem = _itemValue(bind);
    if (fromItem.isNotEmpty) return fromItem;
    return _str(data[bind]);
  }

  String _byRole(String role) {
    final p = parvande;
    switch (role) {
      case 'addressee_name':
        return '${_str(p['name_admin'])} ${_str(p['family_admin'])}'.trim();
      case 'unit_title':
        return _str(p['name_store']);
      case 'location':
        return _str(p['address_store']);
      case 'phone':
        final t = _str(p['tel_admin']);
        final m = _str(p['mob_admin']);
        if (t.isNotEmpty && m.isNotEmpty && t != m) return '$t / $m';
        return t.isNotEmpty ? t : m;
      case 'national_id':
        return _str(p['code_meli_admin']);
      case 'postal_code':
        return _str(p['code_posti_store']);
    }
    return '';
  }

  String _itemValue(String id) {
    for (final raw in _list(data['items'])) {
      if (raw is! Map) continue;
      if (_str(raw['id']) != id) continue;
      return _stringify(raw['value']);
    }
    for (final raw in _list(data['fields'])) {
      if (raw is! Map) continue;
      if (_str(raw['id']) == id || _str(raw['title']) == id) {
        return _stringify(raw['value']);
      }
    }
    return '';
  }

  String _stringify(dynamic v) {
    if (v == null) return '';
    if (v is bool) return v ? 'بله' : 'خیر';
    if (v is List) {
      return v
          .whereType<Map>()
          .where((e) => e['selected'] == true || e['checked'] == true)
          .map((e) => _str(e['label'] ?? e['title']))
          .where((e) => e.isNotEmpty)
          .join(' | ');
    }
    return _str(v);
  }

  List<_TableRow> tableRows(Map<String, dynamic> region) {
    final bind = _str(region['bind']).isEmpty
        ? _str(_map(region['table'])['bind'])
        : _str(region['bind']);
    final items = _list(data['items']);
    Map? chosen;
    for (final raw in items) {
      if (raw is! Map) continue;
      final type = _str(raw['type']);
      if (bind.isNotEmpty && _str(raw['id']) == bind) {
        chosen = raw;
        break;
      }
      if (chosen == null &&
          (type == 'tableSelect' || type == 'checkboxGroup')) {
        chosen = raw;
      }
    }
    final out = <_TableRow>[];
    if (chosen != null && chosen['value'] is List) {
      var i = 1;
      for (final o in chosen['value'] as List) {
        if (o is! Map) continue;
        final lab = _str(o['label'] ?? o['title'] ?? o['id']);
        if (lab.isEmpty) continue;
        final no = _str(o['rowNo']).isEmpty ? '$i' : _str(o['rowNo']);
        out.add(
          _TableRow(
            no,
            lab,
            o['selected'] == true ||
                o['checked'] == true ||
                o['value'] == true,
          ),
        );
        i++;
      }
    }
    if (out.isEmpty) {
      var i = 1;
      for (final raw in items) {
        if (raw is! Map) continue;
        if (_str(raw['type']) != 'checkbox') continue;
        out.add(
          _TableRow(
            '$i',
            _str(raw['title']),
            raw['value'] == true || _str(raw['value']) == 'بله',
          ),
        );
        i++;
      }
    }
    return out;
  }

  String notes() {
    for (final raw in _list(data['items'])) {
      if (raw is! Map) continue;
      if (_str(raw['id']) == 'std_notes' ||
          _str(raw['type']) == 'longText') {
        final v = _str(raw['value']);
        if (v.isNotEmpty) return v;
      }
    }
    return '';
  }

  String sigUrl() {
    final p = _str(data['signature_png_path']);
    if (p.isEmpty) return '';
    return fileUrl?.call(p) ?? p;
  }
}

class _TableRow {
  _TableRow(this.no, this.title, this.checked);
  final String no;
  final String title;
  final bool checked;
}

Widget _region(_PrintCtx ctx, Map<String, dynamic> region) {
  final type = _str(region['type']);
  if (type.contains('footer')) return _Footer(ctx: ctx, region: region);
  if (type.contains('table')) return _Reasons(ctx: ctx, region: region);
  if (type == 'static_centered_caption') {
    return Text(
      ctx.resolve(region, fallback: 'بسمه تعالی'),
      textAlign: TextAlign.center,
      style: PersianFonts.Shabnam.copyWith(
        fontSize: ctx.scale.pt(_num(region['font_size_pt'], 10)),
        color: ctx.spec.colors['muted'] ?? const Color(0xFF4A4A4A),
      ),
    );
  }
  if (type == 'justified_static_paragraph') {
    final fromField = ctx._firstStaticBody();
    final text = fromField.isNotEmpty
        ? fromField
        : ctx.resolve(region, fallback: _defaultBody);
    return Text(
      text,
      textAlign: TextAlign.justify,
      style: PersianFonts.Shabnam.copyWith(
        fontSize: ctx.scale.pt(_num(region['font_size_pt'], ctx.spec.basePt)),
        height: ctx.spec.lineHeight,
        color: ctx.spec.ink,
      ),
    );
  }
  if (type == 'label_plus_ruled_lines') {
    return _Notes(ctx: ctx, region: region);
  }
  if (type == 'two_column_row' && _str(region['id']) == 'signatures') {
    return _Signs(ctx: ctx, region: region);
  }
  if (type == 'two_column_row') {
    return _DeliveryRow(ctx: ctx, region: region);
  }
  if (type == 'rounded_card' || type.contains('header')) {
    return _HeaderCard(ctx: ctx, region: region);
  }
  return const SizedBox.shrink();
}

extension on _PrintCtx {
  String _firstStaticBody() {
    for (final raw in _list(data['form_fields'])) {
      if (raw is! Map) continue;
      if (_str(raw['type']) == 'staticText' && _str(raw['body']).isNotEmpty) {
        return _str(raw['body']);
      }
    }
    return '';
  }
}

const _defaultBody =
    'بدین‌وسیله به اطلاع می‌رساند واحد صنفی فوق مورد بازرسی قرار گرفت و موارد مشروحه در جدول زیر احراز گردید.';

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.ctx, required this.region});
  final _PrintCtx ctx;
  final Map<String, dynamic> region;

  @override
  Widget build(BuildContext context) {
    final children = _list(region['children']).whereType<Map>();
    Map<String, dynamic> top = {};
    Map<String, dynamic> grid = {};
    for (final c in children) {
      final m = Map<String, dynamic>.from(c);
      final t = _str(m['type']);
      if (t.contains('three_column') || _str(m['id']) == 'header_top_row') {
        top = m;
      }
      if (t.contains('field_grid') || _str(m['id']) == 'identity_grid') {
        grid = m;
      }
    }
    final pad = _map(region['padding_mm']);
    return Container(
      padding: EdgeInsets.fromLTRB(
        ctx.scale.mm(_num(pad['left'], 10)),
        ctx.scale.mm(_num(pad['top'], 8)),
        ctx.scale.mm(_num(pad['right'], 10)),
        ctx.scale.mm(_num(pad['bottom'], 10)),
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: ctx.color('card_border', const Color(0xFF6E7F7F)),
          width: 1.2,
        ),
      ),
      child: Column(
        children: [
          _headerTop(top),
          SizedBox(height: ctx.scale.mm(10)),
          _identity(grid),
        ],
      ),
    );
  }

  Widget _headerTop(Map<String, dynamic> top) {
    final cols = _list(top['columns']).whereType<Map>().toList();
    Map<String, dynamic> left = {};
    Map<String, dynamic> center = {};
    for (final c in cols) {
      final m = Map<String, dynamic>.from(c);
      final side = '${m['visual_side'] ?? m['slot'] ?? ''}';
      if (side.contains('left') || side.contains('start')) {
        left = m;
      } else if (side.contains('center')) {
        center = m;
      }
    }
    final titleNode = center.isEmpty ? top : center;
    final titleText = _map(titleNode['text']);
    final title = ctx.resolve(
      {
        ...titleNode,
        'bind': titleNode['bind'] ?? 'form_name',
        'id': 'doc_title_badge',
      },
      fallback: ctx.text(ctx.data['form_name']),
    );
    final union = ctx.text(ctx.data['union_name']);
    final parts = union.split(' ');
    final line1 = parts.isEmpty ? union : parts.first;
    final line2 = parts.length <= 1 ? '' : parts.sublist(1).join(' ');
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 22,
          child: Column(
            children: [
              for (final it in _list(left['items']).whereType<Map>())
                Padding(
                  padding: EdgeInsets.only(bottom: ctx.scale.mm(3)),
                  child: _Dotted(
                    ctx: ctx,
                    label: _str(it['label'] ?? it['id']),
                    value: ctx.resolve(Map<String, dynamic>.from(it)),
                    pt: 11,
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          flex: 46,
          child: Center(
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: ctx.scale.mm(10),
                vertical: ctx.scale.mm(3),
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: ctx.color('title_badge_border', const Color(0xFFC44A3A)),
                  width: 1.4,
                ),
              ),
              child: Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: PersianFonts.Shabnam.copyWith(
                  fontSize: ctx.scale.pt(_num(titleText['font_size_pt'], 16)),
                  fontWeight: FontWeight.w700,
                  color: ctx.color('title_red', const Color(0xFFC0392B)),
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
                        fontSize: ctx.scale.pt(9),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (line2.isNotEmpty)
                      Text(
                        line2,
                        textAlign: TextAlign.right,
                        style: PersianFonts.Shabnam.copyWith(
                          fontSize: ctx.scale.pt(8),
                          color: ctx.spec.colors['muted'] ??
                              const Color(0xFF4A4A4A),
                        ),
                      ),
                  ],
                ),
              ),
              SizedBox(width: ctx.scale.mm(3)),
              Container(
                width: ctx.scale.mm(16),
                height: ctx.scale.mm(16),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: ctx.color('logo_ring', const Color(0xFF2B6CB0)),
                  ),
                ),
                child: Icon(
                  Icons.account_balance,
                  size: ctx.scale.mm(8),
                  color: ctx.color('logo_ring', const Color(0xFF2B6CB0)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _identity(Map<String, dynamic> grid) {
    final cols = _map(grid['columns']);
    final right = _list(_map(cols['right'])['fields']).whereType<Map>().toList();
    final left = _list(_map(cols['left'])['fields']).whereType<Map>().toList();
    final n = math.max(right.length, left.length);
    if (n == 0) {
      return Column(
        children: [
          _idPair('مخاطب', ctx._byRole('addressee_name'), 'نام واحد / تابلو',
              ctx._byRole('unit_title')),
          SizedBox(height: ctx.scale.mm(6)),
          _idPair('نشانی / واقع در', ctx._byRole('location'), 'کد ملی',
              ctx._byRole('national_id')),
          SizedBox(height: ctx.scale.mm(6)),
          _idPair('تلفن', ctx._byRole('phone'), 'کد پستی',
              ctx._byRole('postal_code')),
        ],
      );
    }
    return Column(
      children: [
        for (var i = 0; i < n; i++) ...[
          if (i > 0) SizedBox(height: ctx.scale.mm(6)),
          Row(
            children: [
              Expanded(
                child: i < right.length
                    ? _Dotted(
                        ctx: ctx,
                        label: _str(
                          right[i]['placeholder_label'] ?? right[i]['label'],
                        ),
                        value: ctx.resolve(Map<String, dynamic>.from(right[i])),
                        pt: 11,
                      )
                    : const SizedBox.shrink(),
              ),
              SizedBox(width: ctx.scale.mm(18)),
              Expanded(
                child: i < left.length
                    ? _Dotted(
                        ctx: ctx,
                        label: _str(
                          left[i]['placeholder_label'] ?? left[i]['label'],
                        ),
                        value: ctx.resolve(Map<String, dynamic>.from(left[i])),
                        pt: 11,
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _idPair(String a, String av, String b, String bv) {
    return Row(
      children: [
        Expanded(child: _Dotted(ctx: ctx, label: a, value: av, pt: 11)),
        SizedBox(width: ctx.scale.mm(18)),
        Expanded(child: _Dotted(ctx: ctx, label: b, value: bv, pt: 11)),
      ],
    );
  }
}

class _Dotted extends StatelessWidget {
  const _Dotted({
    required this.ctx,
    required this.label,
    required this.value,
    required this.pt,
    this.suffix = '',
  });

  final _PrintCtx ctx;
  final String label;
  final String value;
  final double pt;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label.isEmpty ? '' : '$label : ',
          style: PersianFonts.Shabnam.copyWith(
            fontSize: ctx.scale.pt(pt),
            color: ctx.spec.ink,
          ),
        ),
        Expanded(
          child: CustomPaint(
            painter: _DotPainter(
              ctx.color('dotted_line', const Color(0xFF9AA3A3)),
            ),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 2, right: 4),
              child: Text(
                value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: PersianFonts.Shabnam.copyWith(
                  fontSize: ctx.scale.pt(pt),
                  color: ctx.spec.ink,
                ),
              ),
            ),
          ),
        ),
        if (suffix.isNotEmpty)
          Text(
            ' $suffix',
            style: PersianFonts.Shabnam.copyWith(fontSize: ctx.scale.pt(pt)),
          ),
      ],
    );
  }
}

class _DotPainter extends CustomPainter {
  _DotPainter(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    const dash = 2.0;
    const gap = 2.2;
    var x = 0.0;
    final y = size.height - 1;
    final p = Paint()
      ..color = color
      ..strokeWidth = 0.8;
    while (x < size.width) {
      canvas.drawLine(Offset(x, y), Offset(math.min(x + dash, size.width), y), p);
      x += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _Reasons extends StatelessWidget {
  const _Reasons({required this.ctx, required this.region});
  final _PrintCtx ctx;
  final Map<String, dynamic> region;

  @override
  Widget build(BuildContext context) {
    final table = _map(region['table']);
    final cols = _list(table['columns']).whereType<Map>().toList();
    final rows = ctx.tableRows(region);
    final shown = rows.isEmpty ? [_TableRow('1', 'موردی ثبت نشده است', false)] : rows;
    String hTitle = ctx.text(ctx.data['form_name']);
    if (cols.length > 1) {
      final mid = Map<String, dynamic>.from(cols[1]);
      final t = ctx.resolve(mid);
      if (t.isNotEmpty) hTitle = t;
    }
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: ctx.color('card_border', const Color(0xFF6E7F7F)),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Table(
        border: TableBorder(
          horizontalInside: BorderSide(
            color: ctx.color('table_grid', const Color(0xFFB8C0C0)),
            width: 0.6,
          ),
          verticalInside: BorderSide(
            color: ctx.color('table_grid', const Color(0xFFB8C0C0)),
            width: 0.6,
          ),
        ),
        columnWidths: const {
          0: FlexColumnWidth(1.1),
          1: FlexColumnWidth(7.2),
          2: FlexColumnWidth(1.7),
        },
        children: [
          TableRow(
            decoration: BoxDecoration(
              color: ctx.color('table_header_fill', const Color(0xFFE8A05A)),
            ),
            children: [
              _th('ردیف'),
              _th(hTitle.isEmpty ? 'موارد بازرسی' : hTitle),
              _th(''),
            ],
          ),
          for (final r in shown)
            TableRow(
              children: [
                _td(r.no),
                _td(r.title),
                Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: ctx.scale.mm(1.6)),
                    child: Container(
                      width: ctx.scale.mm(4.5),
                      height: ctx.scale.mm(4.5),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(2),
                        border: Border.all(color: const Color(0xFF5A5A5A)),
                      ),
                      child: r.checked
                          ? Icon(Icons.check, size: ctx.scale.mm(3.6), color: ctx.spec.ink)
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
        padding: EdgeInsets.symmetric(
          vertical: ctx.scale.mm(2.2),
          horizontal: ctx.scale.mm(2),
        ),
        child: Text(
          t,
          textAlign: TextAlign.center,
          style: PersianFonts.Shabnam.copyWith(
            fontSize: ctx.scale.pt(12),
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      );

  Widget _td(String t) => Padding(
        padding: EdgeInsets.symmetric(
          vertical: ctx.scale.mm(1.8),
          horizontal: ctx.scale.mm(2),
        ),
        child: Text(
          t,
          textAlign: TextAlign.center,
          style: PersianFonts.Shabnam.copyWith(
            fontSize: ctx.scale.pt(10.5),
            color: ctx.spec.ink,
          ),
        ),
      );
}

class _Notes extends StatelessWidget {
  const _Notes({required this.ctx, required this.region});
  final _PrintCtx ctx;
  final Map<String, dynamic> region;

  @override
  Widget build(BuildContext context) {
    final label = _map(region['label']);
    final lines = _map(region['lines']);
    final count = _num(lines['count'], 4).round();
    final notes = ctx.notes();
    return Column(
      children: [
        for (var i = 0; i < count; i++)
          Padding(
            padding: EdgeInsets.only(top: i == 0 ? 0 : ctx.scale.mm(6)),
            child: i == 0
                ? _Dotted(
                    ctx: ctx,
                    label: _str(label['placeholder'] ?? 'توضیحات'),
                    value: notes,
                    pt: _num(label['font_size_pt'], 11),
                  )
                : CustomPaint(
                    painter: _DotPainter(
                      ctx.color('dotted_line', const Color(0xFF9AA3A3)),
                    ),
                    child: SizedBox(height: ctx.scale.mm(5), width: double.infinity),
                  ),
          ),
      ],
    );
  }
}

class _DeliveryRow extends StatelessWidget {
  const _DeliveryRow({required this.ctx, required this.region});
  final _PrintCtx ctx;
  final Map<String, dynamic> region;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 4,
          child: _Dotted(
            ctx: ctx,
            label: 'کد بازرس',
            value: ctx.text(ctx.data['inspector_name']),
            pt: 11,
          ),
        ),
        SizedBox(width: ctx.scale.mm(6)),
        Expanded(
          flex: 6,
          child: _Dotted(
            ctx: ctx,
            label: 'اصل برگ تحویل',
            value: ctx._byRole('addressee_name'),
            pt: 11,
            suffix: 'گردید',
          ),
        ),
      ],
    );
  }
}

class _Signs extends StatelessWidget {
  const _Signs({required this.ctx, required this.region});
  final _PrintCtx ctx;
  final Map<String, dynamic> region;

  @override
  Widget build(BuildContext context) {
    final url = ctx.sigUrl();
    return Padding(
      padding: EdgeInsets.only(top: ctx.scale.mm(8)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              children: [
                SizedBox(height: ctx.scale.mm(14)),
                Text(
                  'امضاء بازرس',
                  style: PersianFonts.Shabnam.copyWith(fontSize: ctx.scale.pt(11)),
                ),
                Text(
                  ctx.text(ctx.data['inspector_name']),
                  style: PersianFonts.Shabnam.copyWith(
                    fontSize: ctx.scale.pt(9),
                    color: ctx.spec.colors['muted'] ?? const Color(0xFF4A4A4A),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              children: [
                SizedBox(
                  height: ctx.scale.mm(18),
                  child: url.isEmpty
                      ? const SizedBox.shrink()
                      : Image.network(url, fit: BoxFit.contain),
                ),
                Text(
                  'امضاء',
                  style: PersianFonts.Shabnam.copyWith(fontSize: ctx.scale.pt(11)),
                ),
                Text(
                  ctx._byRole('addressee_name'),
                  style: PersianFonts.Shabnam.copyWith(
                    fontSize: ctx.scale.pt(9),
                    color: ctx.spec.colors['muted'] ?? const Color(0xFF4A4A4A),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.ctx, required this.region});
  final _PrintCtx ctx;
  final Map<String, dynamic> region;

  @override
  Widget build(BuildContext context) {
    final h = ctx.scale.mm(_num(region['height_mm'], 28));
    return SizedBox(
      height: h,
      width: double.infinity,
      child: CustomPaint(
        painter: _WavePainter(ctx.color('footer_band', const Color(0xFF2E9B8C))),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            ctx.scale.mm(12),
            ctx.scale.mm(10),
            ctx.scale.mm(12),
            ctx.scale.mm(4),
          ),
          child: DefaultTextStyle(
            style: PersianFonts.Shabnam.copyWith(
              fontSize: ctx.scale.pt(_num(region['font_size_pt'], 8.5)),
              color: Colors.white,
              height: 1.4,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (ctx.text(ctx.data['union_address']).isNotEmpty)
                        Text(ctx.text(ctx.data['union_address']), maxLines: 2),
                      if (ctx.text(ctx.data['union_tel']).isNotEmpty)
                        Text('تلفن: ${ctx.text(ctx.data['union_tel'])}'),
                      if (ctx.text(ctx.data['union_mobile']).isNotEmpty)
                        Text('واتساپ: ${ctx.text(ctx.data['union_mobile'])}'),
                    ],
                  ),
                ),
                const Text(
                  'WWW.INJAST-WEB.IR',
                  style: TextStyle(color: Colors.white, letterSpacing: 0.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  _WavePainter(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 18)
      ..quadraticBezierTo(size.width * 0.22, 2, size.width * 0.48, 14)
      ..quadraticBezierTo(size.width * 0.78, 28, size.width, 6)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

Map<String, dynamic> _map(dynamic v) {
  if (v is Map<String, dynamic>) return v;
  if (v is Map) return Map<String, dynamic>.from(v);
  return {};
}

List<dynamic> _list(dynamic v) => v is List ? v : const [];

String _str(dynamic v) => (v ?? '').toString().trim();

double _num(dynamic v, double d) {
  if (v is num) return v.toDouble();
  return double.tryParse('$v') ?? d;
}

Color? _color(dynamic v) {
  final s = _str(v).replaceAll('#', '');
  if (s.length == 6) {
    return Color(int.parse('FF$s', radix: 16));
  }
  if (s.length == 8) {
    return Color(int.parse(s, radix: 16));
  }
  return null;
}
