import 'package:flutter/material.dart';
import 'package:injast_admin/features/inspections/inspection_archive_api.dart';
import 'package:injast_admin/features/shared/admin_ui.dart';
import 'package:injast_admin/features/shekayat/compat/permissions.dart';
import 'package:injast_admin/file_management/jalali_date_util.dart';
import 'package:persian_datetimepickers/persian_datetimepickers.dart';

class InspectionOutcomePanel extends StatefulWidget {
  const InspectionOutcomePanel({
    super.key,
    required this.codeCo,
    required this.sourceKind,
    required this.sourceId,
    required this.idParvande,
    required this.formId,
    required this.formName,
    this.initial,
    this.onChanged,
  });

  final String codeCo;
  final String sourceKind;
  final String sourceId;
  final String idParvande;
  final String formId;
  final String formName;
  final Map<String, dynamic>? initial;
  final ValueChanged<Map<String, dynamic>?>? onChanged;

  @override
  State<InspectionOutcomePanel> createState() => _InspectionOutcomePanelState();
}

class _InspectionOutcomePanelState extends State<InspectionOutcomePanel> {
  Map<String, dynamic>? _outcome;

  @override
  void initState() {
    super.initState();
    _outcome = widget.initial;
  }

  @override
  void didUpdateWidget(covariant InspectionOutcomePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initial != oldWidget.initial) _outcome = widget.initial;
  }

  Future<void> _edit() async {
    final result = await showInspectionOutcomeDialog(
      context: context,
      codeCo: widget.codeCo,
      sourceKind: widget.sourceKind,
      sourceId: widget.sourceId,
      idParvande: widget.idParvande,
      formId: widget.formId,
      formName: widget.formName,
      current: _outcome,
    );
    if (result == null || !mounted) return;
    setState(() => _outcome = result);
    widget.onChanged?.call(result);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AdminUi.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'وضعیت نهایی فرم',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AdminUi.ink,
                  ),
                ),
              ),
              if (Permissions.canSetInspectionOutcome())
                FilledButton.tonal(
                  onPressed: _edit,
                  child: Text(_outcome == null ? 'ثبت وضعیت' : 'ویرایش وضعیت'),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (_outcome == null)
            const Text('هنوز وضعیت نهایی ثبت نشده است.',
                style: TextStyle(color: AdminUi.muted))
          else
            ..._outcomeLines(_outcome!),
        ],
      ),
    );
  }
}

