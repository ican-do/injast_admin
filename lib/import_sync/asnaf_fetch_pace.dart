/// تنظیم سرعت استخراج از API اصناف (مدیریت درخواست بر اساس زمان).
///
/// **تخمین درخواست به apinovin به‌ازای هر پرونده (بازیابی کامل):**
/// - ۱× جزئیات پرونده + ۱× لیست مدارک ≈ **۲ درخواست**
/// - به‌علاوه سهم صفحه‌بندی لیست (حدود ۱/۲۰ تا ۱/۵۰ درخواست برای هر پرونده)
///
/// **نرخ پیشنهادی برای جلوگیری از 429 / بلاک IP (بدون مستند رسمی اصناف):**
/// - حداکثر پایدار: **۲۵–۳۰ درخواست در دقیقه** به همان API
/// - بازیابی کامل: حدود **۸–۱۲ ثانیه به‌ازای هر پرونده** (ایمن)
/// - فقط بدهی: حدود **۴–۶ ثانیه به‌ازای هر پرونده**
enum AsnafFetchPaceMode {
  /// ~۸–۱۲ ثانیه/پرونده کامل — پیش‌فرض پس از محدودیت IP
  safe,

  /// ~۵–۷ ثانیه/پرونده کامل — تعادل
  balanced,

  /// سریع‌تر — فقط اگر محدودیت ندارید
  fast,
}

class AsnafFetchPace {
  const AsnafFetchPace({
    required this.minGapBetweenApiCalls,
    required this.pauseAfterFullParvande,
    required this.pauseAfterDebtParvande,
    required this.pauseAfterListPage,
    required this.pauseBetweenRastePages,
    required this.pauseAfterRecordInCollect,
    required this.pauseAfterPageInCollect,
  });

  /// حداقل فاصله بین هر GET به apinovin (سقف نرخ درخواست).
  final Duration minGapBetweenApiCalls;

  /// بعد از پردازش یک پرونده در بازیابی کامل (جزئیات+مدارک+ذخیره).
  final Duration pauseAfterFullParvande;

  /// بعد از هر پرونده در حالت بدهی.
  final Duration pauseAfterDebtParvande;

  /// بعد از اتمام هر صفحهٔ لیست پرونده‌ها.
  final Duration pauseAfterListPage;

  /// بین صفحات API رسته (شروع بازیابی کامل).
  final Duration pauseBetweenRastePages;

  /// بین رکوردها در [AsnafBotClient.collectRecords].
  final Duration pauseAfterRecordInCollect;

  /// بین صفحات در collectRecords.
  final Duration pauseAfterPageInCollect;

  /// حداکثر درخواست در دقیقه (تقریبی، فقط با فاصلهٔ [minGapBetweenApiCalls]).
  double get approxMaxRequestsPerMinute =>
      60000.0 / minGapBetweenApiCalls.inMilliseconds;

  /// زمان تقریبی هر پرونده کامل (۲ API + فاصله‌ها).
  Duration get approxSecondsPerFullParvande =>
      minGapBetweenApiCalls * 2 + pauseAfterFullParvande;

  static AsnafFetchPaceMode currentMode = AsnafFetchPaceMode.safe;

  static AsnafFetchPace get current => switch (currentMode) {
        AsnafFetchPaceMode.safe => safe,
        AsnafFetchPaceMode.balanced => balanced,
        AsnafFetchPaceMode.fast => fast,
      };

  /// ~۳.۵ ثانیه بین GET → ~۱۷ req/min؛ ~۱۲–۱۵ ثانیه/پرونده کامل
  static const safe = AsnafFetchPace(
    minGapBetweenApiCalls: Duration(milliseconds: 3500),
    pauseAfterFullParvande: Duration(milliseconds: 2800),
    pauseAfterDebtParvande: Duration(milliseconds: 1800),
    pauseAfterListPage: Duration(milliseconds: 3500),
    pauseBetweenRastePages: Duration(milliseconds: 2200),
    pauseAfterRecordInCollect: Duration(milliseconds: 2800),
    pauseAfterPageInCollect: Duration(milliseconds: 4000),
  );

  /// ~۱.۴ ثانیه بین GET → ~۴۳ req/min؛ ~۶–۸ ثانیه/پرونده کامل
  static const balanced = AsnafFetchPace(
    minGapBetweenApiCalls: Duration(milliseconds: 1400),
    pauseAfterFullParvande: Duration(milliseconds: 1300),
    pauseAfterDebtParvande: Duration(milliseconds: 950),
    pauseAfterListPage: Duration(milliseconds: 2000),
    pauseBetweenRastePages: Duration(milliseconds: 1500),
    pauseAfterRecordInCollect: Duration(milliseconds: 1100),
    pauseAfterPageInCollect: Duration(milliseconds: 2000),
  );

  static const fast = AsnafFetchPace(
    minGapBetweenApiCalls: Duration(milliseconds: 900),
    pauseAfterFullParvande: Duration(milliseconds: 600),
    pauseAfterDebtParvande: Duration(milliseconds: 400),
    pauseAfterListPage: Duration(milliseconds: 1200),
    pauseBetweenRastePages: Duration(milliseconds: 1000),
    pauseAfterRecordInCollect: Duration(milliseconds: 700),
    pauseAfterPageInCollect: Duration(milliseconds: 1200),
  );
}
