import 'package:flutter/material.dart';
import 'package:injast_admin/features/shekayat/compat/get_nav.dart';
import 'package:injast_admin/features/shekayat/compat/permissions.dart';
import 'package:injast_admin/features/shekayat/compat/shekayat_basic.dart';
import 'package:injast_admin/features/shekayat/pages/manage_shekayat_v2.dart';

/// نقطه ورود مدیریت شکایات — ۸ دکمه عملیات مطابق پروژه مادر
class ManageShekayatPage extends StatefulWidget {
  const ManageShekayatPage({
    super.key,
    required this.codeCo,
    this.currentUserId,
    this.currentUserType,
    this.currentUser,
    this.initialSearch,
  });

  final String codeCo;
  final String? currentUserId;
  final String? currentUserType;
  final Map<String, dynamic>? currentUser;
  final String? initialSearch;

  @override
  State<ManageShekayatPage> createState() => _ManageShekayatPageState();
}

class _ManageShekayatPageState extends State<ManageShekayatPage> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final user = Map<String, dynamic>.from(widget.currentUser ?? {});
    if (widget.currentUserId != null && widget.currentUserId!.isNotEmpty) {
      user.putIfAbsent('id_user', () => widget.currentUserId);
    }
    if (widget.currentUserType != null && widget.currentUserType!.isNotEmpty) {
      user.putIfAbsent('type_user', () => widget.currentUserType);
    }
    if (user['code_co'] == null) user['code_co'] = widget.codeCo;

    bindShekayatSession(
      codeCo: widget.codeCo,
      user: user.isEmpty ? null : user,
    );
    await Permissions.loadForCurrentUser();
    if (mounted) setState(() => _ready = true);
  }

  @override
  Widget build(BuildContext context) {
    ShekayatNav.bind(context);
    if (!_ready) {
      return const Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    return ManageShekayatV2(
      codeCo: widget.codeCo,
      initialSearch: widget.initialSearch,
    );
  }
}
