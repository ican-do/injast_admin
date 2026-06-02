import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:injast_admin/asnaf_site_page.dart';
import 'package:injast_admin/file_management/bazrasi_map_page.dart';
import 'package:injast_admin/file_management/data_backup_page.dart';
import 'package:injast_admin/file_management/file_management_page.dart';
import 'package:injast_admin/file_management/parvande_api.dart';
import 'package:injast_admin/home_dashboard_insights.dart';
import 'package:injast_admin/local_cache/network_reachability.dart';
import 'package:injast_admin/local_cache/offline_mode_prefs.dart';
import 'package:injast_admin/local_cache/offline_session_store.dart';
import 'package:injast_admin/pos_web_service.dart';
import 'package:injast_admin/reports/hagh_ozviat_debt_reports_page.dart';
import 'package:injast_admin/settings_sync_page.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shamsi_date/shamsi_date.dart';

bool _sqliteFfiReady = false;

Future<void> _initLocalDatabase() async {
  if (kIsWeb || _sqliteFfiReady) return;
  // macOS از sqflite_darwin بومی استفاده می‌کند — بدون FFI و بدون دانلود sqlite3.
  if (Platform.isWindows || Platform.isLinux) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    _sqliteFfiReady = true;
  }
}

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    await _initLocalDatabase();
    runApp(const InjastAdminApp());
  }, (error, stack) {
    debugPrint('main zone error: $error\n$stack');
  });
}

class InjastAdminApp extends StatelessWidget {
  const InjastAdminApp({super.key});

  static ThemeData _buildTheme() {
    const seed = Color(0xFF1E3A5F);
    final base = ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: seed),
      useMaterial3: true,
    );
    final textTheme = GoogleFonts.vazirmatnTextTheme(base.textTheme);
    final primaryTextTheme =
        GoogleFonts.vazirmatnTextTheme(base.primaryTextTheme);
    return base.copyWith(
      textTheme: textTheme,
      primaryTextTheme: primaryTextTheme,
      appBarTheme: base.appBarTheme.copyWith(
        titleTextStyle: GoogleFonts.vazirmatn(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: base.colorScheme.onSurface,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Injast Admin (وب)',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(),
      home: const PosWebHomePage(),
    );
  }
}

class PosWebHomePage extends StatefulWidget {
  const PosWebHomePage({super.key});

  @override
  State<PosWebHomePage> createState() => _PosWebHomePageState();
}

class _PosWebHomePageState extends State<PosWebHomePage> {
  final _svc = PosWebService.instance;
  final _offlinePrefs = OfflineModePrefs();
  String? _error;
  bool _busy = true;
  bool _serverReachable = true;
  bool _hasOfflineSession = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _svc.ensureDeviceUuid();
      _hasOfflineSession = await OfflineSessionStore().hasSavedSession();
      _serverReachable = await NetworkReachability.instance.isServerReachable();
      if (_serverReachable) {
        await _svc.pollOnce();
      } else {
        _error =
            'اتصال به سرور برقرار نیست. می‌توانید با حافظهٔ محلی ادامه دهید.';
      }
      _svc.startPolling(
        onTick: () async {
          if (!mounted || _svc.isLoggedIn) return;
          try {
            await _svc.pollOnce();
            if (mounted) setState(() {});
          } catch (_) {}
        },
      );
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _enterOfflineMode() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final ok = await _svc.restoreOfflineSession();
      if (!ok) {
        _error =
            'نشست آفلاین یافت نشد. حداقل یک‌بار باید با اتصال به سرور وارد شده باشید.';
        return;
      }
      final codeCo = _svc.sessionUser?['code_co']?.toString().trim() ?? '';
      if (codeCo.isNotEmpty) {
        await _offlinePrefs.setAutoOffline(codeCo, true);
      }
      if (mounted) setState(() {});
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _logout() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _svc.logout();
      await _svc.pollOnce();
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _svc.stopPolling();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uuid = _svc.deviceUuid;
    final user = _svc.sessionUser;

