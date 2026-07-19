import 'dart:math';

import 'package:shamsi_date/shamsi_date.dart';

String create_new_code() {
  final now = DateTime.now();
  final timestamp = now.microsecondsSinceEpoch;
  final random = Random().nextInt(900) + 100 + timestamp;
  final s = random.toString();
  return s.substring(s.length - 10);
}

String convert_shamsi_to_miladi(String persianDate) {
  try {
    persianDate = persianDate.replaceAll('/', '-');
    final dateParts = persianDate.split('-').map(int.parse).toList();
    final j = Jalali(dateParts[0], dateParts[1], dateParts[2]);
    final g = j.toGregorian();
    return '${g.year}-${g.month}-${g.day}';
  } catch (_) {
    return '';
  }
}

String convert_date_persian2(DateTime date_) {
  final g2 = Gregorian(date_.year, date_.month, date_.day);
  final j3 = g2.toJalali();
  final f = j3.formatter;
  return '${f.yyyy}/${f.mm}/${f.dd}';
}

String convert_date_persian(DateTime date_) {
  try {
    final g2 = Gregorian(date_.year, date_.month, date_.day);
    final j3 = g2.toJalali();
    final f = j3.formatter;
    return '${f.wN} ${f.d} ${f.mN} ${f.y}';
  } catch (_) {
    return '';
  }
}

List filterListByFields(
  List list,
  List<String> fieldNames,
  String query,
) {
  final q = query.toLowerCase();
  return list
      .where((item) => fieldNames.any((fieldName) =>
          item[fieldName]?.toString().toLowerCase().contains(q) ?? false))
      .toList();
}
