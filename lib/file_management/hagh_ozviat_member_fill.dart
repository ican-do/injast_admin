import 'package:injast_admin/file_management/excel_import/excel_import_shenase.dart';
import 'package:injast_admin/file_management/hagh_ozviat_columns.dart';

/// پر کردن سلول‌های ادغام‌شده با مرز عضو (تغییر کدملی/نام = عضو جدید).
/// «کد صنفی» هرگز در کل فایل کش نمی‌شود — فقط در همان بلوک عضو.
class HaghOzviatMemberFill {
  HaghOzviatMemberFill._();

  static const _identityHeaders = [
    HaghOzviatColumns.codeMeli,
    'نام',
    'نام خانوادگی',
    'وضعیت پروانه',
    HaghOzviatColumns.onvanRaste,
    HaghOzviatColumns.radeSanfi,
  ];

  static List<({int rowIndex, Map<String, String> values})> forwardFillMerged(
    List<({int rowIndex, Map<String, String> values})> raw,
  ) {
    final out = <({int rowIndex, Map<String, String> values})>[];

    var blockMelli = '';
    var blockFirst = '';
    var blockFamily = '';
    var blockShenase = '';

    final lastIdentity = <String, String>{};

    for (final item in raw) {
      final filled = Map<String, String>.from(item.values);

      final explicitShenase = HaghOzviatColumns.readShenase(filled)?.trim() ?? '';
      final melli = HaghOzviatColumns.readMelli(filled);
      final first = HaghOzviatColumns.read(filled, 'نام');
      final family = HaghOzviatColumns.read(filled, 'نام خانوادگی');

      final hasNewIdentity = explicitShenase.isNotEmpty ||
          melli.isNotEmpty ||
          first.isNotEmpty ||
          family.isNotEmpty;

      var newBlock = false;
      if (hasNewIdentity) {
        if (explicitShenase.isNotEmpty &&
            blockShenase.isNotEmpty &&
            ExcelImportShenase.normalize(explicitShenase) !=
                ExcelImportShenase.normalize(blockShenase)) {
          newBlock = true;
        }
        if (melli.isNotEmpty && blockMelli.isNotEmpty && melli != blockMelli) {
          newBlock = true;
        }
        if (first.isNotEmpty && blockFirst.isNotEmpty && first != blockFirst) {
          newBlock = true;
        }
        if (family.isNotEmpty &&
            blockFamily.isNotEmpty &&
            family != blockFamily) {
          newBlock = true;
        }
        if (!newBlock &&
            blockShenase.isEmpty &&
            blockMelli.isEmpty &&
            blockFirst.isEmpty &&
            blockFamily.isEmpty) {
          newBlock = true;
        }
      }

      if (newBlock) {
        blockShenase = '';
        blockMelli = '';
        blockFirst = '';
        blockFamily = '';
        lastIdentity.clear();
      }

      if (explicitShenase.isNotEmpty) {
        blockShenase = explicitShenase;
        filled[HaghOzviatColumns.shenase] = explicitShenase;
      } else if (blockShenase.isNotEmpty) {
        filled[HaghOzviatColumns.shenase] = blockShenase;
      }

      if (melli.isNotEmpty) {
        blockMelli = melli;
      }
      if (first.isNotEmpty) blockFirst = first;
      if (family.isNotEmpty) blockFamily = family;

      for (final header in _identityHeaders) {
        final current = _readHeader(filled, header);
        if (current.isNotEmpty) {
          lastIdentity[header] = current;
          _writeHeader(filled, header, current);
        } else {
          final carried = lastIdentity[header];
          if (carried != null && carried.isNotEmpty) {
            _writeHeader(filled, header, carried);
          }
        }
      }

      out.add((rowIndex: item.rowIndex, values: filled));
    }
    return out;
  }

  static String _readHeader(Map<String, String> values, String header) {
    if (header == HaghOzviatColumns.codeMeli) {
      return HaghOzviatColumns.readMelli(values);
    }
    return HaghOzviatColumns.read(values, header);
  }

  static void _writeHeader(
    Map<String, String> values,
    String header,
    String value,
  ) {
    if (header == HaghOzviatColumns.codeMeli) {
      values[HaghOzviatColumns.codeMeli] = value;
      return;
    }
    values[header] = value;
  }
}
