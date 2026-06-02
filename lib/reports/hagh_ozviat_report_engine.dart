import 'package:injast_admin/file_management/hagh_ozviat_member_index.dart';
import 'package:injast_admin/file_management/hagh_ozviat_models.dart';
import 'package:injast_admin/file_management/jalali_date_util.dart';
import 'package:shamsi_date/shamsi_date.dart';

/// فیلترهای گزارش حق عضویت.
class HaghOzviatReportFilters {
  const HaghOzviatReportFilters({
    this.searchQuery = '',
    this.vaziyat = 'همه',
    this.sal = 'همه',
    this.radeSanfi = 'همه',
    this.dateFrom,
    this.dateTo,
    this.minPendingRial,
    this.maxPendingRial,
  });

  final String searchQuery;
  final String vaziyat;
  final String sal;
  final String radeSanfi;
  final Jalali? dateFrom;
  final Jalali? dateTo;
  final int? minPendingRial;
  final int? maxPendingRial;

  HaghOzviatReportFilters copyWith({
    String? searchQuery,
    String? vaziyat,
    String? sal,
    String? radeSanfi,
    Jalali? dateFrom,
    Jalali? dateTo,
    bool clearDateFrom = false,
    bool clearDateTo = false,
    int? minPendingRial,
    int? maxPendingRial,
    bool clearMinPending = false,
    bool clearMaxPending = false,
  }) {
    return HaghOzviatReportFilters(
      searchQuery: searchQuery ?? this.searchQuery,
      vaziyat: vaziyat ?? this.vaziyat,
      sal: sal ?? this.sal,
      radeSanfi: radeSanfi ?? this.radeSanfi,
      dateFrom: clearDateFrom ? null : (dateFrom ?? this.dateFrom),
      dateTo: clearDateTo ? null : (dateTo ?? this.dateTo),
      minPendingRial:
          clearMinPending ? null : (minPendingRial ?? this.minPendingRial),
      maxPendingRial:
          clearMaxPending ? null : (maxPendingRial ?? this.maxPendingRial),
    );
  }

  bool get hasActive =>
      searchQuery.trim().isNotEmpty ||
      vaziyat != 'همه' ||
      sal != 'همه' ||
      radeSanfi != 'همه' ||
      dateFrom != null ||
      dateTo != null ||
      minPendingRial != null ||
      maxPendingRial != null;
}

class HaghOzviatSalBreakdown {
  const HaghOzviatSalBreakdown({
    required this.sal,
    required this.pendingRial,
    required this.confirmedRial,
    required this.rowCount,
  });

  final String sal;
  final int pendingRial;
  final int confirmedRial;
  final int rowCount;

  int get totalRial => pendingRial + confirmedRial;
}

class HaghOzviatSalDebtYear {
  const HaghOzviatSalDebtYear({
    required this.sal,
    required this.pendingRial,
    required this.debtorCount,
    required this.rowCount,
  });

  final String sal;
  final int pendingRial;
  final int debtorCount;
  final int rowCount;
}

class HaghOzviatMemberDebtRank {
  const HaghOzviatMemberDebtRank({
    required this.shenaseStore,
    required this.pendingRial,
    required this.confirmedRial,
    required this.rowCount,
  });

  final String shenaseStore;
  final int pendingRial;
  final int confirmedRial;
  final int rowCount;
}

class HaghOzviatReportSnapshot {
  const HaghOzviatReportSnapshot({
    required this.filteredRows,
    required this.totalPendingRial,
    required this.totalConfirmedRial,
    required this.debtorMembers,
    required this.settledMembers,
    required this.membersWithRecords,
    required this.rowCount,
    required this.avgDebtPerDebtor,
    required this.maxMemberPending,
    required this.salBreakdown,
    required this.vaziyatBreakdown,
    required this.topDebtors,
    required this.debtorMembersList,
    required this.fullRowData,
    this.yearsWithDebt = const [],
  });

  final List<HaghOzviatRow> filteredRows;
  final int totalPendingRial;
  final int totalConfirmedRial;
  final int debtorMembers;
  final int settledMembers;
  final int membersWithRecords;
  final int rowCount;
  final int avgDebtPerDebtor;
  final int maxMemberPending;
  final List<HaghOzviatSalBreakdown> salBreakdown;
  final Map<String, int> vaziyatBreakdown;
  final List<HaghOzviatMemberDebtRank> topDebtors;
  final List<HaghOzviatMemberDebtRank> debtorMembersList;
  final bool fullRowData;
  final List<HaghOzviatSalDebtYear> yearsWithDebt;
}

class HaghOzviatReportEngine {
  HaghOzviatReportEngine._();

  static const ignoredVaziyat = {'حذف شده'};

  static Jalali? parseTarikhIjad(String raw) {
    final t = raw.trim();
    if (t.isEmpty || t.toLowerCase() == 'null') return null;
    final datePart = t.split(',').first.trim();
    return JalaliDateUtil.parse(datePart);
  }

