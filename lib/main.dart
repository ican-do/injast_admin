import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:injast_admin/asnaf_site_page.dart';
import 'package:injast_admin/features/benefits/manage_benefits_page.dart';
import 'package:injast_admin/features/calendar/my_calendar_page.dart';
import 'package:injast_admin/features/laws/manage_laws_page.dart';
import 'package:injast_admin/features/news/manage_news_page.dart';
import 'package:injast_admin/features/parvande_new/new_parvande_page.dart';
import 'package:injast_admin/features/permissions/manage_access_page.dart';
import 'package:injast_admin/features/personnel/manage_personnel_page.dart';
import 'package:injast_admin/features/personnel/personnel_display_page.dart';
import 'package:injast_admin/features/raste/manage_raste_page.dart';
import 'package:injast_admin/features/rate_sheets/manage_rate_sheets_page.dart';
import 'package:injast_admin/features/reports/bazrasi_reports_hub_page.dart';
import 'package:injast_admin/features/requests/manage_organizations_page.dart';
import 'package:injast_admin/features/requests/manage_request_types_page.dart';
import 'package:injast_admin/features/requests/manage_requests_page.dart';
import 'package:injast_admin/features/shared/admin_ui.dart';
import 'package:injast_admin/features/shekayat/manage_shekayat_page.dart';
import 'package:injast_admin/features/shekayat/register_shekayat_page.dart';
import 'package:injast_admin/features/shekayat/shekayat_reports_page.dart';
import 'package:injast_admin/features/tutorials/manage_tutorials_page.dart';
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
              preferredSize: const Size.fromHeight(148),
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
                  unionInfo: _svc.unionInfo,
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
    this.unionInfo,
  });

  final Map<String, dynamic> user;
  final Map<String, dynamic>? unionInfo;

  @override
  Widget build(BuildContext context) {
    final categories = _panelCategories;
    return _UserContext(
      user: user,
      unionInfo: unionInfo,
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
          final codeCo = user?['code_co']?.toString().trim() ?? '';
          final idUser = user?['id_user']?.toString().trim() ?? '';
          final firstName = user?['name_user']?.toString().trim() ?? '';
          final familyName = user?['family_user']?.toString().trim() ?? '';
          final userName = '$firstName $familyName'.trim();
          final typeUser = user?['type_user']?.toString();
          final idUserInt = int.tryParse(idUser);

          Future<void> push(Widget page) async {
            await Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => page),
            );
          }

          bool requireCodeCo() {
            if (codeCo.isNotEmpty) return true;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('کد اتحادیه نامعتبر است.')),
            );
            return false;
          }

          switch (item.actionKey) {
            case 'asnaf_site':
              if (!requireCodeCo()) return;
              final rawUnionName = user?['name_co']?.toString().trim() ?? '';
              await push(AsnafSitePage(
                codeCo: codeCo,
                userCode: idUser.isEmpty ? '—' : idUser,
                userName: userName.isEmpty ? '—' : userName,
                unionName: rawUnionName.isEmpty ? '—' : rawUnionName,
              ));
              return;
            case 'union_members':
            case 'file_management':
              if (!requireCodeCo()) return;
              await push(FileManagementPage(
                codeCo: codeCo,
                currentUserId: idUser.isEmpty ? null : idUser,
                currentUserName: userName.isEmpty ? null : userName,
                currentUserRole: userRoleLabel(typeUser),
                currentUserType: typeUser,
                isSuperAdmin: typeUser?.trim().toLowerCase() == 'super_admin',
              ));
              return;
            case 'inspection_map':
              if (!requireCodeCo()) return;
              await push(BazrasiMapPage(
                codeCo: codeCo,
                currentUserId: idUser.isEmpty ? null : idUser,
                currentUserName: userName.isEmpty ? null : userName,
                currentUserRole: userRoleLabel(typeUser),
                currentUserType: typeUser,
                isSuperAdmin: typeUser?.trim().toLowerCase() == 'super_admin',
                sessionUser: user,
              ));
              return;
            case 'settings_menu':
              await _showSettingsMenu(context);
              return;
            case 'data_backup':
              if (!requireCodeCo()) return;
              await push(DataBackupPage(codeCo: codeCo, sessionUser: user));
              return;
            case 'hagh_ozviat_reports':
              if (!requireCodeCo()) return;
              await push(HaghOzviatDebtReportsPage(
                codeCo: codeCo,
                unionName: user?['name_co']?.toString().trim() ?? '',
              ));
              return;
            case 'manage_raste':
              if (!requireCodeCo()) return;
              await push(ManageRastePage(
                codeCo: codeCo,
                idUser: idUser.isEmpty ? '0' : idUser,
              ));
              return;
            case 'personnel_display':
              if (!requireCodeCo()) return;
              await push(PersonnelDisplayPage(codeCo: codeCo));
              return;
            case 'manage_personnel':
              if (!requireCodeCo()) return;
              await push(ManagePersonnelPage(
                codeCo: codeCo,
                currentUserId: idUser.isEmpty ? null : idUser,
              ));
              return;
            case 'manage_rate_sheets':
              if (!requireCodeCo()) return;
              await push(ManageRateSheetsPage(
                codeCo: codeCo,
                updatedBy: idUserInt,
              ));
              return;
            case 'new_parvande':
              if (!requireCodeCo()) return;
              await push(NewParvandePage(
                codeCo: codeCo,
                idUser: idUser.isEmpty ? '0' : idUser,
                unionInfo: _UserContext.unionOf(context),
              ));
              return;
            case 'shekayat_hub':
              if (!requireCodeCo()) return;
              final choice = await showFeatureHubSheet<String>(
                context: context,
                title: 'شکایات',
                items: const [
                  FeatureHubItem(
                    label: 'مدیریت شکایات',
                    subtitle: 'پیگیری و بررسی پرونده‌های شکایت',
                    icon: FluentIcons.clipboard_error_24_regular,
                    color: Color(0xFFD32F2F),
                    value: 'manage',
                  ),
                  FeatureHubItem(
                    label: 'ثبت شکایت',
                    subtitle: 'ثبت شکایت جدید',
                    icon: FluentIcons.document_edit_24_regular,
                    color: Color(0xFF8E24AA),
                    value: 'register',
                  ),
                ],
              );
              if (!context.mounted || choice == null) return;
              if (choice == 'register') {
                await push(RegisterShekayatPage(
                  codeCo: codeCo,
                  currentUserId: idUser.isEmpty ? null : idUser,
                  currentUser: user,
                  unionName: _UserContext.unionOf(context)?['name_co']?.toString(),
                ));
              } else {
                await push(ManageShekayatPage(
                  codeCo: codeCo,
                  currentUserId: idUser.isEmpty ? null : idUser,
                  currentUserType: typeUser,
                  currentUser: user,
                ));
              }
              return;
            case 'bazrasi_reports':
              if (!requireCodeCo()) return;
              await push(BazrasiReportsHubPage(
                codeCo: codeCo,
                sessionUser: user,
              ));
              return;
            case 'shekayat_reports':
              if (!requireCodeCo()) return;
              await push(ShekayatReportsPage(codeCo: codeCo));
              return;
            case 'my_calendar':
              if (!requireCodeCo()) return;
              await push(MyCalendarPage(
                codeCo: codeCo,
                userId: idUser.isEmpty ? null : idUser,
              ));
              return;
            case 'manage_laws':
              if (!requireCodeCo()) return;
              await push(ManageLawsPage(codeCo: codeCo));
              return;
            case 'member_requests':
              if (!requireCodeCo()) return;
              final choice = await showFeatureHubSheet<String>(
                context: context,
                title: 'درخواست اعضاء',
                items: const [
                  FeatureHubItem(
                    label: 'مدیریت درخواست‌ها',
                    subtitle: 'بررسی و تغییر وضعیت',
                    icon: Icons.inbox_outlined,
                    color: Color(0xFF1565C0),
                    value: 'requests',
                  ),
                  FeatureHubItem(
                    label: 'تنظیم نوع درخواست',
                    subtitle: 'تعریف انواع درخواست',
                    icon: Icons.category_outlined,
                    color: Color(0xFFEF6C00),
                    value: 'types',
                  ),
                  FeatureHubItem(
                    label: 'تنظیم ارگان‌های طرف قرارداد',
                    subtitle: 'مدیریت ارگان‌های مقصد',
                    icon: Icons.account_balance_outlined,
                    color: Color(0xFF00897B),
                    value: 'orgs',
                  ),
                ],
              );
              if (!context.mounted || choice == null) return;
              await push(switch (choice) {
                'types' => ManageRequestTypesPage(codeCo: codeCo),
                'orgs' => ManageOrganizationsPage(codeCo: codeCo),
                _ => ManageRequestsPage(codeCo: codeCo),
              });
              return;
            case 'manage_benefits':
              if (!requireCodeCo()) return;
              await push(ManageBenefitsPage(codeCo: codeCo));
              return;
            case 'manage_news':
              if (!requireCodeCo()) return;
              await push(ManageNewsPage(
                codeCo: codeCo,
                currentUserId: idUser.isEmpty ? null : idUser,
              ));
              return;
            case 'manage_tutorials':
              if (!requireCodeCo()) return;
              await push(ManageTutorialsPage(
                codeCo: codeCo,
                currentUserId: idUser.isEmpty ? null : idUser,
              ));
              return;
          }

          if (!context.mounted) return;
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
    final user = _UserContext.of(context);
    final codeCo = user?['code_co']?.toString().trim() ?? '';
    if (codeCo.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('کد اتحادیه نامعتبر است.')),
      );
      return;
    }
    if (selected == 'sync') {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => SettingsSyncPage(codeCo: codeCo)),
      );
      return;
    }
    if (selected == 'access') {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ManageAccessPage(codeCo: codeCo)),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('گزینه «موارد خاص» به‌زودی فعال می‌شود.')),
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
    this.unionInfo,
  });
  final Map<String, dynamic> user;
  final Map<String, dynamic>? unionInfo;

  static Map<String, dynamic>? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_UserContext>()?.user;

  static Map<String, dynamic>? unionOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_UserContext>()?.unionInfo;

  @override
  bool updateShouldNotify(covariant _UserContext oldWidget) =>
      oldWidget.user != user || oldWidget.unionInfo != unionInfo;
}

