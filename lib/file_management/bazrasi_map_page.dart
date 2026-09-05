import 'dart:async';
import 'dart:math' as math;

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:geolocator/geolocator.dart';
import 'package:injast_admin/file_management/bazrasi_records_sheet.dart';
import 'package:injast_admin/file_management/map_ir_tile_layer.dart';
import 'package:injast_admin/file_management/new_bazrasi_sheet.dart';
import 'package:injast_admin/file_management/parvande_api.dart';
import 'package:injast_admin/file_management/parvande_card.dart';
import 'package:injast_admin/file_management/parvande_details_dialog.dart';
import 'package:injast_admin/file_management/parvande_documents_sheet.dart';
import 'package:injast_admin/file_management/excel_import/excel_import_shenase.dart';
import 'package:injast_admin/file_management/hagh_ozviat_api.dart';
import 'package:injast_admin/file_management/hagh_ozviat_member_dialog.dart';
import 'package:injast_admin/file_management/hagh_ozviat_member_index.dart';
import 'package:injast_admin/file_management/iran_region_bounds.dart';
import 'package:injast_admin/file_management/parvande_full_edit_page.dart';
import 'package:injast_admin/pos_web_service.dart';
import 'package:injast_admin/file_management/parvande_license_dialog.dart';
import 'package:injast_admin/file_management/parvande_map_dialog.dart';
import 'package:injast_admin/file_management/parvande_permissions.dart';
import 'package:injast_admin/file_management/parvande_quick_edit_dialog.dart';
import 'package:injast_admin/file_management/parvande_sharik_hub_sheet.dart';
import 'package:injast_admin/file_management/parvande_store_images_sheet.dart';
import 'package:injast_admin/file_management/parvande_vaziyat.dart';
import 'package:injast_admin/file_management/placeholders/feature_placeholder_page.dart';
import 'package:injast_admin/import_sync/import_models.dart';
import 'package:injast_admin/local_cache/network_reachability.dart';
import 'package:injast_admin/local_cache/parvande_cache_list_service.dart';
import 'package:injast_admin/local_cache/parvande_local_repository.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

class BazrasiMapPage extends StatefulWidget {
  const BazrasiMapPage({
    super.key,
    required this.codeCo,
    this.currentUserId,
    this.currentUserName,
    this.currentUserRole,
    this.currentUserType,
    this.isSuperAdmin = false,
    this.sessionUser,
  });

  final String codeCo;
  final String? currentUserId;
  final String? currentUserName;
  final String? currentUserRole;
  final String? currentUserType;
  final bool isSuperAdmin;
  final Map<String, dynamic>? sessionUser;

  @override
  State<BazrasiMapPage> createState() => _BazrasiMapPageState();
}

class _BazrasiMapPageState extends State<BazrasiMapPage> {
  static const _accent = Color(0xFF1E3A5F);
  static const _deep = Color(0xFF0E1B2D);
  static const _defaultCenter = LatLng(32.4279, 53.6880);
  static const _allRasteFilter = 'همه رسته‌ها';
  static const _allDebtFilter = 'همه اعضا';
  static const _allStatusFilter = 'همه وضعیت‌ها';
  static const _searchFields = <String>[
    'mob_admin',
    'name_admin',
    'family_admin',
    'code_meli_admin',
    'name_store',
    'shenase_store',
    'raste_store',
    'code_posti_store',
    'num_parvande_store',
    'city_store',
  ];

  final _api = ParvandeApi.instance;
  final _cacheList = ParvandeCacheListService.instance;
  final _mapController = MapController();
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();

  Timer? _moveDebounce;
  List<Map<String, dynamic>> _rows = [];
  List<Map<String, dynamic>> _searchPool = [];
  List<Marker> _markers = [];
  bool _loading = true;
  bool _initialLoading = true;
  bool _offlineData = false;
  bool _offlineMode = false;
  bool _isMapReady = false;
  bool _findingMyLocation = false;
  bool _didAutoCenter = false;
  double _progress = 0.0;
  int _loadedPoints = 0;
  int _totalPoints = 0;
  double _currentZoom = 5.6;
  String _loadingText = 'در حال آماده‌سازی نقشه...';
  String? _boundsFingerprint;
  String? _loadError;
  LatLng? _myLocation;
  bool _preferOfflineMode = false;
  bool _onlineAvailable = true;
  bool _switchingMode = false;
  String? _highlightedParvandeId;
  bool _serverLossNoticeShown = false;
  String _selectedRaste = _allRasteFilter;
  String _selectedDebt = _allDebtFilter;
  String _selectedStatus = _allStatusFilter;
  bool _insideRegion = true;
  Map<String, HaghOzviatMemberIndex> _haghIndex = {};
  bool _haghIndexLoaded = false;

  bool get _canEditParvande => ParvandePermissions.canEditParvande(
        role: widget.currentUserType ?? widget.currentUserRole,
        isSuperAdmin: widget.isSuperAdmin,
      );

  bool get _hasActiveFilters =>
      _selectedRaste != _allRasteFilter ||
      _selectedDebt != _allDebtFilter ||
      _selectedStatus != _allStatusFilter ||
      !_insideRegion;

  List<String> get _rasteOptions {
    final values = (_searchPool.isEmpty ? _rows : _searchPool)
        .map((e) => e.raste.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return [_allRasteFilter, ...values];
  }

  List<String> get _statusOptions {
    final values = (_searchPool.isEmpty ? _rows : _searchPool)
        .map(_statusLabelFor)
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return [_allStatusFilter, ...values];
  }

  List<Map<String, dynamic>> get _filteredViewportRows =>
      _applyFilters(_rows, applyRegion: true);

  List<Map<String, dynamic>> get _filteredSearchPool => _applyFilters(
        _searchPool.isEmpty ? _rows : _searchPool,
        applyRegion: false,
      );

  List<Map<String, dynamic>> get _searchResults {
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) return const [];
    return _filteredSearchPool
        .where((item) {
          final bag = _searchFields
              .map((f) => item[f]?.toString().trim() ?? '')
              .join(' ')
              .toLowerCase();
          return bag.contains(q);
        })
        .take(8)
        .toList();
  }

