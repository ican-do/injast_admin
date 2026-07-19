import 'package:flutter/material.dart';
import 'package:injast_admin/features/shekayat/compat/screen_util_shim.dart';
import 'package:injast_admin/features/shekayat/compat/class_controler.dart';
import 'package:injast_admin/features/shekayat/shekayat_constants.dart';
import 'package:injast_admin/features/shekayat/compat/shekayat_basic.dart';
import 'package:injast_admin/widget/text_fild.dart';
import 'package:persian_datetimepickers/persian_datetimepickers.dart';
import 'package:injast_admin/features/shekayat/compat/persian_fonts_shim.dart';
import 'package:injast_admin/features/shekayat/compat/shekayat_layout.dart';

/// هدر استاندارد صفحات شکایت
class ShekayatAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;

  const ShekayatAppBar({Key? key, required this.title, this.actions, this.bottom}) : super(key: key);

  @override
  Size get preferredSize => Size.fromHeight(56.h + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(title, style: PersianFonts.Shabnam.copyWith(fontSize: font_size_16, fontWeight: FontWeight.w600)),
      backgroundColor: ShekayatTheme.primary,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      actions: actions,
      bottom: bottom,
    );
  }
}

/// دکمه‌های پایین فرم (ثبت / انصراف)
class ShekayatBottomButtons extends StatelessWidget {
  final VoidCallback onSubmit;
  final VoidCallback? onCancel;
  final String submitLabel;
  final String? cancelLabel;
  final bool loading;
  final Widget? extraButton;