  static List<HaghOzviatSalDebtYear> yearsWithPendingDebt(
    List<HaghOzviatRow> rows,
  ) {
    final bySal = <String, ({int pending, Set<String> members, int rows})>{};
    for (final r in rows) {
      if (!r.isPending) continue;
      if (ignoredVaziyat.contains(r.vaziyat.trim())) continue;
      final sal = r.sal.trim();
      if (sal.isEmpty) continue;
      final cur = bySal[sal];
      final members = <String>{...?cur?.members, r.shenaseStore};
      bySal[sal] = (
        pending: (cur?.pending ?? 0) + r.mablaghRial,
        members: members,
        rows: (cur?.rows ?? 0) + 1,
      );
    }
    return bySal.entries
        .map(
          (e) => HaghOzviatSalDebtYear(
            sal: e.key,
            pendingRial: e.value.pending,
            debtorCount: e.value.members.length,
            rowCount: e.value.rows,
          ),
        )
        .toList()
      ..sort((a, b) => b.sal.compareTo(a.sal));
  }

  static List<String> distinctSal(List<HaghOzviatRow> rows) {
    final set = rows
        .map((r) => r.sal.trim())
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList()
      ..sort((a, b) => b.compareTo(a));
    return set;
  }

  static List<String> distinctRade(List<HaghOzviatRow> rows) {
    final set = rows
        .map((r) => r.radeSanfi.trim())
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return set;
  }

  static List<String> distinctVaziyat(List<HaghOzviatRow> rows) {
    final set = rows
        .map((r) => r.vaziyat.trim())
        .where((s) => s.isNotEmpty && !ignoredVaziyat.contains(s))
        .toSet()
        .toList()
      ..sort();
    return set;
  }

  static List<HaghOzviatRow> applyRowFilters(
    List<HaghOzviatRow> rows,
    HaghOzviatReportFilters filters,
  ) {
    final q = filters.searchQuery.trim().toLowerCase();
    return rows.where((r) {
      if (ignoredVaziyat.contains(r.vaziyat.trim())) return false;
      if (filters.vaziyat != 'همه' && r.vaziyat.trim() != filters.vaziyat) {
        return false;
      }
      if (filters.sal != 'همه' && r.sal.trim() != filters.sal) {
        return false;
      }
      if (filters.radeSanfi != 'همه' &&
          r.radeSanfi.trim() != filters.radeSanfi) {
        return false;
      }
      if (q.isNotEmpty) {
        final bag = [
          r.shenaseStore,
          r.onvan,
          r.onvanRaste,
          r.radeSanfi,
          r.sal,
        ].join(' ').toLowerCase();
        if (!bag.contains(q)) return false;
      }
      final created = parseTarikhIjad(r.tarikhIjad);
      if (filters.dateFrom != null && created != null) {
        if (_compareJalali(created, filters.dateFrom!) < 0) return false;
      }
      if (filters.dateTo != null && created != null) {
        if (_compareJalali(created, filters.dateTo!) > 0) return false;
      }
      if (filters.dateFrom != null && created == null) return false;
      if (filters.dateTo != null && created == null) return false;
      return true;
    }).toList();
  }

  static int _compareJalali(Jalali a, Jalali b) {
    if (a.year != b.year) return a.year.compareTo(b.year);
    if (a.month != b.month) return a.month.compareTo(b.month);
    return a.day.compareTo(b.day);
  }