    return Scaffold(
      appBar: user != null
          ? PreferredSize(
              preferredSize: const Size.fromHeight(432),
              child: _LoggedInTopPanel(
                user: user,
                unionInfo: _svc.unionInfo,
                memberStats: _svc.memberStats,
                deviceUuid: uuid ?? '',
                busy: _busy,
                onLogout: _logout,
              ),
            )
          : AppBar(title: const Text('ورود با QR')),
      body: _busy && uuid == null
          ? const Center(child: CircularProgressIndicator())
          : user != null
              ? _LoggedInHome(
                  user: user,
                )
              : _QrActivationView(
                  svc: _svc,
                  uuid: uuid,
                  error: _error,
                  serverReachable: _serverReachable,
                  hasOfflineSession: _hasOfflineSession,
                  onOfflineLogin: _enterOfflineMode,
                ),
    );
  }
}

/// صفحهٔ اصلی بعد از ورود: بالا مشخصات کاربر، وسط خالی (رزرو برای آینده).
class _LoggedInHome extends StatelessWidget {
  const _LoggedInHome({
    required this.user,
  });

  final Map<String, dynamic> user;

  @override
  Widget build(BuildContext context) {
    final categories = _panelCategories;
    return _UserContext(
      user: user,
      child: Container(
        color: const Color(0xFFF4F7FB),
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
          itemCount: categories.length,
          itemBuilder: (context, index) {
            final category = categories[index];
            return _PanelCategoryCard(category: category);
          },
        ),
      ),
    );
  }
}

