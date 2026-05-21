import 'package:flutter/material.dart';

import '../../../../core/constants/app_sizes.dart';
import '../../../../core/theme/app_theme.dart';

class AuthForm extends StatelessWidget {
  const AuthForm({
    required this.title,
    required this.subtitle,
    required this.children,
    super.key,
    this.footer = const [],
  });

  final String title;
  final String subtitle;
  final List<Widget> children;
  final List<Widget> footer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.tokens;
    final mutedText = theme.textTheme.bodyMedium?.color?.withValues(
      alpha: 0.74,
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
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSizes.pagePadding),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSizes.cardPadding),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: tokens.primarySoft,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Icon(
                            Icons.handyman_rounded,
                            size: 32,
                            color: AppTheme.resolveOnColor(tokens.primarySoft),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          title,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          subtitle,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: mutedText,
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: AppSizes.sectionGap),
                        ...children,
                        if (footer.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          ...footer,
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
