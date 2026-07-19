import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:injast_admin/features/news/news_api.dart';
import 'package:injast_admin/features/shared/manage_content_page.dart';

class ManageNewsPage extends StatelessWidget {
  const ManageNewsPage({
    super.key,
    required this.codeCo,
    this.currentUserId,
  });

  final String codeCo;
  final String? currentUserId;

  @override
  Widget build(BuildContext context) {
    return ManageContentPage(
      title: 'مدیریت اخبار',
      subtitle: 'ثبت و انتشار خبرهای مجموعه',
      singularName: 'خبر',
      icon: FluentIcons.news_24_regular,
      emptyMessage: 'خبری برای نمایش وجود ندارد.',
      load: () async {
        final items = await getNewsList(codeCo: codeCo);
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
          await createNews(
            codeCo: codeCo,
            title: title,
            content: content,
            imageUrl: imageUrl,
            publishLink: publishLink,
            isActive: isActive,
            idUser: int.tryParse(currentUserId ?? ''),
          );
        } else {
          await updateNews(
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
        await deleteNews(id);
      },
    );
  }
}
