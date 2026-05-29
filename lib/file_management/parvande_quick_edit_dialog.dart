import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:injast_admin/file_management/parvande_api.dart';

/// دیالوگ ویرایش سریع: موبایل، تلفن، بدهی
class ParvandeQuickEditDialog extends StatefulWidget {
  const ParvandeQuickEditDialog({
    super.key,
    required this.parvande,
    required this.onFullEdit,
  });

  final Map<String, dynamic> parvande;
  final VoidCallback onFullEdit;

  static Future<bool?> show(
    BuildContext context, {
    required Map<String, dynamic> parvande,
    required VoidCallback onFullEdit,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ParvandeQuickEditDialog(
        parvande: parvande,
        onFullEdit: onFullEdit,
      ),
    );
  }

  @override
  State<ParvandeQuickEditDialog> createState() => _ParvandeQuickEditDialogState();
}

class _ParvandeQuickEditDialogState extends State<ParvandeQuickEditDialog> {
  static const _accent = Color(0xFFEF6C00);

  late final TextEditingController _mobCtrl;
  late final TextEditingController _telCtrl;
  late final TextEditingController _moneyCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.parvande;
    _mobCtrl = TextEditingController(text: p.s('mob_admin'));
    _telCtrl = TextEditingController(text: p.s('tel_admin'));
    final money = p.s('money');
    _moneyCtrl = TextEditingController(
      text: money.isEmpty || money == 'null' ? '0' : money,
    );
  }

  @override
  void dispose() {
    _mobCtrl.dispose();
    _telCtrl.dispose();
    _moneyCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveQuick() async {
    setState(() => _saving = true);
    try {
      await ParvandeApi.instance.quickUpdateParvandeh(
        parvande: widget.parvande,
        mobAdmin: _mobCtrl.text,
        telAdmin: _telCtrl.text,
        money: _moneyCtrl.text,
      );
      widget.parvande['mob_admin'] = _mobCtrl.text.trim();
      widget.parvande['tel_admin'] = _telCtrl.text.trim();
      final money = _moneyCtrl.text.trim();
      widget.parvande['money'] = money.isEmpty ? '0' : money;
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطا: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.parvande.fullName;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'ویرایش سریع اطلاعات',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                      ),
                    ),
                    IconButton(
                      onPressed: _saving ? null : () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                if (name.isNotEmpty)
                  Text(name, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                const SizedBox(height: 16),
                _field(
                  controller: _mobCtrl,
                  label: 'شماره همراه',
                  icon: Icons.phone_android,
                  maxLength: 11,
                ),
                const SizedBox(height: 10),
                _field(
                  controller: _telCtrl,
                  label: 'شماره ثابت',
                  icon: Icons.phone,
                  maxLength: 11,
                ),
                const SizedBox(height: 10),
                _field(
                  controller: _moneyCtrl,
                  label: 'وضعیت بدهی (ریال)',
                  icon: Icons.payments_outlined,
                  digitsOnly: true,
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(backgroundColor: _accent),
                        onPressed: _saving
                            ? null
                            : () {
                                Navigator.pop(context);
                                widget.onFullEdit();
                              },
                        child: const Text('ویرایش کامل'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(backgroundColor: const Color(0xFF2E7D32)),
                        onPressed: _saving ? null : _saveQuick,
                        icon: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.check_circle_outline),
                        label: const Text('ویرایش سریع'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int? maxLength,
    bool digitsOnly = false,
  }) {
    return TextField(
      controller: controller,
      maxLength: maxLength,
      keyboardType: digitsOnly ? TextInputType.number : TextInputType.phone,
      inputFormatters: digitsOnly ? [FilteringTextInputFormatter.digitsOnly] : null,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: _accent, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        isDense: true,
        counterText: '',
      ),
    );
  }
}
