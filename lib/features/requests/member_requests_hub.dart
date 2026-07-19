import 'package:flutter/material.dart';
import 'package:injast_admin/features/requests/manage_organizations_page.dart';
import 'package:injast_admin/features/requests/manage_request_types_page.dart';
import 'package:injast_admin/features/requests/manage_requests_page.dart';
import 'package:injast_admin/features/shared/admin_ui.dart';

class MemberRequestsHub extends StatelessWidget {
  const MemberRequestsHub({super.key, required this.codeCo});
  final String codeCo;

  Future<void> _open(BuildContext context) async {
    final choice = await showFeatureHubSheet<String>(
      context: context,
      title: 'مدیریت درخواست اعضا',
      items: const [
        FeatureHubItem(
            label: 'درخواست‌ها',
            subtitle: 'بررسی و تغییر وضعیت',
            icon: Icons.inbox_outlined,
            color: Colors.blue,
            value: 'requests'),
        FeatureHubItem(
            label: 'انواع درخواست',
            subtitle: 'تعریف فرم‌ها و فیلدها',
            icon: Icons.category_outlined,
            color: Colors.orange,
            value: 'types'),
        FeatureHubItem(
            label: 'ارگان‌های مقصد',
            subtitle: 'مدیریت گیرندگان درخواست',
            icon: Icons.account_balance_outlined,
            color: Colors.teal,
            value: 'orgs'),
      ],
    );
    if (!context.mounted || choice == null) return;
    final Widget page = switch (choice) {
      'types' => ManageRequestTypesPage(codeCo: codeCo),
      'orgs' => ManageOrganizationsPage(codeCo: codeCo),
      _ => ManageRequestsPage(codeCo: codeCo),
    };
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    return AdminPageShell(
      title: 'درخواست اعضا',
      icon: Icons.assignment_outlined,
      child: Center(
        child: FilledButton.icon(
          onPressed: () => _open(context),
          icon: const Icon(Icons.dashboard_customize_outlined),
          label: const Text('باز کردن بخش‌های مدیریت'),
        ),
      ),
    );
  }
}
