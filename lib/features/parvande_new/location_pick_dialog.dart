import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:injast_admin/file_management/map_ir_geocoding.dart';
import 'package:injast_admin/file_management/map_ir_tile_layer.dart';
import 'package:injast_admin/features/shared/admin_ui.dart';
import 'package:latlong2/latlong.dart';

class LocationPickResult {
  const LocationPickResult({
    required this.latitude,
    required this.longitude,
    required this.address,
  });

  final double latitude;
  final double longitude;
  final String address;
}

/// دیالوگ انتخاب موقعیت با جابه‌جایی نقشه و آدرس‌یابی معکوس.
class LocationPickDialog extends StatefulWidget {
  const LocationPickDialog({
    super.key,
    this.initialLat,
    this.initialLng,
    this.initialAddress = '',
    this.biasQuery = '',
  });

  final double? initialLat;
  final double? initialLng;
  final String initialAddress;

  /// برای محدود کردن/تقویت جستجو (مثلاً «فارس، شیراز»).
  final String biasQuery;

  static Future<LocationPickResult?> show(
    BuildContext context, {
    double? initialLat,
    double? initialLng,
    String initialAddress = '',
    String biasQuery = '',
  }) {
    return showDialog<LocationPickResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) => LocationPickDialog(
        initialLat: initialLat,
        initialLng: initialLng,
        initialAddress: initialAddress,
        biasQuery: biasQuery,
      ),
    );
  }

  @override
  State<LocationPickDialog> createState() => _LocationPickDialogState();
}

class _LocationPickDialogState extends State<LocationPickDialog> {
  static const _defaultLat = 35.6892;
  static const _defaultLng = 51.3890;

  final _mapController = MapController();
  final _addressCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();
  final _geocoding = MapIrGeocoding.instance;

  Timer? _moveDebounce;
  Timer? _searchDebounce;
  late double _lat;
  late double _lng;
  bool _loadingAddress = false;
  bool _searching = false;
  String? _searchError;
  List<MapIrLocationResult> _suggestions = [];

  @override
  void initState() {
    super.initState();
    _lat = widget.initialLat ?? _defaultLat;
    _lng = widget.initialLng ?? _defaultLng;
    _addressCtrl.text = widget.initialAddress;
    if (widget.initialAddress.trim().isEmpty) {
      _refreshAddress(_lat, _lng);
    }
  }

  @override
  void dispose() {
    _moveDebounce?.cancel();
    _searchDebounce?.cancel();
    _addressCtrl.dispose();
    _searchCtrl.dispose();
    _mapController.dispose();
    super.dispose();
  }

