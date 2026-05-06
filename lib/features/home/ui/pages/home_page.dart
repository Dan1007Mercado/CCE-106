import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../../auth/bloc/auth_bloc.dart';
import '../../../auth/bloc/auth_event.dart';
import '../../../auth/data/models/user_model.dart';
import '../../../customer/ui/pages/customer_dashboard_page.dart';
import '../widgets/home_card.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.select((AuthBloc bloc) => bloc.state.user);

    if (user == null) {
      return const Scaffold(
        body: Center(
          child: LoadingIndicator(message: 'Loading your dashboard...'),
        ),
      );
    }

    if (user.role == AppUserRole.customer) {
      return const CustomerDashboardPage();
    }

    final theme = Theme.of(context);
    final highlights = _roleHighlights(user.role);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFE8F5F2), AppColors.background],
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(AppSizes.pagePadding),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSizes.cardPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Hello, ${user.displayName}',
                                  style: theme.textTheme.headlineSmall
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  user.email,
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: () {
                              context.read<AuthBloc>().add(
                                const AuthSignOutRequested(),
                              );
                            },
                            icon: const Icon(Icons.logout_rounded),
                            label: const Text('Sign out'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: _roleColor(user.role).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(
                            AppSizes.radiusMd,
                          ),
                        ),
                        child: Text(
                          '${user.role.label} role',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: _roleColor(user.role),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        user.role.description,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: AppColors.textSecondary,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSizes.sectionGap),
              Text(
                user.role.dashboardTitle,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _dashboardLead(user.role),
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              for (final item in highlights) ...[
                HomeCard(
                  icon: item.icon,
                  title: item.title,
                  description: item.description,
                ),
                const SizedBox(height: 16),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Color _roleColor(AppUserRole role) {
    switch (role) {
      case AppUserRole.admin:
        return AppColors.primaryDark;
      case AppUserRole.service:
        return AppColors.accent;
      case AppUserRole.customer:
        return AppColors.primary;
    }
  }

  String _dashboardLead(AppUserRole role) {
    switch (role) {
      case AppUserRole.admin:
        return 'Monitor activity, review role assignments, and keep the platform healthy.';
      case AppUserRole.service:
        return 'Stay on top of bookings, update availability, and deliver great service.';
      case AppUserRole.customer:
        return 'Explore services, manage your requests, and track every booking in one place.';
    }
  }

  List<_HomeHighlight> _roleHighlights(AppUserRole role) {
    switch (role) {
      case AppUserRole.admin:
        return const [
          _HomeHighlight(
            icon: Icons.supervisor_account_rounded,
            title: 'User oversight',
            description:
                'Review accounts, support team access, and verify role assignments.',
          ),
          _HomeHighlight(
            icon: Icons.analytics_outlined,
            title: 'Platform metrics',
            description:
                'Track bookings, service activity, and operational trends from one view.',
          ),
          _HomeHighlight(
            icon: Icons.verified_user_outlined,
            title: 'Security controls',
            description:
                'Manage trusted access and keep sensitive roles under internal control.',
          ),
        ];
      case AppUserRole.service:
        return const [
          _HomeHighlight(
            icon: Icons.build_circle_outlined,
            title: 'Job pipeline',
            description:
                'View incoming requests, update progress, and keep customers informed.',
          ),
          _HomeHighlight(
            icon: Icons.event_available_outlined,
            title: 'Availability',
            description:
                'Manage your schedule so customers can book time that works for you.',
          ),
          _HomeHighlight(
            icon: Icons.star_outline_rounded,
            title: 'Service reputation',
            description:
                'Build trust through strong communication, timely work, and good ratings.',
          ),
        ];
      case AppUserRole.customer:
        return const [
          _HomeHighlight(
            icon: Icons.search_rounded,
            title: 'Find the right service',
            description:
                'Browse trusted providers and choose the best fit for your task.',
          ),
          _HomeHighlight(
            icon: Icons.assignment_outlined,
            title: 'Booking history',
            description:
                'Keep your requests organized and revisit completed jobs anytime.',
          ),
          _HomeHighlight(
            icon: Icons.chat_bubble_outline_rounded,
            title: 'Clear communication',
            description:
                'Stay updated on timelines, status, and next steps with service providers.',
          ),
        ];
    }
  }
}

class _HomeHighlight {
  const _HomeHighlight({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;
}
