import 'package:injast_admin/features/shekayat/shekayat_api.dart';

/// ایندکس شکایات متصل به پرونده‌ها (بر اساس id_store / linked_parvandeh_id)
class ParvandeShekayatIndex {
  ParvandeShekayatIndex._(this._byParvandehId);

  final Map<String, List<Map<String, dynamic>>> _byParvandehId;

  static Future<ParvandeShekayatIndex> load(String codeCo) async {
    final list = await ShekayatApi.listComplaints(codeCo);
    final map = <String, List<Map<String, dynamic>>>{};

    for (final raw in list) {
      if (raw is! Map) continue;
      final item = Map<String, dynamic>.from(raw);
      final id = _linkedId(item);
      if (id == null) continue;
      map.putIfAbsent(id, () => []).add(item);
    }

    // تلاش تکمیلی با گزارش تجمیعی در صورت خالی بودن لینک‌ها از list
    if (map.isEmpty) {
      try {
        final report = await ShekayatApi.reportByParvandeh(codeCo);
        for (final raw in report) {
          if (raw is! Map) continue;
          final item = Map<String, dynamic>.from(raw);
          final id = _linkedId(item) ??
              item['id_parvandeh']?.toString().trim();
          if (id == null || id.isEmpty || id == '0') continue;
          final count = int.tryParse(
                item['count']?.toString() ??
                    item['cnt']?.toString() ??
                    item['total']?.toString() ??
                    '',
              ) ??
              0;
          if (count > 0 && !map.containsKey(id)) {
            // فقط تعداد؛ لیست خالی تا با کلیک از list دوباره فیلتر شود
            map[id] = List.generate(
              count,
              (i) => {
                'id_store': id,
                'complaint_number': '',
                'lbl_shekayat': 'شکایت ${i + 1}',
                'status_shekayat': item['status_shekayat']?.toString() ?? '',
                '_aggregate_only': true,
              },
            );
          } else if (!map.containsKey(id)) {
            map.putIfAbsent(id, () => []).add(item);
          }
        }
      } catch (_) {}
    }

    return ParvandeShekayatIndex._(map);
  }

  static String? _linkedId(Map<String, dynamic> item) {
    for (final key in ['linked_parvandeh_id', 'id_store', 'id_parvandeh']) {
      final v = item[key]?.toString().trim() ?? '';
      if (v.isNotEmpty && v != '0' && v.toLowerCase() != 'null') return v;
    }
    return null;
  }

  int countFor(String? idParvandeh) {
    final id = idParvandeh?.trim() ?? '';
    if (id.isEmpty) return 0;
    return _byParvandehId[id]?.length ?? 0;
  }

  List<Map<String, dynamic>> complaintsFor(String? idParvandeh) {
    final id = idParvandeh?.trim() ?? '';
    if (id.isEmpty) return const [];
    return List<Map<String, dynamic>>.from(_byParvandehId[id] ?? const []);
  }

  bool hasComplaints(String? idParvandeh) => countFor(idParvandeh) > 0;
}
