import 'package:flutter/material.dart';
import 'package:injast_admin/features/shekayat/compat/get_nav.dart';
import 'package:injast_admin/features/shekayat/compat/shekayat_basic.dart';
import 'package:injast_admin/features/shekayat/pages/shekayat_register_form.dart';

class RegisterShekayatPage extends StatelessWidget {
  const RegisterShekayatPage({
    super.key,
    required this.codeCo,
    this.currentUserId,
    this.currentUser,
    this.unionName,
    this.prefillStore,
  });

  final String codeCo;
  final String? currentUserId;
  final Map<String, dynamic>? currentUser;
  final String? unionName;
  final Map<String, dynamic>? prefillStore;

  @override
  Widget build(BuildContext context) {
    ShekayatNav.bind(context);
    final user = Map<String, dynamic>.from(currentUser ?? {});
    if (currentUserId != null && currentUserId!.isNotEmpty) {
      user.putIfAbsent('id_user', () => currentUserId);
    }
    if (user['code_co'] == null) user['code_co'] = codeCo;
    bindShekayatSession(codeCo: codeCo, user: user.isEmpty ? null : user);

    return ShekayatRegisterForm(
      codeCo: codeCo,
      unionName: unionName,
      prefillStore: prefillStore,
      registerSource: prefillStore != null ? 'app_store' : 'app',
    );
  }
}
