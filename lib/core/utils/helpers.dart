import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class Helpers {
  static void showSnackBar(
    BuildContext context,
    String message, {
    bool isError = false,
  }) {
    final messenger = ScaffoldMessenger.of(context);
    final backgroundColor = isError
        ? Theme.of(context).colorScheme.error
        : const Color(0xFF15803D);

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: backgroundColor,
          content: Text(
            message,
            style: TextStyle(color: AppTheme.resolveOnColor(backgroundColor)),
          ),
        ),
      );
  }
}
