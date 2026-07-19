import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:injast_admin/features/shared/manage_content_page.dart';
import 'package:injast_admin/features/tutorials/tutorials_api.dart';

class ManageTutorialsPage extends StatelessWidget {
  const ManageTutorialsPage({
    super.key,
    required this.codeCo,
    this.currentUserId,
  });

  final String codeCo;
  final String? currentUserId;

  @override
  Widget build(BuildContext context) {
    return ManageContentPage(
      title: 'مدیریت آموزش‌ها',
      subtitle: 'ثبت و انتشار محتوای آموزشی',
      singularName: 'آموزش',
      icon: FluentIcons.book_open_24_regular,
      placeholderColor: const Color(0xFFFFF3DD),
      emptyMessage: 'آموزشی برای نمایش وجود ندارد.',
      load: () async {
        final items = await getTutorialsList(codeCo: codeCo);
        return items
            .map(
              (item) => ManagedContentItem(
                id: item.id,
                title: item.title,
                content: item.content,
                imageUrl: item.imageUrl,
                publishLink: item.publishLink,
                isActive: item.isActive,
              ),
            )
            .toList();
      },
      save: ({
        int? id,
        required String title,
        required String content,
        String? imageUrl,
        String? publishLink,
        required bool isActive,
      }) async {
        if (id == null) {
          await createTutorial(
            codeCo: codeCo,
            title: title,
            content: content,
            imageUrl: imageUrl,
            publishLink: publishLink,
            isActive: isActive,
            idUser: int.tryParse(currentUserId ?? ''),
          );
        } else {
          await updateTutorial(
            id: id,
            title: title,
            content: content,
            imageUrl: imageUrl,
            publishLink: publishLink,
            isActive: isActive,
          );
        }
      },
      delete: (id) async {
        await deleteTutorial(id);
      },
    );
  }
}