  const ShekayatBottomButtons({
    Key? key,
    required this.onSubmit,
    this.onCancel,
    this.submitLabel = 'ثبت',
    this.cancelLabel = 'انصراف',
    this.loading = false,
    this.extraButton,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      child: Row(
        children: [
          if (extraButton != null) ...[extraButton!, const SizedBox(width: 8)],
          Expanded(
            child: OutlinedButton(
              onPressed: loading ? null : onCancel ?? () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: ShekayatTheme.primary,
                side: const BorderSide(color: ShekayatTheme.primary, width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 10),
                minimumSize: const Size(0, 40),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(cancelLabel ?? 'انصراف', style: PersianFonts.Shabnam.copyWith(fontSize: font_size_12)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ElevatedButton(
              onPressed: loading ? null : onSubmit,
              style: ElevatedButton.styleFrom(
                backgroundColor: ShekayatTheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 10),
                minimumSize: const Size(0, 40),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: loading
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(submitLabel, style: PersianFonts.Shabnam.copyWith(fontSize: font_size_12, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}

/// سه دکمه پایین فرم ثبت (مدارک / ثبت / انصراف)
class ShekayatTripleButtons extends StatelessWidget {
  final VoidCallback onDocs;
  final VoidCallback onSubmit;
  final VoidCallback onCancel;
  final bool loading;

  const ShekayatTripleButtons({
    Key? key,
    required this.onDocs,
    required this.onSubmit,
    required this.onCancel,
    this.loading = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: onCancel,
              style: ElevatedButton.styleFrom(
                backgroundColor: ShekayatTheme.accentRed,
                padding: const EdgeInsets.symmetric(vertical: 10),
                minimumSize: const Size(0, 40),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text('انصراف', style: PersianFonts.Shabnam.copyWith(fontSize: font_size_12, color: Colors.white)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton(
              onPressed: loading ? null : onSubmit,
              style: ElevatedButton.styleFrom(
                backgroundColor: ShekayatTheme.primary,
                padding: const EdgeInsets.symmetric(vertical: 10),
                minimumSize: const Size(0, 40),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text('ثبت شکایت', style: PersianFonts.Shabnam.copyWith(fontSize: font_size_12, color: Colors.white)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton(
              onPressed: onDocs,
              style: ElevatedButton.styleFrom(
                backgroundColor: ShekayatTheme.accentGreen,
                padding: const EdgeInsets.symmetric(vertical: 10),
                minimumSize: const Size(0, 40),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text('مدارک و مستندات', style: PersianFonts.Shabnam.copyWith(fontSize: font_size_10, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}

/// فیلد تاریخ با تقویم شمسی
class ShekayatDateField extends StatefulWidget {
  final String label;
  final TextEditingController controller;
  final VoidCallback? onTap;
  final bool readOnly;

  const ShekayatDateField({
    Key? key,
    required this.label,
    required this.controller,
    this.onTap,
    this.readOnly = false,
  }) : super(key: key);

  @override
  State<ShekayatDateField> createState() => _ShekayatDateFieldState();
}

class _ShekayatDateFieldState extends State<ShekayatDateField> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_rebuild);
  }

  @override
  void didUpdateWidget(covariant ShekayatDateField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_rebuild);
      widget.controller.addListener(_rebuild);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  Future<void> _pickDate() async {
    if (widget.readOnly) return;
    if (widget.onTap != null) {
      widget.onTap!();
      return;
    }
    final d = await showPersianDatePicker(context: context);
    if (d != null) {
      widget.controller.text = convert_date_persian2(d);
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = widget.controller.text;
    return Padding(
      padding: EdgeInsets.all(8.w),
      child: InkWell(
        onTap: widget.readOnly ? null : _pickDate,
        borderRadius: BorderRadius.circular(8),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: widget.label,
            floatingLabelBehavior: FloatingLabelBehavior.always,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            suffixIcon: Icon(Icons.calendar_today, color: ShekayatTheme.primary, size: 20.sp),
          ),
          child: Text(
            text.isEmpty ? 'انتخاب تاریخ' : text,
            style: PersianFonts.Shabnam.copyWith(fontSize: font_size_14, color: text.isEmpty ? Colors.grey : Colors.black),
          ),
        ),
      ),
    );
  }
}

/// دراپ‌داون یکدست
class ShekayatDropdown extends StatelessWidget {
  final String label;
  final String value;
  final List<String> items;
  final ValueChanged<String?>? onChanged;
  final String Function(String)? itemLabel;

  const ShekayatDropdown({
    Key? key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.itemLabel,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(8.w),
      child: DropdownButtonFormField<String>(
        value: items.contains(value) ? value : (items.isNotEmpty ? items.first : null),
        decoration: InputDecoration(
          labelText: label,
          floatingLabelBehavior: FloatingLabelBehavior.always,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
        items: items.map((e) => DropdownMenuItem(
          value: e,
          child: Text(itemLabel != null ? itemLabel!(e) : e, style: PersianFonts.Shabnam.copyWith(fontSize: font_size_12)),
        )).toList(),
        onChanged: onChanged,
      ),
    );
  }
}

/// عنوان بخش
class ShekayatSectionTitle extends StatelessWidget {
  final String title;
  const ShekayatSectionTitle(this.title, {Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: 12.h, bottom: 4.h, right: 8.w),
      child: Text(title, style: PersianFonts.Shabnam.copyWith(fontWeight: FontWeight.w500, fontSize: font_size_20, color: Colors.grey.shade700)),
    );
  }
}

/// ردیف دو فیلد هم‌اندازه
class ShekayatFieldRow extends StatelessWidget {
  final Widget left;
  final Widget right;
  final int leftFlex;
  final int rightFlex;

  const ShekayatFieldRow({
    Key? key,
    required this.left,
    required this.right,
    this.leftFlex = 1,
    this.rightFlex = 1,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: rightFlex, child: right),
        Expanded(flex: leftFlex, child: left),
      ],
    );
  }
}

/// دکمه عملیات رنگی در کارت مدیریت — فشرده برای دسکتاپ
class ShekayatActionButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  final double? fontSize;
  final double? width;
  final double? height;

  const ShekayatActionButton({
    Key? key,
    required this.label,
    required this.color,
    required this.onTap,
    this.fontSize,
    this.width,
    this.height,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final display = label.replaceAll('\n', ' ');
    return SizedBox(
      width: width ?? ShekayatLayout.actionBtnWidth,
      height: height ?? ShekayatLayout.actionBtnHeight,
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                display,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: PersianFonts.Shabnam.copyWith(
                  fontSize: fontSize ?? font_size_10,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  height: 1.1,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// فیلد متنی استاندارد با padding
Widget shekayatField(String label, String hint, TextEditingController ctrl, {int lines = 1, bool enabled = true}) {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
    child: lines > 1
        ? TextFieldMultiLine(labelText: label, hintText: hint, controller: ctrl, enabled: enabled)
        : text_fild_1(labelText: label, hintText: hint, controller: ctrl, enabled: enabled),
  );
}