List<Widget> _outcomeLines(Map<String, dynamic> o) {
  final lines = <String>[
    o['status_label']?.toString() ?? '',
    if ((o['status_date']?.toString() ?? '').isNotEmpty)
      'تاریخ ثبت وضعیت: ${o['status_date']}',
    if ((o['authority_name']?.toString() ?? '').isNotEmpty)
      'مرجع ذیصلاح: ${o['authority_name']}',
    if ((o['reinspect_inspector_name']?.toString() ?? '').isNotEmpty)
      'بازرس محول‌شده: ${o['reinspect_inspector_name']}',
    if ((o['reinspect_date']?.toString() ?? '').isNotEmpty)
      'زمان بازرسی مجدد: ${o['reinspect_date']}',
    if (o['resolved'] == true) 'بازرسی مجدد انجام شد و از کارتابل خارج گردید',
  ].where((e) => e.trim().isNotEmpty).toList();
  return lines
      .map(
        (e) => Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(e, style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
      )
      .toList();
}

String outcomeSummary(Map<String, dynamic>? o) {
  if (o == null || (o['status']?.toString() ?? '').isEmpty) {
    return 'بدون وضعیت نهایی';
  }
  final parts = <String>[
    o['status_label']?.toString() ?? '',
    if ((o['status_date']?.toString() ?? '').isNotEmpty) o['status_date'].toString(),
  ];
  if (o['status'] == 'refer' && (o['authority_name']?.toString() ?? '').isNotEmpty) {
    parts.add(o['authority_name'].toString());
  }
  if (o['status'] == 'reinspect') {
    if ((o['reinspect_inspector_name']?.toString() ?? '').isNotEmpty) {
      parts.add(o['reinspect_inspector_name'].toString());
    }
    if ((o['reinspect_date']?.toString() ?? '').isNotEmpty) {
      parts.add(o['reinspect_date'].toString());
    }
    if (o['resolved'] == true) parts.add('انجام شد');
  }
  return parts.where((e) => e.trim().isNotEmpty).join(' • ');
}

Future<Map<String, dynamic>?> showInspectionOutcomeDialog({
  required BuildContext context,
  required String codeCo,
  required String sourceKind,
  required String sourceId,
  required String idParvande,
  required String formId,
  required String formName,
  Map<String, dynamic>? current,
}) async {
  var status = current?['status']?.toString() ?? 'archive';
  var statusDate = current?['status_date']?.toString().trim().isNotEmpty == true
      ? current!['status_date'].toString()
      : JalaliDateUtil.formatFromDateTime(DateTime.now());
  final authorityCtrl = TextEditingController(
    text: current?['authority_name']?.toString() ?? '',
  );
  var inspectorId = current?['reinspect_inspector_id']?.toString() ?? '';
  var inspectorName = current?['reinspect_inspector_name']?.toString() ?? '';
  var reinspectDate = current?['reinspect_date']?.toString() ??
      JalaliDateUtil.formatFromDateTime(DateTime.now());
  var inspectors = <Map<String, dynamic>>[];
  var loading = true;
  var saving = false;
  String? error;

  try {
    inspectors = await InspectionArchiveApi.instance.fetchInspectors(codeCo);
    loading = false;
  } catch (e) {
    loading = false;
    error = e.toString();
  }

  if (!context.mounted) {
    authorityCtrl.dispose();
    return null;
  }

  return showDialog<Map<String, dynamic>>(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setLocal) {
          Future<void> pickDate(void Function(String) apply) async {
            final picked = await showPersianDatePicker(
              context: ctx,
              initialDate: DateTime.now(),
            );
            if (picked == null) return;
            apply(JalaliDateUtil.formatFromDateTime(picked));
            setLocal(() {});
          }

          return Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              title: const Text('وضعیت نهایی فرم بازرسی'),
              content: SizedBox(
                width: 460,
                child: loading
                    ? const Center(child: CircularProgressIndicator())
                    : SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (error != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Text(error!,
                                    style: const TextStyle(color: Colors.red)),
                              ),
                            DropdownButtonFormField<String>(
                              initialValue: status,
                              decoration: AdminUi.fieldDecoration('وضعیت نهایی'),
                              items: const [
                                DropdownMenuItem(
                                    value: 'archive', child: Text('ثبت بایگانی')),
                                DropdownMenuItem(
                                    value: 'refer',
                                    child: Text('ارجاع به مراجع ذیصلاح')),
                                DropdownMenuItem(
                                    value: 'reinspect',
                                    child: Text('نیاز به بازرسی مجدد')),
                              ],
                              onChanged: (v) => setLocal(() => status = v ?? status),
                            ),
                            const SizedBox(height: 10),
                            TextFormField(
                              readOnly: true,
                              controller: TextEditingController(text: statusDate),
                              decoration: AdminUi.fieldDecoration(
                                'تاریخ ثبت وضعیت',
                                suffix: const Icon(Icons.date_range),
                              ),
                              onTap: () => pickDate((v) => statusDate = v),
                            ),
                            if (status == 'refer') ...[
                              const SizedBox(height: 10),
                              TextFormField(
                                controller: authorityCtrl,
                                decoration: AdminUi.fieldDecoration('نام مرجع ذیصلاح'),
                              ),
                            ],
                            if (status == 'reinspect') ...[
                              const SizedBox(height: 10),
                              DropdownButtonFormField<String>(
                                initialValue: inspectorId.isEmpty ? null : inspectorId,
                                isExpanded: true,
                                decoration: AdminUi.fieldDecoration('بازرس اتحادیه'),
                                items: inspectors
                                    .map(
                                      (e) => DropdownMenuItem(
                                        value: e['id']?.toString() ?? '',
                                        child: Text(e['name']?.toString() ?? ''),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (v) {
                                  inspectorId = v ?? '';
                                  inspectorName = inspectors
                                          .firstWhere(
                                            (e) => e['id']?.toString() == inspectorId,
                                            orElse: () => {},
                                          )['name']
                                          ?.toString() ??
                                      '';
                                  setLocal(() {});
                                },
                              ),
                              const SizedBox(height: 10),
                              TextFormField(
                                readOnly: true,
                                controller: TextEditingController(text: reinspectDate),
                                decoration: AdminUi.fieldDecoration(
                                  'زمان بازرسی مجدد',
                                  suffix: const Icon(Icons.event),
                                ),
                                onTap: () => pickDate((v) => reinspectDate = v),
                              ),
                            ],
                          ],
                        ),
                      ),
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.pop(ctx),
                  child: const Text('انصراف'),
                ),
                FilledButton(
                  onPressed: saving
                      ? null
                      : () async {
                          setLocal(() => saving = true);
                          try {
                            final saved =
                                await InspectionArchiveApi.instance.saveOutcome(
                              codeCo: codeCo,
                              sourceKind: sourceKind,
                              sourceId: sourceId,
                              status: status,
                              statusDate: statusDate,
                              idParvande: idParvande,
                              formId: formId,
                              formName: formName,
                              authorityName: authorityCtrl.text.trim(),
                              reinspectInspectorId: inspectorId,
                              reinspectInspectorName: inspectorName,
                              reinspectDate: reinspectDate,
                            );
                            if (ctx.mounted) Navigator.pop(ctx, saved);
                          } catch (e) {
                            if (ctx.mounted) {
                              showAdminSnack(ctx, e.toString(), error: true);
                              setLocal(() => saving = false);
                            }
                          }
                        },
                  child: saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('ثبت'),
                ),
              ],
            ),
          );
        },
      );
    },
  ).whenComplete(authorityCtrl.dispose);
}