class _PanelCategoryCard extends StatelessWidget {
  const _PanelCategoryCard({required this.category});
  final _PanelCategory category;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE0E7F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(category.titleIcon, color: category.titleColor, size: 20),
                const SizedBox(width: 8),
                Text(
                  category.title,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: category.titleColor,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            LayoutBuilder(
              builder: (context, c) {
                final width = c.maxWidth;
                final itemWidth = width > 1100
                    ? (width - 24) / 4
                    : width > 740
                        ? (width - 16) / 3
                        : (width - 8) / 2;
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: category.items
                      .map((e) => SizedBox(
                            width: itemWidth,
                            child: _PanelItemTile(item: e),
                          ))
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _PanelItemTile extends StatelessWidget {
  const _PanelItemTile({required this.item});
  final _PanelItem item;

  @override
  Widget build(BuildContext context) {
    final featured = item.actionKey == 'inspection_map' ||
        item.actionKey == 'hagh_ozviat_reports';
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          final user = _UserContext.of(context);
          if (item.actionKey == 'asnaf_site') {
            final codeCo = user?['code_co']?.toString().trim() ?? '';
            final userCode = user?['id_user']?.toString().trim() ?? '—';
            final firstName = user?['name_user']?.toString().trim() ?? '';
            final familyName = user?['family_user']?.toString().trim() ?? '';
            final rawUnionName = user?['name_co']?.toString().trim() ?? '';
            final unionName = rawUnionName.isEmpty ? '—' : rawUnionName;
            final userName = '$firstName $familyName'.trim().isEmpty
                ? '—'
                : '$firstName $familyName'.trim();
            if (codeCo.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('کد اتحادیه نامعتبر است.')),
              );
              return;
            }
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => AsnafSitePage(
                  codeCo: codeCo,
                  userCode: userCode,
                  userName: userName,
                  unionName: unionName,
                ),
              ),
            );
            return;
          }
          if (item.actionKey == 'union_members' ||
              item.actionKey == 'file_management') {
            final codeCo = user?['code_co']?.toString().trim() ?? '';
            if (codeCo.isNotEmpty) {
              final firstName = user?['name_user']?.toString().trim() ?? '';
              final familyName = user?['family_user']?.toString().trim() ?? '';
              final userName = '$firstName $familyName'.trim();
              final typeUser = user?['type_user']?.toString();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => FileManagementPage(
                    codeCo: codeCo,
                    currentUserId: user?['id_user']?.toString(),
                    currentUserName: userName.isEmpty ? null : userName,
                    currentUserRole: userRoleLabel(typeUser),
                    currentUserType: typeUser,
                    isSuperAdmin:
                        typeUser?.trim().toLowerCase() == 'super_admin',
                  ),
                ),
              );
              return;
            }
          }
          if (item.actionKey == 'inspection_map') {
            final codeCo = user?['code_co']?.toString().trim() ?? '';
            if (codeCo.isNotEmpty) {
              final firstName = user?['name_user']?.toString().trim() ?? '';
              final familyName = user?['family_user']?.toString().trim() ?? '';
              final userName = '$firstName $familyName'.trim();
              final typeUser = user?['type_user']?.toString();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => BazrasiMapPage(
                    codeCo: codeCo,
                    currentUserId: user?['id_user']?.toString(),
                    currentUserName: userName.isEmpty ? null : userName,
                    currentUserRole: userRoleLabel(typeUser),
                    currentUserType: typeUser,
                    isSuperAdmin:
                        typeUser?.trim().toLowerCase() == 'super_admin',
                    sessionUser: user,
                  ),
                ),
              );
              return;
            }
          }
          if (item.actionKey == 'settings_menu') {
            await _showSettingsMenu(context);
            return;
          }
          if (item.actionKey == 'data_backup') {
            final codeCo = user?['code_co']?.toString().trim() ?? '';
            if (codeCo.isNotEmpty) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => DataBackupPage(
                    codeCo: codeCo,
                    sessionUser: user,
                  ),
                ),
              );
              return;
            }
          }
          if (item.actionKey == 'hagh_ozviat_reports') {
            final codeCo = user?['code_co']?.toString().trim() ?? '';
            if (codeCo.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('کد اتحادیه نامعتبر است.')),
              );
              return;
            }
            final unionName = user?['name_co']?.toString().trim() ?? '';
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => HaghOzviatDebtReportsPage(
                  codeCo: codeCo,
                  unionName: unionName,
                ),
              ),
            );
            return;
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('«${item.label}» به‌زودی فعال می‌شود.')),
          );
        },
        child: Ink(
          decoration: BoxDecoration(
            color: featured ? null : item.backgroundColor,
            gradient: featured
                ? LinearGradient(
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                    colors: item.actionKey == 'hagh_ozviat_reports'
                        ? const [Color(0xFF4A148C), Color(0xFF283593)]
                        : const [Color(0xFF16314E), Color(0xFF2C5C86)],
                  )
                : null,
            borderRadius: BorderRadius.circular(12),
            boxShadow: featured
                ? const [
                    BoxShadow(
                      color: Color(0x22000000),
                      blurRadius: 12,
                      offset: Offset(0, 5),
                    ),
                  ]
                : null,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: featured ? 0.18 : 1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    item.icon,
                    color: featured ? Colors.white : item.iconColor,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    item.label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: featured ? Colors.white : null,
                    ),
                  ),
                ),
                if (featured)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.18)),
                    ),
                    child: const Text(
                      'نقشه',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showSettingsMenu(BuildContext context) async {
    final box = context.findRenderObject() as RenderBox?;
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (box == null || overlay == null) return;
    final topLeft = box.localToGlobal(Offset.zero, ancestor: overlay);
    final rect =
        Rect.fromLTWH(topLeft.dx, topLeft.dy, box.size.width, box.size.height);

    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(rect, Offset.zero & overlay.size),
      items: const [
        PopupMenuItem(
          value: 'sync',
          child: ListTile(
            dense: true,
            leading: Icon(Icons.sync),
            title: Text('بازیابی اطلاعات'),
          ),
        ),
        PopupMenuItem(
          value: 'access',
          child: ListTile(
            dense: true,
            leading: Icon(Icons.lock_outline),
            title: Text('سطح دسترسی'),
          ),
        ),
        PopupMenuItem(
          value: 'special',
          child: ListTile(
            dense: true,
            leading: Icon(Icons.flag_outlined),
            title: Text('موارد خاص'),
          ),
        ),
      ],
    );
    if (selected == null || !context.mounted) return;
    if (selected == 'sync') {
      final user = _UserContext.of(context);
      final codeCo = user?['code_co']?.toString().trim() ?? '';
      if (codeCo.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('کد اتحادیه نامعتبر است.')),
        );
        return;
      }
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => SettingsSyncPage(codeCo: codeCo)),
      );
      return;
    }
    final label = switch (selected) {
      'access' => 'سطح دسترسی',
      'special' => 'موارد خاص',
      _ => 'تنظیمات',
    };
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('گزینه «$label» انتخاب شد.')),
    );
  }
}

