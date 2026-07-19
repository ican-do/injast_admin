import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:injast_admin/features/permissions/permission_catalog.dart';
import 'package:injast_admin/features/permissions/user_permissions_api.dart';
import 'package:injast_admin/features/shared/admin_ui.dart';
import 'package:injast_admin/server_config.dart';

Future<List<Map<String, dynamic>>> _getUnionUsers(String codeCo) async {
  final response = await http.get(
    Uri.parse(
      getApiUrl(
        'select/select_person_co/${Uri.encodeComponent(codeCo.trim())}',
      ),
    ),
  );
  if (response.statusCode != 200) {
    throw Exception('دریافت کاربران ناموفق بود (${response.statusCode})');
  }
  final decoded = jsonDecode(response.body);
  if (decoded is! List) {
    throw const FormatException('ساختار پاسخ کاربران معتبر نیست');
  }
  return decoded
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList();
}

class ManageAccessPage extends StatefulWidget {
  const ManageAccessPage({super.key, required this.codeCo});

  final String codeCo;

  @override
  State<ManageAccessPage> createState() => _ManageAccessPageState();
}

class _ManageAccessPageState extends State<ManageAccessPage> {
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _users = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filtered {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return _users;
    return _users.where((user) {
      return [
        user['name_user'],
        user['family_user'],
        user['mob1_user'],
        user['id_user'],
        user['type_user'],
      ].any((value) => (value?.toString().toLowerCase() ?? '').contains(query));
    }).toList();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final users = await _getUnionUsers(widget.codeCo);
      if (mounted) setState(() => _users = users);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _name(Map<String, dynamic> user) {
    final fullName = [
      user['name_user']?.toString().trim() ?? '',
      user['family_user']?.toString().trim() ?? '',
    ].where((part) => part.isNotEmpty).join(' ');
    return fullName.isEmpty ? 'کاربر بدون نام' : fullName;
  }

  Future<void> _openEditor(Map<String, dynamic> user) async {
    final idUser = user['id_user']?.toString().trim() ?? '';
    if (idUser.isEmpty) {
      showAdminSnack(context, 'شناسه کاربر معتبر نیست', error: true);
      return;
    }
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => UserPermissionsEditorPage(user: user),
      ),
    );
    if (saved == true && mounted) {
      showAdminSnack(context, 'سطح دسترسی کاربر به‌روزرسانی شد');
    }
  }

  Widget _userCard(Map<String, dynamic> user) {
    final role = user['type_user']?.toString() ?? '';
    final active = user['active_user']?.toString() == '1';
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => _openEditor(user),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: AdminUi.cardDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: AdminUi.ink.withValues(alpha: 0.1),
                  child: const Icon(Icons.person_outline, color: AdminUi.ink),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _name(user),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                AdminStatusChip(
                  label: active ? 'فعال' : 'غیرفعال',
                  active: active,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              PermissionCatalog.roleLabel(role),
              style: const TextStyle(color: AdminUi.ink),
            ),
            const SizedBox(height: 4),
            Text(
              'کد کاربر: ${user['id_user'] ?? '—'}',
              style: const TextStyle(color: AdminUi.muted, fontSize: 12),
            ),
            const Spacer(),
            const Align(
              alignment: Alignment.centerLeft,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'ویرایش دسترسی',
                    style: TextStyle(color: AdminUi.ink),
                  ),
                  SizedBox(width: 4),
                  Icon(Icons.chevron_left, color: AdminUi.ink),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final users = _filtered;
    return AdminPageShell(
      title: 'مدیریت سطح دسترسی',
      subtitle: '${users.length} کاربر',
      icon: Icons.admin_panel_settings_outlined,
      actions: [
        IconButton(
          tooltip: 'بازخوانی',
          onPressed: _loading ? null : _load,
          icon: const Icon(Icons.refresh),
        ),
      ],
      child: Column(
        children: [
          AdminToolbar(
            searchController: _searchController,
            searchHint: 'نام، تلفن، نقش یا کد کاربر',
            onSearchChanged: (_) => setState(() {}),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? AdminEmptyState(message: _error!)
                    : users.isEmpty
                        ? const AdminEmptyState(message: 'کاربری یافت نشد')
                        : LayoutBuilder(
                            builder: (context, constraints) {
                              final columns = constraints.maxWidth >= 1000
                                  ? 3
                                  : constraints.maxWidth >= 650
                                      ? 2
                                      : 1;
                              return GridView.builder(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 8, 16, 24),
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: columns,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                  mainAxisExtent: 190,
                                ),
                                itemCount: users.length,
                                itemBuilder: (context, index) =>
                                    _userCard(users[index]),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}

class UserPermissionsEditorPage extends StatefulWidget {
  const UserPermissionsEditorPage({super.key, required this.user});

  final Map<String, dynamic> user;

  @override
  State<UserPermissionsEditorPage> createState() =>
      _UserPermissionsEditorPageState();
}

class _UserPermissionsEditorPageState extends State<UserPermissionsEditorPage> {
  bool _loading = true;
  bool _saving = false;
  String? _error;
  late String _baseRole;
  Set<String> _selected = {};
  bool _hasCustomProfile = false;

  String get _idUser => widget.user['id_user']?.toString().trim() ?? '';

  String get _userName {
    final value = [
      widget.user['name_user']?.toString().trim() ?? '',
      widget.user['family_user']?.toString().trim() ?? '',
    ].where((part) => part.isNotEmpty).join(' ');
    return value.isEmpty ? 'کاربر $_idUser' : value;
  }

  List<MapEntry<String, String>> get _roles {
    final roles = <MapEntry<String, String>>[
      const MapEntry('person_co', 'پرسنل عادی'),
      const MapEntry('admin_co', 'مدیر'),
      const MapEntry('bazras_co', 'بازرس'),
      ...PermissionCatalog.roleOptions,
    ];
    if (!roles.any((entry) => entry.key == _baseRole)) {
      roles.add(MapEntry(_baseRole, PermissionCatalog.roleLabel(_baseRole)));
    }
    return roles;
  }

  @override
  void initState() {
    super.initState();
    _baseRole = widget.user['type_user']?.toString().trim() ?? 'person_co';
    if (_baseRole.isEmpty) _baseRole = 'person_co';
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await UserPermissionsApi.fetch(_idUser);
      if (!mounted) return;
      setState(() {
        if (data?.exists == true) {
          _baseRole = data!.baseRole.isEmpty ? _baseRole : data.baseRole;
          _selected =
              PermissionCatalog.normalizeSavedPermissions(data.permissions);
          _hasCustomProfile = true;
        } else {
          _selected = PermissionCatalog.templateForRole(_baseRole);
          _hasCustomProfile = false;
        }
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Set<String> _keysOf(PermissionNode node) {
    final keys = <String>{};
    void walk(PermissionNode current) {
      if (current.key != null) keys.add(current.key!);
      for (final child in current.children) {
        walk(child);
      }
    }

    walk(node);
    return keys;
  }

  void _toggleGroup(PermissionNode node, bool selected) {
    final keys = _keysOf(node);
    setState(() {
      if (selected) {
        _selected.addAll(keys);
      } else {
        _selected.removeAll(keys);
      }
    });
  }

  Widget _permissionNode(PermissionNode node) {
    if (node.isLeaf) {
      return CheckboxListTile(
        dense: true,
        value: _selected.contains(node.key),
        title: Text(node.label),
        onChanged: _saving
            ? null
            : (value) => setState(() {
                  if (value == true) {
                    _selected.add(node.key!);
                  } else {
                    _selected.remove(node.key);
                  }
                }),
      );
    }

    final keys = _keysOf(node);
    final selectedCount = keys.where(_selected.contains).length;
    return ExpansionTile(
      initiallyExpanded: true,
      title: Text(
        node.label,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text('$selectedCount از ${keys.length} مورد'),
      leading: Checkbox(
        tristate: true,
        value: selectedCount == 0
            ? false
            : selectedCount == keys.length
                ? true
                : null,
        onChanged: _saving
            ? null
            : (value) => _toggleGroup(node, value ?? selectedCount == 0),
      ),
      children: node.children.map(_permissionNode).toList(),
    );
  }

  void _applyTemplate() {
    setState(() {
      _selected = PermissionCatalog.templateForRole(_baseRole);
    });
    showAdminSnack(context, 'الگوی نقش اعمال شد؛ برای ثبت، ذخیره کنید');
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final ok = await UserPermissionsApi.save(
        idUser: _idUser,
        baseRole: _baseRole,
        permissions: _selected,
      );
      if (!mounted) return;
      if (!ok) {
        showAdminSnack(context, 'ذخیره سطح دسترسی ناموفق بود', error: true);
        return;
      }
      Navigator.pop(context, true);
    } catch (error) {
      if (mounted) showAdminSnack(context, error.toString(), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _confirmReset() {
    showAdminConfirm(
      context: context,
      title: 'بازنشانی دسترسی',
      message: 'تنظیمات اختصاصی حذف و الگوی نقش جایگزین شود؟',
      confirmLabel: 'بازنشانی',
      onConfirm: () async {
        setState(() => _saving = true);
        try {
          final ok = await UserPermissionsApi.reset(_idUser);
          if (!mounted) return;
          if (!ok) {
            showAdminSnack(context, 'بازنشانی سطح دسترسی ناموفق بود',
                error: true);
            return;
          }
          setState(() {
            _selected = PermissionCatalog.templateForRole(_baseRole);
            _hasCustomProfile = false;
          });
          showAdminSnack(context, 'سطح دسترسی به الگوی نقش بازنشانی شد');
        } catch (error) {
          if (mounted) showAdminSnack(context, error.toString(), error: true);
        } finally {
          if (mounted) setState(() => _saving = false);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AdminPageShell(
      title: 'دسترسی‌های $_userName',
      subtitle: _hasCustomProfile ? 'پروفایل اختصاصی' : 'الگوی نقش',
      icon: Icons.security_outlined,
      maxWidth: 900,
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? AdminEmptyState(message: _error!)
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: AdminUi.cardDecoration(),
                        child: Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            SizedBox(
                              width: 260,
                              child: DropdownButtonFormField<String>(
                                initialValue: _baseRole,
                                decoration: AdminUi.fieldDecoration('نقش پایه'),
                                items: _roles
                                    .map(
                                      (role) => DropdownMenuItem(
                                        value: role.key,
                                        child: Text(role.value),
                                      ),
                                    )
                                    .toList(),
                                onChanged: _saving
                                    ? null
                                    : (value) =>
                                        setState(() => _baseRole = value!),
                              ),
                            ),
                            OutlinedButton.icon(
                              onPressed: _saving ? null : _applyTemplate,
                              icon: const Icon(Icons.auto_fix_high_outlined),
                              label: const Text('اعمال الگوی نقش'),
                            ),
                            OutlinedButton.icon(
                              onPressed: _saving ? null : _confirmReset,
                              icon: const Icon(Icons.restart_alt),
                              label: const Text('بازنشانی'),
                            ),
                            Text('${_selected.length} دسترسی انتخاب شده'),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
                        children: PermissionCatalog.permissionTree
                            .map(
                              (node) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Container(
                                  decoration: AdminUi.cardDecoration(),
                                  child: _permissionNode(node),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                    SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _saving ? null : _save,
                            icon: _saving
                                ? const SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.save_outlined),
                            label: const Text('ذخیره سطح دسترسی'),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}
