import 'package:flutter/material.dart';

/// متغیرهای مشترک برای صفحات شکایت (سازگار با injast_v3)
Color color_basic_1 = const Color(0xFF0491B7);
Color color_back_page = const Color(0xFFF8FAFF);

/// اندازه‌های فشرده مناسب دسکتاپ (مانیتور واید)
double font_size_6 = 10;
double font_size_8 = 11;
double font_size_10 = 12;
double font_size_12 = 13;
double font_size_14 = 13.5;
double font_size_16 = 14.5;
double font_size_18 = 16;
double font_size_20 = 17;
double font_size_24 = 18;
double font_size_26 = 19;
double font_size_28 = 20;
double font_size_30 = 22;
double with_screen = 0;
double hight_screen = 0;

String code_co = '';
List list_user = [];
List list_user_select = [];
List list_parvande_basic = [];

void bindShekayatSession({
  required String codeCo,
  Map<String, dynamic>? user,
}) {
  code_co = codeCo;
  if (user != null) {
    list_user = [user];
  }
}
