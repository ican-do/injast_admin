import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:injast_admin/file_management/advanced_search_sheet.dart';
import 'package:injast_admin/file_management/parvande_api.dart';
import 'package:injast_admin/file_management/parvande_card.dart';
import 'package:injast_admin/file_management/parvande_details_dialog.dart';
import 'package:injast_admin/file_management/placeholders/feature_placeholder_page.dart';
import 'package:injast_admin/file_management/trash_sheet.dart';
import 'package:injast_admin/file_management/bazrasi_records_sheet.dart';
import 'package:injast_admin/file_management/new_bazrasi_sheet.dart';
import 'package:injast_admin/file_management/parvande_license_dialog.dart';
import 'package:injast_admin/file_management/parvande_sharik_hub_sheet.dart';
import 'package:injast_admin/file_management/parvande_store_images_sheet.dart';
import 'package:injast_admin/file_management/parvande_map_dialog.dart';
import 'package:injast_admin/file_management/parvande_documents_sheet.dart';
import 'package:injast_admin/file_management/parvande_full_edit_page.dart';
import 'package:injast_admin/file_management/parvande_permissions.dart';
import 'package:injast_admin/file_management/parvande_quick_edit_dialog.dart';
import 'package:injast_admin/file_management/excel_import/excel_import_shenase.dart';
import 'package:injast_admin/file_management/hagh_ozviat_api.dart';
import 'package:injast_admin/file_management/hagh_ozviat_member_dialog.dart';
import 'package:injast_admin/file_management/hagh_ozviat_member_index.dart';
import 'package:injast_admin/import_sync/import_draft_store.dart';
import 'package:injast_admin/import_sync/import_models.dart';
import 'package:injast_admin/local_cache/network_reachability.dart';
import 'package:injast_admin/local_cache/offline_mode_prefs.dart';
import 'package:injast_admin/local_cache/parvande_cache_list_service.dart';
import 'package:injast_admin/local_cache/parvande_single_sync.dart';
import 'package:injast_admin/local_cache/parvande_local_repository.dart';
import 'package:injast_admin/local_cache/sync_status.dart';
import 'package:url_launcher/url_launcher.dart';

class FileManagementPage extends StatefulWidget {
  const FileManagementPage({
    super.key,
    required this.codeCo,
    this.currentUserId,
    this.currentUserName,
    this.currentUserRole,
    this.currentUserType,
    this.isSuperAdmin = false,
  });

  final String codeCo;
  final String? currentUserId;
  final String? currentUserName;
  final String? currentUserRole;

  /// کلید خام type_user برای بررسی دسترسی
  final String? currentUserType;
  final bool isSuperAdmin;

  @override
  State<FileManagementPage> createState() => _FileManagementPageState();
}

class _FileManagementPageState extends State<FileManagementPage> {
  final _api = ParvandeApi.instance;
  final _cacheList = ParvandeCacheListService.instance;
  final _offlinePrefs = OfflineModePrefs();
  final _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _all = [];
  bool _loading = true;
  bool _offlineData = false;
  bool _offlineMode = false;
  bool _togglingOffline = false;
  String _tab = 'active'; // active | all | trash
  ParvandeListSyncFilter _syncFilter = ParvandeListSyncFilter.all;
  AdvancedFilters _filters = AdvancedFilters();
  String? _sendingId;
  Map<String, HaghOzviatMemberIndex> _haghIndex = {};
  bool _haghIndexLoaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final offline = await _offlinePrefs.isOfflineEffective(widget.codeCo);
      final online =
          await NetworkReachability.instance.isServerReachableCached();

