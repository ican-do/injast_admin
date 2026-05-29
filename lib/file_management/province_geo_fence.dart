import 'dart:math' as math;

class ProvinceGeoFence {
  const ProvinceGeoFence({
    required this.name,
    required this.centerLat,
    required this.centerLng,
    required this.maxDistanceKm,
  });

  final String name;
  final double centerLat;
  final double centerLng;
  final double maxDistanceKm;

  bool contains(double lat, double lng) {
    final distance = _haversineKm(centerLat, centerLng, lat, lng);
    return distance <= maxDistanceKm;
  }

  static ProvinceGeoFence? fromState(String rawState) {
    final key = normalizeProvinceName(rawState);
    return _byKey[key];
  }

  static String normalizeProvinceName(String raw) {
    final t = raw
        .replaceAll('استان', '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .toLowerCase();
    return t;
  }

  static final Map<String, ProvinceGeoFence> _byKey = {
    'فارس': const ProvinceGeoFence(
      name: 'فارس',
      centerLat: 29.1044,
      centerLng: 53.0459,
      maxDistanceKm: 280,
    ),
    'اصفهان': const ProvinceGeoFence(
      name: 'اصفهان',
      centerLat: 32.6546,
      centerLng: 51.6680,
      maxDistanceKm: 230,
    ),
    'تهران': const ProvinceGeoFence(
      name: 'تهران',
      centerLat: 35.6892,
      centerLng: 51.3890,
      maxDistanceKm: 120,
    ),
    'کرمان': const ProvinceGeoFence(
      name: 'کرمان',
      centerLat: 30.2839,
      centerLng: 57.0834,
      maxDistanceKm: 360,
    ),
  };

  static double _haversineKm(
      double lat1, double lon1, double lat2, double lon2) {
    const earthRadiusKm = 6371.0;
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusKm * c;
  }

  static double _toRadians(double degree) => degree * (math.pi / 180.0);
}