  List<Map<String, dynamic>> _applyFilters(
    List<Map<String, dynamic>> source, {
    bool applyRegion = true,
  }) {
    return source.where((item) {
      if (_selectedRaste != _allRasteFilter && item.raste != _selectedRaste) {
        return false;
      }
      if (_selectedDebt == 'دارای بدهی' && !_hasMemberDebt(item)) {
        return false;
      }
      if (_selectedDebt == 'بدون بدهی' && _hasMemberDebt(item)) {
        return false;
      }
      if (_selectedStatus != _allStatusFilter &&
          _statusLabelFor(item) != _selectedStatus) {
        return false;
      }
      if (applyRegion && !_matchesRegionFilter(item)) {
        return false;
      }
      return true;
    }).toList();
  }

  ({String? state, String? city}) _unionPlace() {
    final union = PosWebService.instance.unionInfo;
    final user = widget.sessionUser;
    String? pick(List<String?> values) {
      for (final v in values) {
        final t = v?.trim() ?? '';
        if (t.isNotEmpty && t.toLowerCase() != 'null') return t;
      }
      return null;
    }

    return (
      state: pick([
        union?['state_co']?.toString(),
        user?['state_co']?.toString(),
        user?['state_user']?.toString(),
      ]),
      city: pick([
        union?['city_co']?.toString(),
        user?['city_co']?.toString(),
        user?['city_user']?.toString(),
      ]),
    );
  }

  bool _matchesRegionFilter(Map<String, dynamic> item) {
    final place = _unionPlace();
    final box = regionBoxFor(state: place.state, city: place.city);
    if (box == null) return true;
    final lat = double.tryParse(item.lat);
    final lon = double.tryParse(item.lng);
    if (lat == null || lon == null) return false;
    final inside = box.contains(lat, lon);
    return _insideRegion ? inside : !inside;
  }

  String _statusLabelFor(Map<String, dynamic> item) {
    final label = item.vaziyat.trim();
    if (label.isNotEmpty) return ParvandeVaziyat.normalizeLabel(label);
    return ParvandeVaziyat.labelForRow(item).trim();
  }

  double _moneyValue(Map<String, dynamic> item) {
    final raw = item.s('money').replaceAll(',', '').trim();
    if (raw.isEmpty || raw.toLowerCase() == 'null') return 0;
    return double.tryParse(raw) ?? 0;
  }

  /// همان منطق کارت پرونده و دیالگ حق عضویت: `pending_rial` از index سرور.
  bool _hasMemberDebt(Map<String, dynamic> item) {
    if (_haghIndexLoaded) {
      final idx = _haghFor(item);
      if (idx != null && idx.hasRecords) {
        return idx.hasPendingDebt;
      }
      return false;
    }
    return _moneyValue(item) > 0;
  }

  void _onFiltersChanged() {
    setState(() {});
    _rebuildMarkers(autoCenter: false);
  }

