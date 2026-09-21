import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:injast_admin/features/inspections/print/bazrasi_print_presets.dart';
import 'package:injast_admin/features/inspections/print/print_bridge.dart';
import 'package:persian_fonts/persian_fonts.dart';

/// نمایش فرم طبق یکی از ۴ قالب آماده + اندازه A4 یا A5.
class BazrasiPresetPrintSheet extends StatelessWidget {
  const BazrasiPresetPrintSheet({
    super.key,
    required this.data,
    this.formatDate,
    this.fileUrl,
  });

  final Map<String, dynamic> data;
  final String Function(dynamic value)? formatDate;
  final String Function(String path)? fileUrl;

  @override
  Widget build(BuildContext context) {
    final preset = BazrasiPrintPresets.resolveId(data);
    final paper = BazrasiPrintPresets.resolvePaper(data);
    final wMm = paper == 'A5' ? 148.0 : 210.0;
    final hMm = paper == 'A5' ? 210.0 : 297.0;
    return LayoutBuilder(
      builder: (context, c) {
        final avail =
            c.maxWidth.isFinite && c.maxWidth > 0 ? c.maxWidth : 820.0;
        final fit = math.min(avail, 820.0) / 210.0;
        final pageW = wMm * fit;
        final ctx = _PCtx(
          data: data,
          uMm: fit,
          uPt: fit * 25.4 / 72.0,
          paper: paper,
          formatDate: formatDate ?? bazrasiJalali,
          fileUrl: fileUrl ?? getStaticFileUrl,
        );
        return Center(
          child: Container(
            width: pageW,
            constraints: BoxConstraints(minHeight: hMm * fit),
            color: Colors.white,
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  ctx.mm(paper == 'A5' ? 8 : 12),
                  ctx.mm(8),
                  ctx.mm(paper == 'A5' ? 8 : 12),
                  ctx.mm(8),
                ),
                child: switch (preset) {
                  'pasini' => _PasiniPage(ctx: ctx),
                  'eblagh_15' => _EblaghPage(ctx: ctx),
                  'advary' => _AdvaryPage(ctx: ctx),
                  _ => _EkhtarPage(ctx: ctx),
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PCtx {
  _PCtx({
    required this.data,
    required this.uMm,
    required this.uPt,
    required this.paper,
    required this.formatDate,
    required this.fileUrl,
  });

  final Map<String, dynamic> data;
  final double uMm;
  final double uPt;
  final String paper;

  double mm(num n) => n * uMm;
  final String Function(dynamic value) formatDate;
  final String Function(String path) fileUrl;

  Map<String, dynamic> get p =>
      Map<String, dynamic>.from(data['parvande'] as Map? ?? {});

  String t(dynamic v) => (v ?? '').toString().trim();

  String date(dynamic v) => formatDate(v);

  String get union => t(data['union_name']).isEmpty
      ? 'اتحادیه صنفی'
      : t(data['union_name']);

  String get formName => t(data['form_name']);
  String get inspector => t(data['inspector_name']);
  String get created => date(data['created_at']);

  String person() => '${t(p['name_admin'])} ${t(p['family_admin'])}'.trim();

  String phone() {
    final a = t(p['tel_admin']);
    final b = t(p['mob_admin']);
    if (a.isNotEmpty && b.isNotEmpty && a != b) return '$a / $b';
    return a.isNotEmpty ? a : b;
  }

  String field(String needle, {String parvandeKey = ''}) {
    for (final raw in (data['items'] as List?) ?? []) {
      if (raw is! Map) continue;
      if (t(raw['title']).contains(needle)) {
        final v = _val(raw['value']);
        if (v.isNotEmpty) return v;
      }
    }
    if (parvandeKey.isNotEmpty) return t(p[parvandeKey]);
    return '';
  }

  String staticBody(String needle) {
    for (final raw in (data['form_fields'] as List?) ?? []) {
      if (raw is! Map) continue;
      if (t(raw['title']).contains(needle) || t(raw['type']) == 'staticText') {
        final b = t(raw['body']);
        if (b.isNotEmpty && t(raw['title']).contains(needle)) return b;
      }
    }
    return '';
  }

  List<_Opt> opts(String needle) {
    for (final raw in (data['items'] as List?) ?? []) {
      if (raw is! Map) continue;
      if (!t(raw['title']).contains(needle)) continue;
      final v = raw['value'];
      if (v is List) return _optsFrom(v);
    }
    for (final raw in (data['form_fields'] as List?) ?? []) {
      if (raw is! Map) continue;
      if (!t(raw['title']).contains(needle)) continue;
      return _optsFrom(raw['options']);
    }
    return [];
  }

  List<_Opt> tableRows() {
    for (final raw in (data['items'] as List?) ?? []) {
      if (raw is! Map) continue;
      final type = t(raw['type']);
      if (type == 'tableSelect' || t(raw['title']).contains('دلایل')) {
        final rows = _optsFrom(raw['value']);
        if (rows.isNotEmpty) return rows;
      }
    }
    for (final raw in (data['form_fields'] as List?) ?? []) {
      if (raw is! Map) continue;
      if (t(raw['type']) == 'tableSelect') {
        return _optsFrom(raw['options']);
      }
    }
    return [];
  }

  List<_Opt> _optsFrom(dynamic v) {
    final out = <_Opt>[];
    if (v is! List) return out;
    var i = 1;
    for (final o in v) {
      if (o is! Map) continue;
      final lab = t(o['label'] ?? o['title'] ?? o['id']);
      if (lab.isEmpty) continue;
      out.add(
        _Opt(
          t(o['rowNo']).isEmpty ? '$i' : t(o['rowNo']),
          lab,
          o['selected'] == true || o['checked'] == true || o['value'] == true,
        ),
      );
      i++;
    }
    return out;
  }

  String _val(dynamic v) {
    if (v == null) return '';
    if (v is bool) return v ? 'بله' : 'خیر';
    if (v is List) {
      return v
          .whereType<Map>()
          .where((e) => e['selected'] == true || e['checked'] == true)
          .map((e) => t(e['label'] ?? e['title']))
          .where((e) => e.isNotEmpty)
          .join('، ');
    }
    return t(v);
  }

  String sig() {
    final pth = t(data['signature_png_path']);
    return pth.isEmpty ? '' : fileUrl(pth);
  }

  TextStyle st(double size, {FontWeight w = FontWeight.w400, Color? c}) {
    return PersianFonts.Shabnam.copyWith(
      fontSize: uPt * size,
      fontWeight: w,
      color: c ?? const Color(0xFF1A1A1A),
      height: 1.45,
    );
  }
}

class _Opt {
  _Opt(this.no, this.label, this.on);
  final String no;
  final String label;
  final bool on;
}

class _EkhtarPage extends StatelessWidget {
  const _EkhtarPage({required this.ctx});
  final _PCtx ctx;

  @override
  Widget build(BuildContext context) {
    final rows = ctx.tableRows();
    final shown = rows.isEmpty
        ? [
            _Opt('1', 'افتتاح واحد کسبی بدون مجوز', false),
            _Opt('2', 'عدم اعتبار پروانه کسب', false),
            _Opt('3', 'عدم حضور در محل کسب', false),
            _Opt('4', 'تداخل شغلی', false),
            _Opt('5', 'نداشتن نرخنامه', false),
            _Opt('6', 'حراج یا فروش فوق‌العاده بدون مجوز', false),
            _Opt('7', 'عدم پرداخت حق عضویت', false),
            _Opt('8', 'عدم اجرای دستورات اتحادیه', false),
            _Opt('9', 'عدم صدور فاکتور معتبر', false),
            _Opt('10', 'تبلیغ خلاف واقع', false),
            _Opt('11', 'عدم همکاری با بازرس', false),
            _Opt('15', 'انجام تعمیرات بدون مجوز', false),
          ]
        : rows;
    final legal = ctx.staticBody('اخطار').isEmpty
        ? 'احتراماً نظر به اینکه واحد صنفی شما دارای یکی از تخلفات به شرح ذیل بوده لذا لازم است ظرف ۴۸ ساعت از تاریخ دریافت ابلاغیه به‌منظور تعیین تکلیف به اتحادیه مراجعه فرمایید. در غیر این صورت وفق مواد ۲۷ یا ۲۸ قانون نظام صنفی واحد صنفی پلمپ می‌گردد.'
        : ctx.staticBody('اخطار');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('بسمه تعالی', textAlign: TextAlign.center, style: ctx.st(10)),
        SizedBox(height: ctx.mm(3)),
        Container(
          padding: EdgeInsets.all(ctx.mm(4)),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFF6E7F7F)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    flex: 22,
                    child: Column(
                      children: [
                        _dot(ctx, 'شماره', ctx.field('شماره', parvandeKey: 'num_parvande_store')),
                        SizedBox(height: ctx.mm(2)),
                        _dot(ctx, 'تاریخ', ctx.field('تاریخ').isEmpty ? ctx.created : ctx.field('تاریخ')),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 46,
                    child: Center(
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: ctx.mm(6),
                          vertical: ctx.mm(2),
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFC44A3A)),
                        ),
                        child: Text(
                          ctx.formName.isEmpty ? 'اخطار قبل از پلمپ' : ctx.formName,
                          textAlign: TextAlign.center,
                          style: ctx.st(14, w: FontWeight.w700, c: const Color(0xFFC0392B)),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 32,
                    child: Text(
                      ctx.union,
                      textAlign: TextAlign.left,
                      style: ctx.st(8, w: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              SizedBox(height: ctx.mm(4)),
              _pair(ctx, 'همکار گرامی', ctx.field('همکار', parvandeKey: '') .isEmpty ? ctx.person() : ctx.field('همکار'),
                  'واحد صنفی (نام تابلو)', ctx.field('تابلو', parvandeKey: 'name_store')),
              SizedBox(height: ctx.mm(2)),
              _pair(ctx, 'واقع در', ctx.field('واقع', parvandeKey: 'address_store'),
                  'کد ملی', ctx.field('کد ملی', parvandeKey: 'code_meli_admin')),
              SizedBox(height: ctx.mm(2)),
              _pair(ctx, 'تلفن ثابت یا همراه', ctx.field('تلفن', parvandeKey: '').isEmpty ? ctx.phone() : ctx.field('تلفن'),
                  'کد پستی', ctx.field('کد پستی', parvandeKey: 'code_posti_store')),
            ],
          ),
        ),
        SizedBox(height: ctx.mm(3)),
        Text(legal, textAlign: TextAlign.justify, style: ctx.st(10)),
        SizedBox(height: ctx.mm(3)),
        _table(ctx, shown, 'دلایل اخطار'),
        SizedBox(height: ctx.mm(4)),
        _dot(ctx, 'توضیحات', ctx.field('توضیح')),
        SizedBox(height: ctx.mm(2)),
        _dot(ctx, '', ''),
        SizedBox(height: ctx.mm(3)),
        Row(
          children: [
            Expanded(child: _dot(ctx, 'کد بازرس', ctx.field('کد بازرس').isEmpty ? ctx.inspector : ctx.field('کد بازرس'))),
            SizedBox(width: ctx.mm(4)),
            Expanded(
              child: _dot(
                ctx,
                'اصل ابلاغیه تحویل',
                ctx.field('تحویل').isEmpty ? ctx.person() : ctx.field('تحویل'),
                suffix: 'گردید',
              ),
            ),
          ],
        ),
        SizedBox(height: ctx.mm(8)),
        Row(
          children: [
            Expanded(child: Text('امضاء بازرس', textAlign: TextAlign.center, style: ctx.st(11))),
            Expanded(
              child: Column(
                children: [
                  if (ctx.sig().isNotEmpty)
                    SizedBox(height: ctx.mm(16), child: Image.network(ctx.sig())),
                  Text('امضاء', textAlign: TextAlign.center, style: ctx.st(11)),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: ctx.mm(6)),
        Container(
          padding: EdgeInsets.all(ctx.mm(3)),
          color: const Color(0xFF2E9B8C),
          child: DefaultTextStyle(
            style: ctx.st(8, c: Colors.white),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (ctx.t(ctx.data['union_address']).isNotEmpty)
                  Text(ctx.t(ctx.data['union_address'])),
                Text(
                  [
                    if (ctx.t(ctx.data['union_tel']).isNotEmpty)
                      'تلفن: ${ctx.t(ctx.data['union_tel'])}',
                    if (ctx.t(ctx.data['union_mobile']).isNotEmpty)
                      'واتساپ: ${ctx.t(ctx.data['union_mobile'])}',
                  ].join('   '),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _EblaghPage extends StatelessWidget {
  const _EblaghPage({required this.ctx});
  final _PCtx ctx;

  @override
  Widget build(BuildContext context) {
    final body = ctx.staticBody('ابلاغ').isEmpty
        ? 'با احترام پیرو بازرسی به‌عمل آمده از واحد صنفی جنابعالی مشاهده گردید که از تاریخ مندرج فاقد هرگونه فعالیت می‌باشید؛ لذا حداکثر ظرف مدت ۱۵ روز به شما فرصت داده می‌شود که جهت تعیین تکلیف به اتحادیه مراجعه نمایید. در غیر این‌صورت پروانه کسب شما مطابق تبصره ۵ ماده ۱۲ قانون نظام صنفی باطل خواهد شد.'
        : ctx.staticBody('ابلاغ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Spacer(),
            Expanded(
              child: Text(ctx.union, textAlign: TextAlign.left, style: ctx.st(9, w: FontWeight.w700)),
            ),
            Container(
              width: ctx.mm(14),
              height: ctx.mm(14),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.black54),
              ),
            ),
          ],
        ),
        SizedBox(height: ctx.mm(6)),
        Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            width: ctx.mm(50),
            child: Column(
              children: [
                _dot(ctx, 'شماره', ctx.field('شماره', parvandeKey: 'num_parvande_store')),
                SizedBox(height: ctx.mm(2)),
                _dot(ctx, 'تاریخ', ctx.field('تاریخ').isEmpty ? ctx.created : ctx.field('تاریخ')),
              ],
            ),
          ),
        ),
        SizedBox(height: ctx.mm(8)),
        Center(
          child: Container(
            width: ctx.mm(90),
            padding: EdgeInsets.symmetric(vertical: ctx.mm(3)),
            decoration: BoxDecoration(
              border: Border.symmetric(
                horizontal: BorderSide(color: Colors.grey.shade800, width: 1.2),
              ),
            ),
            child: Text(
              ctx.formName.isEmpty ? 'ابلاغیه ۱۵ روزه' : ctx.formName,
              textAlign: TextAlign.center,
              style: ctx.st(16, w: FontWeight.w700),
            ),
          ),
        ),
        SizedBox(height: ctx.mm(10)),
        _dot(ctx, 'آقا / خانم', ctx.field('آقا').isEmpty ? ctx.person() : ctx.field('آقا')),
        SizedBox(height: ctx.mm(3)),
        _dot(ctx, 'متصدی محترم فروشگاه / شرکت', ctx.field('متصدی', parvandeKey: 'name_store')),
        SizedBox(height: ctx.mm(3)),
        _dot(ctx, 'به نشانی', ctx.field('نشانی', parvandeKey: 'address_store')),
        SizedBox(height: ctx.mm(8)),
        Text('با سلام', style: ctx.st(12)),
        SizedBox(height: ctx.mm(3)),
        Text(body, textAlign: TextAlign.justify, style: ctx.st(11)),
        SizedBox(height: ctx.mm(10)),
        Text('با تقدیم احترام', textAlign: TextAlign.center, style: ctx.st(11)),
        Text(ctx.union, textAlign: TextAlign.center, style: ctx.st(10, w: FontWeight.w700)),
        SizedBox(height: ctx.mm(16)),
        Row(
          children: [
            Expanded(
              child: Column(
                children: [
                  if (ctx.sig().isNotEmpty)
                    SizedBox(height: ctx.mm(18), child: Image.network(ctx.sig())),
                  Text('نام و امضاء تحویل‌گیرنده', style: ctx.st(10)),
                ],
              ),
            ),
            Expanded(
              child: Text(
                'نام و امضاء بازرس\n${ctx.inspector}',
                textAlign: TextAlign.center,
                style: ctx.st(10),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PasiniPage extends StatelessWidget {
  const _PasiniPage({required this.ctx});
  final _PCtx ctx;

  @override
  Widget build(BuildContext context) {
    var docs = ctx.opts('مدارک');
    if (docs.isEmpty) {
      docs = [
        'شناسنامه',
        'کارت ملی',
        'کارت پایان خدمت / معافیت',
        'سند مالکیت / اجاره‌نامه',
        'گواهی آموزش عمومی',
        'تخصصی',
        'مدرک تحصیلی',
        'مدرک فنی و حرفه‌ای',
        'رضایت شریک',
        'گواهی مالیاتی ماده ۱۸۶',
        'عکس',
        'کارت بهداشت فردی',
      ].map((e) => _Opt('', e, false)).toList();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          ctx.formName.isEmpty ? '(فرم بازدید پسینی از واحد صنفی)' : '(${ctx.formName})',
          textAlign: TextAlign.center,
          style: ctx.st(13, w: FontWeight.w700),
        ),
        SizedBox(height: ctx.mm(4)),
        _dot(ctx, 'مدارک ارائه شده توسط آقای / خانم', ctx.field('مدارک ارائه')),
        Text(
          'حسب بخشنامه‌های صادره می‌بایست اصل مدارک بارگذاری و چنانچه مغایرتی مشاهده نشود، ذیلاً درج گردد:',
          style: ctx.st(9),
        ),
        SizedBox(height: ctx.mm(2)),
        Wrap(
          spacing: ctx.mm(4),
          runSpacing: ctx.mm(1.5),
          children: [
            for (final d in docs)
              SizedBox(
                width: ctx.mm(ctx.paper == 'A5' ? 40 : 58),
                child: _chk(ctx, d.label, d.on),
              ),
          ],
        ),
        SizedBox(height: ctx.mm(2)),
        _dot(ctx, 'مغایرت‌ها', ctx.field('مغایرت')),
        SizedBox(height: ctx.mm(5)),
        Row(
          children: [
            Expanded(child: _dot(ctx, 'جناب آقای / خانم', ctx.field('جناب').isEmpty ? ctx.person() : ctx.field('جناب'))),
            Expanded(child: Text('بازرس اتحادیه', textAlign: TextAlign.center, style: ctx.st(10))),
          ],
        ),
        Text('سلام علیکم', style: ctx.st(10)),
        Text(
          'احتراماً خواهشمند است از واحد صنفی ذیل بازدید و نتیجه را اعلام فرمائید.',
          style: ctx.st(10),
        ),
        SizedBox(height: ctx.mm(2)),
        _pair(ctx, 'به تصدی آقای / خانم', ctx.field('تصدی').isEmpty ? ctx.person() : ctx.field('تصدی'),
            'در رسته', ctx.field('رسته', parvandeKey: 'raste_store')),
        SizedBox(height: ctx.mm(2)),
        _pair(ctx, 'کد پستی', ctx.field('کد پستی', parvandeKey: 'code_posti_store'),
            'تلفن همراه', ctx.field('همراه').isEmpty ? ctx.phone() : ctx.field('همراه')),
        SizedBox(height: ctx.mm(2)),
        _pair(ctx, 'واقع در', ctx.field('واقع', parvandeKey: 'address_store'),
            'نام تابلو', ctx.field('تابلو', parvandeKey: 'name_store')),
        SizedBox(height: ctx.mm(2)),
        _pair(ctx, 'تاریخ پروانه کسب صادر شده', ctx.field('پروانه'),
            'شماره', ctx.field('شماره', parvandeKey: 'num_parvande_store')),
        SizedBox(height: ctx.mm(6)),
        Align(
          alignment: Alignment.centerLeft,
          child: Text('رئیس اتحادیه', style: ctx.st(10)),
        ),
        SizedBox(height: ctx.mm(4)),
        Text('ریاست محترم اتحادیه صنف', style: ctx.st(10, w: FontWeight.w700)),
        Text('سلام علیکم', style: ctx.st(10)),
        Text(
          'احتراماً به استحضار می‌رساند در تاریخ ${ctx.field('تاریخ اعلام').isEmpty ? ctx.created : ctx.field('تاریخ اعلام')} از واحد صنفی فوق بازدید و مراتب به شرح ذیل اعلام می‌گردد.',
          textAlign: TextAlign.justify,
          style: ctx.st(10),
        ),
        SizedBox(height: ctx.mm(2)),
        _pair(ctx, 'مساحت مفید', ctx.field('مساحت'), 'متر مربع در طبقه', ctx.field('طبقه')),
        SizedBox(height: ctx.mm(2)),
        Row(
          children: [
            Expanded(child: _dot(ctx, 'شماره کنتور آب', ctx.field('کنتور آب'))),
            Expanded(child: _dot(ctx, 'برق', ctx.field('کنتور برق'))),
            Expanded(child: _dot(ctx, 'گاز', ctx.field('کنتور گاز'))),
            Expanded(child: _dot(ctx, 'کد پستی رؤیت شده', ctx.field('رؤیت'))),
          ],
        ),
        SizedBox(height: ctx.mm(3)),
        _dot(ctx, 'توضیحات بازرسی و موارد ابلاغ', ctx.field('موارد ابلاغ').isEmpty ? ctx.field('توضیحات بازرسی') : ctx.field('موارد ابلاغ')),
        SizedBox(height: ctx.mm(5)),
        Text(
          'توضیحاتی در خصوص شرایط و ضوابط اتحادیه (به‌طور مثال نرخنامه و ...) و در صورت کسر مدارک اسقاط شرایط به نامبرده ابلاغ و رسید دریافت شود.',
          style: ctx.st(9),
        ),
        _dot(ctx, 'شرح', ctx.field('ضوابط')),
        SizedBox(height: ctx.mm(6)),
        Container(
          height: ctx.mm(22),
          decoration: BoxDecoration(border: Border.all(color: Colors.black54)),
          alignment: Alignment.bottomCenter,
          padding: EdgeInsets.all(ctx.mm(2)),
          child: ctx.sig().isEmpty
              ? Text('امضاء متصدی واحد صنفی', style: ctx.st(10))
              : Image.network(ctx.sig(), fit: BoxFit.contain),
        ),
      ],
    );
  }
}

class _AdvaryPage extends StatelessWidget {
  const _AdvaryPage({required this.ctx});
  final _PCtx ctx;

  @override
  Widget build(BuildContext context) {
    final lines = <Widget>[];
    final items = (ctx.data['items'] as List?) ?? [];
    final fields = (ctx.data['form_fields'] as List?) ?? [];
    final source = items.isNotEmpty ? items : fields;
    var n = 0;
    for (final raw in source) {
      if (raw is! Map) continue;
      final type = ctx.t(raw['type']);
      final title = ctx.t(raw['title']);
      if (type != 'checkboxGroup' && type != 'radioGroup' && type != 'tableSelect') {
        continue;
      }
      n++;
      final opts = ctx._optsFrom(raw['value'] ?? raw['options']);
      lines.add(
        Padding(
          padding: EdgeInsets.only(bottom: ctx.mm(1.2)),
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('$n- $title  ', style: ctx.st(9, w: FontWeight.w600)),
              for (final o in opts) ...[
                _chk(ctx, o.label, o.on),
                SizedBox(width: ctx.mm(3)),
              ],
            ],
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          ctx.formName.isEmpty ? 'گزارش بازرسی ادواری' : ctx.formName,
          textAlign: TextAlign.center,
          style: ctx.st(14, w: FontWeight.w700),
        ),
        SizedBox(height: ctx.mm(3)),
        _pair(ctx, 'احتراماً اینجانب', ctx.inspector.isEmpty ? ctx.field('بازرس') : ctx.inspector,
            'بازرس عضو کمیسیون بازرسی اتحادیه صنف', ctx.union),
        SizedBox(height: ctx.mm(2)),
        _pair(ctx, 'از واحد صنفی', ctx.field('واحد صنفی', parvandeKey: 'name_store'),
            'به نشانی', ctx.field('نشانی', parvandeKey: 'address_store')),
        SizedBox(height: ctx.mm(2)),
        _pair(ctx, 'تلفن', ctx.field('تلفن').isEmpty ? ctx.phone() : ctx.field('تلفن'),
            'کد پستی', ctx.field('کد پستی', parvandeKey: 'code_posti_store')),
        SizedBox(height: ctx.mm(2)),
        _pair(ctx, 'متصدی آقای / خانم', ctx.field('متصدی').isEmpty ? ctx.person() : ctx.field('متصدی'),
            'در تاریخ', ctx.field('تاریخ').isEmpty ? ctx.created : ctx.field('تاریخ')),
        Text(
          'بازدید به‌عمل آورده که نتیجه زیر به‌منظور اطلاع و هرگونه اقدام مقتضی تقدیم می‌گردد.',
          style: ctx.st(9),
        ),
        Divider(height: ctx.mm(4), color: Colors.black54),
        ...lines,
        SizedBox(height: ctx.mm(3)),
        Container(
          padding: EdgeInsets.all(ctx.mm(2)),
          decoration: BoxDecoration(border: Border.all(color: Colors.black45)),
          child: _dot(ctx, 'توضیحات', ctx.field('توضیحات')),
        ),
        SizedBox(height: ctx.mm(4)),
        Row(
          children: [
            Expanded(child: Text('محل امضاء بازرس\n${ctx.inspector}', textAlign: TextAlign.center, style: ctx.st(9))),
            Expanded(
              child: Column(
                children: [
                  if (ctx.sig().isNotEmpty)
                    SizedBox(height: ctx.mm(14), child: Image.network(ctx.sig())),
                  Text('محل مهر و امضاء متصدی واحد صنفی', textAlign: TextAlign.center, style: ctx.st(9)),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: ctx.mm(3)),
        Container(
          padding: EdgeInsets.all(ctx.mm(2)),
          decoration: BoxDecoration(border: Border.all(color: Colors.black45)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('ثبت دفتر کمیسیون بازرسی', style: ctx.st(9, w: FontWeight.w700)),
              _pair(ctx, 'شماره', ctx.field('شماره ثبت'), 'تاریخ', ctx.field('تاریخ ثبت')),
            ],
          ),
        ),
      ],
    );
  }
}

Widget _dot(_PCtx ctx, String label, String value, {String suffix = ''}) {
  return Row(
    children: [
      if (label.isNotEmpty)
        Text('$label : ', style: ctx.st(10)),
      Expanded(
        child: Container(
          padding: const EdgeInsets.only(bottom: 2),
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Color(0xFF9AA3A3), width: 0.7),
            ),
          ),
          child: Text(value, maxLines: 2, overflow: TextOverflow.ellipsis, style: ctx.st(10)),
        ),
      ),
      if (suffix.isNotEmpty) Text(' $suffix', style: ctx.st(10)),
    ],
  );
}

Widget _pair(_PCtx ctx, String a, String av, String b, String bv) {
  return Row(
    children: [
      Expanded(child: _dot(ctx, a, av)),
      SizedBox(width: ctx.mm(6)),
      Expanded(child: _dot(ctx, b, bv)),
    ],
  );
}

Widget _chk(_PCtx ctx, String label, bool on) {
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: ctx.mm(3.6),
        height: ctx.mm(3.6),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.black87),
        ),
        child: on ? Icon(Icons.check, size: ctx.mm(3)) : null,
      ),
      SizedBox(width: ctx.mm(1.2)),
      Flexible(child: Text(label, style: ctx.st(9))),
    ],
  );
}

Widget _table(_PCtx ctx, List<_Opt> rows, String title) {
  return Container(
    decoration: BoxDecoration(
      border: Border.all(color: const Color(0xFF6E7F7F)),
      borderRadius: BorderRadius.circular(10),
    ),
    clipBehavior: Clip.antiAlias,
    child: Table(
      columnWidths: const {
        0: FlexColumnWidth(1.2),
        1: FlexColumnWidth(7.2),
        2: FlexColumnWidth(1.6),
      },
      border: const TableBorder(
        horizontalInside: BorderSide(color: Color(0xFFB8C0C0), width: 0.6),
        verticalInside: BorderSide(color: Color(0xFFB8C0C0), width: 0.6),
      ),
      children: [
        TableRow(
          decoration: const BoxDecoration(color: Color(0xFFE8A05A)),
          children: [
            _th(ctx, 'ردیف'),
            _th(ctx, title),
            _th(ctx, ''),
          ],
        ),
        for (final r in rows)
          TableRow(
            children: [
              Padding(
                padding: EdgeInsets.symmetric(vertical: ctx.mm(1.4)),
                child: Text(r.no, textAlign: TextAlign.center, style: ctx.st(10)),
              ),
              Padding(
                padding: EdgeInsets.symmetric(vertical: ctx.mm(1.4), horizontal: ctx.mm(2)),
                child: Text(r.label, textAlign: TextAlign.center, style: ctx.st(10)),
              ),
              Center(
                child: Container(
                  width: ctx.mm(4.2),
                  height: ctx.mm(4.2),
                  margin: EdgeInsets.symmetric(vertical: ctx.mm(1)),
                  decoration: BoxDecoration(border: Border.all(color: Colors.black54)),
                  child: r.on ? Icon(Icons.check, size: ctx.mm(3.2)) : null,
                ),
              ),
            ],
          ),
      ],
    ),
  );
}

Widget _th(_PCtx ctx, String t) => Padding(
      padding: EdgeInsets.symmetric(vertical: ctx.mm(2)),
      child: Text(
        t,
        textAlign: TextAlign.center,
        style: ctx.st(11, w: FontWeight.w700, c: Colors.white),
      ),
    );
