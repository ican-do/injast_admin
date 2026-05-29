import 'package:flutter/material.dart';
import 'package:injast_admin/file_management/parvande_api.dart';
import 'package:injast_admin/file_management/parvande_sharik_form_sheet.dart';
import 'package:injast_admin/file_management/parvande_sharik_list_sheet.dart';

/// پنجرهٔ اصلی شرکای تجاری
class ParvandeSharikHubSheet extends StatelessWidget {
  const ParvandeSharikHubSheet({
    super.key,
    required this.codeCo,
    required this.parvande,
    required this.userId,
  });

  final String codeCo;
  final Map<String, dynamic> parvande;
  final String userId;

  static const _accent = Color(0xFF7B1FA2);

  static Future<void> show(
    BuildContext context, {
    required String codeCo,
    required Map<String, dynamic> parvande,
    required String userId,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ParvandeSharikHubSheet(
        codeCo: codeCo,
        parvande: parvande,
        userId: userId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = parvande;
    final title = p.storeName.isNotEmpty ? p.storeName : p.fullName;
    return SafeArea(
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
              child: Row(
                children: [
                  const Icon(Icons.groups_outlined, color: _accent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'شرکای تجاری',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                        ),
                        if (title.isNotEmpty)
                          Text(
                            title,
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFF3E5F5),
                child: Icon(Icons.person_add_outlined, color: _accent),
              ),
              title: const Text('ثبت شریک جدید'),
              subtitle: const Text('فرم ثبت شریک، مباشر، راننده و …'),
              onTap: () async {
                final saved = await ParvandeSharikFormSheet.show(
                  context,
                  codeCo: codeCo,
                  parvande: parvande,
                  userId: userId,
                );
                if (saved == true && context.mounted) Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFF3E5F5),
                child: Icon(Icons.list_alt_outlined, color: _accent),
              ),
              title: const Text('لیست شرکا'),
              subtitle: const Text('مشاهده، ویرایش و حذف شرکای این پرونده'),
              onTap: () {
                Navigator.pop(context);
                ParvandeSharikListSheet.show(
                  context,
                  codeCo: codeCo,
                  parvande: parvande,
                  userId: userId,
                );
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
