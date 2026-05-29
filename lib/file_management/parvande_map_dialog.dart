import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:injast_admin/file_management/map_ir_geocoding.dart';
import 'package:injast_admin/file_management/map_ir_tile_layer.dart';
import 'package:injast_admin/file_management/parvande_address_search.dart';
import 'package:injast_admin/file_management/parvande_api.dart';
import 'package:latlong2/latlong.dart';

/// نتیجهٔ ذخیره از دیالوگ نقشه؛ آدرس و لوکیشن مستقل از هم ذخیره می‌شوند.
typedef ParvandeMapSaveCallback = Future<void> Function({
  required bool addressChanged,
  required String address,
  required bool locationChanged,
  required double lat,
  required double lng,
});

/// دیالوگ ویرایش/نمایش لوکیشن پرونده با نقشهٔ پایدار.
class ParvandeMapDialog extends StatefulWidget {
  const ParvandeMapDialog({
    super.key,
    required this.parvande,
    required this.onSave,
    required this.unionParvandes,
    this.lastEditorFuture,
    this.currentUserName,
    this.currentUserRole,
  });

  final Map<String, dynamic> parvande;
  final List<Map<String, dynamic>> unionParvandes;
  final ParvandeMapSaveCallback onSave;
  final Future<ParvandeLocationEditor?>? lastEditorFuture;
  final String? currentUserName;
  final String? currentUserRole;

  static Future<void> show(
    BuildContext context, {
    required Map<String, dynamic> parvande,
    required List<Map<String, dynamic>> unionParvandes,
    required ParvandeMapSaveCallback onSave,
    Future<ParvandeLocationEditor?>? lastEditorFuture,
    String? currentUserName,
    String? currentUserRole,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ParvandeMapDialog(
        parvande: parvande,
        unionParvandes: unionParvandes,
        onSave: onSave,
        lastEditorFuture: lastEditorFuture,
        currentUserName: currentUserName,
        currentUserRole: currentUserRole,
      ),
    );
  }

  @override
  State<ParvandeMapDialog> createState() => _ParvandeMapDialogState();
}

class _ParvandeMapDialogState extends State<ParvandeMapDialog> {
  static const _accent = Color(0xFF1E3A5F);
  static const _defaultLat = 35.6892;
  static const _defaultLng = 51.3890;
  static const _locationEpsilon = 0.000001;

  final _mapController = MapController();
  final _searchCtrl = TextEditingController();
  final _currentAddressCtrl = TextEditingController();
  final _searchFocus = FocusNode();
  final _geocoding = MapIrGeocoding.instance;

  Timer? _debounce;
  Timer? _searchDebounce;
  late List<ParvandeAddressHit> _addressIndex;
  List<ParvandeAddressHit> _searchResults = [];
  late double _selectedLat;
  late double _selectedLng;
  late double _originalLat;
  late double _originalLng;
  late final String _originalAddress;
  String _geocodedAddress = '';
  bool _loadingGeocodedAddress = false;
  bool _saving = false;

  Map<String, dynamic> get _p => widget.parvande;

  @override
  void initState() {
    super.initState();
    _addressIndex = ParvandeAddressSearch.instance.buildIndex(widget.unionParvandes);
    final lat = double.tryParse(_p.lat);
    final lng = double.tryParse(_p.lng);
    _selectedLat = lat ?? _defaultLat;
    _selectedLng = lng ?? _defaultLng;
    _originalLat = _selectedLat;
    _originalLng = _selectedLng;
    _originalAddress = _p.address;
    _currentAddressCtrl.text = _originalAddress;
    _refreshGeocodedAddress(_selectedLat, _selectedLng);
    _searchCtrl.addListener(_onSearchTextChanged);
  }

  bool get _addressChanged =>
      _currentAddressCtrl.text.trim() != _originalAddress.trim();

  bool get _locationChanged =>
      (_selectedLat - _originalLat).abs() > _locationEpsilon ||
      (_selectedLng - _originalLng).abs() > _locationEpsilon;