const List<_PanelCategory> _panelCategories = [
  _PanelCategory(
    title: 'مدیریت و تنظیمات',
    titleIcon: FluentIcons.settings_24_regular,
    titleColor: Color(0xFF2E7D32),
    items: [
      _PanelItem(
          label: 'معرفی رسته',
          icon: FluentIcons.branch_24_regular,
          backgroundColor: Color(0xFFE8F5E9),
          iconColor: Color(0xFF2E7D32),
          actionKey: 'manage_raste'),
      _PanelItem(
          label: 'سایت ایرانی اصناف',
          icon: FluentIcons.globe_24_regular,
          backgroundColor: Color(0xFFE8EAF6),
          iconColor: Color(0xFF3949AB),
          actionKey: 'asnaf_site'),
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
      _PanelItem(
          label: 'نمایش اسامی پرسنل',
          icon: FluentIcons.person_accounts_24_regular,
          backgroundColor: Color(0xFFF3E5F5),
          iconColor: Color(0xFF7B1FA2),
          actionKey: 'personnel_display'),
      _PanelItem(
          label: 'تنظیم اسامی پرسنل',
          icon: Icons.manage_accounts_outlined,
          backgroundColor: Color(0xFFFFF3E0),
          iconColor: Color(0xFFEF6C00),
          actionKey: 'manage_personnel'),
      _PanelItem(
          label: 'مدیریت نرخ‌نامه',
          icon: FluentIcons.receipt_24_regular,
          backgroundColor: Color(0xFFE0F2F1),
          iconColor: Color(0xFF00695C),
          actionKey: 'manage_rate_sheets'),
      _PanelItem(
          label: 'تنظیمات',
          icon: FluentIcons.settings_24_regular,
          backgroundColor: Color(0xFFFFEBEE),
          iconColor: Color(0xFFC62828),
          actionKey: 'settings_menu'),
    ],
  ),
  _PanelCategory(
    title: 'ثبت و عملیات',
    titleIcon: FluentIcons.edit_24_regular,
    titleColor: Color(0xFFEF6C00),
    items: [
      _PanelItem(
          label: 'پرونده جدید',
          icon: FluentIcons.document_add_24_regular,
          backgroundColor: Color(0xFFFFF3E0),
          iconColor: Color(0xFFEF6C00),
          actionKey: 'new_parvande'),
      _PanelItem(
          label: 'شکایات',
          icon: FluentIcons.warning_24_regular,
          backgroundColor: Color(0xFFFFEBEE),
          iconColor: Color(0xFFD32F2F),
          actionKey: 'shekayat_hub'),
    ],
  ),
  _PanelCategory(
    title: 'گزارشات و آمار',
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
      _PanelItem(
          label: 'گزارشات بازرسی',
          icon: FluentIcons.document_search_24_regular,
          backgroundColor: Color(0xFFE8F5E9),
          iconColor: Color(0xFF2E7D32),
          actionKey: 'bazrasi_reports'),
      _PanelItem(
          label: 'گزارشات شکایات',
          icon: FluentIcons.data_histogram_24_regular,
          backgroundColor: Color(0xFFE1F5FE),
          iconColor: Color(0xFF0277BD),
          actionKey: 'shekayat_reports'),
    ],
  ),
  _PanelCategory(
    title: 'بازرسی',
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
  _PanelCategory(
    title: 'خدمات و امکانات',
    titleIcon: FluentIcons.gift_24_regular,
    titleColor: Color(0xFFC2185B),
    items: [
      _PanelItem(
          label: 'تقویم من',
          icon: FluentIcons.calendar_24_regular,
          backgroundColor: Color(0xFFFFEBEE),
          iconColor: Color(0xFFD32F2F),
          actionKey: 'my_calendar'),
      _PanelItem(
          label: 'قوانین و مقررات',
          icon: FluentIcons.document_text_24_regular,
          backgroundColor: Color(0xFFE3F2FD),
          iconColor: Color(0xFF1565C0),
          actionKey: 'manage_laws'),
      _PanelItem(
          label: 'درخواست اعضاء',
          icon: FluentIcons.clipboard_task_24_regular,
          backgroundColor: Color(0xFFE8EAF6),
          iconColor: Color(0xFF3949AB),
          actionKey: 'member_requests'),
      _PanelItem(
          label: 'مزایا و خدمات',
          icon: FluentIcons.wallet_24_regular,
          backgroundColor: Color(0xFFF3E5F5),
          iconColor: Color(0xFF7B1FA2),
          actionKey: 'manage_benefits'),
      _PanelItem(
          label: 'مدیریت اخبار',
          icon: FluentIcons.news_24_regular,
          backgroundColor: Color(0xFFE8F5E9),
          iconColor: Color(0xFF2E7D32),
          actionKey: 'manage_news'),
      _PanelItem(
          label: 'مدیریت آموزش',
          icon: FluentIcons.book_24_regular,
          backgroundColor: Color(0xFFE1F5FE),
          iconColor: Color(0xFF0277BD),
          actionKey: 'manage_tutorials'),
    ],
  ),
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
      toolbarHeight: 148,
      backgroundColor: const Color(0xFF0E1B2D),
      elevation: 0,
      flexibleSpace: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: const LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [Color(0xFF1B2A41), Color(0xFF263E62)],
              ),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
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

                final metrics = <({
                  String title,
                  String value,
                  Color accent,
                  IconData icon,
                })>[
                  (
                    title: 'کل اعضا',
                    value: _formatInt(insights.totalMembers),
                    accent: const Color(0xFF4FC3F7),
                    icon: Icons.people_alt_outlined,
                  ),
                  (
                    title: 'فعال',
                    value: _formatInt(insights.activeMembers),
                    accent: const Color(0xFF80CBC4),
                    icon: Icons.verified_user_outlined,
                  ),
                  (
                    title: 'بدهی',
                    value: _formatMoneyRial(insights.totalDebt),
                    accent: const Color(0xFFFF8A65),
                    icon: Icons.account_balance_wallet_outlined,
                  ),
                  (
                    title: 'جدید ماه',
                    value: _formatInt(insights.newMembersThisMonth),
                    accent: const Color(0xFFA5D6A7),
                    icon: Icons.person_add_alt_1_outlined,
                  ),
                  (
                    title: 'بازرسی ماه',
                    value: loadingInsights && !snapshot.hasData
                        ? '...'
                        : (insights.inspectionsThisMonth == null
                            ? '—'
                            : _formatInt(insights.inspectionsThisMonth!)),
                    accent: const Color(0xFF90CAF9),
                    icon: Icons.fact_check_outlined,
                  ),
                  (
                    title: 'انقضا ماه',
                    value: _formatInt(insights.expiringThisMonth),
                    accent: const Color(0xFFFFCC80),
                    icon: Icons.event_busy_outlined,
                  ),
                ];

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                name.isEmpty ? '—' : name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              _chip(Icons.badge_outlined, roleText),
                              _chip(Icons.pin_outlined, _u('id_user')),
                            ],
                          ),
                        ),
                        StreamBuilder<DateTime>(
                          stream: _clockStream,
                          initialData: DateTime.now(),
                          builder: (context, snap) {
                            final now = snap.data ?? DateTime.now();
                            return Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8),
                              child: Text(
                                '${_faDate(now)}  ${_time(now)}',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            );
                          },
                        ),
                        FilledButton.icon(
                          onPressed: widget.busy ? null : widget.onLogout,
                          icon: const Icon(Icons.logout, size: 15),
                          label: const Text('خروج'),
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF1E3A5F),
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            minimumSize: const Size(0, 30),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        _infoPill(Icons.apartment_outlined, _co('name_co')),
                        _infoPill(Icons.category_outlined, _co('lbl_type')),
                        _infoPill(Icons.qr_code_2_outlined, _u('code_co')),
                        if (_co('tel1_co') != '—')
                          _infoPill(Icons.call_outlined, _co('tel1_co')),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        for (var i = 0; i < metrics.length; i++) ...[
                          if (i > 0) const SizedBox(width: 6),
                          Expanded(
                            child: _compactMetric(
                              title: metrics[i].title,
                              value: metrics[i].value,
                              accent: metrics[i].accent,
                              icon: metrics[i].icon,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
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
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white70),
          const SizedBox(width: 5),
          Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoPill(IconData icon, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white54),
          const SizedBox(width: 5),
          Text(
            value.isEmpty ? '—' : value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _compactMetric({
    required String title,
    required String value,
    required Color accent,
    required IconData icon,
  }) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          Icon(icon, color: accent, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white70,
                    fontWeight: FontWeight.w700,
                    height: 1.15,
                  ),
                ),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: accent,
                    height: 1.2,
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