class _PanelCategory {
  const _PanelCategory({
    required this.title,
    required this.titleIcon,
    required this.titleColor,
    required this.items,
  });
  final String title;
  final IconData titleIcon;
  final Color titleColor;
  final List<_PanelItem> items;
}

class _PanelItem {
  const _PanelItem({
    required this.label,
    required this.icon,
    required this.backgroundColor,
    required this.iconColor,
    this.actionKey,
  });
  final String label;
  final IconData icon;
  final Color backgroundColor;
  final Color iconColor;
  final String? actionKey;
}

class _UserContext extends InheritedWidget {
  const _UserContext({
    required super.child,
    required this.user,
  });
  final Map<String, dynamic> user;

  static Map<String, dynamic>? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_UserContext>()?.user;

  @override
  bool updateShouldNotify(covariant _UserContext oldWidget) =>
      oldWidget.user != user;
}

const List<_PanelCategory> _panelCategories = [
  _PanelCategory(
    title: 'مدیریت و تنظیمات',
    titleIcon: FluentIcons.settings_24_regular,
    titleColor: Color(0xFF2E7D32),
    items: [
      //  _PanelItem(label: 'معرفی رسته', icon: FluentIcons.branch_24_regular, backgroundColor: Color(0xFFE8F5E9), iconColor: Color(0xFF2E7D32)),
      _PanelItem(
          label: 'سایت ایرانی اصناف',
          icon: FluentIcons.globe_24_regular,
          backgroundColor: Color(0xFFE8EAF6),
          iconColor: Color(0xFF3949AB),
          actionKey: 'asnaf_site'),
      //   _PanelItem(label: 'اعضاء اتحادیه', icon: FluentIcons.people_24_regular, backgroundColor: Color(0xFFE3F2FD), iconColor: Color(0xFF1565C0), actionKey: 'union_members'),
      _PanelItem(
          label: 'مدیریت پرونده‌ها',
          icon: FluentIcons.document_table_24_regular,
          backgroundColor: Color(0xFFEAF2FF),
          iconColor: Color(0xFF1E3A5F),
          actionKey: 'file_management'),
      _PanelItem(
          label: 'مدیریت اطلاعات و بکاپ',
          icon: FluentIcons.database_24_regular,
          backgroundColor: Color(0xFFFFF3E0),
          iconColor: Color(0xFF6D4C41),
          actionKey: 'data_backup'),
      //   _PanelItem(label: 'نمایش اسامی پرسنل', icon: FluentIcons.person_accounts_24_regular, backgroundColor: Color(0xFFF3E5F5), iconColor: Color(0xFF7B1FA2)),
      //   _PanelItem(label: 'تنظیم اسامی پرسنل', icon: Icons.manage_accounts_outlined, backgroundColor: Color(0xFFFFF3E0), iconColor: Color(0xFFEF6C00)),
      //   _PanelItem(label: 'مدیریت نرخ‌نامه', icon: FluentIcons.receipt_24_regular, backgroundColor: Color(0xFFE0F2F1), iconColor: Color(0xFF00695C)),
      //   _PanelItem(label: 'تنظیمات', icon: FluentIcons.settings_24_regular, backgroundColor: Color(0xFFFFEBEE), iconColor: Color(0xFFC62828), actionKey: 'settings_menu'),
    ],
  ),
  _PanelCategory(
    title: 'گزارشات',
    titleIcon: FluentIcons.chart_multiple_24_regular,
    titleColor: Color(0xFF6A1B9A),
    items: [
      _PanelItem(
        label: 'گزارش بدهی حق عضویت',
        icon: FluentIcons.data_histogram_24_regular,
        backgroundColor: Color(0xFFF3E5F5),
        iconColor: Color(0xFF6A1B9A),
        actionKey: 'hagh_ozviat_reports',
      ),
    ],
  ),
  _PanelCategory(
    title: 'بازرسی و گزارشات بازرسی',
    titleIcon: FluentIcons.clipboard_pulse_24_regular,
    titleColor: Color(0xFF1565C0),
    items: [
      _PanelItem(
          label: 'بازرسی',
          icon: FluentIcons.location_ripple_24_regular,
          backgroundColor: Color(0xFFE3F2FD),
          iconColor: Color(0xFF1565C0),
          actionKey: 'inspection_map'),
    ],
  ),
  // _PanelCategory(
  //   title: 'ثبت و عملیات',
  //   titleIcon: FluentIcons.edit_24_regular,
  //   titleColor: Color(0xFFEF6C00),
  //   items: [
  //     _PanelItem(label: 'پرونده جدید', icon: FluentIcons.document_add_24_regular, backgroundColor: Color(0xFFFFF3E0), iconColor: Color(0xFFEF6C00)),
  //     _PanelItem(label: 'بازرسی', icon: FluentIcons.location_24_regular, backgroundColor: Color(0xFFE8EAF6), iconColor: Color(0xFF3949AB)),
  //     _PanelItem(label: 'شکایات', icon: FluentIcons.warning_24_regular, backgroundColor: Color(0xFFFFEBEE), iconColor: Color(0xFFD32F2F)),
  //     _PanelItem(label: 'ارسال لینک دعوت', icon: FluentIcons.mail_24_regular, backgroundColor: Color(0xFFE3F2FD), iconColor: Color(0xFF1976D2)),
  //     _PanelItem(label: 'ثبت شکایت', icon: FluentIcons.document_edit_24_regular, backgroundColor: Color(0xFFF3E5F5), iconColor: Color(0xFF8E24AA)),
  //   ],
  // ),
  // _PanelCategory(
  //   title: 'گزارشات و آمار',
  //   titleIcon: FluentIcons.chart_multiple_24_regular,
  //   titleColor: Color(0xFF3949AB),
  //   items: [
  //     _PanelItem(label: 'آمار وگزارشات', icon: FluentIcons.chart_multiple_24_regular, backgroundColor: Color(0xFFE8EAF6), iconColor: Color(0xFF3949AB)),
  //     _PanelItem(label: 'آمار لحظه‌ای وضعیت شکایات', icon: FluentIcons.data_histogram_24_regular, backgroundColor: Color(0xFFE1F5FE), iconColor: Color(0xFF0277BD)),
  //     _PanelItem(label: 'گزارشات ویژه بازرسی', icon: FluentIcons.document_search_24_regular, backgroundColor: Color(0xFFE8F5E9), iconColor: Color(0xFF2E7D32)),
  //   ],
  // ),
  // _PanelCategory(
  //   title: 'خدمات و امکانات',
  //   titleIcon: FluentIcons.gift_24_regular,
  //   titleColor: Color(0xFFC2185B),
  //   items: [
  //     _PanelItem(label: 'تقویم من', icon: FluentIcons.calendar_24_regular, backgroundColor: Color(0xFFFFEBEE), iconColor: Color(0xFFD32F2F)),
  //     _PanelItem(label: 'قوانین و مقررات', icon: FluentIcons.document_text_24_regular, backgroundColor: Color(0xFFE3F2FD), iconColor: Color(0xFF1565C0)),
  //     _PanelItem(label: 'درخواست اعضاء', icon: FluentIcons.clipboard_task_24_regular, backgroundColor: Color(0xFFE8EAF6), iconColor: Color(0xFF3949AB)),
  //     _PanelItem(label: 'مشاور', icon: FluentIcons.person_chat_24_regular, backgroundColor: Color(0xFFE0F2F1), iconColor: Color(0xFF00695C)),
  //     _PanelItem(label: 'کارشناس', icon: FluentIcons.person_feedback_24_regular, backgroundColor: Color(0xFFFFF3E0), iconColor: Color(0xFFEF6C00)),
  //     _PanelItem(label: 'مزایا و خدمات', icon: FluentIcons.wallet_24_regular, backgroundColor: Color(0xFFF3E5F5), iconColor: Color(0xFF7B1FA2)),
  //     _PanelItem(label: 'مدیریت اخبار', icon: FluentIcons.news_24_regular, backgroundColor: Color(0xFFE8F5E9), iconColor: Color(0xFF2E7D32)),
  //     _PanelItem(label: 'مدیریت آموزش', icon: FluentIcons.book_24_regular, backgroundColor: Color(0xFFE1F5FE), iconColor: Color(0xFF0277BD)),
  //     _PanelItem(label: 'تعاونی', icon: FluentIcons.building_shop_24_regular, backgroundColor: Color(0xFFFFF8E1), iconColor: Color(0xFFF9A825)),
  //   ],
  // ),
  // _PanelCategory(
  //   title: 'در حال توسعه',
  //   titleIcon: FluentIcons.toolbox_24_regular,
  //   titleColor: Color(0xFF6A1B9A),
  //   items: [
  //     _PanelItem(label: 'مشاوره', icon: FluentIcons.chat_24_regular, backgroundColor: Color(0xFFF3E5F5), iconColor: Color(0xFF8E24AA)),
  //     _PanelItem(label: 'اطلاعیه‌ها', icon: FluentIcons.alert_24_regular, backgroundColor: Color(0xFFE3F2FD), iconColor: Color(0xFF1565C0)),
  //     _PanelItem(label: 'نظر سنجی', icon: FluentIcons.poll_24_regular, backgroundColor: Color(0xFFE8F5E9), iconColor: Color(0xFF2E7D32)),
  //   ],
  // ),
];

