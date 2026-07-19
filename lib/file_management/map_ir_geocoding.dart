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

    final hits = await searchSuggestions(text, limit: 1);
    return hits.isEmpty ? null : hits.first;
  }

  /// پیشنهادهای جستجو برای دیالوگ نقشه (چند نتیجه).
  Future<List<MapIrLocationResult>> searchSuggestions(
    String query, {
    int limit = 8,
  }) async {
    final text = query.trim();
    if (text.isEmpty) return const [];

    final fromMapIr = await _safeList(() => _searchMapIrAutocomplete(text));
    if (fromMapIr.isNotEmpty) {
      return fromMapIr.take(limit).toList();
    }

    final neshanV6 = await _safeOne(() => _searchNeshanV6(text));
    if (neshanV6 != null) return [neshanV6];

    final neshanPlus = await _safeOne(() => _searchNeshanPlus(text));
    if (neshanPlus != null) return [neshanPlus];

    return const [];
  }

  Future<String?> reverseAddress(double latitude, double longitude) async {
    final fallback = _coordLabel(latitude, longitude);
    final address = await _firstNonNullString([
      () => _reverseMapIr(latitude, longitude),
      () => _reverseNeshan(latitude, longitude),
    ]);
    return address ?? fallback;
  }

  Future<T?> _safeOne<T>(Future<T?> Function() fn) async {
    try {
      return await fn().timeout(MapIrConfig.geocodeTimeout);
    } catch (_) {
      return null;
    }
  }

  Future<List<MapIrLocationResult>> _safeList(
    Future<List<MapIrLocationResult>> Function() fn,
  ) async {
    try {
      return await fn().timeout(MapIrConfig.geocodeTimeout);
    } catch (_) {
      return const [];
    }
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

  Future<List<MapIrLocationResult>> _searchMapIrAutocomplete(String query) async {
    final res = await http.post(
      Uri.parse('https://map.ir/search/v2/autocomplete'),
      headers: {
        ...MapIrConfig.apiHeaders,
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'text': query}),
    );
    if (res.statusCode != 200) return const [];

    final body = jsonDecode(utf8.decode(res.bodyBytes));
    if (body is! Map) return const [];
    final values = body['value'];
    if (values is! List || values.isEmpty) return const [];

    final out = <MapIrLocationResult>[];
    for (final item in values) {
      if (item is! Map) continue;
      final geom = item['geom'];
      if (geom is! Map) continue;
      final coords = geom['coordinates'];
      if (coords is! List || coords.length < 2) continue;
      final lng = _toDouble(coords[0]);
      final lat = _toDouble(coords[1]);
      if (lat == null || lng == null) continue;
      final address = [
        item['address'],
        item['title'],
        item['neighborhood'],
        item['city'],
        item['province'],
      ]
          .map((e) => e?.toString().trim() ?? '')
          .where((e) => e.isNotEmpty)
          .toSet()
          .join('، ');
      out.add(MapIrLocationResult(
        latitude: lat,
        longitude: lng,
        address: address.isNotEmpty ? address : _coordLabel(lat, lng),
      ));
    }
    return out;
  }

  Future<MapIrLocationResult?> _searchNeshanV6(String query) async {
    final key = MapIrConfig.neshanApiKey.trim();
    if (key.isEmpty) return null;

    final uri = Uri.parse(
      'https://api.neshan.org/v6/geocoding?address=${Uri.encodeQueryComponent(query)}',
    );
    final res = await http.get(uri, headers: {'Api-Key': key});
    if (res.statusCode != 200) return null;

    final body = jsonDecode(utf8.decode(res.bodyBytes));
    if (body is! Map) return null;
    final lat = _toDouble(body['location']?['y']);
    final lng = _toDouble(body['location']?['x']);
    if (lat == null || lng == null) return null;

    return MapIrLocationResult(
      latitude: lat,
      longitude: lng,
      address: query,
    );
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

    final body = jsonDecode(utf8.decode(res.bodyBytes));
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

  Future<String?> _reverseMapIr(double lat, double lng) async {
    final uri = Uri.parse('https://map.ir/reverse/').replace(
      queryParameters: {
        'lat': lat.toString(),
        'lon': lng.toString(),
      },
    );
    final res = await http.get(uri, headers: MapIrConfig.apiHeaders);
    if (res.statusCode != 200) return null;
    final body = jsonDecode(utf8.decode(res.bodyBytes));
    if (body is! Map) return null;
    final address = body['address']?.toString().trim();
    return address?.isNotEmpty == true ? address : null;
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

    final body = jsonDecode(utf8.decode(res.bodyBytes));
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
