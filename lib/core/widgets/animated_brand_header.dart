import 'package:flutter/material.dart';

import '../constants/app_strings.dart';
import 'brand_logo.dart';

class AnimatedBrandHeader extends StatefulWidget {
  const AnimatedBrandHeader({
    super.key,
    this.showTitle = true,
    this.logoSize = 64,
    this.title = AppStrings.appName,
  });

  final bool showTitle;
  final double logoSize;
  final String title;

  @override
  State<AnimatedBrandHeader> createState() => _AnimatedBrandHeaderState();
}

class _AnimatedBrandHeaderState extends State<AnimatedBrandHeader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _titleReveal;
  late final Animation<double> _titleOpacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    );
    _titleReveal = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.22, 0.82, curve: Curves.easeInOutCubic),
    );
    _titleOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.42, 1, curve: Curves.easeOutCubic),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future<void>.delayed(const Duration(milliseconds: 180), () {
        if (mounted) {
          _controller.forward();
        }
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final titleStyle = theme.textTheme.titleLarge?.copyWith(
      fontWeight: FontWeight.w800,
      letterSpacing: 0,
    );

    return SizedBox(
      height: widget.logoSize,
      child: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                BrandLogo(size: widget.logoSize),
                if (widget.showTitle) ...[
                  SizedBox(width: 10 * _titleReveal.value),
                  ClipRect(
                    child: Align(
                      widthFactor: _titleReveal.value,
                      child: FadeTransition(
                        opacity: _titleOpacity,
                        child: Text(
                          widget.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: titleStyle,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}
