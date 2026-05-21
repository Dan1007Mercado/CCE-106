import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_sizes.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/helpers.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../../auth/bloc/auth_bloc.dart';
import '../../../auth/bloc/auth_event.dart';
import '../../../auth/data/models/user_model.dart';
import '../../data/models/admin_dashboard_models.dart';
import '../../data/services/admin_service.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  final AdminService _adminService = AdminService();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _termsController = TextEditingController(
    text:
        'HandyMarket connects customers with verified service providers. Users must provide accurate account, booking, payment, and service information.',
  );

  String _searchQuery = '';
  bool _isSavingTerms = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _termsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.select((AuthBloc bloc) => bloc.state.user);

    if (user == null) {
      return const Scaffold(
        body: Center(
          child: LoadingIndicator(message: 'Loading admin dashboard...'),
        ),
      );
    }

    if (user.role != AppUserRole.admin) {
      return _AccessDenied(user: user);
    }

    return StreamBuilder<List<AdminUserAccountModel>>(
      stream: _adminService.streamUsers(),
      builder: (context, userSnapshot) {
        return StreamBuilder<List<ProviderApplicationModel>>(
          stream: _adminService.streamProviderApplications(),
          builder: (context, applicationSnapshot) {
            return StreamBuilder<List<AdminPaymentModel>>(
              stream: _adminService.streamPayments(),
              builder: (context, paymentSnapshot) {
                final isLoading =
                    userSnapshot.connectionState == ConnectionState.waiting &&
                    !userSnapshot.hasData;

                if (isLoading) {
                  return const Scaffold(
                    body: Center(
                      child: LoadingIndicator(
                        message: 'Loading admin dashboard...',
                      ),
                    ),
                  );
                }

                final users = _filterUsers(userSnapshot.data ?? const []);
                final applications = _filterApplications(
                  applicationSnapshot.data ?? const [],
                );
                final payments = paymentSnapshot.data ?? const [];

                return _AdminShell(
                  admin: user,
                  searchController: _searchController,
                  users: users,
                  applications: applications,
                  payments: payments,
                  isSavingTerms: _isSavingTerms,
                  termsController: _termsController,
                  onSignOut: () {
                    context.read<AuthBloc>().add(const AuthSignOutRequested());
                  },
                  onToggleUserSuspension: _toggleUserSuspension,
                  onReviewApplication: _reviewApplication,
                  onSaveTerms: _saveTerms,
                );
              },
            );
          },
        );
      },
    );
  }

  List<AdminUserAccountModel> _filterUsers(List<AdminUserAccountModel> users) {
    if (_searchQuery.isEmpty) {
      return users;
    }

    return users.where((account) {
      final user = account.user;
      final source =
          '${user.displayName} ${user.email} ${user.role.label} ${account.status}'
              .toLowerCase();
      return source.contains(_searchQuery);
    }).toList();
  }

  List<ProviderApplicationModel> _filterApplications(
    List<ProviderApplicationModel> applications,
  ) {
    if (_searchQuery.isEmpty) {
      return applications;
    }

    return applications.where((application) {
      final source =
          '${application.providerName} ${application.skillCategory} ${application.status}'
              .toLowerCase();
      return source.contains(_searchQuery);
    }).toList();
  }

  Future<void> _toggleUserSuspension(AdminUserAccountModel account) async {
    try {
      await _adminService.setUserSuspended(
        uid: account.user.uid,
        suspended: !account.isSuspended,
      );

      if (!mounted) {
        return;
      }

      Helpers.showSnackBar(
        context,
        account.isSuspended ? 'User activated.' : 'User suspended.',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      Helpers.showSnackBar(
        context,
        error.toString().replaceFirst('Exception: ', ''),
        isError: true,
      );
    }
  }

  Future<void> _reviewApplication(
    ProviderApplicationModel application,
    String status,
  ) async {
    try {
      await _adminService.reviewProviderApplication(
        applicationId: application.applicationId,
        status: status,
        adminRemarks: status == 'approved'
            ? 'Skill application approved.'
            : 'Skill application rejected. Please submit clearer proof.',
      );

      if (!mounted) {
        return;
      }

      Helpers.showSnackBar(
        context,
        status == 'approved'
            ? 'Application approved.'
            : 'Application rejected.',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      Helpers.showSnackBar(
        context,
        error.toString().replaceFirst('Exception: ', ''),
        isError: true,
      );
    }
  }

  Future<void> _saveTerms() async {
    setState(() {
      _isSavingTerms = true;
    });

    try {
      await _adminService.saveTerms(_termsController.text);

      if (!mounted) {
        return;
      }

      Helpers.showSnackBar(context, 'Terms and Conditions saved.');
    } catch (error) {
      if (!mounted) {
        return;
      }

      Helpers.showSnackBar(
        context,
        error.toString().replaceFirst('Exception: ', ''),
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSavingTerms = false;
        });
      }
    }
  }
}

