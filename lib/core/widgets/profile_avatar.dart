import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    required this.name,
    super.key,
    this.radius = 20,
  });

  final String name;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final avatarBackground = theme.tokens.avatarBackground;
    final avatarForeground = AppTheme.resolveOnColor(avatarBackground);
    final initials = _readInitials(name);

    return AnimatedContainer(
      duration: AppTheme.motionDuration,
      curve: AppTheme.motionCurve,
      decoration: const BoxDecoration(shape: BoxShape.circle),
      child: CircleAvatar(
        radius: radius,
        backgroundColor: avatarBackground,
        child: Text(
          initials,
          style: theme.textTheme.titleMedium?.copyWith(
            color: avatarForeground,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.4,
          ),
        ),
      ),
    );
  }

  static String _readInitials(String value) {
    final pieces = value
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.trim().isNotEmpty)
        .take(2)
        .toList();

    if (pieces.isEmpty) {
      return 'HM';
    }

    return pieces.map((part) => part.substring(0, 1).toUpperCase()).join();
  }
}
