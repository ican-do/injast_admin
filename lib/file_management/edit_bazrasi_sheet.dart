import 'package:flutter/material.dart';
import 'package:injast_admin/file_management/bazrasi_local_store.dart';
import 'package:injast_admin/file_management/parvande_bazrasi_api.dart';
import 'package:injast_admin/file_management/parvande_api.dart';

/// ویرایش سابقه بازرسی (فیلدهای نامه بازرسی)
class EditBazrasiSheet extends StatefulWidget {
  const EditBazrasiSheet({
    super.key,
    required this.codeCo,
    required this.parvande,
    required this.record,
    required this.offline,
  });

  final String codeCo;
  final Map<String, dynamic> parvande;
  final Map<String, dynamic> record;
  final bool offline;

  static Future<bool?> show(
    BuildContext context, {
    required String codeCo,
    required Map<String, dynamic> parvande,
    required Map<String, dynamic> record,
    required bool offline,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EditBazrasiSheet(
        codeCo: codeCo,
        parvande: parvande,
        record: record,
        offline: offline,
      ),
    );
  }

  @override
  State<EditBazrasiSheet> createState() => _EditBazrasiSheetState();
}

class _EditBazrasiSheetState extends State<EditBazrasiSheet> {
  late final TextEditingController _numAmaken;
  late final TextEditingController _numEjrayi;
  late final TextEditingController _tozihat;
  late String _lastResult;
  bool _saving = false;

  static const _lastResults = [
    'صدور پروانه',
    'تخلیه واحد صنفی',
    'اجرائیات',
    'اماکن',
    'پلمپ',
    'ابطال پروانه',
  ];

  @override
  void initState() {
    super.initState();
    final r = widget.record;
    _numAmaken = TextEditingController(text: r['num_amaken']?.toString() ?? '');
    _numEjrayi = TextEditingController(text: r['num_ejrayi']?.toString() ?? '');
    _tozihat = TextEditingController(text: r['tozihat_bazrasi']?.toString() ?? '');
    _lastResult = r['last_result_bazrasi']?.toString() ?? _lastResults.first;
    if (!_lastResults.contains(_lastResult)) _lastResult = _lastResults.first;
  }

  @override
  void dispose() {
    _numAmaken.dispose();
    _numEjrayi.dispose();
    _tozihat.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final id = widget.record['id_bazrasi']?.toString() ?? '';
    final patch = {
      'num_amaken': _numAmaken.text.trim(),
      'num_ejrayi': _numEjrayi.text.trim(),
      'last_result_bazrasi': _lastResult,
      'tozihat_bazrasi': _tozihat.text.trim(),
    };
    try {
      if (widget.offline || widget.record['_local_only'] == true || id.startsWith('local_')) {
        await BazrasiLocalStore(widget.codeCo).updateLocal(
          widget.parvande.idParvandeh,
          id,
          patch,
        );
      } else {
        await ParvandeBazrasiApi.instance.updateFull(
          idBazrasi: id,
          dateAmaken: widget.record['date_amaken']?.toString() ?? '0',
          numAmaken: _numAmaken.text.trim(),
          dateEjrayi: widget.record['date_ejrayi']?.toString() ?? '0',
          numEjrayi: _numEjrayi.text.trim(),
          lastResult: _lastResult,
          dateTahod: widget.record['date_tahod']?.toString() ?? '0',
          modatTahod: widget.record['modat_tahod']?.toString() ?? '0',
          noeTahod: widget.record['noe_tahod']?.toString() ?? '0',
          dateAdamPelamp: widget.record['date_adam_pelamp']?.toString() ?? '0',
          numAdamPelamp: widget.record['num_adam_pelamp']?.toString() ?? '0',
          datePelamp: widget.record['date_pelamp']?.toString() ?? '0',
          numPelamp: widget.record['num_pelamp']?.toString() ?? '0',
          dateFekPelamp: widget.record['date_fek_pelamp']?.toString() ?? '0',
          numFekPelamp: widget.record['num_fek_pelamp']?.toString() ?? '0',
          tozihat: _tozihat.text.trim(),
        );
      }
      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('بازرسی به‌روزرسانی شد.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطا: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
          ),
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('ویرایش بازرسی', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _lastResult,
                  decoration: const InputDecoration(labelText: 'آخرین نتیجه', border: OutlineInputBorder()),
                  items: _lastResults.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                  onChanged: (v) => setState(() => _lastResult = v ?? _lastResult),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _numAmaken,
                  decoration: const InputDecoration(labelText: 'شماره اماکن', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _numEjrayi,
                  decoration: const InputDecoration(labelText: 'شماره اجرایی', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _tozihat,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'توضیحات', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('ذخیره'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
