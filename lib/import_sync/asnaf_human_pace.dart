import 'dart:async';
import 'dart:math';

/// رفتار زمانی شبیه کاربر انسانی برای استخراج پرونده (ضد تشخیص ربات).
class AsnafHumanPace {
  AsnafHumanPace._();
  static final AsnafHumanPace instance = AsnafHumanPace._();

  final Random _rng = Random();

  /// هر چند پرونده یک استراحت طولانی.
  static const batchEveryParvandeh = 300;

  /// مدت استراحت دسته‌ای: ۳۰ تا ۴۵ دقیقه.
  static const batchRestMinMinutes = 30;
  static const batchRestMaxMinutes = 45;

  /// هدف زمان کل هر پرونده (شامل API + دانلود تصاویر): ۱۰–۲۰ ثانیه.
  static const parvandeTargetMinMs = 10000;
  static const parvandeTargetMaxMs = 20000;

  int _nextTargetMs = 15000;

  void resetSession() {
    _nextTargetMs =
        parvandeTargetMinMs + _rng.nextInt(parvandeTargetMaxMs - parvandeTargetMinMs + 1);
  }

  /// پس از پردازش کامل یک پرونده؛ تا رسیدن به بازهٔ ۱۰–۲۰ ثانیه صبر می‌کند.
  Future<void> waitAfterParvande(Stopwatch elapsed) async {
    final remain = _nextTargetMs - elapsed.elapsedMilliseconds;
    _nextTargetMs =
        parvandeTargetMinMs + _rng.nextInt(parvandeTargetMaxMs - parvandeTargetMinMs + 1);
    if (remain > 0) {
      await Future<void>.delayed(Duration(milliseconds: remain));
    }
  }

  /// هر [batchEveryParvandeh] پرونده: توقف ۳۰–۴۵ دقیقه.
  Future<void> maybeLongRest({
    required int processedCount,
    required void Function(String message) onStatus,
    required bool Function() shouldAbort,
    Future<void> Function()? waitWhilePaused,
  }) async {
    if (processedCount <= 0 || processedCount % batchEveryParvandeh != 0) return;

    final restSeconds = (batchRestMinMinutes * 60) +
        _rng.nextInt((batchRestMaxMinutes - batchRestMinMinutes + 1) * 60);

    var left = restSeconds;
    while (left > 0) {
      if (shouldAbort()) return;
      if (waitWhilePaused != null) await waitWhilePaused();
      if (shouldAbort()) return;

      final mins = (left / 60).ceil();
      onStatus('استراحت ایمن — حدود $mins دقیقه تا ادامه (هر ۳۰۰ پرونده)');

      final step = left > 60 ? 60 : left;
      await Future<void>.delayed(Duration(seconds: step));
      left -= step;
    }
  }

  /// تخمین ساعت برای نمایش در دیالوگ (میانگین ۱۵ ثانیه/پرونده).
  static double estimateHoursForCount(int totalParvande) {
    if (totalParvande <= 0) return 0;
    const avgSec = (parvandeTargetMinMs + parvandeTargetMaxMs) / 2 / 1000;
  final batchPauses = totalParvande ~/ batchEveryParvandeh;
    const avgRestSec = ((batchRestMinMinutes + batchRestMaxMinutes) / 2) * 60;
    final sec = totalParvande * avgSec + batchPauses * avgRestSec;
    return sec / 3600;
  }

  /// پس از timeout سخت — قبل از ادامه (۱۰–۱۵ دقیقه).
  Future<void> cooldownAfterHardNetworkError(
    void Function(String message) onStatus,
  ) async {
    final restSeconds = (10 * 60) + _rng.nextInt(6 * 60);
    var left = restSeconds;
    while (left > 0) {
      final mins = (left / 60).ceil();
      onStatus('قطع/timeout شبکه — استراحت $mins دقیقه قبل از ادامه');
      final step = left > 60 ? 60 : left;
      await Future<void>.delayed(Duration(seconds: step));
      left -= step;
    }
  }
}