class _AdminShell extends StatelessWidget {
  const _AdminShell({
    required this.admin,
    required this.searchController,
    required this.users,
    required this.applications,
    required this.payments,
    required this.isSavingTerms,
    required this.termsController,
    required this.onSignOut,
    required this.onToggleUserSuspension,
    required this.onReviewApplication,
    required this.onSaveTerms,
  });

  final UserModel admin;
  final TextEditingController searchController;
  final List<AdminUserAccountModel> users;
  final List<ProviderApplicationModel> applications;
  final List<AdminPaymentModel> payments;
  final bool isSavingTerms;
  final TextEditingController termsController;
  final VoidCallback onSignOut;
  final ValueChanged<AdminUserAccountModel> onToggleUserSuspension;
  final void Function(ProviderApplicationModel application, String status)
  onReviewApplication;
  final VoidCallback onSaveTerms;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 1000;
        final content = _AdminContent(
          admin: admin,
          searchController: searchController,
          users: users,
          applications: applications,
          payments: payments,
          isDesktop: isDesktop,
          isSavingTerms: isSavingTerms,
          termsController: termsController,
          onSignOut: onSignOut,
          onToggleUserSuspension: onToggleUserSuspension,
          onReviewApplication: onReviewApplication,
          onSaveTerms: onSaveTerms,
        );

        if (!isDesktop) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Super Admin'),
              actions: [
                IconButton(
                  tooltip: 'Sign out',
                  onPressed: onSignOut,
                  icon: const Icon(Icons.logout_rounded),
                ),
              ],
            ),
            body: content,
          );
        }

        return Scaffold(
          body: Row(
            children: [
              _AdminSidebar(admin: admin, onSignOut: onSignOut),
              Expanded(child: content),
            ],
          ),
        );
      },
    );
  }
}

class _AdminContent extends StatelessWidget {
  const _AdminContent({
    required this.admin,
    required this.searchController,
    required this.users,
    required this.applications,
    required this.payments,
    required this.isDesktop,
    required this.isSavingTerms,
    required this.termsController,
    required this.onSignOut,
    required this.onToggleUserSuspension,
    required this.onReviewApplication,
    required this.onSaveTerms,
  });

  final UserModel admin;
  final TextEditingController searchController;
  final List<AdminUserAccountModel> users;
  final List<ProviderApplicationModel> applications;
  final List<AdminPaymentModel> payments;
  final bool isDesktop;
  final bool isSavingTerms;
  final TextEditingController termsController;
  final VoidCallback onSignOut;
  final ValueChanged<AdminUserAccountModel> onToggleUserSuspension;
  final void Function(ProviderApplicationModel application, String status)
  onReviewApplication;
  final VoidCallback onSaveTerms;

