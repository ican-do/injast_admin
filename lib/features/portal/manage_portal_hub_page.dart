import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:injast_admin/features/news/manage_news_page.dart';
import 'package:injast_admin/features/personnel/manage_personnel_page.dart';
import 'package:injast_admin/features/portal/portal_api.dart';
import 'package:injast_admin/features/rate_sheets/manage_rate_sheets_page.dart';
import 'package:injast_admin/features/shared/admin_ui.dart';
import 'package:injast_admin/features/shekayat/compat/upload_image.dart';
import 'package:injast_admin/features/tutorials/manage_tutorials_page.dart';
import 'package:injast_admin/server_config.dart';

String _portalImageExt(XFile file) {
  final name = (file.name.isNotEmpty ? file.name : file.path).toLowerCase();
  for (final e in ['.png', '.webp', '.gif', '.jpeg', '.jpg', '.bmp']) {
    if (name.endsWith(e)) return e == '.jpeg' ? '.jpg' : e;
  }
  final mime = (file.mimeType ?? '').toLowerCase();
  if (mime.contains('png')) return '.png';
  if (mime.contains('webp')) return '.webp';
  if (mime.contains('gif')) return '.gif';
  return '.jpg';
}

class ManagePortalHubPage extends StatefulWidget {
  const ManagePortalHubPage({
    super.key,
    required this.codeCo,
    this.currentUserId,
  });

  final String codeCo;
  final String? currentUserId;

  @override
  State<ManagePortalHubPage> createState() => _ManagePortalHubPageState();
}

class _ManagePortalHubPageState extends State<ManagePortalHubPage> {
  int _index = 0;

  static const _tabs = [
    (FluentIcons.color_24_regular, 'هویت و قالب'),
    (FluentIcons.info_24_regular, 'درباره و رئیس'),
    (FluentIcons.apps_list_24_regular, 'چیدمان خانه'),
    (FluentIcons.data_histogram_24_regular, 'آمار'),
    (FluentIcons.image_24_regular, 'گالری'),
    (FluentIcons.quiz_new_24_regular, 'سوالات متداول'),
    (FluentIcons.timeline_24_regular, 'تایم‌لاین'),
    (FluentIcons.people_team_24_regular, 'هیئت مدیره'),
    (FluentIcons.toolbox_24_regular, 'خدمات سایت'),
    (FluentIcons.gavel_24_regular, 'راهنمای شکایت'),
    (FluentIcons.flash_24_regular, 'اقدامات سریع'),
    (FluentIcons.star_24_regular, 'اعضای عمومی'),
    (FluentIcons.link_24_regular, 'میانبر محتوا'),
  ];

