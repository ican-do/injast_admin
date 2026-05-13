import 'dart:async';

import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:injast_admin/asnaf_site_page.dart';
import 'package:injast_admin/file_management/file_management_page.dart';
import 'package:injast_admin/pos_web_service.dart';
import 'package:injast_admin/settings_sync_page.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shamsi_date/shamsi_date.dart';

void main() {
  runApp(const InjastAdminApp());
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
    final primaryTextTheme = GoogleFonts.vazirmatnTextTheme(base.primaryTextTheme);
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
  String? _error;
  bool _busy = true;

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
      await _svc.pollOnce();
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
              preferredSize: const Size.fromHeight(210),
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
    return Material(
      color: item.backgroundColor,
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
          if (item.actionKey == 'union_members' || item.actionKey == 'file_management') {
            final codeCo = user?['code_co']?.toString().trim() ?? '';
            if (codeCo.isNotEmpty) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => FileManagementPage(codeCo: codeCo),
                ),
              );
              return;
            }
          }
          if (item.actionKey == 'settings_menu') {
            await _showSettingsMenu(context);
            return;
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('«${item.label}» به‌زودی فعال می‌شود.')),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(item.icon, color: item.iconColor, size: 18),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  item.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showSettingsMenu(BuildContext context) async {
    final box = context.findRenderObject() as RenderBox?;
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (box == null || overlay == null) return;
    final topLeft = box.localToGlobal(Offset.zero, ancestor: overlay);
    final rect = Rect.fromLTWH(topLeft.dx, topLeft.dy, box.size.width, box.size.height);

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
      _PanelItem(label: 'سایت ایرانی اصناف', icon: FluentIcons.globe_24_regular, backgroundColor: Color(0xFFE8EAF6), iconColor: Color(0xFF3949AB), actionKey: 'asnaf_site'),
   //   _PanelItem(label: 'اعضاء اتحادیه', icon: FluentIcons.people_24_regular, backgroundColor: Color(0xFFE3F2FD), iconColor: Color(0xFF1565C0), actionKey: 'union_members'),
      _PanelItem(label: 'مدیریت پرونده‌ها', icon: FluentIcons.document_table_24_regular, backgroundColor: Color(0xFFEAF2FF), iconColor: Color(0xFF1E3A5F), actionKey: 'file_management'),
   //   _PanelItem(label: 'نمایش اسامی پرسنل', icon: FluentIcons.person_accounts_24_regular, backgroundColor: Color(0xFFF3E5F5), iconColor: Color(0xFF7B1FA2)),
   //   _PanelItem(label: 'تنظیم اسامی پرسنل', icon: Icons.manage_accounts_outlined, backgroundColor: Color(0xFFFFF3E0), iconColor: Color(0xFFEF6C00)),
   //   _PanelItem(label: 'مدیریت نرخ‌نامه', icon: FluentIcons.receipt_24_regular, backgroundColor: Color(0xFFE0F2F1), iconColor: Color(0xFF00695C)),
   //   _PanelItem(label: 'تنظیمات', icon: FluentIcons.settings_24_regular, backgroundColor: Color(0xFFFFEBEE), iconColor: Color(0xFFC62828), actionKey: 'settings_menu'),
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

class _LoggedInTopPanel extends StatelessWidget {
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

  String _u(String k) => user[k]?.toString().trim().isNotEmpty == true ? user[k].toString().trim() : '—';
  String _co(String k) => unionInfo?[k]?.toString().trim().isNotEmpty == true ? unionInfo![k].toString().trim() : '—';
  static final Stream<DateTime> _clockStream = Stream<DateTime>.periodic(
    const Duration(seconds: 1),
    (_) => DateTime.now(),
  );

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
    final total = memberStats?['total_members']?.toString() ?? '0';
    final active = memberStats?['active_members']?.toString() ?? '0';
    final inactive = memberStats?['inactive_members']?.toString() ?? '0';
    return AppBar(
      automaticallyImplyLeading: false,
      toolbarHeight: 235,
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
                BoxShadow(color: Color(0x44000000), blurRadius: 14, offset: Offset(0, 4)),
              ],
              border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
            ),
            child: LayoutBuilder(
              builder: (context, c) {
                final isNarrow = c.maxWidth < 720;
                final info = <Widget>[
                  _chip('کاربر: ${name.isEmpty ? '—' : name}'),
                  _chip('نقش: ${_roleFa(_u('type_user'))}'),
                  _chip('کد کاربر: ${_u('id_user')}'),
                  _chip('کد اتحادیه: ${_u('code_co')}'),
                  _chip('نام اتحادیه: ${_co('name_co')}'),
                  _chip('نوع اتحادیه: ${_co('lbl_type')}'),
                  _chip('تماس اتحادیه: ${_co('tel1_co')}'),
                  _chip('دستگاه: $deviceUuid'),
                ];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'پنل اصلی',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
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
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    _time(now),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
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
                          onPressed: busy ? null : onLogout,
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
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: _statCard('کل اعضا', total, const Color(0xFF4FC3F7))),
                        const SizedBox(width: 8),
                        Expanded(child: _statCard('اعضای فعال', active, const Color(0xFF81C784))),
                        const SizedBox(width: 8),
                        Expanded(child: _statCard('غیرفعال', inactive, const Color(0xFFFFB74D))),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: isNarrow ? info : info,
                        ),
                      ),
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

  Widget _chip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      constraints: const BoxConstraints(minHeight: 30),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _statCard(String title, String value, Color accent) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: Colors.white70)),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: accent)),
        ],
      ),
    );
  }
}

class _QrActivationView extends StatelessWidget {
  const _QrActivationView({
    required this.svc,
    required this.uuid,
    required this.error,
  });

  final PosWebService svc;
  final String? uuid;
  final String? error;

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
                'هر چند ثانیه یک‌بار وضعیت بررسی می‌شود؛ پس از اتصال موفق، به صفحهٔ اصلی می‌روید.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
