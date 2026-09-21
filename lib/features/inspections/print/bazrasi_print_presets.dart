import 'package:flutter/material.dart';

class BazrasiPrintPreset {
  const BazrasiPrintPreset({
    required this.id,
    required this.templateKey,
    required this.name,
    required this.subtitle,
    required this.icon,
  });

  final String id;
  final String templateKey;
  final String name;
  final String subtitle;
  final IconData icon;
}

class BazrasiPrintPresets {
  static const pasini = BazrasiPrintPreset(
    id: 'pasini',
    templateKey: 'tpl_pasini',
    name: 'بازدید پسینی',
    subtitle: 'مدارک، مشخصات واحد و نتیجه بازدید',
    icon: Icons.fact_check_outlined,
  );
  static const eblagh = BazrasiPrintPreset(
    id: 'eblagh_15',
    templateKey: 'tpl_eblagh_15',
    name: 'ابلاغیه ۱۵ روزه',
    subtitle: 'نامه رسمی با مهلت مراجعه',
    icon: Icons.mail_outline_rounded,
  );
  static const advary = BazrasiPrintPreset(
    id: 'advary',
    templateKey: 'tpl_advary',
    name: 'بازرسی ادواری',
    subtitle: 'چک‌لیست شماره‌دار وضعیت پروانه',
    icon: Icons.assignment_outlined,
  );
  static const ekhtar = BazrasiPrintPreset(
    id: 'ekhtar_plomp',
    templateKey: 'tpl_ekhtar_plomp',
    name: 'اخطار قبل از پلمپ',
    subtitle: 'جدول دلایل و مهلت ۴۸ ساعت',
    icon: Icons.warning_amber_rounded,
  );

  static const all = [pasini, eblagh, advary, ekhtar];

  static BazrasiPrintPreset? byId(String? id) {
    final k = (id ?? '').trim();
    if (k.isEmpty) return null;
    for (final p in all) {
      if (p.id == k || p.templateKey == k) return p;
    }
    return null;
  }

  static Map<String, dynamic> layoutOf(String presetId, {String paper = 'A4'}) {
    final p = byId(presetId);
    return {
      'preset': p?.id ?? presetId,
      'paper': paper == 'A5' ? 'A5' : 'A4',
    };
  }

  static String resolveId(Map<String, dynamic> data) {
    final pl = data['print_layout'];
    if (pl is Map) {
      final preset = '${pl['preset'] ?? pl['template'] ?? ''}'.trim();
      final hit = byId(preset);
      if (hit != null) return hit.id;
    }
    final key = '${data['template_key'] ?? ''}'.trim();
    final fromKey = byId(key)?.id ?? '';
    if (fromKey.isNotEmpty) return fromKey;
    final name = '${data['form_name'] ?? ''}';
    if (name.contains('پسینی')) return pasini.id;
    if (name.contains('ابلاغ')) return eblagh.id;
    if (name.contains('ادوار')) return advary.id;
    if (name.contains('اخطار') || name.contains('پلمپ')) return ekhtar.id;
    return '';
  }

  static String resolvePaper(Map<String, dynamic> data) {
    final pl = data['print_layout'];
    if (pl is Map) {
      final paper = '${pl['paper'] ?? pl['page'] ?? ''}'.toUpperCase();
      if (paper.contains('A5')) return 'A5';
    }
    return 'A4';
  }
}
