import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:injast_admin/file_management/map_ir_config.dart';

/// لایهٔ تایل raster رسمی map.ir.
class MapIrTileLayer extends StatelessWidget {
  const MapIrTileLayer({super.key});

  @override
  Widget build(BuildContext context) {
    return TileLayer(
      urlTemplate: MapIrConfig.tileUrlTemplate,
      maxZoom: 20,
      userAgentPackageName: 'com.example.injast_admin',
      tileProvider: _ValidatedNetworkTileProvider(
        headers: MapIrConfig.tileHeaders,
        fallbackUrlsForTile: _fallbackOsmUrls,
      ),
    );
  }
}

/// لایهٔ OSM با provider سفارشی و لاگ برای عیب‌یابی صفحهٔ بازرسی.
class DiagnosticOsmTileLayer extends StatelessWidget {
  const DiagnosticOsmTileLayer({super.key});

  static const _inspectionUrlTemplate =
      'https://a.basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png';

  @override
  Widget build(BuildContext context) {
    return TileLayer(
      urlTemplate: _inspectionUrlTemplate,
      maxZoom: 20,
      userAgentPackageName: 'com.example.injast_admin',
      tileProvider: _ValidatedNetworkTileProvider(
        headers: _defaultTileHeaders(),
        fallbackUrlsForTile: _inspectionTileFallbackUrls,
      ),
    );
  }
}

/// همان منبع نقشه‌ای که در پروژهٔ قدیمیِ بازرسی استفاده می‌شد.
class LegacyBazrasiTileLayer extends StatelessWidget {
  const LegacyBazrasiTileLayer({super.key});

  static const _legacyBazrasiTileUrlTemplate =
      'https://memaps.ir/hot/{z}/{x}/{y}.png';

  @override
  Widget build(BuildContext context) {
    return TileLayer(
      urlTemplate: _legacyBazrasiTileUrlTemplate,
      additionalOptions: {
        'apikey': MapIrConfig.apiKey,
      },
      userAgentPackageName: 'com.example.injast_admin',
      tileProvider: _ValidatedNetworkTileProvider(
        headers: _defaultTileHeaders(),
        fallbackUrlsForTile: _inspectionTileFallbackUrls,
      ),
    );
  }
}

final Uint8List _transparentTilePng = Uint8List.fromList([
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x06,
  0x00,
  0x00,
  0x00,
  0x1F,
  0x15,
  0xC4,
  0x89,
  0x00,
  0x00,
  0x00,
  0x0A,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0x9C,
  0x63,
  0x00,
  0x01,
  0x00,
  0x00,
  0x05,
  0x00,
  0x01,
  0x0D,
  0x0A,
  0x2D,
  0xB4,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4E,
  0x44,
  0xAE,
  0x42,
  0x60,
  0x82,
]);

class _ValidatedNetworkTileProvider extends NetworkTileProvider {
  _ValidatedNetworkTileProvider({
    super.headers,
    this.fallbackUrlsForTile,
  });

  final List<String> Function(String url)? fallbackUrlsForTile;

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    final tileUrl = getTileUrl(coordinates, options);
    return _ValidatedMapImageProvider(
      url: tileUrl,
      headers: headers,
      httpClient: httpClient,
      fallbackUrls: fallbackUrlsForTile?.call(tileUrl) ?? const [],
    );
  }
}

@immutable
class _ValidatedMapImageProvider
    extends ImageProvider<_ValidatedMapImageProvider> {
  const _ValidatedMapImageProvider({
    required this.url,
    required this.headers,
    required this.httpClient,
    required this.fallbackUrls,
  });

  final String url;
  final Map<String, String>? headers;
  final http.BaseClient httpClient;
  final List<String> fallbackUrls;

  @override
  Future<_ValidatedMapImageProvider> obtainKey(
          ImageConfiguration configuration) =>
      SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(
    _ValidatedMapImageProvider key,
    ImageDecoderCallback decode,
  ) {
    return MultiFrameImageStreamCompleter(
      codec: _loadAsync(decode),
      scale: 1,
      debugLabel: url,
    );
  }

  Future<Codec> _loadAsync(ImageDecoderCallback decode) async {
    try {
      final fetched = await httpClient
          .readBytes(Uri.parse(url), headers: headers)
          .timeout(MapIrConfig.geocodeTimeout);
      final codec = await _tryDecodeBytes(fetched, decode);
      if (codec != null) {
        return codec;
      }
    } catch (_) {
      // Ignore invalid primary tiles and continue to fallbacks.
    }

    if (fallbackUrls.isNotEmpty) {
      for (var i = 0; i < fallbackUrls.length; i += 1) {
        final resolvedFallbackUrl = fallbackUrls[i];
        try {
          final fetched = await httpClient.readBytes(
            Uri.parse(resolvedFallbackUrl),
            headers: _defaultTileHeaders(),
          ).timeout(MapIrConfig.geocodeTimeout);
          final codec = await _tryDecodeBytes(fetched, decode);
          if (codec != null) {
            return codec;
          }
        } catch (_) {
          // Ignore invalid fallback tiles and continue to the next source.
        }
      }
    }

    return decode(await ImmutableBuffer.fromUint8List(_transparentTilePng));
  }

  Future<Codec?> _tryDecodeBytes(
    Uint8List bytes,
    ImageDecoderCallback decode,
  ) async {
    if (bytes.isEmpty) return null;
    try {
      return decode(await ImmutableBuffer.fromUint8List(bytes));
    } catch (_) {
      return null;
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is _ValidatedMapImageProvider && url == other.url);

  @override
  int get hashCode => url.hashCode;
}

Map<String, String> _defaultTileHeaders() => {
      'User-Agent': MapIrConfig.userAgent,
      'Accept': 'image/png,image/jpeg,image/webp,image/*,*/*',
    };

({String z, String x, String y})? _extractTileCoordinates(String originalUrl) {
  final uri = Uri.tryParse(originalUrl);
  if (uri == null) {
    return null;
  }
  final match =
      RegExp(r'/(\d+)/(\d+)/(\d+)\.png$', caseSensitive: false).firstMatch(
    uri.path,
  );
  if (match == null) {
    return null;
  }
  final z = match.group(1);
  final x = match.group(2);
  final y = match.group(3);
  if (z == null || x == null || y == null) {
    return null;
  }
  return (z: z, x: x, y: y);
}

List<String> _fallbackOsmUrls(String originalUrl) {
  final coords = _extractTileCoordinates(originalUrl);
  if (coords == null) {
    return const [];
  }
  final z = coords.z;
  final x = coords.x;
  final y = coords.y;
  return [
    'https://tile.openstreetmap.org/$z/$x/$y.png',
    'https://tile.openstreetmap.de/$z/$x/$y.png',
    'https://a.tile.openstreetmap.fr/hot/$z/$x/$y.png',
  ];
}

List<String> _inspectionTileFallbackUrls(String originalUrl) {
  final coords = _extractTileCoordinates(originalUrl);
  if (coords == null) {
    return const [];
  }
  final z = coords.z;
  final x = coords.x;
  final y = coords.y;
  return [
    'https://b.basemaps.cartocdn.com/light_all/$z/$x/$y.png',
    'https://tile.openstreetmap.de/$z/$x/$y.png',
    'https://a.tile.openstreetmap.fr/hot/$z/$x/$y.png',
    'https://tile.openstreetmap.org/$z/$x/$y.png',
  ];
}
