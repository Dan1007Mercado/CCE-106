import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'brand_logo.dart';

class AnimatedBrandLoader extends StatefulWidget {
  const AnimatedBrandLoader({
    super.key,
    this.message = 'Preparing HandyMarket...',
    this.spinning = true,
  });

  final String message;
  final bool spinning;

  @override
  State<AnimatedBrandLoader> createState() => _AnimatedBrandLoaderState();
}

class _AnimatedBrandLoaderState extends State<AnimatedBrandLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spinController;

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _syncSpin();
  }

  @override
  void didUpdateWidget(covariant AnimatedBrandLoader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.spinning != widget.spinning) {
      _syncSpin();
    }
  }

  @override
  void dispose() {
    _spinController.dispose();
    super.dispose();
  }

  void _syncSpin() {
    if (widget.spinning) {
      _spinController.repeat();
      return;
    }

    _spinController.stop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.tokens;
    final messageStyle = theme.textTheme.bodyMedium?.copyWith(
      color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.74),
      fontWeight: FontWeight.w600,
      letterSpacing: 0,
    );

    return Scaffold(
      body: AnimatedContainer(
        duration: AppTheme.motionDuration,
        curve: AppTheme.motionCurve,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [tokens.pageGradientStart, tokens.pageGradientEnd],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RotationTransition(
                  turns: _spinController,
                  child: const BrandLogo(
                    size: 96,
                    borderRadius: 30,
                    showShadow: true,
                  ),
                ),
                const SizedBox(height: 20),
                AnimatedOpacity(
                  duration: AppTheme.motionReverseDuration,
                  curve: AppTheme.motionCurve,
                  opacity: widget.spinning ? 1 : 0.78,
                  child: Text(widget.message, style: messageStyle),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