  static HaghOzviatReportSnapshot fromRows({
    required List<HaghOzviatRow> allRows,
    required HaghOzviatReportFilters filters,
  }) {
    final filtered = applyRowFilters(allRows, filters);
    var pending = 0;
    var confirmed = 0;
    final byMember = <String, ({int pending, int confirmed, int rows})>{};
    final salMap = <String, ({int pending, int confirmed, int rows})>{};
    final vaziyatMap = <String, int>{};

    for (final r in filtered) {
      if (r.isPending) pending += r.mablaghRial;
      if (r.isConfirmed) confirmed += r.mablaghRial;
      final key = r.shenaseStore;
      final cur = byMember[key];
      byMember[key] = (
        pending: (cur?.pending ?? 0) + (r.isPending ? r.mablaghRial : 0),
        confirmed: (cur?.confirmed ?? 0) + (r.isConfirmed ? r.mablaghRial : 0),
        rows: (cur?.rows ?? 0) + 1,
      );
      final salKey = r.sal.trim().isEmpty ? '—' : r.sal.trim();
      final salCur = salMap[salKey];
      salMap[salKey] = (
        pending: (salCur?.pending ?? 0) + (r.isPending ? r.mablaghRial : 0),
        confirmed:
            (salCur?.confirmed ?? 0) + (r.isConfirmed ? r.mablaghRial : 0),
        rows: (salCur?.rows ?? 0) + 1,
      );
      final vz = r.vaziyat.trim().isEmpty ? '—' : r.vaziyat.trim();
      vaziyatMap[vz] = (vaziyatMap[vz] ?? 0) + 1;
    }

    var debtorMembers = 0;
    var settledMembers = 0;
    var maxMemberPending = 0;
    for (final e in byMember.entries) {
      if (e.value.pending > 0) {
        debtorMembers++;
        if (e.value.pending > maxMemberPending) {
          maxMemberPending = e.value.pending;
        }
      } else if (e.value.rows > 0) {
        settledMembers++;
      }
    }

    final top = byMember.entries
        .map(
          (e) => HaghOzviatMemberDebtRank(
            shenaseStore: e.key,
            pendingRial: e.value.pending,
            confirmedRial: e.value.confirmed,
            rowCount: e.value.rows,
          ),
        )
        .where((e) => e.pendingRial > 0)
        .toList()
      ..sort((a, b) => b.pendingRial.compareTo(a.pendingRial));

    final salBreakdown = salMap.entries
        .map(
          (e) => HaghOzviatSalBreakdown(
            sal: e.key,
            pendingRial: e.value.pending,
            confirmedRial: e.value.confirmed,
            rowCount: e.value.rows,
          ),
        )
        .toList()
      ..sort((a, b) => b.sal.compareTo(a.sal));

    final avg = debtorMembers == 0 ? 0 : pending ~/ debtorMembers;

    return HaghOzviatReportSnapshot(
      filteredRows: filtered,
      totalPendingRial: pending,
      totalConfirmedRial: confirmed,
      debtorMembers: debtorMembers,
      settledMembers: settledMembers,
      membersWithRecords: byMember.length,
      rowCount: filtered.length,
      avgDebtPerDebtor: avg,
      maxMemberPending: maxMemberPending,
      salBreakdown: salBreakdown,
      vaziyatBreakdown: vaziyatMap,
      topDebtors: top.take(15).toList(),
      debtorMembersList: top,
      yearsWithDebt: yearsWithPendingDebt(allRows),
      fullRowData: true,
    );
  }

  static HaghOzviatReportSnapshot fromIndex({
    required Map<String, HaghOzviatMemberIndex> index,
    required HaghOzviatReportFilters filters,
  }) {
    final q = filters.searchQuery.trim();
    final entries = index.entries.where((e) {
      if (q.isNotEmpty && !e.key.contains(q)) return false;
      final pending = e.value.pendingRial;
      if (filters.minPendingRial != null && pending < filters.minPendingRial!) {
        return false;
      }
      if (filters.maxPendingRial != null && pending > filters.maxPendingRial!) {
        return false;
      }
      if (filters.vaziyat == 'در انتظار پرداخت' && pending <= 0) {
        return false;
      }
      if (filters.vaziyat == 'تایید شده' && e.value.confirmedRial <= 0) {
        return false;
      }
      return true;
    }).toList();

    var pending = 0;
    var confirmed = 0;
    var debtorMembers = 0;
    var settledMembers = 0;
    var maxMemberPending = 0;

    final top = <HaghOzviatMemberDebtRank>[];
    for (final e in entries) {
      final idx = e.value;
      pending += idx.pendingRial;
      confirmed += idx.confirmedRial;
      if (idx.hasPendingDebt) {
        debtorMembers++;
        if (idx.pendingRial > maxMemberPending) {
          maxMemberPending = idx.pendingRial;
        }
        top.add(
          HaghOzviatMemberDebtRank(
            shenaseStore: idx.shenaseStore,
            pendingRial: idx.pendingRial,
            confirmedRial: idx.confirmedRial,
            rowCount: idx.rowCount,
          ),
        );
      } else if (idx.hasRecords) {
        settledMembers++;
      }
    }
    top.sort((a, b) => b.pendingRial.compareTo(a.pendingRial));

    final avg = debtorMembers == 0 ? 0 : pending ~/ debtorMembers;

    return HaghOzviatReportSnapshot(
      filteredRows: const [],
      totalPendingRial: pending,
      totalConfirmedRial: confirmed,
      debtorMembers: debtorMembers,
      settledMembers: settledMembers,
      membersWithRecords: entries.length,
      rowCount: entries.fold<int>(0, (s, e) => s + e.value.rowCount),
      avgDebtPerDebtor: avg,
      maxMemberPending: maxMemberPending,
      salBreakdown: const [],
      vaziyatBreakdown: const {},
      topDebtors: top.take(15).toList(),
      debtorMembersList: top,
      yearsWithDebt: const [],
      fullRowData: false,
    );
  }

  static String formatRial(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  static String formatJalali(Jalali? j) {
    if (j == null) return '—';
    return '${j.year}/${j.month.toString().padLeft(2, '0')}/${j.day.toString().padLeft(2, '0')}';
  }
}
