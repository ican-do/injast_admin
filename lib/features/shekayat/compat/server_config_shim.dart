import 'package:injast_admin/server_config.dart';

/// URL فایل‌های استاتیک آپلودشده
String getStaticFileUrl(String filePath) {
  if (filePath.isEmpty) return '';
  if (filePath.startsWith('http://') || filePath.startsWith('https://')) {
    return filePath;
  }
  final path = filePath.startsWith('/') ? filePath : '/$filePath';
  return '$mediaOrigin$path';
}

String getShekayatInviteUrl(String codeCo) =>
    '$publicWebOrigin/#/Complaint/$codeCo';
