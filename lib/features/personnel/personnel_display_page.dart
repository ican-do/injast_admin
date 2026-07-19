import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:injast_admin/features/personnel/personnel_api.dart';
import 'package:injast_admin/features/shared/admin_ui.dart';
import 'package:url_launcher/url_launcher.dart';

class PersonnelDisplayPage extends StatefulWidget {
  const PersonnelDisplayPage({super.key, required this.codeCo});

  final String codeCo;

  @override
  State<PersonnelDisplayPage> createState() => _PersonnelDisplayPageState();
}

class _PersonnelDisplayPageState extends State<PersonnelDisplayPage> {
  List<Personnel> _items = const [];
  List<String> _categories = const [];
  String? _category;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        getPersonnelList(codeCo: widget.codeCo, isActive: true),
        getPersonnelCategories(widget.codeCo),
      ]);
      if (!mounted) return;
      setState(() {
        _items = results[0] as List<Personnel>;
        _categories = results[1] as List<String>;
        if (!_categories.contains(_category)) _category = null;
      });
    } catch (_) {
      if (mounted) setState(() => _error = 'دریافت فهرست پرسنل انجام نشد.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _contact(String value, String scheme) async {
    if (!await launchUrl(Uri(scheme: scheme, path: value)) && mounted) {
      showAdminSnack(context, 'امکان باز کردن این پیوند وجود ندارد.',
          error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = _category == null
        ? _items
        : _items.where((item) => item.category == _category).toList();
    return AdminPageShell(
      title: 'پرسنل',
      subtitle: 'معرفی اعضای فعال مجموعه',
      icon: FluentIcons.people_24_regular,
      actions: [
        IconButton(
          tooltip: 'تازه‌سازی',
          onPressed: _loading ? null : _load,
          icon: const Icon(FluentIcons.arrow_clockwise_24_regular),
        ),
      ],
      child: Column(
        children: [
          if (_categories.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Align(
                alignment: Alignment.centerRight,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('همه'),
                      selected: _category == null,
                      onSelected: (_) => setState(() => _category = null),
                    ),
                    ..._categories.map(
                      (value) => ChoiceChip(
                        label: Text(value),
                        selected: _category == value,
                        onSelected: (_) => setState(() => _category = value),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Expanded(child: _body(visible)),
        ],
      ),
    );
  }

  Widget _body(List<Personnel> items) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return AdminEmptyState(
        message: _error!,
        icon: FluentIcons.error_circle_24_regular,
      );
    }
    if (items.isEmpty) {
      return const AdminEmptyState(
          message: 'پرسنلی در این دسته‌بندی وجود ندارد.');
    }
    return LayoutBuilder(
      builder: (_, constraints) {
        final columns = constraints.maxWidth >= 1000
            ? 3
            : constraints.maxWidth >= 650
                ? 2
                : 1;
        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            mainAxisExtent: 260,
          ),
          itemCount: items.length,
          itemBuilder: (_, index) {
            final item = items[index];
            final photo = item.photoUrl?.trim() ?? '';
            return Container(
              padding: const EdgeInsets.all(18),
              decoration:
                  AdminUi.cardDecoration(color: const Color(0xFFFFFCF7)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: const Color(0xFFE8F1FF),
                        foregroundImage:
                            photo.isEmpty ? null : NetworkImage(photo),
                        child: photo.isEmpty
                            ? const Icon(
                                FluentIcons.person_24_regular,
                                color: AdminUi.ink,
                              )
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.fullName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AdminUi.ink,
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              item.roleTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Chip(
                    visualDensity: VisualDensity.compact,
                    side: BorderSide.none,
                    backgroundColor: const Color(0xFFEAF8F1),
                    label: Text(item.category),
                  ),
                  const SizedBox(height: 6),
                  Expanded(
                    child: Text(
                      item.bio?.trim().isNotEmpty == true
                          ? item.bio!
                          : 'توضیحی ثبت نشده است.',
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AdminUi.muted, height: 1.6),
                    ),
                  ),
                  Wrap(
                    spacing: 6,
                    children: [
                      if (item.phone?.trim().isNotEmpty == true)
                        TextButton.icon(
                          onPressed: () => _contact(item.phone!, 'tel'),
                          icon:
                              const Icon(FluentIcons.call_24_regular, size: 18),
                          label: Text(
                            item.phone!,
                            textDirection: TextDirection.ltr,
                          ),
                        ),
                      if (item.email?.trim().isNotEmpty == true)
                        IconButton(
                          tooltip: item.email,
                          onPressed: () => _contact(item.email!, 'mailto'),
                          icon: const Icon(FluentIcons.mail_24_regular),
                        ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
