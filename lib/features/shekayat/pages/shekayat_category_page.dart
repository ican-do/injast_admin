import 'package:flutter/material.dart';
import 'package:injast_admin/features/shekayat/compat/motion_toast_shim.dart';
import 'package:injast_admin/features/shekayat/compat/persian_fonts_shim.dart';
import 'package:injast_admin/features/shekayat/compat/shekayat_basic.dart';
import 'package:injast_admin/features/shekayat/compat/shekayat_layout.dart';
import 'package:injast_admin/features/shekayat/shekayat_api.dart';
import 'package:injast_admin/features/shekayat/shekayat_constants.dart';
import 'package:injast_admin/features/shekayat/pages/shekayat_widgets.dart';

/// موضوع شکایت — انتخاب دسته‌بندی توسط مسئول
class ShekayatCategoryPage extends StatefulWidget {
  final String codeShekayat;
  final String codeCo;

  const ShekayatCategoryPage({Key? key, required this.codeShekayat, required this.codeCo}) : super(key: key);

  @override
  State<ShekayatCategoryPage> createState() => _ShekayatCategoryPageState();
}

class _ShekayatCategoryPageState extends State<ShekayatCategoryPage> {
  List<dynamic> _categories = [];
  Set<int> _selected = {};
  bool _loading = true;
  bool _saving = false;
  final _newCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _newCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _categories = await ShekayatApi.getCategories(widget.codeCo);
      final assigned = await ShekayatApi.getComplaintCategories(widget.codeShekayat);
      _selected = assigned
          .map((c) => int.tryParse(c['id_category']?.toString() ?? ''))
          .whereType<int>()
          .toSet();
      if (_selected.isEmpty) {
        final detail = await ShekayatApi.getDetail(widget.codeShekayat);
        if (detail?['id_category'] != null) {
          _selected = {int.parse(detail!['id_category'].toString())};
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    if (_selected.isEmpty) {
      MotionToast.warning(title: const Text('توجه'), description: const Text('حداقل یک موضوع انتخاب کنید')).show(context);
      return;
    }
    setState(() => _saving = true);
    try {
      await ShekayatApi.assignCategories(widget.codeShekayat, _selected.toList());
      if (!mounted) return;
      MotionToast.success(
        title: const Text('ثبت شد'),
        description: Text('${_selected.length} موضوع برای شکایت ثبت شد'),
      ).show(context);
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) MotionToast.error(title: const Text('خطا'), description: Text('$e')).show(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _addCategory() async {
    final name = _newCtrl.text.trim();
    if (name.isEmpty) return;
    await ShekayatApi.saveCategory({
      'code_co': widget.codeCo,
      'name_category': name,
      'sort_order': _categories.length + 1,
    });
    _newCtrl.clear();
    _load();
  }

  Future<void> _deleteCategory(int id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('حذف موضوع', style: PersianFonts.Shabnam),
        content: Text('آیا از حذف این موضوع اطمینان دارید؟', style: PersianFonts.Shabnam),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('انصراف')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('حذف', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final deleted = await ShekayatApi.deleteCategory(id);
      if (deleted) {
        _selected.remove(id);
        _load();
        if (mounted) {
          MotionToast.success(title: const Text('حذف شد'), description: const Text('موضوع حذف شد')).show(context);
        }
      }
    } catch (e) {
      if (mounted) MotionToast.error(title: const Text('خطا'), description: Text('$e')).show(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        appBar: const ShekayatAppBar(title: 'موضوع شکایت'),
        body: _loading
            ? Center(child: CircularProgressIndicator(color: ShekayatTheme.primary))
            : ShekayatLayout.constrain(
                maxWidth: ShekayatLayout.formMaxWidth,
                child: Column(
                  children: [
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(0, 12, 0, 8),
                        children: [
                          Text(
                            'می‌توانید چند موضوع را همزمان انتخاب کنید',
                            style: PersianFonts.Shabnam.copyWith(fontSize: font_size_10, color: Colors.grey.shade600),
                          ),
                          const SizedBox(height: 10),
                          if (_categories.isEmpty)
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.black12),
                              ),
                              child: Text(
                                'هنوز موضوعی تعریف نشده. موضوع جدید اضافه کنید.',
                                style: PersianFonts.Shabnam.copyWith(fontSize: font_size_12, color: Colors.grey.shade600),
                                textAlign: TextAlign.center,
                              ),
                            )
                          else
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _categories.map((c) {
                                final id = int.parse(c['id_category'].toString());
                                final name = c['name_category'].toString();
                                final selected = _selected.contains(id);
                                return SizedBox(
                                  width: 320,
                                  child: Material(
                                    color: selected
                                        ? ShekayatTheme.primary.withOpacity(0.08)
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(8),
                                      onTap: () => setState(() {
                                        if (selected) {
                                          _selected.remove(id);
                                        } else {
                                          _selected.add(id);
                                        }
                                      }),
                                      child: Container(
                                        height: 42,
                                        padding: const EdgeInsetsDirectional.only(start: 4, end: 4),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: selected
                                                ? ShekayatTheme.primary
                                                : Colors.grey.shade300,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Checkbox(
                                              value: selected,
                                              visualDensity: VisualDensity.compact,
                                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                              activeColor: ShekayatTheme.primary,
                                              onChanged: (v) => setState(() {
                                                if (v == true) {
                                                  _selected.add(id);
                                                } else {
                                                  _selected.remove(id);
                                                }
                                              }),
                                            ),
                                            Expanded(
                                              child: Text(
                                                name,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: PersianFonts.Shabnam.copyWith(fontSize: font_size_12),
                                              ),
                                            ),
                                            IconButton(
                                              visualDensity: VisualDensity.compact,
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                              icon: Icon(Icons.delete_outline, color: Colors.red.shade400, size: 18),
                                              onPressed: () => _deleteCategory(id),
                                              tooltip: 'حذف موضوع',
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.black12),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _newCtrl,
                                    onSubmitted: (_) => _addCategory(),
                                    decoration: InputDecoration(
                                      labelText: 'افزودن موضوع جدید',
                                      isDense: true,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    style: PersianFonts.Shabnam.copyWith(fontSize: font_size_12),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                SizedBox(
                                  height: 40,
                                  child: ElevatedButton.icon(
                                    onPressed: _addCategory,
                                    icon: const Icon(Icons.add, size: 18),
                                    label: Text('افزودن', style: PersianFonts.Shabnam.copyWith(fontSize: font_size_12)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: ShekayatTheme.primary,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 14),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    ShekayatBottomButtons(
                      onSubmit: _save,
                      onCancel: () => Navigator.pop(context),
                      loading: _saving,
                      submitLabel: 'ثبت موضوعات',
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