  bool get _hasChanges => _addressChanged || _locationChanged;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchDebounce?.cancel();
    _searchCtrl.removeListener(_onSearchTextChanged);
    _searchCtrl.dispose();
    _currentAddressCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _onSearchTextChanged() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      final results = ParvandeAddressSearch.instance.search(_addressIndex, _searchCtrl.text);
      setState(() => _searchResults = results);
    });
  }

  void _selectAddressHit(ParvandeAddressHit hit) {
    _searchFocus.unfocus();
    _searchCtrl.text = hit.address;
    setState(() => _searchResults = []);
    _mapController.move(LatLng(hit.lat, hit.lng), 15);
    setState(() {
      _selectedLat = hit.lat;
      _selectedLng = hit.lng;
      _geocodedAddress = hit.address;
      _loadingGeocodedAddress = false;
    });
  }

  void _onMapMoved() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      final center = _mapController.camera.center;
      setState(() {
        _selectedLat = center.latitude;
        _selectedLng = center.longitude;
      });
      _refreshGeocodedAddress(center.latitude, center.longitude);
    });
  }

  Future<void> _refreshGeocodedAddress(double lat, double lng) async {
    setState(() => _loadingGeocodedAddress = true);
    try {
      final address = await _geocoding.reverseAddress(lat, lng);
      if (!mounted) return;
      setState(() => _geocodedAddress = address?.trim() ?? '');
    } catch (_) {
      if (mounted) setState(() => _geocodedAddress = '');
    } finally {
      if (mounted) setState(() => _loadingGeocodedAddress = false);
    }
  }

  void _zoomIn() {
    final c = _mapController.camera.center;
    _mapController.move(c, _mapController.camera.zoom + 1);
  }

  void _zoomOut() {
    final c = _mapController.camera.center;
    _mapController.move(c, _mapController.camera.zoom - 1);
  }

  Future<void> _onSave() async {
    if (!_hasChanges) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تغییری برای ذخیره وجود ندارد.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await widget.onSave(
        addressChanged: _addressChanged,
        address: _currentAddressCtrl.text.trim(),
        locationChanged: _locationChanged,
        lat: _selectedLat,
        lng: _selectedLng,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تغییرات با موفقیت ذخیره شد.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطا در ذخیره: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final dialogW = size.width > 720 ? 680.0 : size.width * 0.94;
    final mapH = size.height > 640 ? 360.0 : 280.0;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        width: dialogW,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'نقشه و موقعیت',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: _accent,
                          ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'بستن',
                    onPressed: _saving ? null : () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _searchCtrl,
                    focusNode: _searchFocus,
                    textDirection: TextDirection.rtl,
                    decoration: InputDecoration(
                      labelText: 'جستجو در آدرس پرونده‌های اتحادیه',
                      hintText: 'بخشی از آدرس، نام واحد یا نام متصدی…',
                      border: const OutlineInputBorder(),
                      isDense: true,
                      suffixIcon: _searchCtrl.text.trim().isEmpty
                          ? const Icon(Icons.search, size: 22)
                          : IconButton(
                              icon: const Icon(Icons.clear, size: 20),
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() => _searchResults = []);
                              },
                            ),
                    ),
                  ),
                  if (_searchResults.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 6),
                      constraints: const BoxConstraints(maxHeight: 180),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade300),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x18000000),
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        padding: EdgeInsets.zero,
                        itemCount: _searchResults.length,
                        separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.shade200),
                        itemBuilder: (context, i) {
                          final hit = _searchResults[i];
                          return ListTile(
                            dense: true,
                            title: Text(
                              hit.address,
                              textDirection: TextDirection.rtl,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text(
                              [
                                if (hit.storeName.isNotEmpty) hit.storeName,
                                if (hit.fullName.isNotEmpty) hit.fullName,
                              ].join(' • '),
                              textDirection: TextDirection.rtl,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700),
                            ),
                            leading: const Icon(Icons.location_on_outlined, color: Color(0xFFEF6C00)),
                            onTap: () => _selectAddressHit(hit),
                          );
                        },
                      ),
                    )
                  else if (_searchCtrl.text.trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        _addressIndex.isEmpty
                            ? 'هیچ پرونده‌ای با آدرس و مختصات در این اتحادیه یافت نشد.'
                            : 'آدرس مشابهی در پرونده‌های این اتحادیه پیدا نشد.',
                        textAlign: TextAlign.right,
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  height: mapH,
                  child: Stack(
                    children: [
                      FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          initialCenter: LatLng(_selectedLat, _selectedLng),
                          initialZoom: 14,
                          onPositionChanged: (_, hasGesture) {
                            if (hasGesture) _onMapMoved();
                          },
                        ),
                        children: const [
                          LegacyBazrasiTileLayer(),
                        ],
                      ),
                      const Center(
                        child: Icon(Icons.location_on, color: Colors.red, size: 44),
                      ),
                      Positioned(
                        bottom: 12,
                        left: 12,
                        child: Column(
                          children: [
                            _mapFab(Icons.add, 'زوم +', _zoomIn),
                            const SizedBox(height: 8),
                            _mapFab(Icons.remove, 'زوم −', _zoomOut),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _userInfoSection(),
                    const SizedBox(height: 10),
                    _lastEditorSection(),
                    const SizedBox(height: 12),
                    _editableCurrentAddress(),
                    const SizedBox(height: 10),
                    _readOnlyGeocodedAddress(),
                    const SizedBox(height: 6),
                    Text(
                      'مختصات: ${_selectedLat.toStringAsFixed(6)}, ${_selectedLng.toStringAsFixed(6)}',
                      textAlign: TextAlign.right,
                      style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _saving ? null : () => Navigator.of(context).pop(),
                            child: const Text('لغو'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: _saving || !_hasChanges ? null : _onSave,
                            style: FilledButton.styleFrom(backgroundColor: _accent),
                            child: _saving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text('ذخیره'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _mapFab(IconData icon, String tooltip, VoidCallback onTap) {
    return FloatingActionButton.small(
      heroTag: tooltip,
      tooltip: tooltip,
      onPressed: onTap,
      child: Icon(icon),
    );
  }

  Widget _userInfoSection() {
    final name = widget.currentUserName?.trim();
    final role = widget.currentUserRole?.trim();
    if ((name == null || name.isEmpty) && (role == null || role.isEmpty)) {
      return const SizedBox.shrink();
    }
    return _infoRow(
      icon: Icons.person_outline,
      label: 'کاربر فعلی',
      value: [
        if (name != null && name.isNotEmpty) name,
        if (role != null && role.isNotEmpty) role,
      ].join(' — '),
    );
  }

  Widget _lastEditorSection() {
    final future = widget.lastEditorFuture;
    if (future == null) return const SizedBox.shrink();

    return FutureBuilder<ParvandeLocationEditor?>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _infoRow(
            icon: Icons.history,
            label: 'آخرین ویرایش‌کننده',
            value: 'در حال بارگذاری…',
            muted: true,
          );
        }
        final editor = snapshot.data;
        if (editor == null) return const SizedBox.shrink();
        return _infoRow(
          icon: Icons.history,
          label: 'آخرین ویرایش‌کننده',
          value: '${editor.displayName} — ${editor.roleLabel}',
        );
      },
    );
  }

  Widget _infoRow({
    required IconData icon,
    required String label,
    required String value,
    bool muted = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            textDirection: TextDirection.rtl,
            text: TextSpan(
              style: TextStyle(
                fontSize: 12,
                color: muted ? Colors.grey.shade500 : Colors.grey.shade800,
                height: 1.4,
              ),
              children: [
                TextSpan(
                  text: '$label: ',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                TextSpan(text: value),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _editableCurrentAddress() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'آدرس فعلی (آدرس اصلی سیستم)',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: _currentAddressCtrl,
          textDirection: TextDirection.rtl,
          maxLines: 3,
          minLines: 2,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'آدرس ثبت‌شده در سیستم — فقط با ویرایش دستی تغییر می‌کند',
            border: const OutlineInputBorder(),
            isDense: true,
            filled: true,
            fillColor: Colors.grey.shade50,
            suffixIcon: _addressChanged
                ? const Icon(Icons.edit, size: 18, color: Color(0xFFEF6C00))
                : null,
          ),
        ),
      ],
    );
  }

  Widget _readOnlyGeocodedAddress() {
    String value;
    if (_loadingGeocodedAddress) {
      value = 'در حال دریافت آدرس…';
    } else if (_geocodedAddress.isEmpty) {
      value = '—';
    } else {
      value = _geocodedAddress;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'آدرس جدید (بر اساس موقعیت نقشه)',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.shade100),
          ),
          child: Text(
            value,
            textDirection: TextDirection.rtl,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13.5,
              color: _loadingGeocodedAddress ? Colors.grey.shade600 : Colors.black87,
            ),
          ),
        ),
      ],
    );
  }
}
