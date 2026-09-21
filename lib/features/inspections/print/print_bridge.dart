import 'package:injast_admin/file_management/jalali_date_util.dart';

export 'package:injast_admin/server_config.dart' show getStaticFileUrl;

String bazrasiJalali(dynamic value) {
  if (value == null) return '';
  if (value is DateTime) return JalaliDateUtil.formatFromDateTime(value);
  final shown = JalaliDateUtil.serverToDisplay(value.toString());
  return shown.isEmpty ? value.toString() : shown;
}