  void _onMapMoved() {
    _moveDebounce?.cancel();
    _moveDebounce = Timer(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      final center = _mapController.camera.center;
      setState(() {
        _lat = center.latitude;
        _lng = center.longitude;
      });
      _refreshAddress(center.latitude, center.longitude);
    });
  }

  Future<void> _refreshAddress(double lat, double lng) async {
    setState(() => _loadingAddress = true);
    try {
      final address = await _geocoding.reverseAddress(lat, lng);
      if (!mounted) return;
      if (address != null && address.trim().isNotEmpty) {
        _addressCtrl.text = address.trim();
      }
    } finally {
      if (mounted) setState(() => _loadingAddress = false);
    }
  }

  void _onSearchChanged(String _) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 550), _runSearch);
  }

  String _effectiveQuery(String raw) {
    final q = raw.trim();
    final bias = widget.biasQuery.trim();
    if (q.isEmpty) return '';
    if (bias.isEmpty) return q;
    if (q.contains(bias)) return q;
    return '$bias، $q';
  }

  Future<void> _runSearch() async {
    final raw = _searchCtrl.text.trim();
    if (raw.isEmpty) {
      setState(() {
        _suggestions = [];
        _searchError = null;
      });
      return;
    }

    setState(() {
      _searching = true;
      _searchError = null;
    });
    try {
      final hits = await _geocoding.searchSuggestions(
        _effectiveQuery(raw),
        limit: 8,
      );
      if (!mounted) return;
      if (hits.isEmpty) {
        // بدون bias هم یک بار امتحان کن
        final plain = await _geocoding.searchSuggestions(raw, limit: 8);
        if (!mounted) return;
        setState(() {
          _suggestions = plain;
          _searchError =
              plain.isEmpty ? 'نتیجه‌ای برای این جستجو یافت نشد' : null;
        });
        return;
      }
      setState(() => _suggestions = hits);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _suggestions = [];
        _searchError = 'خطا در جستجو: $e';
      });
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _applyHit(MapIrLocationResult hit) {
    _mapController.move(LatLng(hit.latitude, hit.longitude), 16);
    setState(() {
      _lat = hit.latitude;
      _lng = hit.longitude;
      _suggestions = [];
      _searchError = null;
    });
    if (hit.address.trim().isNotEmpty) {
      _addressCtrl.text = hit.address.trim();
    } else {
      _refreshAddress(hit.latitude, hit.longitude);
    }
  }

  void _confirm() {
    Navigator.pop(
      context,
      LocationPickResult(
        latitude: _lat,
        longitude: _lng,
        address: _addressCtrl.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final dialogW = size.width > 760 ? 720.0 : size.width * 0.94;
    final mapH = size.height > 700 ? 400.0 : 280.0;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: SizedBox(
          width: dialogW,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 8, 8),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'انتخاب موقعیت روی نقشه',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: AdminUi.ink,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'بستن',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: _onSearchChanged,
                  onSubmitted: (_) => _runSearch(),
                  decoration: AdminUi.fieldDecoration(
                    'جستجوی آدرس',
                    hint: widget.biasQuery.trim().isEmpty
                        ? 'نام محله، خیابان یا نقطه...'
                        : 'جستجو در ${widget.biasQuery}',
                    suffix: _searching
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : IconButton(
                            tooltip: 'جستجو',
                            onPressed: _runSearch,
                            icon: const Icon(Icons.search),
                          ),
                  ),
                ),
              ),
              if (_searchError != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      _searchError!,
                      style: const TextStyle(
                        color: Color(0xFFC62828),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              if (_suggestions.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Container(
                    constraints: const BoxConstraints(maxHeight: 150),
                    decoration: AdminUi.cardDecoration(),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: _suggestions.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final hit = _suggestions[index];
                        return ListTile(
                          dense: true,
                          leading: const Icon(Icons.place_outlined, size: 18),
                          title: Text(
                            hit.address,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () => _applyHit(hit),
                        );
                      },
                    ),
                  ),
                ),
              const SizedBox(height: 10),
              SizedBox(
                height: mapH,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: LatLng(_lat, _lng),
                        initialZoom: 14,
                        onPositionChanged: (_, __) => _onMapMoved(),
                      ),
                      children: const [
                        MapIrTileLayer(),
                      ],
                    ),
                    const IgnorePointer(
                      child: Icon(
                        Icons.location_on,
                        size: 42,
                        color: Color(0xFFC62828),
                      ),
                    ),
                    Positioned(
                      left: 12,
                      bottom: 12,
                      child: Column(
                        children: [
                          _mapBtn(Icons.add, _zoomIn),
                          const SizedBox(height: 6),
                          _mapBtn(Icons.remove, _zoomOut),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'مختصات: ${_lat.toStringAsFixed(6)} ، ${_lng.toStringAsFixed(6)}',
                      style: const TextStyle(
                        color: AdminUi.muted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _addressCtrl,
                      maxLines: 2,
                      decoration: AdminUi.fieldDecoration(
                        'آدرس یافت‌شده',
                        suffix: _loadingAddress
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(
                                  width: 18,
                                  height: 18,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                ),
                              )
                            : const Icon(Icons.place_outlined),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('انصراف'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _confirm,
                        icon: const Icon(Icons.check),
                        label: const Text('تأیید موقعیت'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _zoomIn() {
    final c = _mapController.camera.center;
    _mapController.move(c, _mapController.camera.zoom + 1);
  }

  void _zoomOut() {
    final c = _mapController.camera.center;
    _mapController.move(c, _mapController.camera.zoom - 1);
  }

  Widget _mapBtn(IconData icon, VoidCallback onTap) {
    return Material(
      color: Colors.white,
      elevation: 2,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(icon, size: 20, color: AdminUi.ink),
        ),
      ),
    );
  }
}