class _LoggedInTopPanel extends StatefulWidget {
  const _LoggedInTopPanel({
    required this.user,
    required this.unionInfo,
    required this.memberStats,
    required this.deviceUuid,
    required this.busy,
    required this.onLogout,
  });

  final Map<String, dynamic> user;
  final Map<String, dynamic>? unionInfo;
  final Map<String, dynamic>? memberStats;
  final String deviceUuid;
  final bool busy;
  final VoidCallback onLogout;

  @override
  State<_LoggedInTopPanel> createState() => _LoggedInTopPanelState();
}

class _LoggedInTopPanelState extends State<_LoggedInTopPanel> {
  late Future<HomeDashboardInsights> _insightsFuture;

  String _u(String k) => widget.user[k]?.toString().trim().isNotEmpty == true
      ? widget.user[k].toString().trim()
      : '—';
  String _co(String k) =>
      widget.unionInfo?[k]?.toString().trim().isNotEmpty == true
          ? widget.unionInfo![k].toString().trim()
          : '—';
  static final Stream<DateTime> _clockStream = Stream<DateTime>.periodic(
    const Duration(seconds: 1),
    (_) => DateTime.now(),
  ).asBroadcastStream();

  @override
  void initState() {
    super.initState();
    _reloadInsights();
  }