  @override
  Widget build(BuildContext context) {
    return AdminPageShell(
      title: 'مدیریت درگاه دیجیتال',
      subtitle: 'تنظیم وب‌سایت اتحادیه · code_co=${widget.codeCo}',
      icon: FluentIcons.globe_24_regular,
      accent: const Color(0xFF1A56DB),
      maxWidth: 1400,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 220,
                height: constraints.maxHeight.isFinite ? constraints.maxHeight : 600,
                child: Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: const BorderSide(color: AdminUi.cardBorder),
                  ),
                  child: ListView.builder(
                    itemCount: _tabs.length,
                    itemBuilder: (context, i) {
                      final t = _tabs[i];
                      final selected = _index == i;
                      return ListTile(
                        selected: selected,
                        selectedTileColor: const Color(0xFFEFF6FF),
                        leading: Icon(t.$1, color: selected ? const Color(0xFF1A56DB) : AdminUi.muted),
                        title: Text(
                          t.$2,
                          style: TextStyle(
                            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        onTap: () => setState(() => _index = i),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: SizedBox(
                  height: constraints.maxHeight.isFinite ? constraints.maxHeight : null,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: switch (_index) {
                      0 => _SettingsThemeTab(codeCo: widget.codeCo, userId: widget.currentUserId),
                      1 => _AboutPresidentTab(codeCo: widget.codeCo, userId: widget.currentUserId),
                      2 => _HomeLayoutTab(codeCo: widget.codeCo, userId: widget.currentUserId),
                      3 => _StatsTab(codeCo: widget.codeCo, userId: widget.currentUserId),
                      4 => _CrudListTab(
                          codeCo: widget.codeCo,
                          userId: widget.currentUserId,
                          resource: 'gallery',
                          title: 'گالری',
                          fields: const [
                            _FieldSpec('title', 'عنوان'),
                            _FieldSpec('image_url', 'آدرس تصویر', isImage: true),
                            _FieldSpec('event_date', 'تاریخ'),
                            _FieldSpec('display_order', 'ترتیب', isNumber: true),
                          ],
                          titleKey: 'title',
                        ),
                      5 => _CrudListTab(
                          codeCo: widget.codeCo,
                          userId: widget.currentUserId,
                          resource: 'faqs',
                          title: 'سوالات متداول',
                          fields: const [
                            _FieldSpec('question', 'سؤال'),
                            _FieldSpec('answer', 'پاسخ', multiline: true),
                            _FieldSpec('category', 'دسته'),
                            _FieldSpec('display_order', 'ترتیب', isNumber: true),
                          ],
                          titleKey: 'question',
                        ),
                      6 => _CrudListTab(
                          codeCo: widget.codeCo,
                          userId: widget.currentUserId,
                          resource: 'timeline',
                          title: 'تایم‌لاین',
                          fields: const [
                            _FieldSpec('year_label', 'سال'),
                            _FieldSpec('title', 'عنوان'),
                            _FieldSpec('description', 'توضیح', multiline: true),
                            _FieldSpec('display_order', 'ترتیب', isNumber: true),
                          ],
                          titleKey: 'title',
                        ),
                      7 => _CrudListTab(
                          codeCo: widget.codeCo,
                          userId: widget.currentUserId,
                          resource: 'board',
                          title: 'هیئت مدیره',
                          fields: const [
                            _FieldSpec('full_name', 'نام'),
                            _FieldSpec('role_title', 'سمت'),
                            _FieldSpec('bio', 'رزومه', multiline: true),
                            _FieldSpec('image_url', 'تصویر', isImage: true),
                            _FieldSpec('email', 'ایمیل'),
                            _FieldSpec('phone', 'تلفن'),
                            _FieldSpec('display_order', 'ترتیب', isNumber: true),
                          ],
                          titleKey: 'full_name',
                        ),
                      8 => _CrudListTab(
                          codeCo: widget.codeCo,
                          userId: widget.currentUserId,
                          resource: 'services',
                          title: 'خدمات سایت',
                          fields: const [
                            _FieldSpec('title', 'عنوان'),
                            _FieldSpec('summary', 'خلاصه'),
                            _FieldSpec('description', 'توضیح کامل', multiline: true),
                            _FieldSpec('duration_text', 'مدت زمان'),
                            _FieldSpec('cost_text', 'هزینه'),
                            _FieldSpec('category', 'دسته'),
                            _FieldSpec('image_url', 'تصویر', isImage: true),
                            _FieldSpec('display_order', 'ترتیب', isNumber: true),
                          ],
                          titleKey: 'title',
                        ),
                      9 => _CrudListTab(
                          codeCo: widget.codeCo,
                          userId: widget.currentUserId,
                          resource: 'complaint-guides',
                          title: 'راهنمای شکایت',
                          fields: const [
                            _FieldSpec('type_key', 'کلید نوع (مثلا customer)'),
                            _FieldSpec('title', 'عنوان'),
                            _FieldSpec('description', 'توضیح'),
                            _FieldSpec('notes', 'نکات (هر خط یک نکته)', multiline: true),
                            _FieldSpec('display_order', 'ترتیب', isNumber: true),
                          ],
                          titleKey: 'title',
                          notesAsLines: true,
                        ),
                      10 => _CrudListTab(
                          codeCo: widget.codeCo,
                          userId: widget.currentUserId,
                          resource: 'quick-actions',
                          title: 'اقدامات سریع',
                          fields: const [
                            _FieldSpec('title', 'عنوان'),
                            _FieldSpec('subtitle', 'زیرعنوان'),
                            _FieldSpec('route_path', 'مسیر (مثلا /complaint)'),
                            _FieldSpec('icon_name', 'نام آیکن'),
                            _FieldSpec('display_order', 'ترتیب', isNumber: true),
                          ],
                          titleKey: 'title',
                        ),
                      11 => _CrudListTab(
                          codeCo: widget.codeCo,
                          userId: widget.currentUserId,
                          resource: 'members',
                          title: 'اعضای عمومی / برتر',
                          fields: const [
                            _FieldSpec('store_name', 'نام واحد'),
                            _FieldSpec('owner_name', 'مالک'),
                            _FieldSpec('raste', 'رسته'),
                            _FieldSpec('district', 'منطقه'),
                            _FieldSpec('address', 'آدرس', multiline: true),
                            _FieldSpec('phone', 'تلفن'),
                            _FieldSpec('about_text', 'درباره', multiline: true),
                            _FieldSpec('logo_url', 'لوگو', isImage: true),
                            _FieldSpec('cover_url', 'کاور', isImage: true),
                            _FieldSpec('rating', 'امتیاز', isNumber: true),
                            _FieldSpec('experience_years', 'سابقه (سال)', isNumber: true),
                            _FieldSpec('work_hours', 'ساعات کاری'),
                            _FieldSpec('website', 'وب‌سایت'),
                            _FieldSpec('instagram', 'اینستاگرام'),
                            _FieldSpec('telegram', 'تلگرام'),
                            _FieldSpec('activity_type', 'نوع فعالیت'),
                            _FieldSpec('display_order', 'ترتیب', isNumber: true),
                          ],
                          titleKey: 'store_name',
                          extraTopFlag: true,
                        ),
                      _ => _ShortcutsTab(
                          codeCo: widget.codeCo,
                          userId: widget.currentUserId,
                        ),
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _FieldSpec {
  const _FieldSpec(this.key, this.label, {this.multiline = false, this.isImage = false, this.isNumber = false});
  final String key;
  final String label;
  final bool multiline;
  final bool isImage;
  final bool isNumber;
}

/* -------------------- Settings Theme -------------------- */

class _SettingsThemeTab extends StatefulWidget {
  const _SettingsThemeTab({required this.codeCo, this.userId});
  final String codeCo;
  final String? userId;

  @override
  State<_SettingsThemeTab> createState() => _SettingsThemeTabState();
}

class _SettingsThemeTabState extends State<_SettingsThemeTab> {
  PortalSettings? _s;
  bool _loading = true;
  bool _saving = false;
  final _ctrls = <String, TextEditingController>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in _ctrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _c(String key, String? value) {
    return _ctrls.putIfAbsent(key, () => TextEditingController(text: value ?? ''));
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final s = await PortalApi.getSettings(widget.codeCo) ?? PortalSettings(codeCo: widget.codeCo);
      _s = s;
      _c('union_display_name', s.unionDisplayName);
      _c('tagline', s.tagline);
      _c('short_description', s.shortDescription);
      _c('primary_color', s.primaryColor);
      _c('primary_dark', s.primaryDark);
      _c('accent_color', s.accentColor);
      _c('surface_tint', s.surfaceTint);
      _c('address', s.address);
      _c('phone', s.phone);
      _c('mobile', s.mobile);
      _c('email', s.email);
      _c('work_hours', s.workHours);
      _c('city', s.city);
      _c('province', s.province);
      _c('ticker_text', s.tickerText);
      _c('app_android_url', s.appAndroidUrl);
      _c('app_ios_url', s.appIosUrl);
      _c('social_instagram', s.socialInstagram);
      _c('social_telegram', s.socialTelegram);
      _c('social_linkedin', s.socialLinkedin);
      _c('hero_highlights', (s.heroHighlights).map((e) => '$e').join('\n'));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطا: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickUpload(String field) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery);
    if (file == null) return;
    final ext = _portalImageExt(file);
    final path = await uploadImageToServer(
      file,
      'portal',
      'portal_${widget.codeCo}_${field}_${DateTime.now().millisecondsSinceEpoch}$ext',
    );
    if (path == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('آپلود ناموفق')));
      }
      return;
    }
    setState(() {
      if (field == 'logo') _s!.logoUrl = path;
      if (field == 'hero') _s!.heroImageUrl = path;
    });
  }

  Future<void> _save() async {
    final s = _s!;
    s.unionDisplayName = _c('union_display_name', null).text.trim();
    s.tagline = _c('tagline', null).text.trim();
    s.shortDescription = _c('short_description', null).text.trim();
    s.primaryColor = _c('primary_color', null).text.trim();
    s.primaryDark = _c('primary_dark', null).text.trim();
    s.accentColor = _c('accent_color', null).text.trim();
    s.surfaceTint = _c('surface_tint', null).text.trim();
    s.address = _c('address', null).text.trim();
    s.phone = _c('phone', null).text.trim();
    s.mobile = _c('mobile', null).text.trim();
    s.email = _c('email', null).text.trim();
    s.workHours = _c('work_hours', null).text.trim();
    s.city = _c('city', null).text.trim();
    s.province = _c('province', null).text.trim();
    s.tickerText = _c('ticker_text', null).text.trim();
    s.appAndroidUrl = _c('app_android_url', null).text.trim();
    s.appIosUrl = _c('app_ios_url', null).text.trim();
    s.socialInstagram = _c('social_instagram', null).text.trim();
    s.socialTelegram = _c('social_telegram', null).text.trim();
    s.socialLinkedin = _c('social_linkedin', null).text.trim();
    s.heroHighlights = _c('hero_highlights', null)
        .text
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    setState(() => _saving = true);
    try {
      _s = await PortalApi.saveSettings(
        widget.codeCo,
        s,
        idUser: int.tryParse(widget.userId ?? ''),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ذخیره شد')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطا: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Color _parse(String hex, Color fallback) {
    try {
      var h = hex.replaceAll('#', '');
      if (h.length == 6) h = 'FF$h';
      return Color(int.parse(h, radix: 16));
    } catch (_) {
      return fallback;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _s == null) {
      return const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()));
    }
    final s = _s!;
    final primary = _parse(s.primaryColor, const Color(0xFF1A56DB));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionCard(
          title: 'هویت بصری و لوگو',
          child: Column(
            children: [
              Row(
                children: [
                  _imageBox(
                    label: 'لوگوی اتحادیه',
                    url: mediaAbsoluteUrl(s.logoUrl),
                    onUpload: () => _pickUpload('logo'),
                    onClear: () => setState(() => s.logoUrl = null),
                  ),
                  const SizedBox(width: 16),
                  _imageBox(
                    label: 'تصویر Hero (اختیاری)',
                    url: mediaAbsoluteUrl(s.heroImageUrl),
                    onUpload: () => _pickUpload('hero'),
                    onClear: () => setState(() => s.heroImageUrl = null),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Container(
                      height: 140,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [primary, _parse(s.accentColor, Colors.cyan)]),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      alignment: Alignment.center,
                      child: const Text('پیش‌نمایش قالب رنگی',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _colorField('رنگ اصلی', 'primary_color', s.primaryColor),
                  _colorField('رنگ تیره', 'primary_dark', s.primaryDark),
                  _colorField('رنگ مکمل', 'accent_color', s.accentColor),
                  _colorField('زمینه روشن', 'surface_tint', s.surfaceTint),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _sectionCard(
          title: 'اطلاعات نمایشی اتحادیه',
          child: Column(
            children: [
              _tf('نام نمایشی اتحادیه', 'union_display_name'),
              _tf('شعار / سامانه خدمات الکترونیکی', 'tagline'),
              _tf('توضیح کوتاه Hero', 'short_description', maxLines: 3),
              _tf('نکات Hero (هر خط یک مورد)', 'hero_highlights', maxLines: 4),
              _tf('متن نوار خبری بالا', 'ticker_text'),
              SwitchListTile(
                title: const Text('انتشار عمومی درگاه'),
                value: s.isPublished,
                onChanged: (v) => setState(() => s.isPublished = v),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _sectionCard(
          title: 'تماس و اپ',
          child: Column(
            children: [
              _tf('آدرس', 'address', maxLines: 2),
              Row(children: [
                Expanded(child: _tf('تلفن', 'phone')),
                const SizedBox(width: 8),
                Expanded(child: _tf('موبایل', 'mobile')),
              ]),
              Row(children: [
                Expanded(child: _tf('ایمیل', 'email')),
                const SizedBox(width: 8),
                Expanded(child: _tf('ساعات کاری', 'work_hours')),
              ]),
              Row(children: [
                Expanded(child: _tf('شهر', 'city')),
                const SizedBox(width: 8),
                Expanded(child: _tf('استان', 'province')),
              ]),
              _tf('لینک Google Play', 'app_android_url'),
              _tf('لینک App Store', 'app_ios_url'),
              Row(children: [
                Expanded(child: _tf('اینستاگرام', 'social_instagram')),
                const SizedBox(width: 8),
                Expanded(child: _tf('تلگرام', 'social_telegram')),
                const SizedBox(width: 8),
                Expanded(child: _tf('لینکدین', 'social_linkedin')),
              ]),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.save_outlined),
            label: const Text('ذخیره هویت و قالب'),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'آدرس عمومی درگاه پس از اتصال دامنه: /?co=${widget.codeCo}\nAPI: ${getApiUrl('portal/public/${widget.codeCo}')}',
          style: const TextStyle(color: AdminUi.muted, fontSize: 12, height: 1.5),
        ),
      ],
    );
  }

  Widget _colorField(String label, String key, String current) {
    final color = _parse(current, Colors.blue);
    return SizedBox(
      width: 200,
      child: TextField(
        controller: _c(key, current),
        decoration: AdminUi.fieldDecoration(label).copyWith(
          prefixIcon: Padding(
            padding: const EdgeInsets.all(10),
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4), border: Border.all()),
            ),
          ),
        ),
        onChanged: (_) => setState(() {
          if (key == 'primary_color') _s!.primaryColor = _c(key, null).text;
          if (key == 'accent_color') _s!.accentColor = _c(key, null).text;
          if (key == 'primary_dark') _s!.primaryDark = _c(key, null).text;
          if (key == 'surface_tint') _s!.surfaceTint = _c(key, null).text;
        }),
      ),
    );
  }

  Widget _tf(String label, String key, {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: _c(key, null),
        maxLines: maxLines,
        decoration: AdminUi.fieldDecoration(label),
      ),
    );
  }
}

Widget _sectionCard({required String title, required Widget child}) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: AdminUi.cardDecoration(),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
        const SizedBox(height: 12),
        child,
      ],
    ),
  );
}

Widget _imageBox({
  required String label,
  required String url,
  required VoidCallback onUpload,
  required VoidCallback onClear,
}) {
  return Column(
    children: [
      Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      Container(
        width: 140,
        height: 140,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AdminUi.cardBorder),
        ),
        clipBehavior: Clip.antiAlias,
        child: url.isEmpty
            ? const Icon(Icons.image_outlined, size: 40, color: AdminUi.muted)
            : Image.network(url, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image)),
      ),
      const SizedBox(height: 8),
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextButton(onPressed: onUpload, child: const Text('آپلود')),
          TextButton(onPressed: onClear, child: const Text('حذف')),
        ],
      ),
    ],
  );
}

/* -------------------- About / President -------------------- */

class _AboutPresidentTab extends StatefulWidget {
  const _AboutPresidentTab({required this.codeCo, this.userId});
  final String codeCo;
  final String? userId;

  @override
  State<_AboutPresidentTab> createState() => _AboutPresidentTabState();
}

class _AboutPresidentTabState extends State<_AboutPresidentTab> {
  PortalSettings? _s;
  bool _loading = true;
  final _ctrls = <String, TextEditingController>{};

  TextEditingController _c(String k, String? v) =>
      _ctrls.putIfAbsent(k, () => TextEditingController(text: v ?? ''));

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in _ctrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final s = await PortalApi.getSettings(widget.codeCo) ?? PortalSettings(codeCo: widget.codeCo);
      _s = s;
      _c('about_text', s.aboutText);
      _c('mission', s.mission);
      _c('vision', s.vision);
      _c('goals', s.goals);
      _c('history_summary', s.historySummary);
      _c('president_name', s.presidentName);
      _c('president_title', s.presidentTitle);
      _c('president_message', s.presidentMessage);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    final s = _s!;
    s.aboutText = _c('about_text', null).text;
    s.mission = _c('mission', null).text;
    s.vision = _c('vision', null).text;
    s.goals = _c('goals', null).text;
    s.historySummary = _c('history_summary', null).text;
    s.presidentName = _c('president_name', null).text;
    s.presidentTitle = _c('president_title', null).text;
    s.presidentMessage = _c('president_message', null).text;
    try {
      await PortalApi.saveSettings(widget.codeCo, s, idUser: int.tryParse(widget.userId ?? ''));
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ذخیره شد')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _uploadPresident() async {
    // بدون imageQuality تا PNG فشرده/تبدیل به JPG نشود
    final file = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (file == null) return;
    final ext = _portalImageExt(file);
    final path = await uploadImageToServer(
      file,
      'portal',
      'president_${widget.codeCo}_${DateTime.now().millisecondsSinceEpoch}$ext',
    );
    if (path == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('آپلود ناموفق')));
      }
      return;
    }
    setState(() => _s!.presidentImageUrl = path);
    try {
      await PortalApi.saveSettings(widget.codeCo, _s!, idUser: int.tryParse(widget.userId ?? ''));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تصویر رئیس ذخیره شد')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('آپلود شد ولی ذخیره تنظیمات ناموفق: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _s == null) return const Center(child: CircularProgressIndicator());
    return Column(
      children: [
        _sectionCard(
          title: 'درباره اتحادیه',
          child: Column(
            children: [
              TextField(controller: _c('about_text', null), maxLines: 5, decoration: AdminUi.fieldDecoration('متن درباره')),
              const SizedBox(height: 8),
              TextField(controller: _c('history_summary', null), maxLines: 2, decoration: AdminUi.fieldDecoration('خلاصه تاریخچه')),
              const SizedBox(height: 8),
              TextField(controller: _c('mission', null), maxLines: 2, decoration: AdminUi.fieldDecoration('ماموریت')),
              const SizedBox(height: 8),
              TextField(controller: _c('vision', null), maxLines: 2, decoration: AdminUi.fieldDecoration('چشم‌انداز')),
              const SizedBox(height: 8),
              TextField(controller: _c('goals', null), maxLines: 2, decoration: AdminUi.fieldDecoration('اهداف')),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _sectionCard(
          title: 'پیام رئیس اتحادیه',
          child: Column(
            children: [
              _imageBox(
                label: 'تصویر رئیس',
                url: mediaAbsoluteUrl(_s!.presidentImageUrl),
                onUpload: _uploadPresident,
                onClear: () => setState(() => _s!.presidentImageUrl = null),
              ),
              TextField(controller: _c('president_name', null), decoration: AdminUi.fieldDecoration('نام')),
              const SizedBox(height: 8),
              TextField(controller: _c('president_title', null), decoration: AdminUi.fieldDecoration('سمت')),
              const SizedBox(height: 8),
              TextField(controller: _c('president_message', null), maxLines: 5, decoration: AdminUi.fieldDecoration('پیام')),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(onPressed: _save, icon: const Icon(Icons.save), label: const Text('ذخیره')),
        ),
      ],
    );
  }
}

/* -------------------- Home layout / Stats -------------------- */

class _HomeLayoutTab extends StatefulWidget {
  const _HomeLayoutTab({required this.codeCo, this.userId});
  final String codeCo;
  final String? userId;
  @override
  State<_HomeLayoutTab> createState() => _HomeLayoutTabState();
}

class _HomeLayoutTabState extends State<_HomeLayoutTab> {
  List<Map<String, dynamic>> _widgets = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await PortalApi.getSettings(widget.codeCo);
    setState(() {
      _widgets = (s?.homeWidgets ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList()
        ..sort((a, b) => (a['order'] as num? ?? 0).compareTo(b['order'] as num? ?? 0));
      _loading = false;
    });
  }

  Future<void> _save() async {
    final s = await PortalApi.getSettings(widget.codeCo) ?? PortalSettings(codeCo: widget.codeCo);
    s.homeWidgets = _widgets;
    await PortalApi.saveSettings(widget.codeCo, s, idUser: int.tryParse(widget.userId ?? ''));
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('چیدمان ذخیره شد')));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return Column(
      children: [
        _sectionCard(
          title: 'ویجت‌های صفحه اصلی',
          child: ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _widgets.length,
            onReorder: (o, n) {
              setState(() {
                if (n > o) n--;
                final item = _widgets.removeAt(o);
                _widgets.insert(n, item);
                for (var i = 0; i < _widgets.length; i++) {
                  _widgets[i]['order'] = i + 1;
                }
              });
            },
            itemBuilder: (context, i) {
              final w = _widgets[i];
              return ListTile(
                key: ValueKey(w['id']),
                leading: const Icon(Icons.drag_indicator),
                title: Text('${w['id']}'),
                subtitle: Text('حداکثر آیتم: ${w['itemLimit'] ?? 4}'),
                trailing: Switch(
                  value: w['enabled'] == true,
                  onChanged: (v) => setState(() => w['enabled'] = v),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton(onPressed: _save, child: const Text('ذخیره چیدمان')),
        ),
      ],
    );
  }
}

class _StatsTab extends StatefulWidget {
  const _StatsTab({required this.codeCo, this.userId});
  final String codeCo;
  final String? userId;
  @override
  State<_StatsTab> createState() => _StatsTabState();
}

class _StatsTabState extends State<_StatsTab> {
  List<Map<String, dynamic>> _stats = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await PortalApi.getSettings(widget.codeCo);
    setState(() {
      _stats = (s?.stats ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      if (_stats.isEmpty) {
        _stats = [
          {'label': 'سال فعالیت', 'value': 0, 'suffix': '', 'icon': 'timeline'},
          {'label': 'عضو فعال', 'value': 0, 'suffix': '+', 'icon': 'groups'},
          {'label': 'شکایت رسیدگی‌شده', 'value': 0, 'suffix': '', 'icon': 'task'},
          {'label': 'رضایت', 'value': 0, 'suffix': '%', 'icon': 'smile'},
        ];
      }
      _loading = false;
    });
  }

  Future<void> _save() async {
    final s = await PortalApi.getSettings(widget.codeCo) ?? PortalSettings(codeCo: widget.codeCo);
    s.stats = _stats;
    await PortalApi.saveSettings(widget.codeCo, s, idUser: int.tryParse(widget.userId ?? ''));
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('آمار ذخیره شد')));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return Column(
      children: [
        ..._stats.asMap().entries.map((e) {
          final i = e.key;
          final st = e.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _sectionCard(
              title: 'شمارنده ${i + 1}',
              child: Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      initialValue: '${st['label'] ?? ''}',
                      decoration: AdminUi.fieldDecoration('برچسب'),
                      onChanged: (v) => st['label'] = v,
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 100,
                    child: TextFormField(
                      initialValue: '${st['value'] ?? 0}',
                      decoration: AdminUi.fieldDecoration('مقدار'),
                      onChanged: (v) => st['value'] = int.tryParse(v) ?? 0,
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 80,
                    child: TextFormField(
                      initialValue: '${st['suffix'] ?? ''}',
                      decoration: AdminUi.fieldDecoration('پسوند'),
                      onChanged: (v) => st['suffix'] = v,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton(onPressed: _save, child: const Text('ذخیره آمار')),
        ),
      ],
    );
  }
}

/* -------------------- Generic CRUD -------------------- */

class _CrudListTab extends StatefulWidget {
  const _CrudListTab({
    required this.codeCo,
    required this.resource,
    required this.title,
    required this.fields,
    required this.titleKey,
    this.userId,
    this.notesAsLines = false,
    this.extraTopFlag = false,
  });

  final String codeCo;
  final String? userId;
  final String resource;
  final String title;
  final List<_FieldSpec> fields;
  final String titleKey;
  final bool notesAsLines;
  final bool extraTopFlag;

  @override
  State<_CrudListTab> createState() => _CrudListTabState();
}

class _CrudListTabState extends State<_CrudListTab> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _items = await PortalApi.list(widget.resource, widget.codeCo);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _edit([Map<String, dynamic>? existing]) async {
    final ctrls = <String, TextEditingController>{};
    for (final f in widget.fields) {
      var val = existing?[f.key];
      if (f.key == 'notes' && val is List) val = val.join('\n');
      ctrls[f.key] = TextEditingController(text: '${val ?? ''}');
    }
    var isActive = existing == null || existing['is_active'] == 1 || existing['is_active'] == true;
    var isTop = existing?['is_top'] == 1 || existing?['is_top'] == true;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(existing == null ? 'افزودن ${widget.title}' : 'ویرایش'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final f in widget.fields) ...[
                    if (f.isImage)
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: ctrls[f.key],
                              decoration: AdminUi.fieldDecoration(f.label),
                            ),
                          ),
                          IconButton(
                            tooltip: 'آپلود',
                            onPressed: () async {
                              final file = await ImagePicker().pickImage(source: ImageSource.gallery);
                              if (file == null) return;
                              final ext = _portalImageExt(file);
                              final path = await uploadImageToServer(
                                file,
                                'portal',
                                'portal_${widget.resource}_${DateTime.now().millisecondsSinceEpoch}$ext',
                              );
                              if (path != null) ctrls[f.key]!.text = path;
                              setLocal(() {});
                            },
                            icon: const Icon(Icons.upload),
                          ),
                        ],
                      )
                    else
                      TextField(
                        controller: ctrls[f.key],
                        maxLines: f.multiline ? 4 : 1,
                        keyboardType: f.isNumber ? TextInputType.number : TextInputType.text,
                        decoration: AdminUi.fieldDecoration(f.label),
                      ),
                    const SizedBox(height: 8),
                  ],
                  SwitchListTile(
                    title: const Text('فعال'),
                    value: isActive,
                    onChanged: (v) => setLocal(() => isActive = v),
                  ),
                  if (widget.extraTopFlag)
                    SwitchListTile(
                      title: const Text('عضو برتر'),
                      value: isTop,
                      onChanged: (v) => setLocal(() => isTop = v),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('انصراف')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('ذخیره')),
          ],
        ),
      ),
    );

    if (ok != true) {
      for (final c in ctrls.values) {
        c.dispose();
      }
      return;
    }

    final body = <String, dynamic>{
      'code_co': widget.codeCo,
      'is_active': isActive,
      if (widget.userId != null) 'id_user': int.tryParse(widget.userId!),
      if (widget.extraTopFlag) 'is_top': isTop,
    };
    for (final f in widget.fields) {
      final raw = ctrls[f.key]!.text.trim();
      if (f.key == 'notes' && widget.notesAsLines) {
        body['notes'] = raw.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      } else if (f.isNumber) {
        body[f.key] = num.tryParse(raw) ?? 0;
      } else {
        body[f.key] = raw;
      }
    }

    try {
      if (existing == null) {
        await PortalApi.create(widget.resource, body);
      } else {
        await PortalApi.update(widget.resource, existing['id'] as int, body);
      }
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
    for (final c in ctrls.values) {
      c.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return Column(
      children: [
        Row(
          children: [
            Text(widget.title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
            const Spacer(),
            FilledButton.icon(
              onPressed: () => _edit(),
              icon: const Icon(Icons.add),
              label: const Text('افزودن'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_items.isEmpty)
          const Padding(padding: EdgeInsets.all(40), child: Text('موردی ثبت نشده'))
        else
          ..._items.map((item) {
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text('${item[widget.titleKey] ?? item['title'] ?? item['id']}'),
                subtitle: Text(item['is_active'] == 1 || item['is_active'] == true ? 'فعال' : 'غیرفعال'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(onPressed: () => _edit(item), icon: const Icon(Icons.edit_outlined)),
                    IconButton(
                      onPressed: () async {
                        await PortalApi.delete(widget.resource, item['id'] as int);
                        await _load();
                      },
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }
}

class _ShortcutsTab extends StatelessWidget {
  const _ShortcutsTab({required this.codeCo, this.userId});
  final String codeCo;
  final String? userId;

  @override
  Widget build(BuildContext context) {
    Widget tile(String title, IconData icon, Widget page) {
      return ListTile(
        leading: Icon(icon, color: const Color(0xFF1A56DB)),
        title: Text(title),
        trailing: const Icon(Icons.chevron_left),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => page)),
      );
    }

    return _sectionCard(
      title: 'محتوای موجود سامانه (اشتراکی با اپ‌ها)',
      child: Column(
        children: [
          tile('مدیریت اخبار', FluentIcons.news_24_regular, ManageNewsPage(codeCo: codeCo, currentUserId: userId)),
          tile('مدیریت آموزش', FluentIcons.book_24_regular, ManageTutorialsPage(codeCo: codeCo, currentUserId: userId)),
          tile('نرخ‌نامه', FluentIcons.money_24_regular, ManageRateSheetsPage(codeCo: codeCo)),
          tile('پرسنل اتحادیه', FluentIcons.people_24_regular, ManagePersonnelPage(codeCo: codeCo, currentUserId: userId)),
          const Divider(),
          SelectableText('API عمومی: ${getApiUrl('portal/public/$codeCo')}'),
        ],
      ),
    );
  }
}
