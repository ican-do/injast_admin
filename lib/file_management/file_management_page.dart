import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:injast_admin/file_management/advanced_search_sheet.dart';
import 'package:injast_admin/file_management/parvande_api.dart';
import 'package:injast_admin/file_management/parvande_card.dart';
import 'package:injast_admin/file_management/parvande_details_dialog.dart';
import 'package:injast_admin/file_management/placeholders/feature_placeholder_page.dart';
import 'package:injast_admin/file_management/trash_sheet.dart';
import 'package:url_launcher/url_launcher.dart';

class FileManagementPage extends StatefulWidget {
  const FileManagementPage({super.key, required this.codeCo});

  final String codeCo;

  @override
  State<FileManagementPage> createState() => _FileManagementPageState();
}

class _FileManagementPageState extends State<FileManagementPage> {
  final _api = ParvandeApi.instance;
  final _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _all = [];
  bool _loading = true;
  String _tab = 'active'; // active | all | trash
  AdvancedFilters _filters = AdvancedFilters();

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
      _all = await _api.fetchAll(widget.codeCo);
      if (kDebugMode) {
        final withImage = _all.where((e) => e.imageProfile.trim().isNotEmpty).length;
        debugPrint('[FileManagement] total=${_all.length} withImage=$withImage');
        if (_all.isNotEmpty) {
          final first = _all.first;
          debugPrint('[FileManagement] firstMember=${first.fullName} id=${first.idParvandeh}');
          debugPrint('[FileManagement] first.image_profile.raw="${first.imageProfile}"');
          debugPrint('[FileManagement] first.image_profile.url="${first.imageProfileUrl}"');
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطا در دریافت پرونده‌ها: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _baseByTab {
    if (_tab == 'all') return _all;
    if (_tab == 'trash') return _all.where((e) => e.isTrash).toList();
    return _all.where((e) => e.isActive).toList();
  }

  List<Map<String, dynamic>> get _visible {
    final q = _searchCtrl.text.trim().toLowerCase();
    final filtered = _filters.apply(_baseByTab);
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

  Future<bool> _setAct(Map<String, dynamic> p, int act, {required String okMsg}) async {
    try {
      await _api.setActParvande(p.idParvandeh, act);
      if (!mounted) return true;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(okMsg)));
      await _load();
      return true;
    } catch (e) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('خطا: $e')));
      return false;
    }
  }

  Future<bool> _deleteForever(Map<String, dynamic> p) async {
    try {
      await _api.deleteForever(p.idParvandeh);
      if (!mounted) return true;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('پرونده برای همیشه حذف شد.')));
      await _load();
      return true;
    } catch (e) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('خطا: $e')));
      return false;
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
    final q = p.hasLocation ? '${p.lat},${p.lng}' : p.address;
    if (q.trim().isEmpty) return;
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(q)}',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _openAdvancedSearch() async {
    final raste = _all.map((e) => e.raste).where((e) => e.isNotEmpty).toSet().toList();
    final vaziyat = _all.map((e) => e.vaziyat).where((e) => e.isNotEmpty).toSet().toList();
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
        title: const Text('حذف منطقی پرونده'),
        content: Text('پروندهٔ «${p.fullName}» به سطل زباله منتقل شود؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('انصراف')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('تایید')),
        ],
      ),
    );
    if (ok == true) {
      await _setAct(p, 2, okMsg: 'پرونده به سطل زباله منتقل شد.');
    }
  }

  void _openPlaceholder(
    String title,
    IconData icon,
    Color color,
    Map<String, dynamic> p,
  ) {
    final info = '${p.fullName.isEmpty ? '—' : p.fullName} • ${p.storeName.isEmpty ? '—' : p.storeName}';
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

  void _openDetails(Map<String, dynamic> p) {
    showDialog(
      context: context,
      builder: (_) => ParvandeDetailsDialog(
        parvande: p,
        onCall: () => _call(p.mob),
        onSms: () => _sms(p.mob),
        onMap: () => _map(p),
        onInspections: () => _openPlaceholder(
          'سوابق بازرسی',
          FluentIcons.clipboard_search_24_regular,
          const Color(0xFF3949AB),
          p,
        ),
        onImages: () => _openPlaceholder(
          'تصاویر',
          FluentIcons.image_multiple_24_regular,
          const Color(0xFF7B1FA2),
          p,
        ),
        onLicense: () => _openPlaceholder(
          'پروانه',
          FluentIcons.document_24_regular,
          const Color(0xFF00695C),
          p,
        ),
        onDocuments: () => _openPlaceholder(
          'مدارک',
          FluentIcons.document_folder_24_regular,
          const Color(0xFF6D4C41),
          p,
        ),
        onPartners: () => _openPlaceholder(
          'شریک',
          FluentIcons.people_team_24_regular,
          const Color(0xFF455A64),
          p,
        ),
        onComplaint: () => _openPlaceholder(
          'ثبت شکایت',
          FluentIcons.warning_24_regular,
          const Color(0xFFD32F2F),
          p,
        ),
        onEdit: () => _openPlaceholder(
          'ویرایش پرونده',
          FluentIcons.edit_24_regular,
          const Color(0xFFEF6C00),
          p,
        ),
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
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
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
                            final count = c.maxWidth >= 1200 ? 3 : c.maxWidth >= 700 ? 2 : 1;
                            final cardHeight = count == 1 ? 324.0 : count == 2 ? 306.0 : 292.0;
                            return GridView.builder(
                              padding: const EdgeInsets.fromLTRB(12, 6, 12, 14),
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
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
              Expanded(child: _countChip('کل', _all.length, const Color(0xFF455A64))),
              const SizedBox(width: 8),
              Expanded(
                  child:
                      _countChip('فعال', _all.where((e) => e.isActive).length, const Color(0xFF2E7D32))),
              const SizedBox(width: 8),
              Expanded(child: _countChip('نمایش', visibleCount, const Color(0xFF1E3A5F))),
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
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
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
        ],
      ),
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
          Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w700))),
          Text('$value', style: TextStyle(fontWeight: FontWeight.w800, color: c)),
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
    return ParvandeCard(
      parvande: p,
      onDetails: () => _openDetails(p),
      onCall: () => _call(p.mob),
      onSms: () => _sms(p.mob),
      onMap: () => _map(p),
      onSoftDelete: () => _confirmSoftDelete(p),
      onRestore: () => _setAct(p, 1, okMsg: 'پرونده بازیابی شد.'),
      onHardDelete: () => _deleteForever(p),
      onInspections: () => _openPlaceholder(
        'سوابق بازرسی',
        FluentIcons.clipboard_search_24_regular,
        const Color(0xFF3949AB),
        p,
      ),
      onImages: () => _openPlaceholder(
        'تصاویر',
        FluentIcons.image_multiple_24_regular,
        const Color(0xFF7B1FA2),
        p,
      ),
      onLicense: () => _openPlaceholder(
        'پروانه',
        FluentIcons.document_24_regular,
        const Color(0xFF00695C),
        p,
      ),
      onDocuments: () => _openPlaceholder(
        'مدارک',
        FluentIcons.document_folder_24_regular,
        const Color(0xFF6D4C41),
        p,
      ),
      onPartners: () => _openPlaceholder(
        'شریک',
        FluentIcons.people_team_24_regular,
        const Color(0xFF455A64),
        p,
      ),
      onComplaint: () => _openPlaceholder(
        'ثبت شکایت',
        FluentIcons.warning_24_regular,
        const Color(0xFFD32F2F),
        p,
      ),
      onEdit: () => _openPlaceholder(
        'ویرایش پرونده',
        FluentIcons.edit_24_regular,
        const Color(0xFFEF6C00),
        p,
      ),
    );
  }
}
