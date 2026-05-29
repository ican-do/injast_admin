import 'dart:convert';
import 'dart:developer' show log;
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;
import 'package:flutter/services.dart' show AssetManifest, rootBundle;
import 'package:injast_admin/file_management/excel_import/excel_import_columns.dart';
import 'package:injast_admin/file_management/excel_import/excel_import_models.dart';
import 'package:injast_admin/file_management/xls_raw_table_reader.dart';
import 'package:path/path.dart' as p;

const _logName = 'excel_import';
const _scriptAsset = 'scripts/xls_to_import_json.py';
const _pydepsAssetPrefix = 'scripts/pydeps/';
const _pydepsDiskRelative = 'scripts/pydeps';

/// خواندن `.xls` با Python+xlrd (دقیقاً مثل Excel) روی دسکتاپ/موبایل native.
class XlsPythonBridge {
  static Directory? _cachedPydepsDir;

  /// خروجی خام جدول xls (کلید = همان عنوان ستون در فایل).
  static Future<List<({int rowIndex, Map<String, String> values})>> parseRawRows(
    Uint8List bytes,
  ) async {
    if (kIsWeb) {
      throw UnsupportedError(
        'ورود فایل .xls در نسخه وب پشتیبانی نمی‌شود.',
      );
    }

    List<({int rowIndex, Map<String, String> values})>? dartRows;
    try {
      dartRows = XlsRawTableReader.parseRows(bytes);
    } catch (e, st) {
      log('xls dart reader error: $e\n$st', name: _logName);
    }

    final pythonCmd = await _resolvePythonCommand();
    if (pythonCmd != null) {
      try {
        final pyRows = await _parseRawRowsViaPython(bytes, pythonCmd: pythonCmd);
        if (pyRows.isNotEmpty) {
          final dartCount = dartRows?.length ?? 0;
          if (dartCount == 0 || pyRows.length >= dartCount) {
            log(
              'xls parseRawRows via python | rows=${pyRows.length} '
              '(dart had $dartCount)',
              name: _logName,
            );
            return pyRows;
          }
        }
      } catch (e) {
        log('xls python parse failed: $e', name: _logName);
      }
    }

    if (dartRows != null && dartRows.isNotEmpty) {
      log(
        'xls parseRawRows via excel2003 (dart) | rows=${dartRows.length}',
        name: _logName,
      );
      return dartRows;
    }

    if (pythonCmd != null) {
      return _parseRawRowsViaPython(bytes, pythonCmd: pythonCmd);
    }

    throw Exception(
      'خواندن فایل .xls ممکن نشد. یک‌بار در پوشه پروژه اجرا کنید:\n'
      'tool/setup_xls_venv.sh\n'
      'سپس Hot Restart.\n'
      'یا فایل را در Excel با پسوند .xlsx ذخیره کنید.',
    );
  }

  static Future<List<({int rowIndex, Map<String, String> values})>>
      _parseRawRowsViaPython(
    Uint8List bytes, {
    String? pythonCmd,
  }) async {
    final tempDir = Directory.systemTemp.createTempSync('injast_xls_raw_');
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final xlsPath = p.join(tempDir.path, 'table_$stamp.xls');
    final scriptPath = await _materializeScript(tempDir.path);
    final pydepsPath = await _resolvePydepsPath(tempDir.path);
    final python = pythonCmd ?? await _resolvePython(pydepsPath);

    await File(xlsPath).writeAsBytes(bytes, flush: true);

    final env = <String, String>{};
    if (pydepsPath != null && pydepsPath.isNotEmpty) {
      env['PYTHONPATH'] = pydepsPath;
    }

    final result = await Process.run(
      python,
      [scriptPath, xlsPath],
      runInShell: false,
      environment: env.isEmpty ? null : env,
    );

    try {
      await File(xlsPath).delete();
      tempDir.deleteSync(recursive: true);
    } catch (_) {}

    final stdout = _decodeProcessOutput(result.stdout).trim();
    final stderr = _decodeProcessOutput(result.stderr).trim();

    if (stdout.isEmpty) {
      throw Exception(
        'پاسخی از مبدل xls دریافت نشد.'
        '${stderr.isNotEmpty ? '\n$stderr' : ''}',
      );
    }

    final decoded = jsonDecode(stdout);
    if (decoded is! Map || decoded['ok'] != true) {
      final err = decoded is Map
          ? decoded['error']?.toString().trim() ?? 'خطای نامشخص'
          : 'خروجی نامعتبر';
      throw Exception(err);
    }

    final rawRows = decoded['rows'];
    if (rawRows is! List) return const [];

    final out = <({int rowIndex, Map<String, String> values})>[];
    for (final item in rawRows) {
      if (item is! Map) continue;
      final rowIndex = int.tryParse('${item['row_index'] ?? 0}') ?? 0;
      final valuesRaw = item['values'];
      if (valuesRaw is! Map) continue;
      final values = <String, String>{};
      for (final entry in valuesRaw.entries) {
        final key = entry.key.toString().trim();
        if (key.isEmpty) continue;
        values[key] = entry.value?.toString().trim() ?? '';
      }
      if (values.isEmpty) continue;
      out.add((rowIndex: rowIndex, values: values));
    }
    return out;
  }

