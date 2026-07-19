import 'package:flutter/material.dart';
import 'package:injast_admin/features/shekayat/compat/screen_util_shim.dart';
import 'package:injast_admin/features/shekayat/compat/get_nav.dart';
import 'package:injast_admin/features/shekayat/compat/permissions.dart';
import 'package:injast_admin/features/shekayat/shekayat_api.dart';
import 'package:injast_admin/features/shekayat/shekayat_constants.dart';
import 'package:injast_admin/features/shekayat/compat/shekayat_basic.dart';
import 'package:injast_admin/features/shekayat/pages/shekayat_all_docs_page.dart';
import 'package:injast_admin/features/shekayat/pages/shekayat_category_page.dart';
import 'package:injast_admin/features/shekayat/pages/shekayat_commission_page.dart';
import 'package:injast_admin/features/shekayat/pages/shekayat_edit_page.dart';
import 'package:injast_admin/features/shekayat/pages/shekayat_expert_page.dart';
import 'package:injast_admin/features/shekayat/pages/shekayat_followup_page.dart';
import 'package:injast_admin/features/shekayat/pages/shekayat_link_parvandeh_page.dart';
import 'package:injast_admin/features/shekayat/pages/shekayat_form_mapper.dart';
import 'package:injast_admin/features/shekayat/pages/shekayat_help_page.dart';
import 'package:injast_admin/features/shekayat/pages/shekayat_case_view_page.dart';
import 'package:injast_admin/features/shekayat/pages/shekayat_widgets.dart';
import 'package:injast_admin/features/shekayat/compat/motion_toast_shim.dart';
import 'package:injast_admin/features/shekayat/compat/persian_fonts_shim.dart';
import 'package:injast_admin/features/shekayat/compat/shekayat_layout.dart';

/// صفحه مدیریت شکایات — مطابق ماکاپ
class ManageShekayatV2 extends StatefulWidget {
  final String? codeCo;
  final String? initialSearch;
  const ManageShekayatV2({Key? key, this.codeCo, this.initialSearch}) : super(key: key);

  @override
  State<ManageShekayatV2> createState() => _ManageShekayatV2State();
}

class _ManageShekayatV2State extends State<ManageShekayatV2> {
  final _searchCtrl = TextEditingController();
  List<dynamic> _items = [];
  bool _loading = true;
  String _statusFilter = 'همه';

  String get _codeCo => widget.codeCo ?? code_co;

