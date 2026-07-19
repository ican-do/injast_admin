import 'package:flutter/material.dart';

/// ناوبری سبک شبیه GetX برای صفحات شکایت
class ShekayatNav {
  static BuildContext? context;

  static void bind(BuildContext ctx) => context = ctx;
}

class Get {
  static Future<T?>? to<T>(Widget Function() page) {
    final ctx = ShekayatNav.context;
    if (ctx == null) return null;
    return Navigator.of(ctx).push<T>(
      MaterialPageRoute(builder: (_) => page()),
    );
  }

  static void back<T>([T? result]) {
    final ctx = ShekayatNav.context;
    if (ctx == null) return;
    if (Navigator.of(ctx).canPop()) {
      Navigator.of(ctx).pop(result);
    }
  }
}
