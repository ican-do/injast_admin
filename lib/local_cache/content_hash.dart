import 'dart:convert';

import 'package:crypto/crypto.dart';

/// هش محتوای payload برای تشخیص بروزرسانی (بدون فیلدهای داخلی موقت).
String computePayloadContentHash(Map<String, String> payload) {
  final keys = payload.keys.where((k) => !k.startsWith('_')).toList()..sort();
  final buf = StringBuffer();
  for (final k in keys) {
    buf.write('$k=${payload[k] ?? ''}|');
  }
  return md5.convert(utf8.encode(buf.toString())).toString();
}
