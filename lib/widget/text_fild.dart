import 'package:flutter/material.dart';
import 'package:injast_admin/features/shekayat/compat/persian_fonts_shim.dart';
import 'package:injast_admin/features/shekayat/compat/shekayat_basic.dart';

class text_fild_1 extends StatelessWidget {
  final String labelText;
  final String hintText;
  final TextEditingController controller;
  final bool enabled;

  const text_fild_1({
    Key? key,
    required this.labelText,
    required this.hintText,
    required this.controller,
    this.enabled = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: TextField(
        controller: controller,
        enabled: enabled,
        textAlign: TextAlign.right,
        decoration: InputDecoration(
          floatingLabelBehavior: FloatingLabelBehavior.always,
          labelText: labelText,
          hintText: hintText,
          isDense: true,
          labelStyle: PersianFonts.Shabnam.copyWith(
            fontWeight: FontWeight.w300,
            fontSize: font_size_12,
            color: Colors.black,
          ),
          hintStyle: PersianFonts.Shabnam.copyWith(
            fontWeight: FontWeight.w300,
            fontSize: font_size_12,
            color: Colors.grey,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          border: const OutlineInputBorder(),
          alignLabelWithHint: true,
        ),
      ),
    );
  }
}

class TextFieldMultiLine extends StatelessWidget {
  final String labelText;
  final String hintText;
  final TextEditingController controller;
  final bool enabled;

  const TextFieldMultiLine({
    Key? key,
    required this.labelText,
    required this.hintText,
    required this.controller,
    this.enabled = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: TextField(
        controller: controller,
        enabled: enabled,
        textAlign: TextAlign.right,
        maxLines: 4,
        minLines: 1,
        decoration: InputDecoration(
          floatingLabelBehavior: FloatingLabelBehavior.always,
          labelText: labelText,
          hintText: hintText,
          isDense: true,
          labelStyle: PersianFonts.Shabnam.copyWith(
            fontWeight: FontWeight.w300,
            fontSize: font_size_12,
            color: Colors.black,
          ),
          hintStyle: PersianFonts.Shabnam.copyWith(
            fontWeight: FontWeight.w300,
            fontSize: font_size_12,
            color: Colors.grey,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          border: const OutlineInputBorder(),
          alignLabelWithHint: true,
        ),
      ),
    );
  }
}
