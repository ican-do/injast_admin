import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:injast_admin/file_management/map_ir_config.dart';

/// جستجو و آدرس‌یابی معکوس با APIهای map.ir (و نشان به‌عنوان پشتیبان).
class MapIrGeocoding {
  MapIrGeocoding._();
  static final MapIrGeocoding instance = MapIrGeocoding._();

  Future<MapIrLocationResult?> searchAddress(String query) async {
    final text = query.trim();
    if (text.isEmpty) return null;

    return _firstNonNull([() => _searchNeshanPlus(text)]);
  }

  Future<String?> reverseAddress(double latitude, double longitude) async {
    final fallback = _coordLabel(latitude, longitude);
    final address =
        await _firstNonNullString([() => _reverseNeshan(latitude, longitude)]);
    return address ?? fallback;
  }

  Future<MapIrLocationResult?> _firstNonNull(
    List<Future<MapIrLocationResult?> Function()> providers,
  ) async {
    for (final provider in providers) {
      try {
        final result = await provider().timeout(MapIrConfig.geocodeTimeout);
        if (result != null) return result;
      } catch (_) {}
    }
    return null;
  }

  Future<String?> _firstNonNullString(
    List<Future<String?> Function()> providers,
  ) async {
    for (final provider in providers) {
      try {
        final result = await provider().timeout(MapIrConfig.geocodeTimeout);
        if (result != null && result.trim().isNotEmpty) return result.trim();
      } catch (_) {}
    }
    return null;
  }

  Future<MapIrLocationResult?> _searchNeshanPlus(String query) async {
    final key = MapIrConfig.neshanApiKey.trim();
    if (key.isEmpty) return null;

    final payload = {'address': query};
    final uri = Uri.parse(
      'https://api.neshan.org/geocoding/v1/plus?json=${Uri.encodeQueryComponent(jsonEncode(payload))}',
    );
    final res = await http.get(
      uri,
      headers: {
        'Api-Key': key,
        'Content-Type': 'application/json',
      },
    );
    if (res.statusCode != 200) return null;

    final body = jsonDecode(res.body);
    if (body is! Map) return null;
    final items = body['items'];
    if (items is! List || items.isEmpty) return null;
    final first = items.first;
    if (first is! Map) return null;
    final lat = _toDouble(first['location']?['latitude']);
    final lng = _toDouble(first['location']?['longitude']);
    if (lat == null || lng == null) return null;
    final province = first['province']?.toString().trim() ?? '';
    final city = first['city']?.toString().trim() ?? '';
    final neighborhood = first['neighbourhood']?.toString().trim() ?? '';
    final address =
        [province, city, neighborhood].where((e) => e.isNotEmpty).join('، ');

    return MapIrLocationResult(
      latitude: lat,
      longitude: lng,
      address: address.isNotEmpty ? address : _coordLabel(lat, lng),
    );
  }

  Future<String?> _reverseNeshan(double lat, double lng) async {
    final key = MapIrConfig.neshanApiKey.trim();
    if (key.isEmpty) return null;

    final uri = Uri.parse('https://api.neshan.org/v5/reverse').replace(
      queryParameters: {'lat': lat.toString(), 'lng': lng.toString()},
    );
    final res = await http
        .get(uri, headers: {'Api-Key': key, ...MapIrConfig.apiHeaders});
    if (res.statusCode != 200) return null;

    final body = jsonDecode(res.body);
    if (body is! Map) return null;
    final address = body['formatted_address']?.toString().trim();
    return address?.isNotEmpty == true ? address : null;
  }

  double? _toDouble(dynamic value) => double.tryParse(value?.toString() ?? '');

  String _coordLabel(double lat, double lng) =>
      'مختصات: ${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}';
}

class MapIrLocationResult {
  const MapIrLocationResult({
    required this.latitude,
    required this.longitude,
    required this.address,
  });

  final double latitude;
  final double longitude;
  final String address;
}