  static Future<List<ExcelParsedRow>> parse(Uint8List bytes) async {
    if (kIsWeb) {
      throw UnsupportedError(
        'ورود فایل .xls در نسخه وب پشتیبانی نمی‌شود. فایل را با Excel به .xlsx ذخیره کنید.',
      );
    }

    try {
      final raw = await parseRawRows(bytes);
      final out = <ExcelParsedRow>[];
      for (final item in raw) {
        final values = <String, String>{};
        for (final entry in item.values.entries) {
          final key = ExcelImportColumns.normalizeHeader(entry.key);
          if (key.isEmpty) continue;
          values[key] = entry.value;
        }
        if (values.isEmpty) continue;
        out.add(ExcelParsedRow(rowIndex: item.rowIndex, values: values));
      }
      if (out.isNotEmpty) {
        log('xls parse via dart+normalize | rows=${out.length}', name: _logName);
        return out;
      }
    } catch (e) {
      log('xls parse dart path failed, python fallback: $e', name: _logName);
    }

    final tempDir = Directory.systemTemp.createTempSync('injast_xls_import_');
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final xlsPath = p.join(tempDir.path, 'import_$stamp.xls');
    final scriptPath = await _materializeScript(tempDir.path);
    final pydepsPath = await _resolvePydepsPath(tempDir.path);
    final python = await _resolvePython(pydepsPath);

    await File(xlsPath).writeAsBytes(bytes, flush: true);

    log(
      'xls python bridge | python=$python | pydeps=$pydepsPath | file=$xlsPath',
      name: _logName,
    );

    final env = <String, String>{};
    if (pydepsPath != null && pydepsPath.isNotEmpty) {
      env['PYTHONPATH'] = pydepsPath;
    }

    final result = await Process.run(
      python,
      [scriptPath, xlsPath],
      runInShell: false,
      environment: env.isEmpty ? null : env,
    );

    try {
      await File(xlsPath).delete();
      tempDir.deleteSync(recursive: true);
    } catch (_) {}

    final stdout = _decodeProcessOutput(result.stdout).trim();
    final stderr = _decodeProcessOutput(result.stderr).trim();

    if (stdout.isEmpty) {
      throw Exception(
        'پاسخی از مبدل xls دریافت نشد.'
        '${stderr.isNotEmpty ? '\n$stderr' : ''}',
      );
    }

    final decoded = jsonDecode(stdout);
    if (decoded is! Map) {
      throw Exception('خروجی نامعتبر از مبدل xls.');
    }

    if (decoded['ok'] != true) {
      final err = decoded['error']?.toString().trim() ?? 'خطای نامشخص';
      throw Exception(err);
    }

    final rawRows = decoded['rows'];
    if (rawRows is! List) {
      return const [];
    }

    final out = <ExcelParsedRow>[];
    for (final item in rawRows) {
      if (item is! Map) continue;
      final rowIndex = int.tryParse('${item['row_index'] ?? 0}') ?? 0;
      final valuesRaw = item['values'];
      if (valuesRaw is! Map) continue;

      final values = <String, String>{};
      for (final entry in valuesRaw.entries) {
        final key = ExcelImportColumns.normalizeHeader(entry.key.toString());
        if (key.isEmpty) continue;
        values[key] = entry.value?.toString().trim() ?? '';
      }
      if (values.isEmpty) continue;
      out.add(ExcelParsedRow(rowIndex: rowIndex, values: values));
    }

    log('xls python bridge ok | rows=${out.length}', name: _logName);
    return out;
  }

