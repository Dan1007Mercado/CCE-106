import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_sizes.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/helpers.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../../../core/widgets/profile_avatar.dart';
import '../../../auth/bloc/auth_bloc.dart';
import '../../../auth/bloc/auth_event.dart';
import '../../../auth/data/models/user_model.dart';
import '../../../customer/data/models/service_listing_model.dart';
import '../../../provider/data/models/provider_application_model.dart';
import '../../../provider/data/models/provider_booking_model.dart';
import '../../data/models/admin_dashboard_models.dart';
import '../../data/services/admin_service.dart';

enum _AdminSection {
  overview,
  users,
  applications,
  services,
  bookings,
  revenue,
  terms,
  notifications,
}

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

  _AdminSection _selectedSection = _AdminSection.overview;
  String _searchQuery = '';
  bool _isSavingTerms = false;
  bool _didLoadTerms = false;

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
    final admin = context.select((AuthBloc bloc) => bloc.state.user);

    if (admin == null) {
      return const Scaffold(
        body: Center(
          child: LoadingIndicator(message: 'Loading admin dashboard...'),
        ),
      );
    }

    if (admin.role != AppUserRole.admin) {
      return _AccessDenied(user: admin);
    }

    return StreamBuilder<List<AdminUserAccountModel>>(
      stream: _adminService.streamUsers(),
      builder: (context, usersSnapshot) {
        return StreamBuilder<List<ProviderApplicationModel>>(
          stream: _adminService.streamProviderApplications(),
          builder: (context, applicationsSnapshot) {
            return StreamBuilder<List<ServiceListingModel>>(
              stream: _adminService.streamServices(),
              builder: (context, servicesSnapshot) {
                return StreamBuilder<List<ProviderBookingModel>>(
                  stream: _adminService.streamBookings(),
                  builder: (context, bookingsSnapshot) {
                    return StreamBuilder<List<AdminPaymentModel>>(
                      stream: _adminService.streamPayments(),
                      builder: (context, paymentsSnapshot) {
                        return StreamBuilder<List<AppNotificationModel>>(
                          stream: _adminService.streamAdminNotifications(),
                          builder: (context, notificationsSnapshot) {
                            return StreamBuilder<AdminTermsModel?>(
                              stream: _adminService.streamTerms(),
                              builder: (context, termsSnapshot) {
                                final isLoading =
                                    usersSnapshot.connectionState ==
                                        ConnectionState.waiting &&
                                    !usersSnapshot.hasData;
                                if (isLoading) {
                                  return const Scaffold(
                                    body: Center(
                                      child: LoadingIndicator(
                                        message: 'Loading admin dashboard...',
                                      ),
                                    ),
                                  );
                                }

                                final terms = termsSnapshot.data;
                                if (!_didLoadTerms && terms != null) {
                                  _didLoadTerms = true;
                                  _termsController.text = terms.body;
                                }

                                return _AdminPanel(
                                  admin: admin,
                                  selectedSection: _selectedSection,
                                  searchController: _searchController,
                                  users: _filterUsers(
                                    usersSnapshot.data ?? const [],
                                  ),
                                  applications: _filterApplications(
                                    applicationsSnapshot.data ?? const [],
                                  ),
                                  services: _filterServices(
                                    servicesSnapshot.data ?? const [],
                                  ),
                                  bookings: _filterBookings(
                                    bookingsSnapshot.data ?? const [],
                                  ),
                                  payments: paymentsSnapshot.data ?? const [],
                                  notifications:
                                      notificationsSnapshot.data ?? const [],
                                  terms: terms,
                                  termsController: _termsController,
                                  isSavingTerms: _isSavingTerms,
                                  onSelectSection: (section) {
                                    setState(() {
                                      _selectedSection = section;
                                    });
                                  },
                                  onSignOut: () {
                                    context.read<AuthBloc>().add(
                                      const AuthSignOutRequested(),
                                    );
                                  },
                                  onToggleUserSuspension: _toggleUserSuspension,
                                  onReviewApplication: (application, status) =>
                                      _reviewApplication(
                                        admin,
                                        application,
                                        status,
                                      ),
                                  onSaveTerms: _saveTerms,
                                );
                              },
                            );
                          },
                        );
                      },
                    );
                  },
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
          '${user.displayName} ${user.email} ${user.role.label} ${account.status} ${user.providerVerificationStatus}'
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
          '${application.fullName} ${application.providerEmail} ${application.skillCategory} ${application.status}'
              .toLowerCase();
      return source.contains(_searchQuery);
    }).toList();
  }

  List<ServiceListingModel> _filterServices(
    List<ServiceListingModel> services,
  ) {
    if (_searchQuery.isEmpty) {
      return services;
    }

    return services.where((service) {
      final source =
          '${service.title} ${service.providerName} ${service.category} ${service.status}'
              .toLowerCase();
      return source.contains(_searchQuery);
    }).toList();
  }

  List<ProviderBookingModel> _filterBookings(
    List<ProviderBookingModel> bookings,
  ) {
    if (_searchQuery.isEmpty) {
      return bookings;
    }

    return bookings.where((booking) {
      final source =
          '${booking.bookingId} ${booking.customerName} ${booking.providerName} ${booking.serviceTitle} ${booking.status} ${booking.paymentStatus}'
              .toLowerCase();
      return source.contains(_searchQuery);
    }).toList();
  }

  Future<void> _toggleUserSuspension(AdminUserAccountModel account) async {
    try {
      await _adminService.setUserSuspended(
        uid: account.user.uid,
        suspended: !account.isSuspended,
        currentAdminId: context.read<AuthBloc>().state.user?.uid,
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
    UserModel admin,
    ProviderApplicationModel application,
    String status,
  ) async {
    final remarksController = TextEditingController(
      text: status == 'approved'
          ? 'Provider verification approved.'
          : application.adminRemarks,
    );
    final remarks = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            status == 'approved' ? 'Approve application' : 'Reject application',
          ),
          content: TextField(
            controller: remarksController,
            minLines: 3,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'Admin remarks',
              alignLabelWithHint: true,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(remarksController.text),
              child: Text(status == 'approved' ? 'Approve' : 'Reject'),
            ),
          ],
        );
      },
    );
    remarksController.dispose();

    if (remarks == null) {
      return;
    }

    try {
      await _adminService.reviewProviderApplication(
        applicationId: application.applicationId,
        status: status,
        reviewedBy: admin.uid,
        adminRemarks: remarks,
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

class _AdminPanel extends StatelessWidget {
  const _AdminPanel({
    required this.admin,
    required this.selectedSection,
    required this.searchController,
    required this.users,
    required this.applications,
    required this.services,
    required this.bookings,
    required this.payments,
    required this.notifications,
    required this.terms,
    required this.termsController,
    required this.isSavingTerms,
    required this.onSelectSection,
    required this.onSignOut,
    required this.onToggleUserSuspension,
    required this.onReviewApplication,
    required this.onSaveTerms,
  });

  final UserModel admin;
  final _AdminSection selectedSection;
  final TextEditingController searchController;
  final List<AdminUserAccountModel> users;
  final List<ProviderApplicationModel> applications;
  final List<ServiceListingModel> services;
  final List<ProviderBookingModel> bookings;
  final List<AdminPaymentModel> payments;
  final List<AppNotificationModel> notifications;
  final AdminTermsModel? terms;
  final TextEditingController termsController;
  final bool isSavingTerms;
  final ValueChanged<_AdminSection> onSelectSection;
  final VoidCallback onSignOut;
  final ValueChanged<AdminUserAccountModel> onToggleUserSuspension;
  final void Function(ProviderApplicationModel application, String status)
  onReviewApplication;
  final VoidCallback onSaveTerms;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surfaceContainerHighest.withValues(
        alpha: 0.35,
      ),
      body: Row(
        children: [
          _AdminSidebar(
            admin: admin,
            selectedSection: selectedSection,
            onSelectSection: onSelectSection,
            onSignOut: onSignOut,
          ),
          Expanded(
            child: Column(
              children: [
                _AdminTopBar(
                  admin: admin,
                  searchController: searchController,
                  onSignOut: onSignOut,
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(28),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1400),
                      child: _sectionWidget(context),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionWidget(BuildContext context) {
    return switch (selectedSection) {
      _AdminSection.overview => _OverviewSection(
        users: users,
        applications: applications,
        bookings: bookings,
        payments: payments,
      ),
      _AdminSection.users => _UsersSection(
        currentAdminId: admin.uid,
        users: users,
        onToggleUserSuspension: onToggleUserSuspension,
      ),
      _AdminSection.applications => _ApplicationsSection(
        applications: applications,
        onReviewApplication: onReviewApplication,
      ),
      _AdminSection.services => _ServicesSection(services: services),
      _AdminSection.bookings => _BookingsSection(bookings: bookings),
      _AdminSection.revenue => _RevenueSection(payments: payments),
      _AdminSection.terms => _TermsSection(
        terms: terms,
        termsController: termsController,
        isSavingTerms: isSavingTerms,
        onSaveTerms: onSaveTerms,
      ),
      _AdminSection.notifications => _NotificationsSection(
        notifications: notifications,
      ),
    };
  }
}

class _AdminSidebar extends StatelessWidget {
  const _AdminSidebar({
    required this.admin,
    required this.selectedSection,
    required this.onSelectSection,
    required this.onSignOut,
  });

  final UserModel admin;
  final _AdminSection selectedSection;
  final ValueChanged<_AdminSection> onSelectSection;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 276,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          right: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.72),
          ),
        ),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
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
                    'Super Admin',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30),
            for (final item in _sidebarItems)
              _SidebarButton(
                item: item,
                selected: selectedSection == item.section,
                onTap: () => onSelectSection(item.section),
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

class _AdminTopBar extends StatelessWidget {
  const _AdminTopBar({
    required this.admin,
    required this.searchController,
    required this.onSignOut,
  });

  final UserModel admin;
  final TextEditingController searchController;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 84,
      padding: const EdgeInsets.symmetric(horizontal: 28),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.72),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: searchController,
              decoration: const InputDecoration(
                hintText: 'Search users, applications, services, bookings',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
          ),
          const SizedBox(width: 18),
          ProfileAvatar(
            radius: 20,
            name: admin.displayName,
          ),
          const SizedBox(width: 10),
          Text(
            admin.displayName,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 12),
          IconButton(
            tooltip: 'Sign out',
            onPressed: onSignOut,
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
    );
  }
}

class _OverviewSection extends StatelessWidget {
  const _OverviewSection({
    required this.users,
    required this.applications,
    required this.bookings,
    required this.payments,
  });

  final List<AdminUserAccountModel> users;
  final List<ProviderApplicationModel> applications;
  final List<ProviderBookingModel> bookings;
  final List<AdminPaymentModel> payments;

  @override
  Widget build(BuildContext context) {
    final customers = users
        .where((account) => account.user.role == AppUserRole.customer)
        .length;
    final providers = users
        .where((account) => account.user.role == AppUserRole.service)
        .length;
    final pendingApplications = applications
        .where((application) => application.status == 'pending')
        .length;
    final approvedProviders = users
        .where((account) => account.user.isApprovedProvider)
        .length;
    final platformRevenue = payments
        .where((payment) => payment.status == 'paid')
        .fold<double>(
          0,
          (sum, payment) => sum + payment.platformCommissionAmount,
        );
    final pendingPayments = payments
        .where((payment) => payment.status != 'paid')
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(
          title: 'Overview',
          subtitle: 'Platform health, verification, bookings, and payments.',
        ),
        const SizedBox(height: 20),
        _MetricGrid(
          metrics: [
            _DashboardMetric(
              'Total users',
              users.length.toString(),
              Icons.group_outlined,
            ),
            _DashboardMetric(
              'Customers',
              customers.toString(),
              Icons.person_outline_rounded,
            ),
            _DashboardMetric(
              'Service providers',
              providers.toString(),
              Icons.engineering_outlined,
            ),
            _DashboardMetric(
              'Pending applications',
              pendingApplications.toString(),
              Icons.pending_actions_rounded,
            ),
            _DashboardMetric(
              'Approved providers',
              approvedProviders.toString(),
              Icons.verified_rounded,
            ),
            _DashboardMetric(
              'Total bookings',
              bookings.length.toString(),
              Icons.calendar_month_outlined,
            ),
            _DashboardMetric(
              'Platform revenue',
              _formatCurrency(platformRevenue),
              Icons.payments_outlined,
            ),
            _DashboardMetric(
              'Pending payments',
              pendingPayments.toString(),
              Icons.receipt_long_outlined,
            ),
          ],
        ),
        const SizedBox(height: 28),
        _ApplicationsSection(applications: applications.take(5).toList()),
      ],
    );
  }
}

class _UsersSection extends StatelessWidget {
  const _UsersSection({
    required this.currentAdminId,
    required this.users,
    required this.onToggleUserSuspension,
  });

  final String currentAdminId;
  final List<AdminUserAccountModel> users;
  final ValueChanged<AdminUserAccountModel> onToggleUserSuspension;

  @override
  Widget build(BuildContext context) {
    return _TableCard(
      title: 'Users',
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Name')),
          DataColumn(label: Text('Email')),
          DataColumn(label: Text('Role')),
          DataColumn(label: Text('Status')),
          DataColumn(label: Text('Provider Verification')),
          DataColumn(label: Text('Actions')),
        ],
        rows: [
          for (final account in users)
            DataRow(
              cells: [
                DataCell(Text(account.user.displayName)),
                DataCell(Text(account.user.email)),
                DataCell(Text(account.user.role.label)),
                DataCell(_StatusPill(label: account.status)),
                DataCell(
                  _StatusPill(
                    label: _formatStatus(
                      account.user.providerVerificationStatus,
                    ),
                  ),
                ),
                DataCell(
                  Wrap(
                    spacing: 8,
                    children: [
                      TextButton(
                        onPressed: () => _showUserDetails(context, account),
                        child: const Text('View details'),
                      ),
                      TextButton(
                        onPressed: account.user.uid == currentAdminId
                            ? null
                            : () => onToggleUserSuspension(account),
                        child: Text(
                          account.isSuspended ? 'Activate' : 'Suspend',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _ApplicationsSection extends StatelessWidget {
  const _ApplicationsSection({
    required this.applications,
    this.onReviewApplication,
  });

  final List<ProviderApplicationModel> applications;
  final void Function(ProviderApplicationModel application, String status)?
  onReviewApplication;

  @override
  Widget build(BuildContext context) {
    return _TableCard(
      title: 'Provider Applications',
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Provider Name')),
          DataColumn(label: Text('Age')),
          DataColumn(label: Text('Phone')),
          DataColumn(label: Text('Skill Category')),
          DataColumn(label: Text('Experience')),
          DataColumn(label: Text('Valid ID Type')),
          DataColumn(label: Text('Masked ID Number')),
          DataColumn(label: Text('Status')),
          DataColumn(label: Text('Submitted Date')),
          DataColumn(label: Text('Actions')),
        ],
        rows: [
          for (final application in applications)
            DataRow(
              cells: [
                DataCell(Text(application.fullName)),
                DataCell(Text(application.age.toString())),
                DataCell(Text(application.phoneNumber)),
                DataCell(Text(application.skillCategory)),
                DataCell(Text('${application.experienceYears} yrs')),
                DataCell(Text(application.validIdType)),
                DataCell(Text(application.maskedValidIdNumber)),
                DataCell(_StatusPill(label: application.status)),
                DataCell(Text(_formatDate(application.createdAt))),
                DataCell(
                  Wrap(
                    spacing: 8,
                    children: [
                      TextButton(
                        onPressed: () =>
                            _showApplicationDetails(context, application),
                        child: const Text('View details'),
                      ),
                      TextButton(
                        onPressed:
                            onReviewApplication == null ||
                                application.isApproved
                            ? null
                            : () =>
                                  onReviewApplication!(application, 'approved'),
                        child: const Text('Approve'),
                      ),
                      TextButton(
                        onPressed:
                            onReviewApplication == null ||
                                application.isRejected
                            ? null
                            : () =>
                                  onReviewApplication!(application, 'rejected'),
                        child: const Text('Reject'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _ServicesSection extends StatelessWidget {
  const _ServicesSection({required this.services});

  final List<ServiceListingModel> services;

  @override
  Widget build(BuildContext context) {
    return _TableCard(
      title: 'Services',
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Service title')),
          DataColumn(label: Text('Provider name')),
          DataColumn(label: Text('Category')),
          DataColumn(label: Text('Price')),
          DataColumn(label: Text('Service status')),
          DataColumn(label: Text('Provider verification')),
          DataColumn(label: Text('Actions')),
        ],
        rows: [
          for (final service in services)
            DataRow(
              cells: [
                DataCell(Text(service.title)),
                DataCell(Text(service.providerName)),
                DataCell(Text(service.category)),
                DataCell(Text(_formatCurrency(service.price))),
                DataCell(_StatusPill(label: service.status)),
                DataCell(
                  _StatusPill(
                    label: service.providerVerificationStatus.trim().isEmpty
                        ? 'unknown'
                        : service.providerVerificationStatus,
                  ),
                ),
                DataCell(
                  TextButton(
                    onPressed: () => _showServiceDetails(context, service),
                    child: const Text('View details'),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _BookingsSection extends StatelessWidget {
  const _BookingsSection({required this.bookings});

  final List<ProviderBookingModel> bookings;

  @override
  Widget build(BuildContext context) {
    return _TableCard(
      title: 'Bookings',
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Booking ID')),
          DataColumn(label: Text('Customer')),
          DataColumn(label: Text('Provider')),
          DataColumn(label: Text('Service')),
          DataColumn(label: Text('Schedule')),
          DataColumn(label: Text('Booking status')),
          DataColumn(label: Text('Payment status')),
          DataColumn(label: Text('Total amount')),
        ],
        rows: [
          for (final booking in bookings)
            DataRow(
              cells: [
                DataCell(Text(_shortId(booking.bookingId))),
                DataCell(Text(booking.customerName)),
                DataCell(Text(booking.providerName)),
                DataCell(Text(booking.serviceTitle)),
                DataCell(Text(booking.selectedTimeSlot)),
                DataCell(_StatusPill(label: booking.status)),
                DataCell(_StatusPill(label: booking.paymentStatus)),
                DataCell(Text(_formatCurrency(booking.totalAmount))),
              ],
            ),
        ],
      ),
    );
  }
}

class _RevenueSection extends StatelessWidget {
  const _RevenueSection({required this.payments});

  final List<AdminPaymentModel> payments;

  @override
  Widget build(BuildContext context) {
    final paid = payments.where((payment) => payment.status == 'paid').toList();
    final pending = payments
        .where((payment) => payment.status != 'paid')
        .length;
    final totalCommission = paid.fold<double>(
      0,
      (sum, payment) => sum + payment.platformCommissionAmount,
    );
    final providerEarnings = paid.fold<double>(
      0,
      (sum, payment) => sum + payment.providerEarning,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(
          title: 'Revenue',
          subtitle: 'Mock payment lifecycle and platform commission.',
        ),
        const SizedBox(height: 20),
        _MetricGrid(
          metrics: [
            _DashboardMetric(
              'Platform commission',
              _formatCurrency(totalCommission),
              Icons.payments_outlined,
            ),
            _DashboardMetric(
              'Provider earnings',
              _formatCurrency(providerEarnings),
              Icons.account_balance_wallet_outlined,
            ),
            _DashboardMetric(
              'Paid bookings',
              paid.length.toString(),
              Icons.check_circle_outline_rounded,
            ),
            _DashboardMetric(
              'Pending payments',
              pending.toString(),
              Icons.pending_actions_rounded,
            ),
          ],
        ),
        const SizedBox(height: 24),
        _TableCard(
          title: 'Recent payments',
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Payment ID')),
              DataColumn(label: Text('Booking ID')),
              DataColumn(label: Text('Amount')),
              DataColumn(label: Text('Commission')),
              DataColumn(label: Text('Provider earning')),
              DataColumn(label: Text('Status')),
            ],
            rows: [
              for (final payment in payments.take(20))
                DataRow(
                  cells: [
                    DataCell(Text(_shortId(payment.paymentId))),
                    DataCell(Text(_shortId(payment.bookingId))),
                    DataCell(Text(_formatCurrency(payment.amount))),
                    DataCell(
                      Text(_formatCurrency(payment.platformCommissionAmount)),
                    ),
                    DataCell(Text(_formatCurrency(payment.providerEarning))),
                    DataCell(_StatusPill(label: payment.status)),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TermsSection extends StatelessWidget {
  const _TermsSection({
    required this.terms,
    required this.termsController,
    required this.isSavingTerms,
    required this.onSaveTerms,
  });

  final AdminTermsModel? terms;
  final TextEditingController termsController;
  final bool isSavingTerms;
  final VoidCallback onSaveTerms;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(
          title: 'Terms and Conditions',
          subtitle: 'Wide editor for platform booking and usage policy.',
        ),
        const SizedBox(height: 20),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 18,
                  runSpacing: 8,
                  children: [
                    Text(
                      'Version: ${terms?.version.isEmpty ?? true ? 'Not set' : terms!.version}',
                    ),
                    Text(
                      'Updated: ${terms?.updatedAt == null ? 'Not set' : _formatDate(terms!.updatedAt!)}',
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: termsController,
                  minLines: 14,
                  maxLines: 20,
                  decoration: const InputDecoration(
                    labelText: 'Terms and Conditions',
                    alignLabelWithHint: true,
                    prefixIcon: Icon(Icons.policy_outlined),
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: 220,
                  child: CustomButton(
                    label: 'Save Terms',
                    icon: Icons.save_rounded,
                    isLoading: isSavingTerms,
                    onPressed: onSaveTerms,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _NotificationsSection extends StatelessWidget {
  const _NotificationsSection({required this.notifications});

  final List<AppNotificationModel> notifications;

  @override
  Widget build(BuildContext context) {
    return _TableCard(
      title: 'Notifications',
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Title')),
          DataColumn(label: Text('Type')),
          DataColumn(label: Text('Body')),
          DataColumn(label: Text('Related ID')),
          DataColumn(label: Text('Created')),
        ],
        rows: [
          for (final notification in notifications)
            DataRow(
              cells: [
                DataCell(Text(notification.title)),
                DataCell(Text(notification.type)),
                DataCell(Text(notification.body)),
                DataCell(Text(_shortId(notification.relatedId))),
                DataCell(Text(_formatDate(notification.createdAt))),
              ],
            ),
        ],
      ),
    );
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.metrics});

  final List<_DashboardMetric> metrics;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      itemCount: metrics.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 260,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        mainAxisExtent: 130,
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
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
                Text(
                  metric.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
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

class _TableCard extends StatelessWidget {
  const _TableCard({required this.title, required this.child});

  final String title;
  final DataTable child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 18),
            if (child.rows.isEmpty)
              const _EmptyState()
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: child,
              ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Theme.of(
              context,
            ).textTheme.bodyLarge?.color?.withValues(alpha: 0.72),
          ),
        ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final normalized = label.trim().toLowerCase();
    final theme = Theme.of(context);
    final background = switch (normalized) {
      'approved' ||
      'active' ||
      'paid' ||
      'completed' => theme.tokens.successSoft,
      'rejected' ||
      'suspended' ||
      'failed' ||
      'declined' => theme.colorScheme.error.withValues(alpha: 0.12),
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

class _SidebarButton extends StatelessWidget {
  const _SidebarButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final _SidebarItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final background = selected ? theme.tokens.primarySoft : Colors.transparent;
    final foreground = selected
        ? AppTheme.resolveOnColor(theme.tokens.primarySoft)
        : theme.textTheme.bodyMedium?.color;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Icon(item.icon, color: foreground),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    item.label,
                    style: TextStyle(
                      color: foreground,
                      fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Text(
          'No records found.',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
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
  const _DashboardMetric(this.label, this.value, this.icon);

  final String label;
  final String value;
  final IconData icon;
}

class _SidebarItem {
  const _SidebarItem(this.section, this.icon, this.label);

  final _AdminSection section;
  final IconData icon;
  final String label;
}

const _sidebarItems = [
  _SidebarItem(_AdminSection.overview, Icons.dashboard_outlined, 'Overview'),
  _SidebarItem(_AdminSection.users, Icons.group_outlined, 'Users'),
  _SidebarItem(
    _AdminSection.applications,
    Icons.verified_user_outlined,
    'Provider Applications',
  ),
  _SidebarItem(
    _AdminSection.services,
    Icons.home_repair_service_outlined,
    'Services',
  ),
  _SidebarItem(
    _AdminSection.bookings,
    Icons.calendar_month_outlined,
    'Bookings',
  ),
  _SidebarItem(_AdminSection.revenue, Icons.payments_outlined, 'Revenue'),
  _SidebarItem(
    _AdminSection.terms,
    Icons.policy_outlined,
    'Terms and Conditions',
  ),
  _SidebarItem(
    _AdminSection.notifications,
    Icons.notifications_outlined,
    'Notifications',
  ),
];

void _showUserDetails(BuildContext context, AdminUserAccountModel account) {
  final user = account.user;
  showDialog<void>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('User details'),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ProfileAvatar(
                radius: 42,
                name: user.displayName,
              ),
              const SizedBox(height: 18),
              _DetailRow('Full name', user.legalName),
              _DetailRow('Email', user.email),
              _DetailRow('Role', user.role.label),
              _DetailRow('Phone', user.phone),
              _DetailRow('Address', user.locationLabel),
              _DetailRow('Account status', account.status),
              _DetailRow(
                'Provider verification',
                _formatStatus(user.providerVerificationStatus),
              ),
              _DetailRow(
                'Created',
                user.createdAt == null
                    ? 'Not available'
                    : _formatDate(user.createdAt!),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      );
    },
  );
}

void _showApplicationDetails(
  BuildContext context,
  ProviderApplicationModel application,
) {
  showDialog<void>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Provider application'),
        content: SizedBox(
          width: 760,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _DetailRow('Full name', application.fullName),
                _DetailRow('First name', application.firstName),
                _DetailRow('Middle name', application.middleName),
                _DetailRow('Last name', application.lastName),
                _DetailRow('Suffix', application.suffix),
                _DetailRow('Age', application.age.toString()),
                _DetailRow(
                  'Birth date',
                  application.birthDate == null
                      ? ''
                      : _formatDate(application.birthDate!),
                ),
                _DetailRow('Gender', application.gender),
                _DetailRow('Phone number', application.phoneNumber),
                _DetailRow('Email', application.email),
                _DetailRow('Address', application.address),
                _DetailRow('City', application.city),
                _DetailRow('Province', application.province),
                _DetailRow('Valid ID type', application.validIdType),
                _DetailRow('Valid ID number', application.validIdNumber),
                _DetailRow('Valid ID details', application.validIdDetails),
                _DetailRow('Skill category', application.skillCategory),
                _DetailRow(
                  'Experience',
                  '${application.experienceYears} years',
                ),
                _DetailRow(
                  'Service description',
                  application.serviceDescription,
                ),
                _DetailRow(
                  'Previous work',
                  application.previousWorkDescription,
                ),
                _DetailRow(
                  'Coverage area',
                  application.serviceLocationCoverage,
                ),
                _DetailRow(
                  'Expected rate',
                  application.expectedRate == null
                      ? ''
                      : _formatCurrency(application.expectedRate!),
                ),
                _DetailRow(
                  'Consent accepted',
                  application.verificationConsentAccepted ? 'Yes' : 'No',
                ),
                _DetailRow(
                  'Consent accepted date',
                  application.verificationConsentAcceptedAt == null
                      ? 'Not recorded'
                      : _formatDate(application.verificationConsentAcceptedAt!),
                ),
                _DetailRow(
                  'Privacy notice version',
                  application.dataPrivacyNoticeVersion,
                ),
                _DetailRow('Status', application.status),
                _DetailRow('Admin remarks', application.adminRemarks),
                _DetailRow('Submitted', _formatDate(application.createdAt)),
                _DetailRow(
                  'Reviewed',
                  application.reviewedAt == null
                      ? 'Not reviewed'
                      : _formatDate(application.reviewedAt!),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      );
    },
  );
}

void _showServiceDetails(BuildContext context, ServiceListingModel service) {
  showDialog<void>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Service listing'),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _DetailRow('Service title', service.title),
              _DetailRow('Provider', service.providerName),
              _DetailRow('Provider phone', service.providerPhone),
              _DetailRow('Category', service.category),
              _DetailRow('Description', service.description),
              _DetailRow('Location', service.location),
              _DetailRow('Price', _formatCurrency(service.price)),
              _DetailRow('Rating', service.rating.toStringAsFixed(1)),
              _DetailRow('Status', service.status),
              _DetailRow(
                'Provider verification',
                service.providerVerificationStatus.trim().isEmpty
                    ? 'Unknown'
                    : _formatStatus(service.providerVerificationStatus),
              ),
              _DetailRow('Created', _formatDate(service.createdAt)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      );
    },
  );
}

class _DetailRow extends StatelessWidget {
  const _DetailRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 190,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          Expanded(child: Text(value.trim().isEmpty ? 'Not provided' : value)),
        ],
      ),
    );
  }
}

String _formatCurrency(double value) => 'PHP ${value.toStringAsFixed(2)}';

String _formatStatus(String status) {
  return switch (status.trim().toLowerCase()) {
    'pending' => 'Pending',
    'approved' => 'Approved',
    'rejected' => 'Rejected',
    'no_application' => 'No application',
    _ => status.trim().isEmpty ? 'Unknown' : status,
  };
}

String _shortId(String value) {
  if (value.length <= 8) {
    return value;
  }

  return value.substring(0, 8);
}

String _formatDate(DateTime value) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[value.month - 1]} ${value.day}, ${value.year}';
}
