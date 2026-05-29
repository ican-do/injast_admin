import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// مسیرهای فیزیکی حافظهٔ محلی (برای نمایش به کاربر و دیباگ).
class LocalCachePaths {
  LocalCachePaths._();

  /// پوشهٔ ریشهٔ cache اصناف روی دستگاه.
  static Future<String?> asnafCacheRoot() async {
    if (kIsWeb) return null;
    final base = await getApplicationDocumentsDirectory();
    return p.join(base.path, 'asnaf_cache');
  }

  /// پوشهٔ تصاویر یک اتحادیه: .../asnaf_cache/{codeCo}/
  static Future<String?> unionCacheDir(String codeCo) async {
    final root = await asnafCacheRoot();
    if (root == null) return null;
    return p.join(root, codeCo);
  }

  /// پوشهٔ تصاویر یک پرونده: .../asnaf_cache/{codeCo}/{idParvandeh}/
  static Future<String?> parvandeMediaDir(String codeCo, String idParvandeh) async {
    final u = await unionCacheDir(codeCo);
    if (u == null) return null;
    return p.join(u, idParvandeh);
  }
}
