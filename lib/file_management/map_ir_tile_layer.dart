import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:injast_admin/file_management/map_ir_config.dart';

const String _osmTileUrlTemplate =
    'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

/// لایهٔ تایل — OSM رایگان (کلید Map.ir و Carto منقضی/پولی شده‌اند).
class MapIrTileLayer extends StatelessWidget {
  const MapIrTileLayer({super.key});

  @override
  Widget build(BuildContext context) => const _OsmTileLayer();
}

/// لایهٔ OSM برای عیب‌یابی صفحهٔ بازرسی.
class DiagnosticOsmTileLayer extends StatelessWidget {
  const DiagnosticOsmTileLayer({super.key});

  @override
  Widget build(BuildContext context) => const _OsmTileLayer();
}

/// لایهٔ نقشهٔ بازرسی / پرونده.
class LegacyBazrasiTileLayer extends StatelessWidget {
  const LegacyBazrasiTileLayer({super.key});

  @override
  Widget build(BuildContext context) => const _OsmTileLayer();
}

class _OsmTileLayer extends StatelessWidget {
  const _OsmTileLayer();

  @override
  Widget build(BuildContext context) {
    return TileLayer(
      urlTemplate: _osmTileUrlTemplate,
      maxZoom: 19,
      userAgentPackageName: 'ir.injast.admin',
      tileProvider: _ValidatedNetworkTileProvider(
        headers: _defaultTileHeaders(),
        fallbackUrlsForTile: _fallbackOsmUrls,
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
      if (_looksLikeKeyRequiredTile(fetched)) {
        throw StateError('tile vendor requires api key');
      }
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
          if (_looksLikeKeyRequiredTile(fetched)) {
            continue;
          }
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
      'User-Agent': 'InjastAdmin/1.0 (desktop; http://injast-web.ir)',
      'Accept': 'image/png,image/jpeg,image/webp,image/*,*/*',
    };

/// Carto و بعضی CDNها به‌جای ۴۰۳ یک PNG با متن «API KEY REQUIRED» می‌دهند.
bool _looksLikeKeyRequiredTile(Uint8List bytes) {
  if (bytes.isEmpty) return true;
  final sample = bytes.length > 800 ? bytes.sublist(0, 800) : bytes;
  final text = String.fromCharCodes(
    sample.where((b) => b >= 0x20 && b <= 0x7E),
  ).toLowerCase();
  return text.contains('api key required') ||
      text.contains('apikey') && text.contains('carto');
}

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
    'https://tile.openstreetmap.de/$z/$x/$y.png',
    'https://a.tile.openstreetmap.fr/hot/$z/$x/$y.png',
    'https://b.tile.openstreetmap.fr/hot/$z/$x/$y.png',
    'https://server.arcgisonline.com/ArcGIS/rest/services/World_Street_Map/MapServer/tile/$z/$y/$x',
  ];
}
