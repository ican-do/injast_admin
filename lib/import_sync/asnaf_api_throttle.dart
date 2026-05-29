import 'dart:math';

import 'package:injast_admin/import_sync/asnaf_fetch_pace.dart';

/// فاصلهٔ حداقلی بین درخواست‌های متوالی به API اصناف (ضد اسپم و بلاک IP).
class AsnafApiThrottle {
  AsnafApiThrottle._();
  static final AsnafApiThrottle instance = AsnafApiThrottle._();

  final Random _rng = Random();

  Duration get minGap => AsnafFetchPace.current.minGapBetweenApiCalls;

  DateTime? _lastAt;

  Future<void> waitTurn() async {
    final now = DateTime.now();
    if (_lastAt != null) {
      final elapsed = now.difference(_lastAt!);
      if (elapsed < minGap) {
        await Future<void>.delayed(minGap - elapsed);
      }
    }
    _lastAt = DateTime.now();
  }

  /// مکث تصادفی بین دو مرحلهٔ یک پرونده (مثلاً جزئیات → مدارک).
  Future<void> randomBetweenSteps({
    int minMs = 3000,
    int maxMs = 7000,
  }) async {
    if (maxMs <= minMs) {
      await Future<void>.delayed(Duration(milliseconds: minMs));
      return;
    }
    final ms = minMs + _rng.nextInt(maxMs - minMs + 1);
    await Future<void>.delayed(Duration(milliseconds: ms));
  }

  /// پس از 429 — صبر طولانی‌تر قبل از تلاش بعدی.
  Future<void> backoff429(int attempt) async {
    final sec = (attempt * 4).clamp(4, 90);
    await Future<void>.delayed(Duration(seconds: sec));
  }

  /// پس از timeout / قطع اتصال — صبر قبل از retry یا پروندهٔ بعدی.
  Future<void> backoffNetworkError(int attempt) async {
    final sec = switch (attempt) {
      1 => 45,
      2 => 90,
      _ => 180,
    };
    await Future<void>.delayed(Duration(seconds: sec));
  }
}
