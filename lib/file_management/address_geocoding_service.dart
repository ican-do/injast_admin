import 'dart:developer' show log;

import 'package:injast_admin/file_management/map_ir_geocoding.dart';
import 'package:injast_admin/file_management/province_geo_fence.dart';
import 'package:injast_admin/import_sync/asnaf_bot_client.dart';

const _logName = 'address_geocode';

/// تبدیل آدرس متنی به مختصات با نشان + کنترل محدوده استان.
class AddressGeocodingService {
  AddressGeocodingService._();

  static final AddressGeocodingService instance = AddressGeocodingService._();

  static const _pauseBetweenRows = Duration(milliseconds: 280);

  final _neshanGeo = MapIrGeocoding.instance;
  final _neshanDirect = AsnafBotClient();

  /// [latitude, longitude] به‌صورت رشته (مثل فیلدهای پرونده).
  Future<(String lat, String lng)?> resolve({
    required String address,
    String state = '',
    String city = '',
  }) async {
    final normalizedAddress = normalizeAddress(address);
    final normalizedState = _cleanPart(state);
    final normalizedCity = _cleanPart(city);
    final variants = _queryVariants(
      state: normalizedState,
      city: normalizedCity,
      address: normalizedAddress,
    );
    if (variants.isEmpty) return null;

    final fence = ProvinceGeoFence.fromState(normalizedState);
    for (final query in variants) {
      try {
        final hit = await _neshanGeo.searchAddress(query);
        if (hit != null &&
            _isInsideProvinceFence(fence, hit.latitude, hit.longitude)) {
          return (
            hit.latitude.toString(),
            hit.longitude.toString(),
          );
        }
      } catch (e) {
        log('neshan plus search failed: $e | q=$query', name: _logName);
      }
    }

    final neshan = await _neshanDirect.geocodeAddress(variants.first);
    await Future<void>.delayed(_pauseBetweenRows);
    if (neshan == null) return null;
    final lat = double.tryParse(neshan.$1);
    final lng = double.tryParse(neshan.$2);
    if (lat == null || lng == null) return null;
    if (!_isInsideProvinceFence(fence, lat, lng)) return null;
    return neshan;
  }

  bool _isInsideProvinceFence(ProvinceGeoFence? fence, double lat, double lng) {
    if (fence == null) return true;
    return fence.contains(lat, lng);
  }

  Future<void> pauseBetweenImports() => Future<void>.delayed(_pauseBetweenRows);

  List<String> _queryVariants({
    required String state,
    required String city,
    required String address,
  }) {
    final s = _cleanPart(state);
    final c = _cleanPart(city);
    final a = _cleanPart(address);
    final out = <String>[];

    void add(String value) {
      final t = value.trim();
      if (t.length < 4) return;
      if (!out.contains(t)) out.add(t);
    }

    if (s.isNotEmpty && c.isNotEmpty && a.isNotEmpty) {
      add('$s، $c، $a');
      add('$c، $a');
    } else if (c.isNotEmpty && a.isNotEmpty) {
      add('$c، $a');
    }
    if (a.isNotEmpty) add(a);

    return out;
  }

  String _cleanPart(String raw) {
    return raw
        .replaceAll('\uFEFF', '')
        .replaceAll('ي', 'ی')
        .replaceAll('ك', 'ک')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String normalizeAddress(String raw) {
    var out = _cleanPart(raw)
        .replaceAll('میدان مرکزی میوه وتر', 'میدان مرکزی میوه و تره بار')
        .replaceAll('میوه وتربار', 'میوه و تره بار')
        .replaceAll(RegExp(r'[-–—]+'), '، ')
        .replaceAll('/', '، ')
        .replaceAll(RegExp(r'[()]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    out = out.replaceAll(RegExp(r'\s*،\s*'), '، ');
    out = out.replaceAll(RegExp(r'(،\s*)+'), '، ');
    return out;
  }
}