  void _resetFilters() {
    _selectedRaste = _allRasteFilter;
    _selectedDebt = _allDebtFilter;
    _selectedStatus = _allStatusFilter;
    _insideRegion = true;
    _onFiltersChanged();
  }

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _moveDebounce?.cancel();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    await _loadMarkersForCurrentView(initial: true, force: true);
  }

  LatLngBounds? _currentBounds() {
    if (!_isMapReady) return null;
    return _mapController.camera.visibleBounds;
  }

  String _fingerprintForBounds(LatLngBounds? bounds) {
    if (bounds == null) return 'all';
    return [
      bounds.north.toStringAsFixed(2),
      bounds.south.toStringAsFixed(2),
      bounds.east.toStringAsFixed(2),
      bounds.west.toStringAsFixed(2),
    ].join('|');
  }

  Future<void> _loadMarkersForCurrentView({
    bool initial = false,
    bool force = false,
  }) async {
    final bounds = _currentBounds();
    final fingerprint = _fingerprintForBounds(bounds);
    if (!force &&
        _isMapReady &&
        _boundsFingerprint == fingerprint &&
        !_offlineMode) {
      return;
    }
    if (mounted) {
      setState(() {
        _loading = true;
        if (initial) _initialLoading = true;
        _loadError = null;
        _progress = 0.14;
        _loadedPoints = 0;
        _totalPoints = 0;
        _loadingText = 'در حال دریافت پرونده‌های بازرسی...';
      });
    }
    try {
      List<Map<String, dynamic>> data;
      if (_preferOfflineMode) {
        data = await _cacheList.fetchAllFromCache(widget.codeCo);
        _offlineData = true;
        _offlineMode = true;
      } else {
        try {
          data = await _cacheList.mergeSyncStatusFromCache(
            widget.codeCo,
            await _api.fetchInspectionMapData(
              codeCo: widget.codeCo,
              userContext: widget.sessionUser,
              bounds: bounds,
            ),
          );
          _onlineAvailable = true;
          _offlineData = false;
          _offlineMode = false;
          _serverLossNoticeShown = false;
        } catch (_) {
          _onlineAvailable = false;
          final hasCurrentData =
              _rows.isNotEmpty || _markers.isNotEmpty || _searchPool.isNotEmpty;
          if (hasCurrentData && !initial) {
            _loadingText =
                'ارتباط با سرور موقتاً قطع شد؛ داده‌های فعلی نقشه حفظ شدند.';
            if (mounted && !_serverLossNoticeShown) {
              _serverLossNoticeShown = true;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'اتصال سرور لحظه‌ای قطع شد؛ برای جلوگیری از محو شدن نقاط، داده‌های فعلی نقشه نگه داشته شدند.',
                  ),
                ),
              );
            }
            return;
          }
          data = await _cacheList.fetchAllFromCache(widget.codeCo);
          _offlineData = true;
          _offlineMode = true;
          if (mounted && data.isNotEmpty && !_serverLossNoticeShown) {
            _serverLossNoticeShown = true;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'سرور در دسترس نبود؛ فعلاً داده‌های محلی نمایش داده شد.',
                ),
              ),
            );
          }
        }
      }

      final activeRows = data.where((e) => !e.isTrash).toList();
      _rows = activeRows;
      _searchPool = List<Map<String, dynamic>>.from(activeRows);
      if (_highlightedParvandeId != null &&
          !_searchPool.any((e) => e.idParvandeh == _highlightedParvandeId)) {
        _highlightedParvandeId = null;
      }
      _boundsFingerprint = fingerprint;
      if (!_offlineData) {
        await _loadHaghIndex();
      } else if (mounted) {
        setState(() {
          _haghIndex = {};
          _haghIndexLoaded = false;
        });
      }
      _loadingText = 'در حال ساخت مارکرها...';
      await _rebuildMarkers(autoCenter: initial);
      if (_searchPool.isEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _offlineMode
                  ? 'هیچ پرونده‌ای در حافظهٔ محلی برای نقشه بازرسی پیدا نشد.'
                  : 'پرونده‌ای برای نمایش روی نقشه بازرسی پیدا نشد.',
            ),
          ),
        );
      }
    } catch (e) {
      _loadError = e.toString();
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _initialLoading = false;
          _progress = 1.0;
          _loadingText = _loadError ?? 'آماده';
        });
      }
    }
  }

  Future<void> _switchDataMode(bool preferOffline) async {
    if (_switchingMode) return;
    if (!preferOffline) {
      final online = await NetworkReachability.instance.isServerReachable();
      if (!online) {
        if (mounted) {
          setState(() => _onlineAvailable = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'سرور در دسترس نیست؛ تا برقراری اتصال، فقط حالت محلی قابل استفاده است.',
              ),
            ),
          );
        }
        return;
      }
      _onlineAvailable = true;
    }
    if (_preferOfflineMode == preferOffline &&
        (preferOffline || _offlineMode == false)) {
      return;
    }
    setState(() {
      _preferOfflineMode = preferOffline;
      _switchingMode = true;
    });
    try {
      await _loadMarkersForCurrentView(force: true);
    } finally {
      if (mounted) {
        setState(() => _switchingMode = false);
      }
    }
  }

  Future<void> _rebuildMarkers({required bool autoCenter}) async {
    final markers = <Marker>[];
    final validRows =
        _filteredViewportRows.where((e) => e.hasLocation).toList();
    _totalPoints = validRows.length;
    _loadedPoints = 0;

    for (final item in validRows) {
      final lat = double.tryParse(item.lat);
      final lng = double.tryParse(item.lng);
      if (lat == null || lng == null) continue;
      final highlighted = item.idParvandeh == _highlightedParvandeId;
      markers.add(
        Marker(
          width: highlighted ? 84 : 56,
          height: highlighted ? 98 : 66,
          point: LatLng(lat, lng),
          child: GestureDetector(
            onTap: () {
              setState(() => _highlightedParvandeId = item.idParvandeh);
              _showParvandeCardSheet(item);
            },
            child: _InspectionMarker(
              color: _markerColorForVaziyat(item.vaziyatCode),
              editedLocation: item.s('edit_location') == '1',
              highlighted: highlighted,
            ),
          ),
        ),
      );

      _loadedPoints++;
      if (mounted &&
          (_loadedPoints == _totalPoints || _loadedPoints % 50 == 0)) {
        setState(() {
          _progress = _totalPoints == 0
              ? 0.82
              : 0.30 + (_loadedPoints / _totalPoints) * 0.62;
        });
      }
    }

    if (mounted) {
      setState(() {
        _markers = markers;
        _progress = markers.isEmpty ? 0.84 : 0.94;
        _loadingText = markers.isEmpty
            ? 'نقطه‌ای با مختصات معتبر یافت نشد.'
            : 'در حال نمایش نقشه...';
      });
    }
    if (autoCenter && !_didAutoCenter && markers.isNotEmpty) {
      _autoCenterOnRows(validRows);
    }
  }

  void _autoCenterOnRows(List<Map<String, dynamic>> rows) {
    if (!_isMapReady || rows.isEmpty) return;
    double latSum = 0;
    double lngSum = 0;
    var count = 0;
    for (final row in rows) {
      final lat = double.tryParse(row.lat);
      final lng = double.tryParse(row.lng);
      if (lat == null || lng == null) continue;
      latSum += lat;
      lngSum += lng;
      count++;
    }
    if (count == 0) return;
    final target = LatLng(latSum / count, lngSum / count);
    final zoom = count == 1
        ? 16.0
        : count < 20
            ? 12.5
            : count < 120
                ? 10.5
                : 8.0;
    _mapController.move(target, zoom);
    _currentZoom = zoom;
    _didAutoCenter = true;
  }

  Color _markerColorForVaziyat(String value) {
    switch (value.trim()) {
      case '1':
        return const Color(0xFFF9A825);
      case '2':
        return const Color(0xFF2E7D32);
      case '3':
      case '10':
      case '11':
      case '12':
        return const Color(0xFFC62828);
      case '5':
      case '6':
      case '8':
        return Colors.black;
      case '4':
      case '7':
        return const Color(0xFFEF6C00);
      default:
        return const Color(0xFF757575);
    }
  }

  void _onMapPositionChanged(MapPosition position, bool hasGesture) {
    _currentZoom = position.zoom ?? _currentZoom;
    if (!hasGesture || _offlineMode) return;
    _moveDebounce?.cancel();
    _moveDebounce = Timer(
      const Duration(milliseconds: 500),
      () => _loadMarkersForCurrentView(),
    );
  }

  Future<void> _moveToMyLocation() async {
    if (_findingMyLocation) return;
    setState(() => _findingMyLocation = true);
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        throw Exception('سرویس موقعیت دستگاه خاموش است.');
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception('دسترسی موقعیت جغرافیایی صادر نشد.');
      }
      final pos = await Geolocator.getCurrentPosition();
      final target = LatLng(pos.latitude, pos.longitude);
      setState(() => _myLocation = target);
      _mapController.move(target, 16);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطا در موقعیت‌یابی: $e')),
      );
    } finally {
      if (mounted) setState(() => _findingMyLocation = false);
    }
  }

  void _focusSearch() {
    FocusScope.of(context).requestFocus(_searchFocus);
  }

  void _selectSearchResult(Map<String, dynamic> item) {
    _searchFocus.unfocus();
    final lat = double.tryParse(item.lat);
    final lng = double.tryParse(item.lng);
    _highlightedParvandeId = item.idParvandeh;
    if (lat != null && lng != null) {
      _mapController.move(LatLng(lat, lng), math.max(_currentZoom, 17.5));
    }
    _searchCtrl.clear();
    setState(() {});
    _showParvandeCardSheet(item);
  }

  void _offlineOnlySnack() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
            'این عملیات در حالت آفلاین فقط از حافظهٔ محلی است و به سرور نیاز دارد.'),
      ),
    );
  }

  Map<String, dynamic>? _findRowById(String idParvandeh) {
    for (final item in _searchPool) {
      if (item.idParvandeh == idParvandeh) return item;
    }
    for (final item in _rows) {
      if (item.idParvandeh == idParvandeh) return item;
    }
    return null;
  }

  Future<void> _openFullEdit(Map<String, dynamic> p) async {
    if (_offlineData) {
      _offlineOnlySnack();
      return;
    }
    final saved = await ParvandeFullEditPage.open(
      context,
      codeCo: widget.codeCo,
      parvande: p,
      allParvandes: _searchPool.isEmpty ? _rows : _searchPool,
      currentUserId: widget.currentUserId,
      currentUserName: widget.currentUserName,
      currentUserRole: widget.currentUserRole,
    );
    if (saved == true && mounted) {
      await _loadMarkersForCurrentView(force: true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('پرونده با موفقیت ویرایش شد.')),
      );
    }
  }

  Future<void> _openEdit(Map<String, dynamic> p) async {
    if (_offlineData) {
      _offlineOnlySnack();
      return;
    }
    final saved = await ParvandeQuickEditDialog.show(
      context,
      parvande: p,
      onFullEdit: () => _openFullEdit(p),
    );
    if (saved == true && mounted) {
      await _loadMarkersForCurrentView(force: true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اطلاعات پرونده بروزرسانی شد.')),
      );
    }
  }

  Future<void> _call(String phone) async {
    if (phone.trim().isEmpty) return;
    await launchUrl(Uri.parse('tel:${phone.trim()}'));
  }

  Future<void> _sms(String phone) async {
    if (phone.trim().isEmpty) return;
    await launchUrl(Uri.parse('sms:${phone.trim()}'));
  }

  Future<void> _map(Map<String, dynamic> p) async {
    await ParvandeMapDialog.show(
      context,
      parvande: p,
      unionParvandes: _searchPool.isEmpty ? _rows : _searchPool,
      currentUserName: widget.currentUserName,
      currentUserRole: widget.currentUserRole,
      lastEditorFuture: _offlineData
          ? Future.value(null)
          : _api.fetchLocationEditor(p.idParvandeh),
      onSave: ({
        required addressChanged,
        required address,
        required locationChanged,
        required lat,
        required lng,
      }) =>
          _saveLocation(
        p,
        addressChanged: addressChanged,
        address: address,
        locationChanged: locationChanged,
        lat: lat,
        lng: lng,
      ),
    );
  }

  Future<void> _saveLocation(
    Map<String, dynamic> p, {
    required bool addressChanged,
    required String address,
    required bool locationChanged,
    required double lat,
    required double lng,
  }) async {
    final latStr = lat.toString();
    final lngStr = lng.toString();
    final addressStr = address.trim();

    if (!_offlineData) {
      if (addressChanged && locationChanged) {
        await _api.updateParvandeAddressAndLocation(
          parvande: p,
          address: addressStr,
          lat: latStr,
          lng: lngStr,
          idUser: widget.currentUserId,
          keepEditLocation: widget.isSuperAdmin,
        );
      } else if (addressChanged) {
        await _api.updateParvandeAddressOnly(
          parvande: p,
          address: addressStr,
        );
      } else if (locationChanged) {
        await _api.updateStoreLocation(
          idParvandeh: p.idParvandeh,
          lat: latStr,
          lng: lngStr,
          idUser: widget.currentUserId,
          keepEditLocation: widget.isSuperAdmin,
        );
      }
    }

    if (addressChanged && addressStr.isNotEmpty) {
      p['address_store'] = addressStr;
    }
    if (locationChanged) {
      p['lat_store'] = latStr;
      p['long_store'] = lngStr;
      p['edit_location'] = widget.isSuperAdmin ? p['edit_location'] : '1';
    }

    await _persistParvandeLocally(p, markSynced: !_offlineData);

    if (_offlineData && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'آدرس/لوکیشن در حافظهٔ محلی ذخیره شد؛ پس از اتصال ارسال کنید.'),
        ),
      );
    }
    await _loadMarkersForCurrentView(force: true);
  }

  Future<void> _persistParvandeLocally(
    Map<String, dynamic> p, {
    required bool markSynced,
  }) async {
    final payload =
        p.map((k, v) => MapEntry(k.toString(), v?.toString() ?? ''));
    payload['code_co'] = widget.codeCo;
    payload.remove('_sync_status');

    await ParvandeLocalRepository.instance.upsertFromImportRecord(
      codeCo: widget.codeCo,
      record: ImportDraftRecord(
        clientTempId: p.idParvandeh,
        payload: payload,
      ),
      downloadImages: false,
    );
    if (markSynced) {
      await ParvandeLocalRepository.instance
          .markSynced(widget.codeCo, p.idParvandeh);
    }
  }

  Future<void> _markParvandeDirty(Map<String, dynamic> p) async {
    await _persistParvandeLocally(p, markSynced: false);
    if (mounted) setState(() {});
  }

  Future<void> _openNewInspection(Map<String, dynamic> p) async {
    final saved = await NewBazrasiSheet.show(
      context,
      codeCo: widget.codeCo,
      parvande: p,
      offline: _offlineData,
      userId: widget.currentUserId,
    );
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ثبت بازرسی انجام شد.')),
      );
    }
  }

  Future<void> _openInspectionHistory(Map<String, dynamic> p) async {
    await BazrasiRecordsSheet.show(
      context,
      codeCo: widget.codeCo,
      parvande: p,
      offline: _offlineData,
      userId: widget.currentUserId,
    );
  }

  Future<void> _openStoreImages(Map<String, dynamic> p) async {
    await ParvandeStoreImagesSheet.show(
      context,
      codeCo: widget.codeCo,
      parvande: p,
      offline: _offlineData,
      onPersistDirty: () => _markParvandeDirty(p),
    );
  }

  Future<void> _openPartners(Map<String, dynamic> p) async {
    if (_offlineData) {
      _offlineOnlySnack();
      return;
    }
    await ParvandeSharikHubSheet.show(
      context,
      codeCo: widget.codeCo,
      parvande: p,
      userId: widget.currentUserId ?? '0',
    );
  }

  Future<void> _openLicense(Map<String, dynamic> p) async {
    await ParvandeLicenseDialog.show(
      context,
      codeCo: widget.codeCo,
      parvande: p,
    );
  }

  Future<void> _openDocuments(Map<String, dynamic> p) async {
    await ParvandeDocumentsSheet.show(
      context,
      codeCo: widget.codeCo,
      parvande: p,
      onlineMode: !_offlineData,
    );
  }

  void _openPlaceholder(
    String title,
    IconData icon,
    Color color,
    Map<String, dynamic>? p,
  ) {
    final info = p == null
        ? null
        : '${p.fullName.isEmpty ? '—' : p.fullName} • ${p.storeName.isEmpty ? '—' : p.storeName}';
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FeaturePlaceholderPage(
          title: title,
          icon: icon,
          color: color,
          contextInfo: info,
        ),
      ),
    );
  }

  Future<void> _loadHaghIndex() async {
    if (_offlineData) {
      if (!mounted) return;
      setState(() {
        _haghIndex = {};
        _haghIndexLoaded = false;
      });
      return;
    }
    try {
      final map = await HaghOzviatApi.instance.fetchIndex(widget.codeCo);
      if (!mounted) return;
      setState(() {
        _haghIndex = map;
        _haghIndexLoaded = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _haghIndex = {};
        _haghIndexLoaded = true;
      });
    }
  }

  HaghOzviatMemberIndex? _haghFor(Map<String, dynamic> p) {
    final key = ExcelImportShenase.normalize(p.shenase);
    if (key.isEmpty) return null;
    return _haghIndex[key];
  }

  void _openMembership(Map<String, dynamic> p) {
    final shenase = p.shenase.trim();
    if (shenase.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('کد صنفی برای این پرونده ثبت نشده است.')),
      );
      return;
    }
    if (_haghIndexLoaded) {
      final idx = _haghFor(p);
      if (idx == null || !idx.hasRecords) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('سابقهٔ حق عضویت برای این عضو ثبت نشده است.'),
          ),
        );
        return;
      }
    }
    showHaghOzviatMemberDialog(
      context: context,
      codeCo: widget.codeCo,
      shenaseStore: shenase,
      memberName: p.fullName,
    );
  }

  void _openDetails(Map<String, dynamic> p) {
    showDialog(
      context: context,
      builder: (_) => ParvandeDetailsDialog(
        parvande: p,
        onCall: () => _call(p.mob),
        onSms: () => _sms(p.mob),
        onMap: () => _map(p),
        onNewInspection: () => _openNewInspection(p),
        onInspectionHistory: () => _openInspectionHistory(p),
        onImages: () => _openStoreImages(p),
        onLicense: () => _openLicense(p),
        onDocuments: () => _openDocuments(p),
        onPartners: () => _openPartners(p),
        onComplaint: () => _openPlaceholder(
          'ثبت شکایت',
          FluentIcons.warning_24_regular,
          const Color(0xFFD32F2F),
          p,
        ),
        showEdit: _canEditParvande,
        onEdit: () => _openEdit(p),
      ),
    );
  }

  Future<bool> _setAct(Map<String, dynamic> p, int act,
      {required String okMsg}) async {
    try {
      if (!_offlineData) {
        await _api.setActParvande(p.idParvandeh, act);
      }
      p['act_parvande'] = act.toString();
      await _persistParvandeLocally(p, markSynced: !_offlineData);
      if (!mounted) return true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _offlineData ? '$okMsg (فقط حافظهٔ محلی)' : okMsg,
          ),
        ),
      );
      await _loadMarkersForCurrentView(force: true);
      return true;
    } catch (e) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطا: $e')),
      );
      return false;
    }
  }

  Future<void> _confirmSoftDelete(Map<String, dynamic> p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('انتقال به سطل زباله'),
        content: Text(
          'پروندهٔ «${p.fullName}» به سطل زباله منتقل شود؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('انصراف'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('انتقال'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _setAct(p, 2, okMsg: 'پرونده به سطل زباله منتقل شد.');
    }
  }

  Future<bool> _deleteForever(Map<String, dynamic> p) async {
    if (_offlineData) {
      _offlineOnlySnack();
      return false;
    }
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon: const Icon(
          Icons.warning_amber_rounded,
          color: Color(0xFFB71C1C),
          size: 48,
        ),
        title: const Text('حذف کامل و غیرقابل بازگشت'),
        content: Text(
          'پروندهٔ «${p.fullName}» برای همیشه از سرور حذف می‌شود.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('انصراف'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFB71C1C)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف کامل'),
          ),
        ],
      ),
    );
    if (ok != true) return false;
    try {
      await _api.deleteForever(p.idParvandeh);
      if (p.isInLocalCache) {
        await ParvandeLocalRepository.instance
            .deleteRecord(widget.codeCo, p.idParvandeh);
      }
      if (!mounted) return true;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('پرونده برای همیشه حذف شد.')),
      );
      await _loadMarkersForCurrentView(force: true);
      return true;
    } catch (e) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطا: $e')),
      );
      return false;
    }
  }

  Future<void> _showParvandeCardSheet(Map<String, dynamic> raw) async {
    final p = _findRowById(raw.idParvandeh) ?? raw;
    final h = MediaQuery.sizeOf(context).height;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Container(
            decoration: const BoxDecoration(
              color: Color(0xFFF4F7FB),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p.storeName.isEmpty ? 'پرونده بازرسی' : p.storeName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 15),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            p.fullName.isEmpty ? '—' : p.fullName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey.shade700),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                SizedBox(
                  height: math.min(404, h * 0.6),
                  child: SingleChildScrollView(
                    child: ParvandeCard(
                      codeCo: widget.codeCo,
                      parvande: p,
                      membershipIndex: _haghFor(p),
                      membershipIndexLoaded: _haghIndexLoaded,
                      preferServerImages: !_offlineData,
                      onDetails: () => _openDetails(p),
                      onMembership: () => _openMembership(p),
                      onMap: () => _map(p),
                      onSoftDelete: () => _confirmSoftDelete(p),
                      onRestore: () => _setAct(p, 1, okMsg: 'پرونده بازیابی شد.'),
                      onHardDelete: () => _deleteForever(p),
                      onNewInspection: () => _openNewInspection(p),
                      onInspectionHistory: () => _openInspectionHistory(p),
                      onImages: () => _openStoreImages(p),
                      onLicense: () => _openLicense(p),
                      onDocuments: () => _openDocuments(p),
                      onPartners: () => _openPartners(p),
                      onComplaint: () => _openPlaceholder(
                        'ثبت شکایت',
                        FluentIcons.warning_24_regular,
                        const Color(0xFFD32F2F),
                        p,
                      ),
                      showEdit: _canEditParvande,
                      onEdit: () => _openEdit(p),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTopPanel() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xF51B2A41), Color(0xE5274A73)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
              color: Color(0x22000000), blurRadius: 16, offset: Offset(0, 8)),
        ],
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'داشبورد بازرسی',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      !_onlineAvailable && !_preferOfflineMode
                          ? (_offlineMode
                              ? 'سرور در دسترس نیست؛ نمایش از حافظهٔ محلی'
                              : 'سرور موقتاً در دسترس نیست؛ داده‌های فعلی نقشه حفظ شده‌اند')
                          : _offlineMode
                              ? 'نمایش از حافظهٔ محلی'
                              : 'نمایش پرونده‌های مجاز روی نقشه',
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
              _modeSelector(),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _searchCtrl,
            focusNode: _searchFocus,
            textDirection: TextDirection.rtl,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              hintText: 'جستجو: نام، واحد، رسته، شماره پرونده، کد ملی...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchCtrl.text.trim().isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() {});
                      },
                      icon: const Icon(Icons.close),
                    ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'فیلتر نقاط روی نقشه',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              _regionSwitch(),
              if (_hasActiveFilters) ...[
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: _resetFilters,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    backgroundColor: Colors.white.withValues(alpha: 0.12),
                  ),
                  icon: const Icon(Icons.filter_alt_off, size: 16),
                  label: const Text('پاک کردن'),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              final maxWidth = constraints.maxWidth;
              final itemWidth = maxWidth >= 960
                  ? (maxWidth - 16) / 3
                  : maxWidth >= 620
                      ? (maxWidth - 8) / 2
                      : maxWidth;
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  SizedBox(
                    width: itemWidth,
                    child: _filterDropdown(
                      label: 'فیلتر رسته صنفی',
                      icon: FluentIcons.branch_24_regular,
                      value: _selectedRaste,
                      items: _rasteOptions,
                      onChanged: (value) {
                        _selectedRaste = value ?? _allRasteFilter;
                        _onFiltersChanged();
                      },
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _filterDropdown(
                      label: 'فیلتر بدهی حق عضویت',
                      icon: FluentIcons.receipt_money_24_regular,
                      value: _selectedDebt,
                      items: const [
                        _allDebtFilter,
                        'دارای بدهی',
                        'بدون بدهی',
                      ],
                      itemLabels: const {
                        _allDebtFilter: 'همه اعضا (بدون فیلتر)',
                        'دارای بدهی': 'دارای بدهی (حق عضویت)',
                        'بدون بدهی': 'بدون بدهی / تسویه',
                      },
                      onChanged: (value) {
                        _selectedDebt = value ?? _allDebtFilter;
                        _onFiltersChanged();
                      },
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _filterDropdown(
                      label: 'فیلتر وضعیت اعتبار پرونده',
                      icon: FluentIcons.clipboard_task_24_regular,
                      value: _selectedStatus,
                      items: _statusOptions,
                      onChanged: (value) {
                        _selectedStatus = value ?? _allStatusFilter;
                        _onFiltersChanged();
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _regionSwitch() {
    final inside = _insideRegion;
    final color = inside ? Colors.teal : Colors.deepOrange;
    return Material(
      color: color.shade50,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: () {
          _insideRegion = !_insideRegion;
          _onFiltersChanged();
        },
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                inside ? Icons.location_on : Icons.location_off,
                size: 16,
                color: color.shade800,
              ),
              const SizedBox(width: 6),
              Text(
                inside ? 'داخل منطقه' : 'خارج از منطقه',
                style: TextStyle(
                  color: color.shade800,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.swap_horiz, size: 16, color: color.shade800),
            ],
          ),
        ),
      ),
    );
  }

  Widget _modeSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _modeChip(
            label: 'آنلاین',
            icon: Icons.cloud_done,
            active: !_offlineMode,
            enabled: true,
            onTap: () => _switchDataMode(false),
          ),
          const SizedBox(width: 6),
          _modeChip(
            label: 'محلی',
            icon: Icons.cloud_off,
            active: _offlineMode,
            enabled: true,
            onTap: () => _switchDataMode(true),
          ),
        ],
      ),
    );
  }

  Widget _modeChip({
    required String label,
    required IconData icon,
    required bool active,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    final bg = active ? Colors.white : Colors.transparent;
    final fg = active ? _accent : Colors.white;
    final disabledFg = Colors.white54;
    return InkWell(
      onTap: (!enabled || _switchingMode || (active && enabled)) ? null : onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_switchingMode && active)
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: fg,
                ),
              )
            else
              Icon(icon, size: 16, color: enabled ? fg : disabledFg),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: enabled ? fg : disabledFg,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterDropdown({
    required String label,
    required IconData icon,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    Map<String, String>? itemLabels,
  }) {
    String captionFor(String item) => itemLabels?[item] ?? item;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: Colors.white.withValues(alpha: 0.92)),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.96),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  height: 1.25,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          key: ValueKey('$label|$value'),
          initialValue: items.contains(value) ? value : items.first,
          decoration: InputDecoration(
            hintText: 'انتخاب کنید…',
            hintStyle: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          ),
          style: const TextStyle(
            color: Color(0xFF1E3A5F),
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
          ),
          icon: const Icon(Icons.keyboard_arrow_down_rounded,
              color: Color(0xFF1E3A5F)),
          dropdownColor: Colors.white,
          isExpanded: true,
          selectedItemBuilder: (context) => items
              .map(
                (item) => Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    captionFor(item),
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E3A5F),
                    ),
                  ),
                ),
              )
              .toList(),
          items: items
              .map(
                (item) => DropdownMenuItem<String>(
                  value: item,
                  child: Text(
                    captionFor(item),
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E3A5F),
                    ),
                  ),
                ),
              )
              .toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildSearchResults() {
    final results = _searchResults;
    if (_searchCtrl.text.trim().isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
              color: Color(0x22000000), blurRadius: 14, offset: Offset(0, 6)),
        ],
        border: Border.all(color: const Color(0xFFE3EAF2)),
      ),
      child: results.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(14),
              child: Text(
                'موردی مطابق جستجوی شما پیدا نشد.',
                style: TextStyle(color: Colors.grey.shade700),
              ),
            )
          : ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 6),
              itemCount: results.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final item = results[i];
                return ListTile(
                  leading: Icon(
                    item.hasLocation
                        ? Icons.location_on
                        : Icons.description_outlined,
                    color: item.hasLocation ? _accent : Colors.grey,
                  ),
                  title: Text(
                    item.storeName.isEmpty ? item.fullName : item.storeName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                  subtitle: Text(
                    [
                      if (item.fullName.isNotEmpty) item.fullName,
                      if (item.raste.isNotEmpty) item.raste,
                      if (item.numParvande.isNotEmpty) 'پ ${item.numParvande}',
                    ].join(' • '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Text(
                    item.hasLocation ? 'روی نقشه' : 'بدون مختصات',
                    style: TextStyle(
                      fontSize: 11,
                      color: item.hasLocation
                          ? const Color(0xFF2E7D32)
                          : Colors.grey.shade600,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onTap: () => _selectSearchResult(item),
                );
              },
            ),
    );
  }

  Widget _buildLoadingOverlay() {
    return Container(
      color: const Color(0xFFF4F7FB),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        _accent.withValues(alpha: 0.14),
                        const Color(0xFF4FC3F7).withValues(alpha: 0.16),
                      ],
                    ),
                  ),
                  child: Center(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 88,
                          height: 88,
                          child: CircularProgressIndicator(
                            value: _progress.clamp(0.0, 1.0),
                            strokeWidth: 7,
                            color: _accent,
                            backgroundColor: Colors.white,
                          ),
                        ),
                        Text(
                          '${(_progress * 100).clamp(0, 100).toStringAsFixed(0)}%',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 20,
                            color: _accent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  _loadingText,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 16),
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: _progress.clamp(0.0, 1.0),
                    minHeight: 10,
                    color: _accent,
                    backgroundColor: const Color(0xFFDDE5EF),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _totalPoints > 0
                      ? '$_loadedPoints از $_totalPoints نقطه پردازش شد'
                      : 'در حال آماده‌سازی لایه‌ها و داده‌های نقشه',
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
                if (_loadError != null) ...[
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: () =>
                        _loadMarkersForCurrentView(initial: true, force: true),
                    icon: const Icon(Icons.refresh),
                    label: const Text('تلاش مجدد'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLegend() {
    return Container(
      width: 240,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
              color: Color(0x16000000), blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: const [
          Text('معنی رنگ مارکرها',
              style: TextStyle(fontWeight: FontWeight.w800)),
          SizedBox(height: 8),
          _LegendRow(color: Color(0xFFF9A825), label: 'در دست اقدام'),
          _LegendRow(color: Color(0xFF2E7D32), label: 'فعال / صادر شده'),
          _LegendRow(
              color: Color(0xFFC62828), label: 'منقضی / فاقد اعتبار / تعلیق'),
          _LegendRow(color: Colors.black, label: 'ابطال / ابطال متقاضی'),
          _LegendRow(color: Color(0xFFEF6C00), label: 'تغییر نشانی'),
          _LegendRow(color: Color(0xFF757575), label: 'نامشخص'),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _mapFab(
          icon: Icons.search,
          tooltip: 'جستجو',
          color: const Color(0xFF3949AB),
          onPressed: _focusSearch,
        ),
        const SizedBox(height: 10),
        _mapFab(
          icon: Icons.my_location,
          tooltip: 'موقعیت من',
          color: const Color(0xFF1565C0),
          busy: _findingMyLocation,
          onPressed: _moveToMyLocation,
        ),
        const SizedBox(height: 10),
        _mapFab(
          icon: Icons.add_business_outlined,
          tooltip: 'پرونده جدید',
          color: const Color(0xFF2E7D32),
          onPressed: () => _openPlaceholder(
            'پرونده جدید',
            FluentIcons.document_add_24_regular,
            const Color(0xFF2E7D32),
            null,
          ),
        ),
        const SizedBox(height: 10),
        _mapFab(
          icon: Icons.refresh,
          tooltip: 'بارگذاری مجدد',
          color: const Color(0xFFEF6C00),
          busy: _loading && !_initialLoading,
          onPressed: () => _loadMarkersForCurrentView(force: true),
        ),
      ],
    );
  }

  Widget _mapFab({
    required IconData icon,
    required String tooltip,
    required Color color,
    required VoidCallback onPressed,
    bool busy = false,
  }) {
    return Tooltip(
      message: tooltip,
      child: FloatingActionButton.small(
        heroTag: tooltip,
        backgroundColor: color,
        foregroundColor: Colors.white,
        onPressed: busy ? null : onPressed,
        child: busy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
            : Icon(icon),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F7FB),
        appBar: AppBar(
          backgroundColor: _deep,
          foregroundColor: Colors.white,
          title: const Text('بازرسی'),
          actions: [
            IconButton(
              tooltip: 'بارگذاری مجدد',
              onPressed: () => _loadMarkersForCurrentView(force: true),
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _myLocation ?? _defaultCenter,
                initialZoom: _currentZoom,
                maxZoom: 19,
                minZoom: 4,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all,
                ),
                onMapReady: () {
                  _isMapReady = true;
                  _loadMarkersForCurrentView(force: true);
                },
                onPositionChanged: _onMapPositionChanged,
              ),
              children: [
                const LegacyBazrasiTileLayer(),
                MarkerClusterLayerWidget(
                  options: MarkerClusterLayerOptions(
                    markers: _markers,
                    maxClusterRadius: 60,
                    size: const Size(48, 48),
                    alignment: Alignment.center,
                    padding: const EdgeInsets.all(48),
                    builder: (context, markers) {
                      return Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            begin: Alignment.topRight,
                            end: Alignment.bottomLeft,
                            colors: [Color(0xFF1B2A41), Color(0xFF2C4A75)],
                          ),
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: const [
                            BoxShadow(
                                color: Color(0x22000000),
                                blurRadius: 10,
                                offset: Offset(0, 3)),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            '${markers.length}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                if (_myLocation != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _myLocation!,
                        width: 54,
                        height: 54,
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color:
                                const Color(0xFF1565C0).withValues(alpha: 0.18),
                          ),
                          child: Center(
                            child: Container(
                              width: 18,
                              height: 18,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFF1565C0),
                                border:
                                    Border.all(color: Colors.white, width: 3),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildTopPanel(),
                    _buildSearchResults(),
                  ],
                ),
              ),
            ),
            if (_loading && !_initialLoading)
              Positioned(
                top: 20,
                left: 16,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.96),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(
                          color: Color(0x16000000),
                          blurRadius: 8,
                          offset: Offset(0, 3)),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _loadingText,
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ),
            Positioned(
              right: 14,
              bottom: 24,
              child: _buildActionButtons(),
            ),
            Positioned(
              left: 14,
              bottom: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_myLocation != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.96),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: const [
                          BoxShadow(
                              color: Color(0x16000000),
                              blurRadius: 8,
                              offset: Offset(0, 3)),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.my_location,
                              size: 16, color: Color(0xFF1565C0)),
                          SizedBox(width: 6),
                          Text('موقعیت شما',
                              style: TextStyle(fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  _buildLegend(),
                ],
              ),
            ),
            if (_initialLoading) _buildLoadingOverlay(),
          ],
        ),
      ),
    );
  }
}