  @visibleForTesting
  static Future<String?> discoverProjectRoot() async {
    for (final root in await _projectRoots()) {
      final venv = File(p.join(root, 'tool', 'xls_venv', 'bin', 'python3'));
      if (await venv.exists()) return root;
      final pydeps = Directory(p.join(root, _pydepsDiskRelative));
      if (await pydeps.exists()) return root;
    }
    return null;
  }

  static Future<String> _materializeScript(String tempDirPath) async {
    final dest = p.join(tempDirPath, 'xls_to_import_json.py');

    for (final candidate in await _scriptCandidates()) {
      final file = File(candidate);
      if (await file.exists()) {
        log('xls script from disk: $candidate', name: _logName);
        return file.path;
      }
    }

    try {
      final scriptBytes = await rootBundle.load(_scriptAsset);
      await File(dest).writeAsBytes(
        scriptBytes.buffer.asUint8List(
          scriptBytes.offsetInBytes,
          scriptBytes.lengthInBytes,
        ),
        flush: true,
      );
      log('xls script from asset bundle', name: _logName);
      return dest;
    } catch (e) {
      throw Exception(
        'اسکریپت تبدیل xls یافت نشد. پروژه را rebuild کنید یا فایل را xlsx ذخیره کنید.\n$e',
      );
    }
  }

  static Future<String?> _resolvePydepsPath(String tempDirPath) async {
    if (_cachedPydepsDir != null && await _cachedPydepsDir!.exists()) {
      return _cachedPydepsDir!.path;
    }

    for (final root in await _projectRoots()) {
      final onDisk = Directory(p.join(root, _pydepsDiskRelative));
      if (await onDisk.exists()) {
        _cachedPydepsDir = onDisk;
        log('xls pydeps from disk: ${onDisk.path}', name: _logName);
        return onDisk.path;
      }
    }

    try {
      final dir = await _materializePydepsFromAssets(tempDirPath);
      _cachedPydepsDir = dir;
      log('xls pydeps from asset bundle: ${dir.path}', name: _logName);
      return dir.path;
    } catch (e) {
      log('xls pydeps asset materialize failed: $e', name: _logName);
      return null;
    }
  }

  static Future<Directory> _materializePydepsFromAssets(
    String tempDirPath,
  ) async {
    final dest = Directory(p.join(tempDirPath, 'pydeps'));
    if (!await dest.exists()) {
      await dest.create(recursive: true);
    }

    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final keys = manifest
        .listAssets()
        .where((k) => k.startsWith(_pydepsAssetPrefix))
        .toList();
    if (keys.isEmpty) {
      throw Exception('xlrd در asset bundle نیست. tool/setup_xls_venv.sh را اجرا کنید.');
    }

    for (final assetKey in keys) {
      final relative = assetKey.substring(_pydepsAssetPrefix.length);
      if (relative.isEmpty) continue;
      final outFile = File(p.join(dest.path, relative));
      await outFile.parent.create(recursive: true);
      final data = await rootBundle.load(assetKey);
      await outFile.writeAsBytes(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        flush: true,
      );
    }
    return dest;
  }

  static String _decodeProcessOutput(dynamic raw) {
    if (raw == null) return '';
    if (raw is String) return raw;
    if (raw is List<int>) return utf8.decode(raw, allowMalformed: true);
    return raw.toString();
  }

  static Iterable<String> _ancestorDirs(String start) sync* {
    var dir = Directory(p.normalize(start));
    for (var i = 0; i < 16; i++) {
      yield dir.path;
      final parent = dir.parent;
      if (parent.path == dir.path) break;
      dir = parent;
    }
  }

  static String? _filePathFromUri(Uri uri) {
    if (uri.scheme != 'file') return null;
    return p.normalize(uri.toFilePath());
  }

