import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class BrandLogo extends StatelessWidget {
  const BrandLogo({
    super.key,
    this.size = 64,
    this.borderRadius = 20,
    this.fit = BoxFit.contain,
    this.padding = EdgeInsets.zero,
    this.showShadow = false,
  });

  final double size;
  final double borderRadius;
  final BoxFit fit;
  final EdgeInsetsGeometry padding;
  final bool showShadow;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.tokens;

    return Container(
      width: size,
      height: size,
      padding: padding,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: tokens.primarySoft,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: showShadow
            ? [
                BoxShadow(
                  color: theme.colorScheme.primary.withValues(alpha: 0.18),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ]
            : null,
      ),
      child: Image.asset(
        'assets/images/handymarket_logo.png',
        fit: fit,
        filterQuality: FilterQuality.high,
      ),
    );
  }
}
