import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:injast_admin/file_management/excel_import/xls_python_bridge.dart';
import 'package:path/path.dart' as p;

void main() {
  test('discovers project root with bundled pydeps', () async {
    final root = await XlsPythonBridge.discoverProjectRoot();
    expect(root, isNotNull);
    expect(
      Directory(p.join(root!, 'scripts', 'pydeps')).existsSync(),
      isTrue,
    );
  });
}
