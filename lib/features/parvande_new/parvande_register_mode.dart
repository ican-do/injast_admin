import 'package:flutter/material.dart';
import 'package:injast_admin/features/parvande_new/new_parvande_page.dart';
import 'package:injast_admin/features/shared/admin_ui.dart';

/// نحوهٔ نمایش فرم ثبت پروندهٔ جدید
enum ParvandeRegisterMode {
  /// فقط فیلدهای ستاره‌دار / اجباری
  quick,

  /// همهٔ فیلدها
  full,
}

/// دیالوگ انتخاب «ثبت سریع» یا «ثبت اطلاعات کامل»
Future<ParvandeRegisterMode?> showParvandeRegisterModeDialog(
  BuildContext context,
) {
  return showDialog<ParvandeRegisterMode>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: true,
    builder: (ctx) {
      return Directionality(
        textDirection: TextDirection.rtl,
        child: Dialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'ثبت پرونده جدید',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AdminUi.ink,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'نوع ثبت را انتخاب کنید:',
                    textAlign: TextAlign.right,
                    style: TextStyle(fontSize: 14, height: 1.5, color: AdminUi.muted),
                  ),
                  const SizedBox(height: 16),
                  _modeButton(
                    ctx,
                    title: 'ثبت سریع پرونده',
                    subtitle: 'فقط فیلدهای اجباری (ستاره‌دار)',
                    icon: Icons.flash_on_outlined,
                    color: const Color(0xFF047857),
                    mode: ParvandeRegisterMode.quick,
                  ),
                  const SizedBox(height: 10),
                  _modeButton(
                    ctx,
                    title: 'ثبت اطلاعات کامل',
                    subtitle: 'همهٔ فیلدها مانند قبل',
                    icon: Icons.description_outlined,
                    color: AdminUi.ink,
                    mode: ParvandeRegisterMode.full,
                  ),
                  const SizedBox(height: 4),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('انصراف'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

Widget _modeButton(
  BuildContext ctx, {
  required String title,
  required String subtitle,
  required IconData icon,
  required Color color,
  required ParvandeRegisterMode mode,
}) {
  return Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(10),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: () => Navigator.pop(ctx, mode),
      child: Ink(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              Icon(icon, color: color, size: 26),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Colors.black87,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// دیالوگ نوع ثبت + باز کردن فرم پرونده جدید
Future<bool> startNewParvandeAdminFlow(
  BuildContext context, {
  required String codeCo,
  required String idUser,
  Map<String, dynamic>? unionInfo,
}) async {
  if (codeCo.trim().isEmpty) return false;
  final mode = await showParvandeRegisterModeDialog(context);
  if (mode == null || !context.mounted) return false;
  final created = await Navigator.of(context, rootNavigator: true).push<bool>(
    MaterialPageRoute(
      builder: (_) => NewParvandePage(
        codeCo: codeCo,
        idUser: idUser.isEmpty ? '0' : idUser,
        unionInfo: unionInfo,
        registerMode: mode,
      ),
    ),
  );
  return created == true;
}