  @override
  void didUpdateWidget(covariant _LoggedInTopPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldCode = oldWidget.user['code_co']?.toString().trim() ?? '';
    final newCode = widget.user['code_co']?.toString().trim() ?? '';
    if (oldCode != newCode || oldWidget.memberStats != widget.memberStats) {
      _reloadInsights();
    }
  }

  void _reloadInsights() {
    final codeCo = widget.user['code_co']?.toString().trim() ?? '';
    _insightsFuture = codeCo.isEmpty
        ? Future.value(
            HomeDashboardInsights.fallback(memberStats: widget.memberStats),
          )
        : HomeDashboardInsightsLoader.load(
            codeCo: codeCo,
            memberStats: widget.memberStats,
          );
  }

  String _faDate(DateTime dt) {
    final j = Gregorian(dt.year, dt.month, dt.day).toJalali();
    final f = j.formatter;
    return '${f.wN} ${f.d} ${f.mN} ${f.yyyy}';
  }

  String _time(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  String _roleFa(String role) {
    const map = {
      'super_admin': 'سوپر ادمین',
      'admin_co': 'مدیر اتحادیه',
      'person_co': 'پرسنل',
      'bazras_co': 'بازرس',
      'sandoghdar': 'صندوق‌دار',
      'raees_etehadiye': 'رئیس اتحادیه',
      'moaven_modir': 'معاون مدیر',
      'heyat_modire': 'هیئت مدیره',
      'modir_ejraei': 'مدیر اجرایی',
      'karshenas': 'کارشناس',
    };
    return map[role] ?? role;
  }

  @override
  Widget build(BuildContext context) {
    final name = '${_u('name_user')} ${_u('family_user')}'.trim();
    final roleText = _roleFa(_u('type_user'));
    return AppBar(
      automaticallyImplyLeading: false,
      toolbarHeight: 432,
      backgroundColor: const Color(0xFF0E1B2D),
      elevation: 0,
      flexibleSpace: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: const LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [Color(0xFF1B2A41), Color(0xFF263E62)],
              ),
              boxShadow: const [
                BoxShadow(
                    color: Color(0x44000000),
                    blurRadius: 14,
                    offset: Offset(0, 4)),
              ],
              border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
            ),
            child: FutureBuilder<HomeDashboardInsights>(
              future: _insightsFuture,
              builder: (context, snapshot) {
                final insights = snapshot.data ??
                    HomeDashboardInsights.fallback(
                      memberStats: widget.memberStats,
                    );
                final loadingInsights =
                    snapshot.connectionState == ConnectionState.waiting;
                final stats = <Widget>[
                  _metricCard(
                    title: 'کل اعضا',
                    value: _formatInt(insights.totalMembers),
                    subtitle: 'فعال ${_formatInt(insights.activeMembers)}',
                    icon: Icons.people_alt_outlined,
                    accent: const Color(0xFF4FC3F7),
                  ),
                  _metricCard(
                    title: 'بدهی کل',
                    value: _formatMoneyRial(insights.totalDebt),
                    subtitle:
                        '${_formatInt(insights.debtorMembers)} عضو بدهکار',
                    icon: Icons.account_balance_wallet_outlined,
                    accent: const Color(0xFFFF8A65),
                  ),
                  _metricCard(
                    title: 'اعضای جدید ماه',
                    value: _formatInt(insights.newMembersThisMonth),
                    subtitle: 'بر پایه تاریخ صدور',
                    icon: Icons.person_add_alt_1_outlined,
                    accent: const Color(0xFF80CBC4),
                  ),
                  _metricCard(
                    title: 'بازرسی ماه',
                    value: loadingInsights && !snapshot.hasData
                        ? '...'
                        : (insights.inspectionsThisMonth == null
                            ? '—'
                            : _formatInt(insights.inspectionsThisMonth!)),
                    subtitle: insights.inspectionsThisMonth == null
                        ? 'نیازمند API تجمیعی'
                        : 'انجام شده در این ماه',
                    icon: Icons.fact_check_outlined,
                    accent: const Color(0xFF90CAF9),
                  ),
                  _metricCard(
                    title: 'دارای موقعیت',
                    value: _formatInt(insights.withLocationCount),
                    subtitle: 'آماده نمایش روی نقشه',
                    icon: Icons.my_location_outlined,
                    accent: const Color(0xFFA5D6A7),
                  ),
                  _metricCard(
                    title: 'انقضای این ماه',
                    value: _formatInt(insights.expiringThisMonth),
                    subtitle: 'نیازمند پیگیری',
                    icon: Icons.event_busy_outlined,
                    accent: const Color(0xFFFFCC80),
                  ),
                ];

                return LayoutBuilder(
                  builder: (context, c) {
                    final statWidth = c.maxWidth > 1080
                        ? (c.maxWidth - 16) / 3
                        : c.maxWidth > 720
                            ? (c.maxWidth - 8) / 2
                            : c.maxWidth;
                    final unionInfo = <Widget>[
                      _unionInfoLine(
                        Icons.apartment_outlined,
                        'نام اتحادیه',
                        _co('name_co'),
                      ),
                      _unionInfoLine(
                        Icons.category_outlined,
                        'نوع اتحادیه',
                        _co('lbl_type'),
                      ),
                      _unionInfoLine(
                        Icons.qr_code_2_outlined,
                        'کد اتحادیه',
                        _u('code_co'),
                      ),
                      _unionInfoLine(
                        Icons.call_outlined,
                        'تماس اتحادیه',
                        _co('tel1_co'),
                      ),
                    ];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color:
                                          Colors.white.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(
                                        color: Colors.white
                                            .withValues(alpha: 0.14),
                                      ),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          FluentIcons.data_trending_24_regular,
                                          color: Colors.white70,
                                          size: 15,
                                        ),
                                        SizedBox(width: 6),
                                        Text(
                                          'پنل اصلی',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    name.isEmpty ? '—' : name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 19,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      _chip(Icons.badge_outlined, roleText),
                                      _chip(Icons.pin_outlined,
                                          'کد کاربر: ${_u('id_user')}'),
                                      _chip(Icons.devices_outlined,
                                          'دستگاه: ${widget.deviceUuid}'),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: StreamBuilder<DateTime>(
                                stream: _clockStream,
                                initialData: DateTime.now(),
                                builder: (context, snapshot) {
                                  final now = snapshot.data ?? DateTime.now();
                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        _faDate(now),
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        _time(now),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.4,
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                            FilledButton.icon(
                              onPressed: widget.busy ? null : widget.onLogout,
                              icon: const Icon(Icons.logout, size: 16),
                              label: const Text('خروج'),
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: const Color(0xFF1E3A5F),
                                visualDensity: VisualDensity.compact,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.12),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: unionInfo,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: stats
                              .map(
                                (e) => SizedBox(
                                  width: statWidth,
                                  child: e,
                                ),
                              )
                              .toList(),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _chip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white70),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _unionInfoLine(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '$label: ${value.isEmpty ? '—' : value}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11.7,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Icon(icon, size: 15, color: Colors.white60),
        ],
      ),
    );
  }

  Widget _metricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color accent,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.55)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: accent, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10.8, color: Colors.white70),
                ),
                const SizedBox(height: 1),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    color: accent,
                  ),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10.2,
                    color: Colors.white54,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatInt(int value) {
    final digits = value.toString();
    final pattern = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return digits.replaceAllMapped(pattern, (m) => '${m[1]},');
  }

  String _formatMoneyRial(double amount) {
    if (amount <= 0) return '۰ ریال';
    return '${_formatInt(amount.round())} ریال';
  }
}