  static Future<List<String>> _projectRoots() async {
    final roots = <String>{};
    final envRoot = Platform.environment['INJAST_ADMIN_ROOT']?.trim();
    if (envRoot != null && envRoot.isNotEmpty) {
      roots.add(p.normalize(envRoot));
    }

    final starts = <String>{
      Directory.current.path,
      File(Platform.resolvedExecutable).parent.path,
    };
    final scriptPath = _filePathFromUri(Platform.script);
    if (scriptPath != null) {
      starts.add(File(scriptPath).parent.path);
    }

    final packageConfig = Platform.packageConfig;
    if (packageConfig != null && packageConfig.isNotEmpty) {
      final pcUri = Uri.parse(packageConfig);
      if (pcUri.isAbsolute) {
        roots.add(
          p.normalize(p.join(File(pcUri.toFilePath()).parent.path, '..')),
        );
      } else {
        for (final start in starts) {
          for (final dir in _ancestorDirs(start)) {
            final candidate = File(p.join(dir, packageConfig));
            if (await candidate.exists()) {
              roots.add(p.normalize(p.join(candidate.parent.path, '..')));
              break;
            }
          }
        }
      }
    }

    for (final start in starts) {
      for (final dir in _ancestorDirs(start)) {
        final pubspec = File(p.join(dir, 'pubspec.yaml'));
        final venvPy = File(p.join(dir, 'tool', 'xls_venv', 'bin', 'python3'));
        final pydepsDir = Directory(p.join(dir, _pydepsDiskRelative));
        final hasPydeps = await pydepsDir.exists();
        final hasVenv = await venvPy.exists();
        final hasScript = await File(
          p.join(dir, 'scripts', 'xls_to_import_json.py'),
        ).exists();
        if (!hasPydeps && !hasVenv && !hasScript) continue;
        if (await pubspec.exists() || hasPydeps || hasVenv || hasScript) {
          roots.add(dir);
        }
      }
    }

    final list = roots.toList();
    if (list.isNotEmpty) {
      log('xls project roots: ${list.join(' | ')}', name: _logName);
    } else {
      log(
        'xls project root not found | cwd=${Directory.current.path} | '
        'exe=${Platform.resolvedExecutable}',
        name: _logName,
      );
    }
    return list;
  }

  static String _bundledVenvPython() {
    final exe = Platform.resolvedExecutable;
    return p.normalize(
      p.join(
        File(exe).parent.path,
        '..',
        'Resources',
        'tool',
        'xls_venv',
        'bin',
        'python3',
      ),
    );
  }

  static Future<List<String>> _scriptCandidates() async {
    final out = <String>[];
    for (final root in await _projectRoots()) {
      out.add(p.join(root, 'scripts', 'xls_to_import_json.py'));
    }
    final cwd = Directory.current.path;
    out.addAll([
      p.join(cwd, 'scripts', 'xls_to_import_json.py'),
      p.join(cwd, '..', 'scripts', 'xls_to_import_json.py'),
    ]);
    return out;
  }

  static Future<String?> _resolvePythonCommand() async {
    final pydeps = await _diskPydepsPath();
    for (final cmd in ['python3', 'python']) {
      if (await _pythonHasXlrd(cmd, pydepsPath: pydeps)) return cmd;
    }
    final cwdVenv =
        p.join(Directory.current.path, 'tool', 'xls_venv', 'bin', 'python3');
    if (await _pythonHasXlrd(cwdVenv)) return cwdVenv;
    for (final root in await _projectRoots()) {
      final venv = p.join(root, 'tool', 'xls_venv', 'bin', 'python3');
      if (await _pythonHasXlrd(venv)) return venv;
    }
    final bundled = _bundledVenvPython();
    if (await _pythonHasXlrd(bundled)) return bundled;
    return null;
  }

  static Future<String?> _diskPydepsPath() async {
    final cwd = Directory.current.path;
    final cwdPydeps = p.join(cwd, _pydepsDiskRelative);
    if (await Directory(cwdPydeps).exists()) return cwdPydeps;

    for (final root in await _projectRoots()) {
      final dir = p.join(root, _pydepsDiskRelative);
      if (await Directory(dir).exists()) return dir;
    }
    return null;
  }

  static Future<bool> _pythonHasXlrd(
    String cmd, {
    String? pydepsPath,
  }) async {
    try {
      if (cmd.contains(p.separator) && !await File(cmd).exists()) {
        return false;
      }
      final env = <String, String>{};
      if (pydepsPath != null && pydepsPath.isNotEmpty) {
        env['PYTHONPATH'] = pydepsPath;
      }
      final r = await Process.run(
        cmd,
        ['-c', 'import xlrd'],
        environment: env.isEmpty ? null : env,
      );
      return r.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  static Future<String> _resolvePython(String? pydepsPath) async {
    final resolved = await _resolvePythonCommand();
    if (resolved != null) {
      log('xls python resolved: $resolved', name: _logName);
      return resolved;
    }
    throw Exception(
      'Python 3 با xlrd یافت نشد.\n'
      'در پوشه پروژه اجرا کنید: tool/setup_xls_venv.sh\n'
      'سپس Hot Restart.\n'
      'یا فایل را با Excel به .xlsx ذخیره کنید.',
    );
  }
}
