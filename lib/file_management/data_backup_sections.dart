import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:injast_admin/file_management/backup_rtl_text.dart';

/// سطح جزئیات راهنمای هر دسته
enum BackupHelpLevel { simple, full }

/// یک عملیات داخل دسته
class BackupActionItem {
  const BackupActionItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.formatBadge,
    this.isDanger = false,
    this.isPrimary = false,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback? onTap;
  final String? formatBadge;
  final bool isDanger;
  final bool isPrimary;
}

/// یک دستهٔ ویژگی در صفحه بکاپ
class BackupCategorySection {
  const BackupCategorySection({
    required this.number,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.icon,
    required this.helpIntro,
    required this.helpSteps,
    required this.actions,
    this.helpLevel = BackupHelpLevel.simple,
    this.defaultExpanded = true,
  });

  final int number;
  final String title;
  final String subtitle;
  final Color color;
  final IconData icon;
  final String helpIntro;
  final List<String> helpSteps;
  final List<BackupActionItem> actions;
  final BackupHelpLevel helpLevel;
  final bool defaultExpanded;
}

/// کارت دسته‌بندی با طراحی مدرن
class BackupCategoryCard extends StatefulWidget {
  const BackupCategoryCard({
    super.key,
    required this.section,
  });

  final BackupCategorySection section;

  @override
  State<BackupCategoryCard> createState() => _BackupCategoryCardState();
}

class _BackupCategoryCardState extends State<BackupCategoryCard> {
  late bool _helpExpanded = widget.section.defaultExpanded;

  @override
  Widget build(BuildContext context) {
    final s = widget.section;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: s.color.withValues(alpha: 0.14)),
        boxShadow: [
          BoxShadow(
            color: s.color.withValues(alpha: 0.07),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(s),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _helpPanel(s),
                const SizedBox(height: 14),
                _actionsGrid(s),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _header(BackupCategorySection s) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            s.color,
            Color.lerp(s.color, Colors.black, 0.18)!,
          ],
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${s.number}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 18,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                BackupRtlText(
                  s.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                BackupRtlText(
                  s.subtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.88),
                    height: 1.5,
                    fontSize: 12.8,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(s.icon, color: Colors.white.withValues(alpha: 0.9), size: 28),
        ],
      ),
    );
  }

  Widget _helpPanel(BackupCategorySection s) {
    final isFull = s.helpLevel == BackupHelpLevel.full;
    return Material(
      color: s.color.withValues(alpha: 0.05),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () => setState(() => _helpExpanded = !_helpExpanded),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    FluentIcons.book_information_24_regular,
                    size: 18,
                    color: s.color,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: BackupRtlText(
                      isFull ? 'راهنمای کامل' : 'راهنمای سریع',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: s.color,
                        fontSize: 13.5,
                      ),
                    ),
                  ),
                  Icon(
                    _helpExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: s.color,
                  ),
                ],
              ),
              if (_helpExpanded) ...[
                const SizedBox(height: 10),
                BackupRtlText(
                  s.helpIntro,
                  style: const TextStyle(height: 1.75, fontSize: 13.2),
                ),
                const SizedBox(height: 10),
                ...s.helpSteps.asMap().entries.map(
                      (e) => _stepRow(
                        index: e.key + 1,
                        text: e.value,
                        color: s.color,
                      ),
                    ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _stepRow({
    required int index,
    required String text,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Text(
              '$index',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: BackupRtlText(
              text,
              style: const TextStyle(height: 1.65, fontSize: 12.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionsGrid(BackupCategorySection s) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 640;
        final cols = wide
            ? s.actions.length.clamp(1, 3)
            : 1;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            mainAxisExtent: 148,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemCount: s.actions.length,
          itemBuilder: (_, i) => _actionTile(s.actions[i], s.color),
        );
      },
    );
  }

  Widget _actionTile(BackupActionItem action, Color color) {
    final enabled = action.onTap != null;
    final tileColor = action.isDanger
        ? const Color(0xFFB71C1C)
        : (action.isPrimary ? color : color.withValues(alpha: 0.85));

    return Material(
      color: action.isDanger
          ? const Color(0xFFFFEBEE)
          : color.withValues(alpha: 0.04),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: action.onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: action.isDanger
                  ? const Color(0xFFB71C1C).withValues(alpha: 0.35)
                  : color.withValues(alpha: 0.18),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: tileColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      action.icon,
                      color: enabled ? tileColor : Colors.grey,
                      size: 20,
                    ),
                  ),
                  const Spacer(),
                  if (action.formatBadge != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: color.withValues(alpha: 0.2)),
                      ),
                      child: BackupLatinBadge(
                        action.formatBadge!,
                        color: color,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              BackupRtlText(
                action.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13.5,
                  color: enabled
                      ? (action.isDanger
                          ? const Color(0xFFB71C1C)
                          : Colors.black87)
                      : Colors.grey,
                ),
              ),
              const SizedBox(height: 4),
              Expanded(
                child: BackupRtlText(
                  action.subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.45,
                    color: Colors.black.withValues(alpha: 0.55),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    backgroundColor: enabled
                        ? tileColor.withValues(alpha: 0.14)
                        : Colors.grey.shade200,
                    foregroundColor: enabled ? tileColor : Colors.grey,
                  ),
                  onPressed: action.onTap,
                  icon: Icon(
                    action.isDanger
                        ? Icons.warning_amber_rounded
                        : Icons.play_arrow_rounded,
                    size: 18,
                  ),
                  label: Text(
                    action.isDanger ? 'ادامه با احتیاط' : 'شروع',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
