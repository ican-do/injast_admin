import 'package:injast_admin/file_management/parvande_api.dart';

/// یک آدرس قابل جستجو از میان پرونده‌های اتحادیه.
class ParvandeAddressHit {
  const ParvandeAddressHit({
    required this.idParvandeh,
    required this.address,
    required this.storeName,
    required this.fullName,
    required this.lat,
    required this.lng,
  });

  final String idParvandeh;
  final String address;
  final String storeName;
  final String fullName;
  final double lat;
  final double lng;
}

/// جستجوی محلی آدرس در پرونده‌های همان اتحادیه.
class ParvandeAddressSearch {
  ParvandeAddressSearch._();
  static final ParvandeAddressSearch instance = ParvandeAddressSearch._();

  List<ParvandeAddressHit> buildIndex(List<Map<String, dynamic>> parvandes) {
    final out = <ParvandeAddressHit>[];
    final seen = <String>{};

    for (final p in parvandes) {
      final row = p; // ParvandeRow extension
      final address = row.address.trim();
      if (address.isEmpty || !row.hasLocation) continue;

      final lat = double.tryParse(row.lat);
      final lng = double.tryParse(row.lng);
      if (lat == null || lng == null) continue;

      final key = '${address.toLowerCase()}|$lat|$lng';
      if (seen.contains(key)) continue;
      seen.add(key);

      out.add(
        ParvandeAddressHit(
          idParvandeh: row.idParvandeh,
          address: address,
          storeName: row.storeName,
          fullName: row.fullName,
          lat: lat,
          lng: lng,
        ),
      );
    }

    out.sort((a, b) => a.address.compareTo(b.address));
    return out;
  }

  List<ParvandeAddressHit> search(
    List<ParvandeAddressHit> index,
    String query, {
    int limit = 15,
  }) {
    final q = _normalize(query);
    if (q.isEmpty) return const [];

    final scored = <(ParvandeAddressHit, int)>[];
    for (final hit in index) {
      final score = _matchScore(q, hit);
      if (score > 0) scored.add((hit, score));
    }

    scored.sort((a, b) {
      final byScore = b.$2.compareTo(a.$2);
      if (byScore != 0) return byScore;
      return a.$1.address.length.compareTo(b.$1.address.length);
    });

    return scored.take(limit).map((e) => e.$1).toList();
  }

  String _normalize(String raw) =>
      raw.replaceAll('\u200c', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();

  int _matchScore(String query, ParvandeAddressHit hit) {
    final address = _normalize(hit.address);
    final store = _normalize(hit.storeName);
    final name = _normalize(hit.fullName);
    final q = query;

    if (address.startsWith(q)) return 100;
    if (store.startsWith(q)) return 90;
    if (name.startsWith(q)) return 80;
    if (address.contains(q)) return 70;
    if (store.contains(q)) return 60;
    if (name.contains(q)) return 50;

    final tokens = q.split(' ').where((t) => t.length >= 2);
    if (tokens.isEmpty) return 0;
    var matched = 0;
    for (final token in tokens) {
      if (address.contains(token) || store.contains(token) || name.contains(token)) {
        matched++;
      }
    }
    if (matched == 0) return 0;
    return 30 + matched * 5;
  }
}