class _QrActivationView extends StatelessWidget {
  const _QrActivationView({
    required this.svc,
    required this.uuid,
    required this.error,
    required this.serverReachable,
    required this.hasOfflineSession,
    required this.onOfflineLogin,
  });

  final PosWebService svc;
  final String? uuid;
  final String? error;
  final bool serverReachable;
  final bool hasOfflineSession;
  final VoidCallback onOfflineLogin;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    error!,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ),
              const Text(
                'این QR را در اپ injast_v3 از مسیر «مدیریت کاربران» روی کارت همان کاربر با دکمهٔ «فعال سازی وب» اسکن کنید.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              if (uuid != null)
                AspectRatio(
                  aspectRatio: 1,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [
                        BoxShadow(blurRadius: 8, color: Colors.black26),
                      ],
                    ),
                    padding: const EdgeInsets.all(16),
                    child: QrImageView(
                      data: svc.qrPayloadJson,
                      version: QrVersions.auto,
                      gapless: true,
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              SelectableText(
                uuid ?? '',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              Text(
                serverReachable
                    ? 'هر چند ثانیه یک‌بار وضعیت بررسی می‌شود؛ پس از اتصال موفق، به صفحهٔ اصلی می‌روید.'
                    : 'سرور در دسترس نیست. اگر قبلاً با این دستگاه وارد شده‌اید، از دکمهٔ زیر استفاده کنید.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (!serverReachable && hasOfflineSession) ...[
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: onOfflineLogin,
                  icon: const Icon(Icons.cloud_off),
                  label: const Text('ادامه در حالت آفلاین (حافظه محلی)'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF5D4037),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'پرونده‌ها و تصاویر از حافظهٔ داخلی دستگاه بارگذاری می‌شوند.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
