import 'package:flutter/material.dart';
import 'package:injast_admin/features/shekayat/compat/get_nav.dart';
import 'package:injast_admin/features/shekayat/compat/shekayat_basic.dart';
import 'package:injast_admin/features/shekayat/reports/shekayat_reports_hub.dart';

class ShekayatReportsPage extends StatelessWidget {
  const ShekayatReportsPage({super.key, required this.codeCo});

  final String codeCo;

  @override
  Widget build(BuildContext context) {
    ShekayatNav.bind(context);
    bindShekayatSession(codeCo: codeCo);
    return ShekayatReportsHub(codeCo: codeCo);
  }
}
