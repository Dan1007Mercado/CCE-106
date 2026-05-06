import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

class Helpers {
  static void showSnackBar(
    BuildContext context,
    String message, {
    bool isError = false,
  }) {
    final messenger = ScaffoldMessenger.of(context);

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: isError ? AppColors.error : AppColors.success,
          content: Text(message),
        ),
      );
  }
}