      if (offline || !online) {
        _all = await _cacheList.fetchAllFromCache(widget.codeCo);
        _offlineData = true;
        _offlineMode = true;
        if (!mounted) return;
        if (_all.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'حافظهٔ محلی خالی است. یک‌بار در حالت آنلاین از «سایت اصناف» پرونده‌ها را بازیابی کنید.',
              ),
              duration: Duration(seconds: 8),
            ),
          );
        }
      } else {
        try {
          _all = await _cacheList.mergeSyncStatusFromCache(
            widget.codeCo,
            await _api.fetchAll(widget.codeCo),
          );
          _offlineData = false;
          _offlineMode = false;
          await _offlinePrefs.clearAutoOfflineIfOnline(widget.codeCo);
        } catch (e) {
          final cached = await _cacheList.fetchAllFromCache(widget.codeCo);
          if (cached.isNotEmpty) {
            _all = cached;
            _offlineData = true;
            _offlineMode = true;
            await _offlinePrefs.setAutoOffline(widget.codeCo, true);
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'سرور در دسترس نیست؛ ${cached.length} پرونده از حافظهٔ محلی نمایش داده شد.',
                ),
                duration: const Duration(seconds: 8),
              ),
            );
          } else {
            rethrow;
          }
        }
      }

      if (!_offlineData) {
        await _loadHaghIndex();
      } else {
        _haghIndex = {};
        _haghIndexLoaded = false;
      }

      if (kDebugMode) {
        final withImage =
            _all.where((e) => e.imageProfile.trim().isNotEmpty).length;
        debugPrint(
          '[FileManagement] offline=$_offlineData total=${_all.length} withImage=$withImage',
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطا در بارگذاری پرونده‌ها: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _offlineOnlySnack() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
            'این عملیات در حالت آفلاین فقط از حافظهٔ محلی است و به سرور نیاز دارد.'),
      ),
    );
  }

  bool get _canEditParvande => ParvandePermissions.canEditParvande(
        role: widget.currentUserType ?? widget.currentUserRole,
        isSuperAdmin: widget.isSuperAdmin,
      );

  void _patchParvandeRow(
    Map<String, dynamic> p, {
    Map<String, String>? fields,
  }) {
    if (fields == null || fields.isEmpty) return;
    final idx = _all.indexWhere((e) => e.idParvandeh == p.idParvandeh);
    if (idx < 0) return;
    setState(() {
      _all[idx].addAll(fields);
    });
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
      allParvandes: _all,
      currentUserId: widget.currentUserId,
      currentUserName: widget.currentUserName,
      currentUserRole: widget.currentUserRole,
    );
    if (saved == true && mounted) {
      await _load();
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
      _patchParvandeRow(
        p,
        fields: {
          'mob_admin': p.s('mob_admin'),
          'tel_admin': p.s('tel_admin'),
          'money': p.s('money'),
        },
      );
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اطلاعات تماس و بدهی ذخیره شد.')),
      );
    }
  }

  Future<void> _toggleOfflineMode(bool value) async {
    if (_togglingOffline || _loading) return;

    if (!value) {
      final online = await NetworkReachability.instance.isServerReachable();
      if (!online) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'سرور در دسترس نیست؛ تا برقراری اتصال، حالت آفلاین فعال می‌ماند.'),
          ),
        );
        return;
      }
      await _offlinePrefs.setUserOffline(widget.codeCo, false);
      await _offlinePrefs.clearAutoOfflineIfOnline(widget.codeCo);
    } else {
      await _offlinePrefs.setUserOffline(widget.codeCo, true);
    }

    if (!mounted) return;
    setState(() {
      _offlineMode = value;
      _togglingOffline = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          value
              ? 'حالت آفلاین: فقط حافظهٔ محلی.'
              : 'حالت آنلاین: بارگذاری از سرور.',
        ),
      ),
    );

    await _load();
    if (mounted) setState(() => _togglingOffline = false);
  }

  Widget _offlineModeSwitch() {
    return FutureBuilder<bool>(
      future: NetworkReachability.instance.isServerReachableCached(),
      builder: (context, snap) {
        final serverUp = snap.data ?? true;
        final lockedOffline = _offlineMode && !serverUp;
        final disabled = _loading || _togglingOffline || lockedOffline;

        return Tooltip(
          message: lockedOffline
              ? 'قطع اینترنت/سرور — آفلاین اجباری'
              : (_offlineMode
                  ? 'حالت آفلاین — فقط حافظهٔ محلی'
                  : 'حالت آنلاین — بارگذاری از سرور'),
          child: Padding(
            padding: const EdgeInsetsDirectional.only(end: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'محلی',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight:
                        _offlineMode ? FontWeight.w700 : FontWeight.w400,
                    color: _offlineMode
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                Switch(
                  value: !_offlineMode,
                  onChanged:
                      disabled ? null : (online) => _toggleOfflineMode(!online),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                Text(
                  'آنلاین',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight:
                        !_offlineMode ? FontWeight.w700 : FontWeight.w400,
                    color: !_offlineMode
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Map<String, dynamic>> get _baseByTab {
    if (_tab == 'all') return _all;
    if (_tab == 'trash') return _all.where((e) => e.isTrash).toList();
    return _all.where((e) => e.isActive).toList();
  }

  List<Map<String, dynamic>> get _visible {
    final q = _searchCtrl.text.trim().toLowerCase();
    var filtered = _filters.apply(_baseByTab);
    final wantStatus = _syncFilter.statusOrNull;
    if (wantStatus != null) {
      filtered =
          filtered.where((p) => p.cacheSyncStatus == wantStatus).toList();
    }
    if (q.isEmpty) return filtered;
    return filtered.where((p) {
      final bag = [
        p.s('name_admin'),
        p.s('family_admin'),
        p.storeName,
        p.raste,
        p.mob,
        p.codeMeli,
        p.codePosti,
        p.numParvande,
      ].join(' ').toLowerCase();
      return bag.contains(q);
    }).toList();
  }

  int get _trashCount => _all.where((e) => e.isTrash).length;

  int _syncCount(ParvandeSyncStatus status) =>
      _all.where((e) => e.cacheSyncStatus == status).length;

  Future<void> _refreshSyncStatusOnList() async {
    _all = await _cacheList.mergeSyncStatusFromCache(widget.codeCo, _all);
  }

  Future<void> _sendOneToServer(Map<String, dynamic> p) async {
    if (_sendingId != null) return;
    if (_offlineData) {
      _offlineOnlySnack();
      return;
    }
    final online = await NetworkReachability.instance.isServerReachableCached();
    if (!online) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('سرور در دسترس نیست. اتصال را بررسی کنید.')),
      );
      return;
    }
    if (!p.isInLocalCache) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'این پرونده در حافظهٔ محلی نیست. از «سایت اصناف» آن را بازیابی کنید.',
          ),
        ),
      );
      return;
    }
    if (!p.needsSyncSend) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('این پرونده قبلاً به سرور ارسال شده است.')),
      );
      return;
    }

    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ارسال به سرور'),
        content: Text(
          'پروندهٔ «${p.fullName}» با تصاویر و مدارک محلی به سرور ارسال شود؟\n'
          'پس از موفقیت وضعیت «ارسال‌شده» می‌شود و در حافظه باقی می‌ماند.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('انصراف')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('ارسال')),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    final store = ImportDraftStore(widget.codeCo);
    ImportDraftRecord? record;
    for (final r in await store.read()) {
      if (r.clientTempId == p.idParvandeh) {
        record = r;
        break;
      }
    }
    if (record == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('رکورد در حافظه یافت نشد.')),
      );
      return;
    }

    setState(() => _sendingId = p.idParvandeh);
    try {
      final fin = await ParvandeSingleSync.sendOne(
        codeCo: widget.codeCo,
        record: record,
      );
      if (!mounted) return;
      await _refreshSyncStatusOnList();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'ارسال انجام شد: ${fin.inserted} پرونده، ${fin.docsInserted} مدرک.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطا در ارسال: $e')),
      );
    } finally {
      if (mounted) setState(() => _sendingId = null);
    }
  }

  Future<void> _confirmDeleteFromCache(Map<String, dynamic> p) async {
    if (!p.isInLocalCache) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('این پرونده در حافظهٔ محلی ذخیره نشده است.')),
      );
      return;
    }
    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف از حافظه'),
        content: Text(
          'پروندهٔ «${p.fullName}» با تمام تصاویر و مدارک محلی از حافظه حذف شود؟\n'
          'این عمل فقط دادهٔ محلی را پاک می‌کند و روی سرور اتحادیه اثر ندارد.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('انصراف')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFC62828)),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await ImportDraftStore(widget.codeCo).deleteRecord(p.idParvandeh);
      setState(() {
        _all.removeWhere((e) => e.idParvandeh == p.idParvandeh);
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('پرونده از حافظهٔ محلی حذف شد.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطا در حذف: $e')),
      );
    }
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
      if (_offlineData) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  '$okMsg (فقط حافظهٔ محلی — پس از اتصال «ارسال به سرور»)')),
        );
        setState(() {});
      } else {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(okMsg)));
        await _load();
      }
      return true;
    } catch (e) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('خطا: $e')));
      return false;
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
        icon: const Icon(Icons.warning_amber_rounded,
            color: Color(0xFFB71C1C), size: 48),
        title: const Text('حذف کامل و غیرقابل بازگشت'),
        content: Text(
          'پروندهٔ «${p.fullName}» برای همیشه از سرور حذف می‌شود.\n\n'
          'این عمل فقط در حالت آنلاین مجاز است و قابل بازگشت نیست.',
          style: const TextStyle(height: 1.5),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('انصراف')),
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
      await _load();
      return true;
    } catch (e) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('خطا: $e')));
      return false;
    }
  }

  Future<void> _markParvandeDirty(Map<String, dynamic> p) async {
    await _persistParvandeLocally(p, markSynced: false);
    if (mounted) setState(() {});
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
      unionParvandes: _all,
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

    if (!_offlineData) {
      await _load();
    } else if (mounted) {
      setState(() {});
      final parts = <String>[];
      if (addressChanged) parts.add('آدرس');
      if (locationChanged) parts.add('لوکیشن');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${parts.join(' و ')} در حافظهٔ محلی ذخیره شد؛ پس از اتصال ارسال کنید.',
          ),
        ),
      );
    }
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

  Future<void> _openAdvancedSearch() async {
    final raste =
        _all.map((e) => e.raste).where((e) => e.isNotEmpty).toSet().toList();
    final vaziyat =
        _all.map((e) => e.vaziyat).where((e) => e.isNotEmpty).toSet().toList();
    final result = await showModalBottomSheet<AdvancedFilters>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AdvancedSearchSheet(
        initial: _filters,
        allRasteOptions: raste,
        allVaziyatOptions: vaziyat,
      ),
    );
    if (result != null) {
      setState(() => _filters = result);
    }
  }

  Future<void> _openTrashSheet() async {
    final result = await showModalBottomSheet<TrashSheetResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TrashSheet(
        trashItems: _all.where((e) => e.isTrash).toList(),
        offline: _offlineData,
        onRestore: (p) => _setAct(p, 1, okMsg: 'پرونده بازیابی شد.'),
        onHardDelete: _deleteForever,
      ),
    );
    if (result?.changed == true && mounted) {
      await _load();
    }
  }

  Future<void> _confirmSoftDelete(Map<String, dynamic> p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('انتقال به سطل زباله'),
        content: Text(
          'پروندهٔ «${p.fullName}» به سطل زباله منتقل شود؟\n'
          'پس از انتقال فقط در سطل زباله قابل مشاهده است.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('انصراف')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('انتقال')),
        ],
      ),
    );
    if (ok == true) {
      await _setAct(p, 2, okMsg: 'پرونده به سطل زباله منتقل شد.');
    }
  }

  Future<void> _openNewInspection(Map<String, dynamic> p) async {
    await NewBazrasiSheet.show(
      context,
      codeCo: widget.codeCo,
      parvande: p,
      offline: _offlineData,
      userId: widget.currentUserId,
    );
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

  void _openPlaceholder(
    String title,
    IconData icon,
    Color color,
    Map<String, dynamic> p,
  ) {
    final info =
        '${p.fullName.isEmpty ? '—' : p.fullName} • ${p.storeName.isEmpty ? '—' : p.storeName}';
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

  @override
  Widget build(BuildContext context) {
    final visible = _visible;
    return Scaffold(
      appBar: AppBar(
        title: const Text('مدیریت پرونده‌ها'),
        actions: [
          _offlineModeSwitch(),
          IconButton(
            onPressed: _loading ? null : _load,
            tooltip: 'بروزرسانی',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const FeaturePlaceholderPage(
                title: 'پرونده جدید',
                icon: FluentIcons.document_add_24_regular,
                color: Color(0xFFEF6C00),
              ),
            ),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('پرونده جدید'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _headerSection(visible.length),
                Expanded(
                  child: visible.isEmpty
                      ? const Center(child: Text('موردی یافت نشد'))
                      : LayoutBuilder(
                          builder: (context, c) {
                            final count = c.maxWidth >= 1200
                                ? 3
                                : c.maxWidth >= 700
                                    ? 2
                                    : 1;
                            final cardHeight = count == 1
                                ? 452.0
                                : count == 2
                                    ? 432.0
                                    : 420.0;
                            return GridView.builder(
                              padding: const EdgeInsets.fromLTRB(12, 6, 12, 14),
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: count,
                                crossAxisSpacing: 10,
                                mainAxisSpacing: 10,
                                mainAxisExtent: cardHeight,
                              ),
                              itemCount: visible.length,
                              itemBuilder: (_, i) => _buildCard(visible[i]),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _headerSection(int visibleCount) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                  child:
                      _countChip('کل', _all.length, const Color(0xFF455A64))),
              const SizedBox(width: 8),
              Expanded(
                  child: _countChip(
                      'فعال',
                      _all.where((e) => e.isActive).length,
                      const Color(0xFF2E7D32))),
              const SizedBox(width: 8),
              Expanded(
                  child: _countChip(
                      'نمایش', visibleCount, const Color(0xFF1E3A5F))),
              const SizedBox(width: 8),
              _trashButton(),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'جستجوی سریع: نام، واحد، رسته، موبایل...',
                    prefixIcon: const Icon(Icons.search),
                    isDense: true,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              IconButton.filledTonal(
                tooltip: 'جستجوی حرفه‌ای',
                onPressed: _openAdvancedSearch,
                icon: Badge(
                  isLabelVisible: !_filters.isEmpty,
                  label: const Text('!'),
                  child: const Icon(FluentIcons.filter_24_regular),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _tabBtn('active', 'فعال'),
              const SizedBox(width: 6),
              _tabBtn('all', 'همه'),
              const SizedBox(width: 6),
              _tabBtn('trash', 'سطل'),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _syncFilterChip(ParvandeListSyncFilter.all, _all.length),
                const SizedBox(width: 6),
                _syncFilterChip(
                  ParvandeListSyncFilter.localNew,
                  _syncCount(ParvandeSyncStatus.local),
                ),
                const SizedBox(width: 6),
                _syncFilterChip(
                  ParvandeListSyncFilter.synced,
                  _syncCount(ParvandeSyncStatus.synced),
                ),
                const SizedBox(width: 6),
                _syncFilterChip(
                  ParvandeListSyncFilter.dirty,
                  _syncCount(ParvandeSyncStatus.dirty),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _syncFilterChip(ParvandeListSyncFilter filter, int count) {
    final active = _syncFilter == filter;
    final status = filter.statusOrNull;
    final color = status?.color ?? const Color(0xFF455A64);
    return FilterChip(
      label: Text('${filter.label} ($count)'),
      selected: active,
      onSelected: (_) => setState(() => _syncFilter = filter),
      selectedColor: color.withValues(alpha: 0.2),
      checkmarkColor: color,
      labelStyle: TextStyle(
        fontWeight: FontWeight.w700,
        color: active ? color : Colors.black87,
        fontSize: 12,
      ),
      side: BorderSide(color: active ? color : const Color(0xFFDDE5EF)),
    );
  }

  Widget _countChip(String title, int value, Color c) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
              child: Text(title,
                  style: const TextStyle(fontWeight: FontWeight.w700))),
          Text('$value',
              style: TextStyle(fontWeight: FontWeight.w800, color: c)),
        ],
      ),
    );
  }

  Widget _trashButton() {
    return Badge(
      isLabelVisible: _trashCount > 0,
      label: Text('$_trashCount'),
      child: IconButton.filled(
        tooltip: 'سطل زباله',
        onPressed: _openTrashSheet,
        icon: const Icon(FluentIcons.delete_24_regular),
      ),
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

  Widget _tabBtn(String value, String title) {
    final active = _tab == value;
    return Expanded(
      child: FilledButton.tonal(
        onPressed: () => setState(() => _tab = value),
        style: FilledButton.styleFrom(
          backgroundColor: active ? const Color(0xFF1E3A5F) : null,
          foregroundColor: active ? Colors.white : null,
        ),
        child: Text(title),
      ),
    );
  }

  Widget _buildCard(Map<String, dynamic> p) {
    final sending = _sendingId == p.idParvandeh;
    final hagh = _haghFor(p);
    return ParvandeCard(
      codeCo: widget.codeCo,
      parvande: p,
      membershipIndex: hagh,
      membershipIndexLoaded: _haghIndexLoaded,
      preferServerImages: !_offlineData,
      isSendingToServer: sending,
      onSendToServer: p.isInLocalCache ? () => _sendOneToServer(p) : null,
      onDeleteFromCache:
          p.isInLocalCache ? () => _confirmDeleteFromCache(p) : null,
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
    );
  }
}