class _InspectionMarker extends StatelessWidget {
  const _InspectionMarker({
    required this.color,
    required this.editedLocation,
    required this.highlighted,
  });

  final Color color;
  final bool editedLocation;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final outerPinSize = highlighted ? 44.0 : 38.0;
    final innerPinSize = highlighted ? 38.0 : 32.0;
    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        if (highlighted)
          Positioned(
            top: 2,
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF00BCD4).withValues(alpha: 0.18),
                border: Border.all(
                  color: const Color(0xFF00BCD4).withValues(alpha: 0.55),
                  width: 2,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x5500BCD4),
                    blurRadius: 14,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
          ),
        Positioned(
          top: highlighted ? 12 : 8,
          child: Container(
            width: highlighted ? 28 : 24,
            height: highlighted ? 28 : 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.28),
            ),
          ),
        ),
        Icon(
          Icons.location_on,
          size: outerPinSize,
          color: Colors.black.withValues(alpha: highlighted ? 0.28 : 0.22),
        ),
        Icon(Icons.location_on, size: innerPinSize, color: color),
        if (highlighted)
          Positioned(
            top: -4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF00BCD4),
                borderRadius: BorderRadius.circular(999),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x3300BCD4),
                    blurRadius: 10,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.auto_awesome, size: 11, color: Colors.white),
                  SizedBox(width: 4),
                  Text(
                    'یافت شد',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (editedLocation)
          Positioned(
            bottom: highlighted ? 16 : 10,
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: Colors.black,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.6),
              ),
            ),
          ),
      ],
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({
    required this.color,
    required this.label,
  });

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style:
                  const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