  @override
  Widget build(BuildContext context) {
    final pendingApplications = applications
        .where((application) => application.status == 'pending')
        .length;
    final customers = users
        .where((account) => account.user.role == AppUserRole.customer)
        .length;
    final providers = users
        .where((account) => account.user.role == AppUserRole.service)
        .length;
    final platformRevenue = payments
        .where((payment) => payment.status == 'paid')
        .fold<double>(
          0,
          (sum, payment) => sum + payment.platformCommissionAmount,
        );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSizes.pagePadding),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1280),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _AdminTopHeader(
                admin: admin,
                searchController: searchController,
                onSignOut: onSignOut,
                isDesktop: isDesktop,
              ),
              const SizedBox(height: AppSizes.sectionGap),
              _AdminHero(admin: admin),
              const SizedBox(height: AppSizes.sectionGap),
              _MetricGrid(
                isDesktop: isDesktop,
                metrics: [
                  _DashboardMetric(
                    icon: Icons.group_outlined,
                    label: 'Total users',
                    value: users.length.toString(),
                  ),
                  _DashboardMetric(
                    icon: Icons.person_outline_rounded,
                    label: 'Customers',
                    value: customers.toString(),
                  ),
                  _DashboardMetric(
                    icon: Icons.engineering_outlined,
                    label: 'Providers',
                    value: providers.toString(),
                  ),
                  _DashboardMetric(
                    icon: Icons.verified_user_outlined,
                    label: 'Skill validations',
                    value: pendingApplications.toString(),
                  ),
                  _DashboardMetric(
                    icon: Icons.payments_outlined,
                    label: 'Platform revenue',
                    value: _formatCurrency(platformRevenue),
                  ),
                ],
              ),
              const SizedBox(height: AppSizes.sectionGap),
              _SkillValidationTable(
                applications: applications,
                onReviewApplication: onReviewApplication,
              ),
              const SizedBox(height: AppSizes.sectionGap),
              _UserManagementTable(
                currentAdminId: admin.uid,
                users: users,
                onToggleUserSuspension: onToggleUserSuspension,
              ),
              const SizedBox(height: AppSizes.sectionGap),
              if (isDesktop)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: _RevenueOverview(payments: payments),
                    ),
                    const SizedBox(width: AppSizes.sectionGap),
                    Expanded(
                      flex: 2,
                      child: _PolicyManagementCard(
                        termsController: termsController,
                        isSavingTerms: isSavingTerms,
                        onSaveTerms: onSaveTerms,
                      ),
                    ),
                  ],
                )
              else ...[
                _RevenueOverview(payments: payments),
                const SizedBox(height: AppSizes.sectionGap),
                _PolicyManagementCard(
                  termsController: termsController,
                  isSavingTerms: isSavingTerms,
                  onSaveTerms: onSaveTerms,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminSidebar extends StatelessWidget {
  const _AdminSidebar({required this.admin, required this.onSignOut});

  final UserModel admin;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: 272,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(right: BorderSide(color: theme.colorScheme.outline)),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.admin_panel_settings_rounded,
                    color: theme.colorScheme.onPrimary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'HandyMarket',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30),
            const _SidebarItem(
              icon: Icons.dashboard_outlined,
              label: 'Overview',
              selected: true,
            ),
            const _SidebarItem(
              icon: Icons.verified_user_outlined,
              label: 'Skill validation',
            ),
            const _SidebarItem(
              icon: Icons.group_outlined,
              label: 'User management',
            ),
            const _SidebarItem(icon: Icons.payments_outlined, label: 'Revenue'),
            const _SidebarItem(
              icon: Icons.policy_outlined,
              label: 'Terms and policy',
            ),
            const Spacer(),
            Text(
              admin.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              admin.email,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: onSignOut,
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Sign out'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.icon,
    required this.label,
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final background = selected ? theme.tokens.primarySoft : Colors.transparent;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: selected
                ? AppTheme.resolveOnColor(theme.tokens.primarySoft)
                : theme.iconTheme.color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                color: selected
                    ? AppTheme.resolveOnColor(theme.tokens.primarySoft)
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminTopHeader extends StatelessWidget {
  const _AdminTopHeader({
    required this.admin,
    required this.searchController,
    required this.onSignOut,
    required this.isDesktop,
  });

  final UserModel admin;
  final TextEditingController searchController;
  final VoidCallback onSignOut;
  final bool isDesktop;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: searchController,
            decoration: const InputDecoration(
              hintText: 'Search users, providers, requests, status',
              prefixIcon: Icon(Icons.search_rounded),
            ),
          ),
        ),
        if (isDesktop) ...[
          const SizedBox(width: 16),
          CircleAvatar(
            backgroundColor: theme.tokens.primarySoft,
            child: Icon(
              Icons.person_outline_rounded,
              color: AppTheme.resolveOnColor(theme.tokens.primarySoft),
            ),
          ),
          const SizedBox(width: 10),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 180),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  admin.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  'Super Admin',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.textTheme.bodySmall?.color?.withValues(
                      alpha: 0.72,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _AdminHero extends StatelessWidget {
  const _AdminHero({required this.admin});

  final UserModel admin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSizes.cardPadding),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [theme.colorScheme.primary, const Color(0xFF2563EB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Super Admin Dashboard',
            style: theme.textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Monitor HandyMarket users, provider validations, policy content, and platform revenue.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: Colors.white.withValues(alpha: 0.88),
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.metrics, required this.isDesktop});

  final List<_DashboardMetric> metrics;
  final bool isDesktop;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      itemCount: metrics.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isDesktop ? 5 : 2,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        mainAxisExtent: 126,
      ),
      itemBuilder: (context, index) {
        final metric = metrics[index];
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(metric.icon, color: Theme.of(context).colorScheme.primary),
                Text(
                  metric.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                Text(
                  metric.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.color?.withValues(alpha: 0.72),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SkillValidationTable extends StatelessWidget {
  const _SkillValidationTable({
    required this.applications,
    required this.onReviewApplication,
  });

  final List<ProviderApplicationModel> applications;
  final void Function(ProviderApplicationModel application, String status)
  onReviewApplication;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Skill validation requests',
      child: applications.isEmpty
          ? const _EmptyState(
              icon: Icons.verified_user_outlined,
              title: 'No provider applications',
              description: 'Skill validation submissions will appear here.',
            )
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Provider')),
                  DataColumn(label: Text('Skill')),
                  DataColumn(label: Text('Experience')),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('Action')),
                ],
                rows: [
                  for (final application in applications.take(8))
                    DataRow(
                      cells: [
                        DataCell(Text(application.providerName)),
                        DataCell(Text(application.skillCategory)),
                        DataCell(Text('${application.experienceYears} yrs')),
                        DataCell(_StatusPill(label: application.status)),
                        DataCell(
                          Wrap(
                            spacing: 8,
                            children: [
                              TextButton(
                                onPressed: application.status == 'approved'
                                    ? null
                                    : () => onReviewApplication(
                                        application,
                                        'approved',
                                      ),
                                child: const Text('Approve'),
                              ),
                              TextButton(
                                onPressed: application.status == 'rejected'
                                    ? null
                                    : () => onReviewApplication(
                                        application,
                                        'rejected',
                                      ),
                                child: const Text('Reject'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
    );
  }
}

class _UserManagementTable extends StatelessWidget {
  const _UserManagementTable({
    required this.currentAdminId,
    required this.users,
    required this.onToggleUserSuspension,
  });

  final String currentAdminId;
  final List<AdminUserAccountModel> users;
  final ValueChanged<AdminUserAccountModel> onToggleUserSuspension;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'User management',
      child: users.isEmpty
          ? const _EmptyState(
              icon: Icons.group_outlined,
              title: 'No users found',
              description: 'Try clearing the search field.',
            )
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Name')),
                  DataColumn(label: Text('Email')),
                  DataColumn(label: Text('Role')),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('Action')),
                ],
                rows: [
                  for (final account in users.take(10))
                    DataRow(
                      cells: [
                        DataCell(Text(account.user.displayName)),
                        DataCell(Text(account.user.email)),
                        DataCell(Text(account.user.role.label)),
                        DataCell(_StatusPill(label: account.status)),
                        DataCell(
                          TextButton(
                            onPressed: account.user.uid == currentAdminId
                                ? null
                                : () => onToggleUserSuspension(account),
                            child: Text(
                              account.isSuspended ? 'Activate' : 'Suspend',
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
    );
  }
}

class _RevenueOverview extends StatelessWidget {
  const _RevenueOverview({required this.payments});

  final List<AdminPaymentModel> payments;

  @override
  Widget build(BuildContext context) {
    final paid = payments.where((payment) => payment.status == 'paid').toList();
    final totalCommission = paid.fold<double>(
      0,
      (sum, payment) => sum + payment.platformCommissionAmount,
    );
    final maxAmount = paid.fold<double>(
      1,
      (max, payment) => payment.platformCommissionAmount > max
          ? payment.platformCommissionAmount
          : max,
    );
    final recent = paid.take(6).toList();

    return _SectionCard(
      title: 'Revenue overview',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _formatCurrency(totalCommission),
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            'Platform commission from paid mock/test payments.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(
                context,
              ).textTheme.bodyMedium?.color?.withValues(alpha: 0.72),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 160,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (recent.isEmpty)
                  const Expanded(
                    child: Center(child: Text('Revenue chart placeholder')),
                  )
                else
                  for (final payment in recent) ...[
                    Expanded(
                      child: _RevenueBar(
                        heightFactor:
                            payment.platformCommissionAmount / maxAmount,
                        label: _formatCurrency(
                          payment.platformCommissionAmount,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RevenueBar extends StatelessWidget {
  const _RevenueBar({required this.heightFactor, required this.label});

  final double heightFactor;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final clampedHeight = heightFactor.clamp(0.08, 1.0);

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Expanded(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: FractionallySizedBox(
              heightFactor: clampedHeight,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      theme.colorScheme.primary,
                      const Color(0xFF2563EB),
                    ],
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _PolicyManagementCard extends StatelessWidget {
  const _PolicyManagementCard({
    required this.termsController,
    required this.isSavingTerms,
    required this.onSaveTerms,
  });

  final TextEditingController termsController;
  final bool isSavingTerms;
  final VoidCallback onSaveTerms;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Policy management',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: termsController,
            minLines: 6,
            maxLines: 8,
            decoration: const InputDecoration(
              labelText: 'Terms and Conditions',
              alignLabelWithHint: true,
              prefixIcon: Icon(Icons.policy_outlined),
            ),
          ),
          const SizedBox(height: AppSizes.fieldGap),
          CustomButton(
            label: 'Save Terms',
            icon: Icons.save_rounded,
            isLoading: isSavingTerms,
            onPressed: onSaveTerms,
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 18),
            child,
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final normalized = label.toLowerCase();
    final theme = Theme.of(context);
    final background = switch (normalized) {
      'approved' || 'active' || 'paid' => theme.tokens.successSoft,
      'rejected' ||
      'suspended' ||
      'failed' => theme.colorScheme.error.withValues(alpha: 0.12),
      _ => theme.tokens.warningSoft,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: AppTheme.resolveOnColor(background),
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        children: [
          Icon(
            icon,
            size: 38,
            color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.48),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            description,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.72),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _AccessDenied extends StatelessWidget {
  const _AccessDenied({required this.user});

  final UserModel user;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Super Admin')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.pagePadding),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSizes.cardPadding),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock_outline_rounded, size: 42),
                  const SizedBox(height: 12),
                  Text(
                    'Admin access only',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${user.displayName} is signed in as ${user.role.label}.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DashboardMetric {
  const _DashboardMetric({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;
}

String _formatCurrency(double value) => 'PHP ${value.toStringAsFixed(2)}';