  @override
  void initState() {
    super.initState();
    if (widget.initialSearch != null && widget.initialSearch!.isNotEmpty) {
      _searchCtrl.text = widget.initialSearch!;
    }
    _load();
    _searchCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      String? status;
      if (_statusFilter != 'همه') status = _statusFilter;
      final expertId = Permissions.isComplaintExpertRole() ? Permissions.currentUserId : null;
      _items = await ShekayatApi.listComplaints(
        _codeCo,
        status: status,
        search: _searchCtrl.text.trim().isEmpty ? null : _searchCtrl.text.trim(),
        idExpert: (expertId != null && expertId.isNotEmpty) ? expertId : null,
      );
    } catch (e) {
      _items = [];
    }
    if (mounted) setState(() => _loading = false);
  }

  List<dynamic> get _filtered {
    if (_statusFilter == 'همه') return _items;
    return _items;
  }

  String _formatCategories(dynamic item) {
    final names = item['category_names'];
    if (names is List && names.isNotEmpty) return names.join('، ');
    return item['category_name']?.toString() ?? '-';
  }

  String _shortText(String value, int max) {
    final t = value.trim();
    if (t.length <= max) return t;
    return '${t.substring(0, max)}…';
  }

  List<String> _motshakiLines(dynamic item) {
    final c = item is Map<String, dynamic> ? item : Map<String, dynamic>.from(item as Map);
    final mot = ShekayatFormMapper.respondentFields(c);
    final lines = <String>[];
    final fullName = '${mot['motName'] ?? ''} ${mot['motFamily'] ?? ''}'.trim();
    if (fullName.isNotEmpty) {
      lines.add('نام و نام خانوادگی: $fullName');
    }
    if ((mot['motMeli'] ?? '').isNotEmpty) lines.add('کد ملی: ${mot['motMeli']}');
    if ((mot['motMob'] ?? '').isNotEmpty) lines.add('موبایل: ${mot['motMob']}');
    if ((mot['motAddr'] ?? '').isNotEmpty) lines.add('آدرس: ${mot['motAddr']}');
    if (mot['linkedNote'] != null) lines.add(mot['linkedNote']!);
    if (lines.isEmpty) lines.add('اطلاعاتی ثبت نشده');
    return lines;
  }

  @override
  Widget build(BuildContext context) {
    ShekayatNav.bind(context);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.grey.shade100,
        appBar: ShekayatAppBar(
          title: Permissions.isComplaintExpertRole() ? 'پرونده‌های ارجاع‌شده' : 'مدیریت شکایات',
          actions: [
            IconButton(
              icon: const Icon(Icons.school_outlined),
              tooltip: 'راهنما و آموزش',
              onPressed: () => openShekayatHelp(context, _codeCo),
            ),
            IconButton(icon: const Icon(Icons.refresh), onPressed: _loading ? null : _load),
          ],
        ),
        body: ShekayatLayout.constrain(
          maxWidth: ShekayatLayout.listMaxWidth,
          child: Column(
            children: [
              _buildSearch(),
              _buildStatusChips(),
              Expanded(
                child: _loading
                    ? Center(child: CircularProgressIndicator(color: ShekayatTheme.primary))
                    : _filtered.isEmpty
                        ? Center(child: Text('پرونده‌ای یافت نشد', style: PersianFonts.Shabnam.copyWith(color: Colors.grey)))
                        : RefreshIndicator(
                            onRefresh: _load,
                            color: ShekayatTheme.primary,
                            child: _buildCaseList(context),
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCaseList(BuildContext context) {
    final twoCol = ShekayatLayout.isWide(context, min: 1100);
    if (!twoCol) {
      return ListView.builder(
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 16),
        itemCount: _filtered.length,
        itemBuilder: (_, i) => _buildCard(_filtered[i]),
      );
    }

    final rowCount = (_filtered.length / 2).ceil();
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 16),
      itemCount: rowCount,
      itemBuilder: (_, row) {
        final leftIndex = row * 2;
        final rightIndex = leftIndex + 1;
        final hasRight = rightIndex < _filtered.length;
        return Padding(
          padding: const EdgeInsets.only(bottom: 0),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _buildCard(_filtered[leftIndex])),
                const SizedBox(width: 10),
                Expanded(
                  child: hasRight ? _buildCard(_filtered[rightIndex]) : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSearch() {
    return Container(
      margin: const EdgeInsets.fromLTRB(0, 10, 0, 4),
      height: 42,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.black12),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              onSubmitted: (_) => _load(),
              decoration: InputDecoration(
                hintText: 'جستجو در شماره شکایت، تاریخ، شاکی، متشاکی...',
                hintStyle: PersianFonts.Shabnam.copyWith(fontSize: font_size_10, color: Colors.grey),
                prefixIcon: const Icon(Icons.search, color: ShekayatTheme.primary, size: 20),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
              style: PersianFonts.Shabnam.copyWith(fontSize: font_size_12),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 6, right: 4),
            child: SizedBox(
              height: 32,
              child: ElevatedButton(
                onPressed: _loading ? null : _load,
                style: ElevatedButton.styleFrom(
                  backgroundColor: ShekayatTheme.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Text('جستجو', style: PersianFonts.Shabnam.copyWith(fontSize: font_size_10, color: Colors.white)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChips() {
    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 6),
            child: FilterChip(
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              label: Text('همه', style: PersianFonts.Shabnam.copyWith(fontSize: font_size_10)),
              selected: _statusFilter == 'همه',
              selectedColor: ShekayatTheme.primary.withOpacity(0.2),
              checkmarkColor: ShekayatTheme.primary,
              onSelected: (_) {
                setState(() => _statusFilter = 'همه');
                _load();
              },
            ),
          ),
          ...ShekayatConstants.statusTabs.map((s) {
            final selected = _statusFilter == s;
            return Padding(
              padding: const EdgeInsets.only(left: 6),
              child: FilterChip(
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                label: Text(s, style: PersianFonts.Shabnam.copyWith(fontSize: font_size_10)),
                selected: selected,
                selectedColor: ShekayatTheme.primary.withOpacity(0.2),
                checkmarkColor: ShekayatTheme.primary,
                onSelected: (_) {
                  setState(() => _statusFilter = s);
                  _load();
                },
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildCard(dynamic item) {
    final status = item['status_shekayat']?.toString() ?? '-';
    final result = item['result_shekayat']?.toString().trim() ?? '';
    final hasResult = result.isNotEmpty;
    final statusColor = ShekayatConstants.statusColor(status);
    final resultColor = ShekayatConstants.resultColor(result);

    final actions = <Widget>[
      if (Permissions.canShekForm())
        ShekayatActionButton(label: 'فرم شکایت', color: ShekayatTheme.primaryDark, onTap: () => _openFormView(item)),
      if (Permissions.canShekSubjects())
        ShekayatActionButton(label: 'موضوع شکایت', color: Colors.amber.shade700, onTap: () => _openCategory(item)),
      if (Permissions.canShekDocuments())
        ShekayatActionButton(label: 'مدارک و مستندات', color: ShekayatTheme.accentGreen, onTap: () => _openAllDocs(item)),
      if (Permissions.canShekFollowups())
        ShekayatActionButton(label: 'پیگیری‌ها', color: Colors.indigo.shade700, onTap: () => _openFollowup(item)),
      if (Permissions.canShekExpertise())
        ShekayatActionButton(label: 'کارشناسی', color: ShekayatTheme.accentCyan, onTap: () => _openExpert(item)),
      if (Permissions.canShekCommission())
        ShekayatActionButton(label: 'کمیسیون شکایات', color: Colors.grey.shade700, onTap: () => _openCommission(item)),
      if (Permissions.canShekEditResult())
        ShekayatActionButton(label: 'ویرایش و نتیجه‌گیری', color: ShekayatTheme.accentOrange, onTap: () => _openEdit(item)),
      if (Permissions.canShekDeleteCase())
        ShekayatActionButton(label: 'حذف پرونده', color: ShekayatTheme.accentRed, onTap: () => _confirmDelete(item)),
    ];

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 1.5,
      shadowColor: ShekayatTheme.primary.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [ShekayatTheme.primary.withOpacity(0.95), ShekayatTheme.primaryDark],
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(6)),
                  child: Text(
                    '#${item['complaint_number'] ?? '-'}',
                    style: PersianFonts.Shabnam.copyWith(fontSize: font_size_12, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item['lbl_shekayat']?.toString() ?? 'بدون عنوان',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: PersianFonts.Shabnam.copyWith(fontSize: font_size_12, color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    _badge('وضعیت: $status', statusColor, Icons.flag_outlined),
                    if ((item['last_expert_expertise']?.toString() ?? '').isNotEmpty)
                      _badge(
                        'تاریخ کارشناسی: ${item['last_expert_expertise']}',
                        ShekayatTheme.accentCyan,
                        Icons.event_available_outlined,
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                _section('شاکی', Icons.person_outline, [
                  ShekayatFormMapper.shakiFullName(item is Map<String, dynamic> ? item : Map<String, dynamic>.from(item as Map)),
                  if ((item['code_meli_shaki']?.toString() ?? '').isNotEmpty) 'کد ملی: ${item['code_meli_shaki']}',
                  if ((item['mob_shaki']?.toString() ?? '').isNotEmpty) 'موبایل: ${item['mob_shaki']}',
                ]),
                _sectionWithAction(
                  'متشاکی',
                  Icons.store_outlined,
                  _motshakiLines(item),
                  Permissions.canShekUnitLink()
                      ? IconButton(
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          icon: Icon(
                            Icons.link,
                            size: 18,
                            color: ShekayatFormMapper.isLinked(item is Map<String, dynamic> ? item : Map<String, dynamic>.from(item as Map))
                                ? Colors.green
                                : ShekayatTheme.primary,
                          ),
                          tooltip: 'اتصال واحد صنفی',
                          onPressed: () => _openLinkParvandeh(item),
                        )
                      : null,
                ),
                _section('اطلاعات پرونده', Icons.info_outline, [
                  if ((item['lbl_shekayat']?.toString() ?? '').isNotEmpty) 'عنوان: ${item['lbl_shekayat']}',
                  if ((item['caption']?.toString() ?? '').isNotEmpty)
                    'متن: ${_shortText(item['caption']?.toString() ?? '', 90)}',
                  'تاریخ شکایت: ${item['date_shekayat'] ?? '-'}',
                  'مرجع شکایت: ${item['source_shekayat'] ?? '-'}',
                  if (_formatCategories(item) != '-') 'موضوع شکایت: ${_formatCategories(item)}',
                ]),
                if ((item['last_expert_name']?.toString() ?? '').isNotEmpty ||
                    (item['last_expert_expertise']?.toString() ?? '').isNotEmpty ||
                    (item['last_session_date']?.toString() ?? '').isNotEmpty)
                  _section('رسیدگی', Icons.engineering_outlined, [
                    if ((item['last_expert_name']?.toString() ?? '').isNotEmpty) 'کارشناس: ${item['last_expert_name']}',
                    if ((item['last_expert_expertise']?.toString() ?? '').isNotEmpty)
                      'تاریخ کارشناسی: ${item['last_expert_expertise']}',
                    if ((item['last_session_date']?.toString() ?? '').isNotEmpty)
                      'جلسه: ${item['last_session_date']} ${item['last_session_time'] ?? ''}',
                  ]),
                if (hasResult)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      color: resultColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: resultColor.withOpacity(0.35)),
                    ),
                    child: Row(
                      children: [
                        Icon(ShekayatConstants.resultIcon(result), color: resultColor, size: 16),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'نتیجه: $result',
                            style: PersianFonts.Shabnam.copyWith(fontSize: font_size_12, fontWeight: FontWeight.bold, color: resultColor),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: actions,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _badge(String text, Color color, IconData icon, {bool filled = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: filled ? color.withOpacity(0.15) : color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(text, style: PersianFonts.Shabnam.copyWith(fontSize: font_size_10, color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _section(String title, IconData icon, List<String> lines) =>
      _sectionWithAction(title, icon, lines, null);

  Widget _sectionWithAction(String title, IconData icon, List<String> lines, Widget? action) {
    final content = lines.where((l) => l.trim().isNotEmpty && l != '-').toList();
    if (content.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: ShekayatTheme.primary),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(title, style: PersianFonts.Shabnam.copyWith(fontSize: font_size_10, color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
                    ),
                    if (action != null) action,
                  ],
                ),
                ...content.map((l) => Text(l, style: PersianFonts.Shabnam.copyWith(fontSize: font_size_12, height: 1.3))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openFormView(dynamic item) {
    final data = item is Map<String, dynamic> ? item : Map<String, dynamic>.from(item as Map);
    Get.to(() => ShekayatCaseViewPage(
      codeCo: _codeCo,
      complaint: data,
    ));
  }

  void _openAllDocs(dynamic item) {
    Get.to(() => ShekayatAllDocsPage(
      codeShekayat: item['code_shekayat'].toString(),
      complaintTitle: item['lbl_shekayat']?.toString(),
    ));
  }

  void _openCategory(dynamic item) {
    Get.to(() => ShekayatCategoryPage(codeShekayat: item['code_shekayat'].toString(), codeCo: _codeCo))?.then((_) => _load());
  }

  void _openLinkParvandeh(dynamic item) {
    Get.to(() => ShekayatLinkParvandehPage(
      codeShekayat: item['code_shekayat'].toString(),
      codeCo: _codeCo,
      currentParvandehId: item['id_store']?.toString() ?? item['linked_parvandeh_id']?.toString(),
      complaintTitle: item['lbl_shekayat']?.toString(),
    ))?.then((_) => _load());
  }

  void _openFollowup(dynamic item) {
    Get.to(() => ShekayatFollowupPage(
      codeShekayat: item['code_shekayat'].toString(),
      codeCo: _codeCo,
      complaint: item,
    ));
  }

  void _openExpert(dynamic item) {
    Get.to(() => ShekayatExpertPage(codeShekayat: item['code_shekayat'].toString(), codeCo: _codeCo, complaint: item));
  }

  void _openCommission(dynamic item) {
    Get.to(() => ShekayatCommissionPage(
      codeShekayat: item['code_shekayat'].toString(),
      codeCo: _codeCo,
      complaint: item,
    ));
  }

  void _openEdit(dynamic item) {
    Get.to(() => ShekayatEditPage(complaint: item, codeCo: _codeCo))?.then((saved) {
      if (saved == true) _load();
    });
  }

  Future<void> _confirmDelete(dynamic item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('حذف شکایت', style: PersianFonts.Shabnam),
        content: Text('آیا از حذف کامل این پرونده اطمینان دارید؟', style: PersianFonts.Shabnam),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('انصراف')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('حذف', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ShekayatApi.deleteFull(item['code_shekayat'].toString());
      _load();
    } catch (e) {
      MotionToast.error(title: const Text('خطا'), description: Text('$e')).show(context);
    }
  }
}

/// سازگاری با کد قبلی
class manage_shekayat extends StatelessWidget {
  final String? codeCo;
  const manage_shekayat({Key? key, this.codeCo}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ManageShekayatV2(codeCo: codeCo);
  }
}
