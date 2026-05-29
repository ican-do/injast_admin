import 'dart:convert';
import 'dart:developer' show log;
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show rootBundle;
import 'package:injast_admin/file_management/excel_import/xls_python_bridge.dart';
import 'package:path/path.dart' as p;

const _logName = 'hagh_ozviat_csv';
const _scriptAsset = 'scripts/xls_to_csv.py';

/// تبدیل XLS به CSV با Python+xlrd (سلول ادغام → یک مقدار در هر ردیف).
class HaghOzviatXlsToCsvBridge {
  HaghOzviatXlsToCsvBridge._();

  static Future<Uint8List?> convert(Uint8List xlsBytes) async {
    if (kIsWeb) return null;

    final pythonCmd = await XlsPythonBridge.discoverProjectRoot() != null ||
            await _resolvePython() != null
        ? await _resolvePython()
        : null;
    if (pythonCmd == null) return null;

    final tempDir = Directory.systemTemp.createTempSync('injast_xls_csv_');
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final xlsPath = p.join(tempDir.path, 'in_$stamp.xls');
    final scriptPath = await _materializeScript(tempDir.path);

    try {
      await File(xlsPath).writeAsBytes(xlsBytes, flush: true);

      String? pydepsPath;
      final projectRoot = await XlsPythonBridge.discoverProjectRoot();
      if (projectRoot != null) {
        final onDisk = Directory(p.join(projectRoot, 'scripts', 'pydeps'));
        if (await onDisk.exists()) pydepsPath = onDisk.path;
      }

      final env = <String, String>{};
      if (pydepsPath != null && pydepsPath.isNotEmpty) {
        env['PYTHONPATH'] = pydepsPath;
      }

      final result = await Process.run(
        pythonCmd,
        [scriptPath, xlsPath],
        runInShell: false,
        environment: env.isEmpty ? null : env,
      );

      if (result.exitCode != 0) {
        log(
          'xls_to_csv failed: ${_decode(result.stderr)}',
          name: _logName,
        );
        return null;
      }

      final out = result.stdout;
      if (out is List<int>) {
        if (out.isEmpty) return null;
        log('xls_to_csv ok | bytes=${out.length}', name: _logName);
        return Uint8List.fromList(out);
      }
      final text = out.toString();
      if (text.isEmpty) return null;
      return Uint8List.fromList(utf8.encode(text));
    } catch (e, st) {
      log('xls_to_csv error: $e\n$st', name: _logName);
      return null;
    } finally {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    }
  }

  static Future<String?> _resolvePython() async {
    try {
      final r = await Process.run('python3', ['--version']);
      if (r.exitCode == 0) return 'python3';
    } catch (_) {}
    try {
      final r = await Process.run('python', ['--version']);
      if (r.exitCode == 0) return 'python';
    } catch (_) {}
    return null;
  }

  static Future<String> _materializeScript(String tempDirPath) async {
    final dest = p.join(tempDirPath, 'xls_to_csv.py');
    final projectRoot = await XlsPythonBridge.discoverProjectRoot();
    if (projectRoot != null) {
      final onDisk = p.join(projectRoot, 'scripts', 'xls_to_csv.py');
      if (await File(onDisk).exists()) return onDisk;
    }
    final scriptBytes = await rootBundle.load(_scriptAsset);
    await File(dest).writeAsBytes(
      scriptBytes.buffer.asUint8List(
        scriptBytes.offsetInBytes,
        scriptBytes.lengthInBytes,
      ),
      flush: true,
    );
    return dest;
  }

  static String _decode(dynamic bytes) {
    if (bytes is List<int>) {
      return utf8.decode(bytes, allowMalformed: true);
    }
    return bytes?.toString() ?? '';
  }
}
