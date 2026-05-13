import 'package:flutter/material.dart';

/// صفحهٔ Placeholder یکپارچه برای امکاناتی که در فاز اول API ندارند.
/// با چیدمان رسمی و توضیح، در فازهای بعدی با ماژول واقعی جایگزین می‌شود.
class FeaturePlaceholderPage extends StatelessWidget {
  const FeaturePlaceholderPage({
    super.key,
    required this.title,
    required this.icon,
    required this.color,
    this.subtitle,
    this.contextInfo,
  });

  final String title;
  final IconData icon;
  final Color color;
  final String? subtitle;

  /// اطلاعات کانتکست (مثلا نام پرونده/شناسه) که در سرتیتر صفحه نمایش داده می‌شود.
  final String? contextInfo;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 86,
                  height: 86,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 44, color: color),
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                if (contextInfo != null && contextInfo!.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    contextInfo!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w600),
                  ),
                ],
                const SizedBox(height: 12),
                Text(
                  subtitle ??
                      'این بخش در فاز بعدی با API اختصاصی فعال خواهد شد. UI کامل آن جهت چیدمان نهایی پنل آماده است.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.black54, fontSize: 13.5, height: 1.7),
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('بازگشت'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
