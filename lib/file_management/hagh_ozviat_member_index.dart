/// خلاصهٔ حق عضویت یک عضو (برای نمایش روی کارت پرونده).
class HaghOzviatMemberIndex {
  const HaghOzviatMemberIndex({
    required this.shenaseStore,
    required this.pendingRial,
    required this.confirmedRial,
    required this.rowCount,
  });

  final String shenaseStore;
  final int pendingRial;
  final int confirmedRial;
  final int rowCount;

  bool get hasRecords => rowCount > 0;

  bool get hasPendingDebt => hasRecords && pendingRial > 0;

  factory HaghOzviatMemberIndex.fromJson(Map<String, dynamic> json) {
    return HaghOzviatMemberIndex(
      shenaseStore: json['shenase_store']?.toString() ?? '',
      pendingRial: _toInt(json['pending_rial']),
      confirmedRial: _toInt(json['confirmed_rial']),
      rowCount: _toInt(json['row_count']),
    );
  }

  static int _toInt(dynamic v) => int.tryParse(v?.toString() ?? '') ?? 0;
}
