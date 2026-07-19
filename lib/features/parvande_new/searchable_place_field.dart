import 'package:flutter/material.dart';
import 'package:injast_admin/features/shared/admin_ui.dart';

/// فیلد قابل جستجو برای انتخاب از فهرست (استان / شهرستان).
class SearchablePlaceField extends StatelessWidget {
  const SearchablePlaceField({
    super.key,
    required this.label,
    required this.options,
    required this.value,
    required this.onSelected,
    this.enabled = true,
    this.requiredField = false,
    this.loading = false,
    this.width = 350,
  });

  final String label;
  final List<String> options;
  final String? value;
  final ValueChanged<String> onSelected;
  final bool enabled;
  final bool requiredField;
  final bool loading;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Autocomplete<String>(
        key: ValueKey('$label-${value ?? ''}-${options.length}'),
        initialValue: TextEditingValue(text: value ?? ''),
        optionsBuilder: (textEditingValue) {
          if (!enabled) return const Iterable<String>.empty();
          final q = textEditingValue.text.trim().toLowerCase();
          if (q.isEmpty) return options;
          return options.where((e) => e.toLowerCase().contains(q));
        },
        onSelected: onSelected,
        optionsViewBuilder: (context, onSelectedOption, opts) {
          final list = opts.toList();
          return Align(
            alignment: Alignment.topRight,
            child: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(12),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 240, maxWidth: 350),
                child: ListView.builder(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  itemCount: list.length,
                  itemBuilder: (context, index) {
                    final option = list[index];
                    return ListTile(
                      dense: true,
                      title: Text(option),
                      onTap: () => onSelectedOption(option),
                    );
                  },
                ),
              ),
            ),
          );
        },
        fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
          return TextFormField(
            controller: controller,
            focusNode: focusNode,
            enabled: enabled && !loading,
            validator: requiredField
                ? (v) =>
                    v == null || v.trim().isEmpty ? 'انتخاب $label الزامی است' : null
                : null,
            onChanged: (text) {
              final trimmed = text.trim();
              if (options.contains(trimmed)) onSelected(trimmed);
            },
            decoration: AdminUi.fieldDecoration(
              label,
              hint: 'جستجو و انتخاب $label',
              suffix: loading
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : Icon(
                      enabled ? Icons.arrow_drop_down : Icons.lock_outline,
                      color: AdminUi.muted,
                    ),
            ),
          );
        },
      ),
    );
  }
}
