import 'dart:math' as math;

import 'package:flutter/material.dart';

/// محدودیت عرض صفحات شکایت برای مانیتور واید دسکتاپ
class ShekayatLayout {
  static const double contentMaxWidth = 980;
  static const double listMaxWidth = 1360;
  static const double formMaxWidth = 720;
  static const double docsMaxWidth = 1100;
  static const double reportsMaxWidth = 1200;
  static const double actionBtnWidth = 104;
  static const double actionBtnHeight = 30;

  static bool isWide(BuildContext context, {double min = 1000}) =>
      MediaQuery.sizeOf(context).width >= min;

  /// بدنه صفحه با عرض محدود و ارتفاع کامل (مناسب Column/Expanded)
  static Widget constrain({
    required Widget child,
    double maxWidth = contentMaxWidth,
    EdgeInsetsGeometry padding = const EdgeInsets.symmetric(horizontal: 16),
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = math.min(maxWidth, constraints.maxWidth);
        return Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: width,
            height: constraints.hasBoundedHeight ? constraints.maxHeight : null,
            child: Padding(padding: padding, child: child),
          ),
        );
      },
    );
  }

  /// اسکرول فرم با عرض محدود
  static Widget formScroll({
    required Widget child,
    double maxWidth = formMaxWidth,
    EdgeInsetsGeometry padding = const EdgeInsets.fromLTRB(16, 12, 16, 24),
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = math.min(maxWidth, constraints.maxWidth);
        return Align(
          alignment: Alignment.topCenter,
          child: SingleChildScrollView(
            padding: padding,
            child: SizedBox(width: width, child: child),
          ),
        );
      },
    );
  }
}
