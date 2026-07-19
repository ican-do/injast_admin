import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:injast_admin/features/shekayat/compat/screen_util_shim.dart';
import 'package:injast_admin/features/shekayat/shekayat_api.dart';
import 'package:injast_admin/features/shekayat/shekayat_constants.dart';
import 'package:injast_admin/features/shekayat/compat/shekayat_basic.dart';
import 'package:injast_admin/features/shekayat/compat/server_config_shim.dart';
import 'package:injast_admin/features/shekayat/pages/shekayat_widgets.dart';
import 'package:injast_admin/features/shekayat/compat/motion_toast_shim.dart';
import 'package:injast_admin/features/shekayat/compat/persian_fonts_shim.dart';

/// راهنمای کامل سامانه مدیریت شکایات
class ShekayatHelpPage extends StatefulWidget {
  final String codeCo;

  const ShekayatHelpPage({Key? key, required this.codeCo}) : super(key: key);

  @override
  State<ShekayatHelpPage> createState() => _ShekayatHelpPageState();
}

class _ShekayatHelpPageState extends State<ShekayatHelpPage> with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;
  final _formNoteCtrl = TextEditingController();
  bool _noteLoading = true;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 4, vsync: this);
    _loadFormNote();
  }

  Future<void> _loadFormNote() async {
    try {
      final data = await ShekayatApi.getFormNote(widget.codeCo);
      _formNoteCtrl.text = data['form_note']?.toString() ?? '';
    } catch (_) {}
    if (mounted) setState(() => _noteLoading = false);
  }

  Future<void> _saveFormNote() async {
    final ok = await ShekayatApi.saveFormNote(widget.codeCo, _formNoteCtrl.text.trim());
    if (!mounted) return;
    if (ok) {
      MotionToast.success(title: const Text('ذخیره شد'), description: const Text('توضیحات فرم شاکی به‌روز شد')).show(context);
    }
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _formNoteCtrl.dispose();
    super.dispose();
  }

  String get _webLink => getShekayatInviteUrl(widget.codeCo);

  void _copyLink() {
    Clipboard.setData(ClipboardData(text: _webLink));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('لینک کپی شد', style: PersianFonts.Shabnam),
        behavior: SnackBarBehavior.floating,
        backgroundColor: ShekayatTheme.primary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF0F4F8),
        body: NestedScrollView(
          headerSliverBuilder: (_, __) => [
            SliverAppBar(
              expandedHeight: 140.h,
              pinned: true,
              backgroundColor: ShekayatTheme.primary,
              foregroundColor: Colors.white,
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [ShekayatTheme.primary, ShekayatTheme.primaryDark],
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                    ),
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(20.w, 48.h, 20.w, 12.h),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: EdgeInsets.all(10.w),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.school_rounded, color: Colors.white, size: 28.sp),
                              ),
                              SizedBox(width: 12.w),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'راهنمای سامانه شکایات',
                                      style: PersianFonts.Shabnam.copyWith(
                                        fontSize: font_size_18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    Text(
                                      'آشنایی با فرایند، امکانات و لینک وب',
                                      style: PersianFonts.Shabnam.copyWith(fontSize: font_size_10, color: Colors.white70),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              bottom: TabBar(
                controller: _tabCtrl,
                indicatorColor: Colors.white,
                indicatorWeight: 3,
                labelStyle: PersianFonts.Shabnam.copyWith(fontSize: font_size_12, fontWeight: FontWeight.bold),
                unselectedLabelStyle: PersianFonts.Shabnam.copyWith(fontSize: font_size_12),
                tabs: const [
                  Tab(text: 'فرایند کامل'),
                  Tab(text: 'امکانات و دکمه‌ها'),
                  Tab(text: 'لینک وب'),
                  Tab(text: 'توضیحات فرم'),
                ],
              ),
            ),
          ],
          body: TabBarView(
            controller: _tabCtrl,
            children: [
              _buildWorkflowTab(),
              _buildFeaturesTab(),
              _buildWebTab(),
              _buildFormNoteTab(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWorkflowTab() {
    final steps = [
      _StepData(
        1,
        'ثبت شکایت',
        'شکایت از دو راه ثبت می‌شود:\n• توسط اپ اتحادیه (ثبت توسط مسئول)\n• توسط شاکی از طریق لینک وب عمومی\nوضعیت اولیه: «ثبت اولیه»',
        Icons.post_add_rounded,
        ShekayatTheme.primary,
      ),
      _StepData(
        2,
        'تعیین موضوع',
        'از دکمه «موضوع» روی کارت، یک یا چند موضوع شکایت را انتخاب کنید (مثل کم‌فروشی، گران‌فروشی و...).',
        Icons.topic_rounded,
        Colors.amber.shade700,
      ),
      _StepData(
        3,
        'بررسی اولیه',
        'وضعیت را از «ویرایش و نتیجه‌گیری» به «در حال بررسی» تغییر دهید. از فیلتر «بررسی» در بالای لیست برای یافتن این پرونده‌ها استفاده کنید.',
        Icons.fact_check_rounded,
        Colors.orange.shade700,
      ),
      _StepData(
        4,
        'اتصال به واحد صنفی',
        'با «اتصال واحد» پرونده شکایت را به واحد صنفی مرتبط در سیستم وصل کنید. اطلاعات واحد خودکار پر می‌شود.',
        Icons.link_rounded,
        Colors.deepPurple,
      ),
      _StepData(
        5,
        'مدارک و مستندات',
        '• مدارک شاکی: تصاویر آپلودشده از وب یا اپ\n• مدارک مسئول: مستندات ثبت‌شده توسط اتحادیه',
        Icons.folder_copy_rounded,
        ShekayatTheme.accentGreen,
      ),
      _StepData(
        6,
        'کارشناسی',
        'در «کارشناسی» ابتدا پروفایل کارشناس را ثبت کنید، سپس «کارشناسی جدید» را بزنید و نظریه را وارد کنید. وضعیت خودکار «کارشناسی» می‌شود.',
        Icons.engineering_rounded,
        ShekayatTheme.accentCyan,
      ),
      _StepData(
        7,
        'پیگیری',
        'هر تماس، اقدام یا یادداشت پیگیری را با تاریخ و مسئول در بخش «پیگیری» ثبت کنید.',
        Icons.history_rounded,
        Colors.indigo.shade700,
      ),
      _StepData(
        8,
        'جلسه کمیسیون',
        'تاریخ، ساعت و صورتجلسه کمیسیون حل اختلاف را در بخش «کمیسیون» ثبت کنید.',
        Icons.gavel_rounded,
        Colors.grey.shade700,
      ),
      _StepData(
        9,
        'نتیجه‌گیری و اختتام',
        'از «ویرایش و نتیجه‌گیری» نتیجه نهایی (توافق، عدم توافق، رضایت و...) را ثبت کنید. در صورت اختتام، وضعیت «مختومه» می‌شود.',
        Icons.check_circle_outline_rounded,
        ShekayatTheme.accentGreen,
      ),
      _StepData(
        10,
        'گزارش‌گیری',
        'از آیکون گزارش در بالای صفحه، آمار و نمودارهای تفکیکی (وضعیت، موضوع، کارشناس، روند زمانی و...) را مشاهده کنید.',
        Icons.analytics_rounded,
        ShekayatTheme.primaryDark,
      ),
    ];

    return ListView(
      padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 24.h),
      children: [
        _infoBanner(
          'فرایند پیشنهادی',
          'مراحل زیر ترتیب منطقی رسیدگی به شکایت است. بسته به نوع پرونده ممکن است برخی مراحل تکرار یا حذف شوند.',
          Icons.route_rounded,
        ),
        ...steps.asMap().entries.map((e) => _buildStepCard(e.value, isLast: e.key == steps.length - 1)),
      ],
    );
  }

  Widget _buildStepCard(_StepData step, {required bool isLast}) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 40.w,
            child: Column(
              children: [
                Container(
                  width: 32.w,
                  height: 32.w,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [step.color, step.color.withOpacity(0.7)]),
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: step.color.withOpacity(0.35), blurRadius: 6)],
                  ),
                  child: Center(
                    child: Text(
                      '${step.number}',
                      style: PersianFonts.Shabnam.copyWith(fontSize: font_size_12, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(width: 2, margin: EdgeInsets.symmetric(vertical: 4.h), color: step.color.withOpacity(0.3)),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              margin: EdgeInsets.only(bottom: 12.h, left: 4.w),
              padding: EdgeInsets.all(14.w),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
                border: Border.all(color: step.color.withOpacity(0.15)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(step.icon, color: step.color, size: 20.sp),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: Text(step.title, style: PersianFonts.Shabnam.copyWith(fontSize: font_size_14, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  SizedBox(height: 8.h),
                  Text(step.body, style: PersianFonts.Shabnam.copyWith(fontSize: font_size_12, height: 1.55, color: Colors.grey.shade800)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturesTab() {
    final features = [
      _FeatureData('جستجو', Icons.search, ShekayatTheme.primary, 'جستجو در شماره شکایت، نام شاکی، متشاکی، کارشناس و سایر فیلدها.'),
      _FeatureData('فیلتر وضعیت', Icons.filter_list, Colors.orange, 'چیپ‌های «همه / بررسی / کارشناسی / کارشناسی مجدد» فقط لیست را فیلتر می‌کنند.'),
      _FeatureData('موضوع', Icons.topic, Colors.amber.shade700, 'انتخاب چند موضوع برای هر شکایت. امکان افزودن موضوع جدید.'),
      _FeatureData('مدارک شاکی', Icons.collections, ShekayatTheme.accentGreen, 'مشاهده تصاویر و فایل‌هایی که شاکی از طریق وب آپلود کرده (حداکثر ۵ تصویر).'),
      _FeatureData('مدارک مسئول', Icons.folder_open, Colors.teal.shade800, 'ثبت و مدیریت مستندات رسمی اتحادیه.'),
      _FeatureData('اتصال واحد', Icons.store, Colors.deepPurple, 'اتصال شکایت به پرونده واحد صنفی با جستجو در لیست اعضا.'),
      _FeatureData('پیگیری', Icons.history, Colors.indigo.shade700, 'ثبت سوابق پیگیری با تاریخ، مسئول و شرح اقدام.'),
      _FeatureData('کارشناسی', Icons.engineering, ShekayatTheme.accentCyan, 'مدیریت کارشناسان، ثبت نظریه، برآورد خسارت و مدارک کارشناس.'),
      _FeatureData('کمیسیون', Icons.gavel, Colors.grey.shade700, 'ثبت جلسات کمیسیون حل اختلاف با تاریخ و صورتجلسه.'),
      _FeatureData('ویرایش و نتیجه‌گیری', Icons.edit_note, ShekayatTheme.accentOrange, 'تغییر وضعیت، مرجع شکایت و ثبت نتیجه نهایی پرونده.'),
      _FeatureData('حذف پرونده', Icons.delete_forever, ShekayatTheme.accentRed, 'حذف کامل شکایت و تمام پیوست‌ها — غیرقابل بازگشت!'),
      _FeatureData('گزارشات', Icons.assessment, ShekayatTheme.primaryDark, 'داشبورد، نمودار وضعیت، موضوعات، کارشناسان، روند زمانی و فیلتر پیشرفته.'),
    ];

    return ListView(
      padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 24.h),
      children: [
        _infoBanner(
          'راهنمای کارت شکایت',
          'هر کارت خلاصه‌ای از پرونده است: شماره، وضعیت، نتیجه (رنگی)، اطلاعات شاکی و متشاکی، و دکمه‌های عملیاتی.',
          Icons.dashboard_customize_rounded,
        ),
        SizedBox(height: 8.h),
        _sectionTitle('وضعیت‌های پرونده'),
        Wrap(
          spacing: 6.w,
          runSpacing: 6.h,
          children: ShekayatConstants.statuses.map((s) {
            final c = ShekayatConstants.statusColor(s);
            return Chip(
              label: Text(s, style: PersianFonts.Shabnam.copyWith(fontSize: font_size_10, color: c)),
              backgroundColor: c.withOpacity(0.1),
              side: BorderSide(color: c.withOpacity(0.3)),
            );
          }).toList(),
        ),
        SizedBox(height: 16.h),
        _sectionTitle('دکمه‌ها و امکانات'),
        ...features.map(_buildFeatureCard),
      ],
    );
  }

  Widget _buildFeatureCard(_FeatureData f) {
    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(10.w),
            decoration: BoxDecoration(
              color: f.color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(f.icon, color: f.color, size: 22.sp),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(f.title, style: PersianFonts.Shabnam.copyWith(fontSize: font_size_14, fontWeight: FontWeight.bold)),
                SizedBox(height: 4.h),
                Text(f.desc, style: PersianFonts.Shabnam.copyWith(fontSize: font_size_12, height: 1.5, color: Colors.grey.shade700)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWebTab() {
    return ListView(
      padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 24.h),
      children: [
        Container(
          padding: EdgeInsets.all(20.w),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [ShekayatTheme.primary, ShekayatTheme.primaryDark],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.public, color: Colors.white, size: 32.sp),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Text(
                      'فرم عمومی ثبت شکایت (وب)',
                      style: PersianFonts.Shabnam.copyWith(fontSize: font_size_16, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12.h),
              Text(
                'با این لینک، شاکی بدون نصب اپ می‌تواند شکایت خود را ثبت کند. پرونده مستقیماً در همین لیست مدیریت شکایات ظاهر می‌شود.',
                style: PersianFonts.Shabnam.copyWith(fontSize: font_size_12, color: Colors.white.withOpacity(0.9), height: 1.6),
              ),
            ],
          ),
        ),
        SizedBox(height: 16.h),
        Container(
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: ShekayatTheme.primary.withOpacity(0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('لینک اختصاصی اتحادیه شما', style: PersianFonts.Shabnam.copyWith(fontSize: font_size_12, fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
              SizedBox(height: 10.h),
              Container(
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: SelectableText(
                  _webLink,
                  style: PersianFonts.Shabnam.copyWith(fontSize: font_size_10, color: ShekayatTheme.primaryDark),
                ),
              ),
              SizedBox(height: 12.h),
              ElevatedButton.icon(
                onPressed: _copyLink,
                icon: const Icon(Icons.copy, color: Colors.white),
                label: Text('کپی لینک', style: PersianFonts.Shabnam.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ShekayatTheme.primary,
                  padding: EdgeInsets.symmetric(vertical: 12.h),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 16.h),
        _sectionTitle('شاکی در وب چه کارهایی می‌تواند انجام دهد؟'),
        _webStep(Icons.edit_document, 'اطلاعات شاکی و متشاکی را وارد کند'),
        _webStep(Icons.category_outlined, 'نوع شکایت را انتخاب کند'),
        _webStep(Icons.add_photo_alternate_outlined, 'تا ۵ تصویر مدرک آپلود کند'),
        _webStep(Icons.send_rounded, 'شکایت را ثبت کند — بدون نیاز به لاگین'),
        SizedBox(height: 16.h),
        _sectionTitle('نکات مهم'),
        _bullet('کد اتحادیه در لینک: ${widget.codeCo}'),
        _bullet('مدارک شاکی در «مدارک شاکی» روی کارت قابل مشاهده است'),
        _bullet('شماره شکایت پس از ثبت وب، خودکار صادر می‌شود'),
        _bullet('لینک را از طریق پیامک، واتساپ یا چاپ QR در واحدها منتشر کنید'),
      ],
    );
  }

  Widget _webStep(IconData icon, String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: Row(
        children: [
          Icon(icon, color: ShekayatTheme.primary, size: 20.sp),
          SizedBox(width: 10.w),
          Expanded(child: Text(text, style: PersianFonts.Shabnam.copyWith(fontSize: font_size_12))),
        ],
      ),
    );
  }

  Widget _bullet(String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: 6.h, right: 4.w),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('• ', style: PersianFonts.Shabnam.copyWith(fontSize: font_size_14, color: ShekayatTheme.primary)),
          Expanded(child: Text(text, style: PersianFonts.Shabnam.copyWith(fontSize: font_size_12, height: 1.5))),
        ],
      ),
    );
  }

  Widget _infoBanner(String title, String body, IconData icon) {
    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: ShekayatTheme.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ShekayatTheme.primary.withOpacity(0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: ShekayatTheme.primary, size: 24.sp),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: PersianFonts.Shabnam.copyWith(fontSize: font_size_14, fontWeight: FontWeight.bold, color: ShekayatTheme.primaryDark)),
                SizedBox(height: 4.h),
                Text(body, style: PersianFonts.Shabnam.copyWith(fontSize: font_size_12, height: 1.5, color: Colors.grey.shade700)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: EdgeInsets.only(bottom: 10.h),
      child: Text(title, style: PersianFonts.Shabnam.copyWith(fontSize: font_size_14, fontWeight: FontWeight.bold, color: ShekayatTheme.primaryDark)),
    );
  }

  Widget _buildFormNoteTab() {
    if (_noteLoading) {
      return Center(child: CircularProgressIndicator(color: ShekayatTheme.primary));
    }
    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionTitle('توضیحات فرم ثبت شکایت (سمت شاکی)'),
          Text(
            'این متن در فرم وب ثبت شکایت برای شاکی نمایش داده می‌شود. مثلاً: «لطفاً عکس سریال گوشی، فاکتور یا کد ملی را بارگذاری کنید.»',
            style: PersianFonts.Shabnam.copyWith(fontSize: font_size_12, color: Colors.grey.shade600, height: 1.5),
          ),
          SizedBox(height: 12.h),
          TextField(
            controller: _formNoteCtrl,
            maxLines: 8,
            decoration: InputDecoration(
              labelText: 'متن توضیحات اتحادیه',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              alignLabelWithHint: true,
            ),
            style: PersianFonts.Shabnam.copyWith(fontSize: font_size_12),
          ),
          SizedBox(height: 16.h),
          ElevatedButton(
            onPressed: _saveFormNote,
            style: ElevatedButton.styleFrom(backgroundColor: ShekayatTheme.primary, padding: EdgeInsets.symmetric(vertical: 14.h)),
            child: Text('ذخیره توضیحات', style: PersianFonts.Shabnam.copyWith(color: Colors.white, fontSize: font_size_14)),
          ),
        ],
      ),
    );
  }
}

class _StepData {
  final int number;
  final String title;
  final String body;
  final IconData icon;
  final Color color;
  const _StepData(this.number, this.title, this.body, this.icon, this.color);
}

class _FeatureData {
  final String title;
  final IconData icon;
  final Color color;
  final String desc;
  const _FeatureData(this.title, this.icon, this.color, this.desc);
}

/// باز کردن راهنما به صورت تمام‌صفحه
void openShekayatHelp(BuildContext context, String codeCo) {
  Navigator.of(context).push(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => ShekayatHelpPage(codeCo: codeCo),
    ),
  );
}
