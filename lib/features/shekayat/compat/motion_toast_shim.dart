import 'package:flutter/material.dart';

enum _ToastKind { success, error, warning, info }

class MotionToast {
  MotionToast._(this._kind, {this.title, this.description});

  final _ToastKind _kind;
  final Widget? title;
  final Widget? description;

  factory MotionToast.success({Widget? title, Widget? description}) =>
      MotionToast._(_ToastKind.success, title: title, description: description);

  factory MotionToast.error({Widget? title, Widget? description}) =>
      MotionToast._(_ToastKind.error, title: title, description: description);

  factory MotionToast.warning({Widget? title, Widget? description}) =>
      MotionToast._(_ToastKind.warning, title: title, description: description);

  factory MotionToast.info({Widget? title, Widget? description}) =>
      MotionToast._(_ToastKind.info, title: title, description: description);

  void show(BuildContext context) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    Color bg;
    switch (_kind) {
      case _ToastKind.success:
        bg = Colors.green.shade700;
        break;
      case _ToastKind.error:
        bg = Colors.red.shade700;
        break;
      case _ToastKind.warning:
        bg = Colors.orange.shade800;
        break;
      case _ToastKind.info:
        bg = Colors.blueGrey.shade700;
        break;
    }

    String text = '';
    if (description is Text) {
      text = (description as Text).data ?? '';
    } else if (title is Text) {
      text = (title as Text).data ?? '';
    } else {
      text = 'پیام';
    }

    messenger.showSnackBar(
      SnackBar(
        content: Text(text, textDirection: TextDirection.rtl),
        backgroundColor: bg,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
