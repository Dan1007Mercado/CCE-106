import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_sizes.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/helpers.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/custom_textfield.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../../auth/bloc/auth_bloc.dart';
import '../../../auth/bloc/auth_event.dart';
import '../../../auth/data/models/user_model.dart';
import '../../../customer/data/models/job_post_model.dart';
import '../../../customer/data/models/service_listing_model.dart';
import '../../../customer/data/services/customer_service.dart';
import '../../data/models/provider_availability_slot_model.dart';
import '../../data/models/provider_booking_model.dart';
import '../../data/services/provider_service.dart';

class ProviderDashboardPage extends StatefulWidget {
  const ProviderDashboardPage({super.key});

  @override
  State<ProviderDashboardPage> createState() => _ProviderDashboardPageState();
}

class _ProviderDashboardPageState extends State<ProviderDashboardPage> {
  final ProviderService _providerService = ProviderService();
  final CustomerService _customerService = CustomerService();

  @override
  Widget build(BuildContext context) {
    final user = context.select((AuthBloc bloc) => bloc.state.user);

    if (user == null) {
      return const Scaffold(
        body: Center(
          child: LoadingIndicator(message: 'Loading provider dashboard...'),
        ),
      );
    }

    if (user.role != AppUserRole.service) {
      return _AccessDenied(user: user);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('HandyMarket Provider'),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            onPressed: () {
              context.read<AuthBloc>().add(const AuthSignOutRequested());
            },
            icon: const Icon(Icons.logout_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: StreamBuilder<List<ServiceListingModel>>(
        stream: _providerService.streamProviderServices(user.uid),
        builder: (context, serviceSnapshot) {
          return StreamBuilder<List<ProviderBookingModel>>(
            stream: _providerService.streamProviderBookings(user.uid),
            builder: (context, bookingSnapshot) {
              return StreamBuilder<List<ProviderPaymentModel>>(
                stream: _providerService.streamProviderPayments(user.uid),
                builder: (context, paymentSnapshot) {
                  return StreamBuilder<List<ProviderAvailabilitySlotModel>>(
                    stream: _providerService.streamAvailabilitySlots(user.uid),
                    builder: (context, availabilitySnapshot) {
                      final isLoading =
                          serviceSnapshot.connectionState ==
                              ConnectionState.waiting &&
                          !serviceSnapshot.hasData;

                      if (isLoading) {
                        return const Center(
                          child: LoadingIndicator(
                            message: 'Loading provider dashboard...',
                          ),
                        );
                      }

                      final services = serviceSnapshot.data ?? const [];
                      final bookings = bookingSnapshot.data ?? const [];
                      final payments = paymentSnapshot.data ?? const [];
                      final slots = availabilitySnapshot.data ?? const [];
                      final serviceCategories = services
                          .map((service) => service.category)
                          .toSet()
                          .toList();

                      return StreamBuilder<List<JobPostModel>>(
                        stream: _customerService.streamOpenJobsForProviders(
                          categories: serviceCategories,
                          excludeCustomerId: user.uid,
                        ),
                        builder: (context, jobSnapshot) {
                          final openJobRequests =
                              jobSnapshot.data ?? const <JobPostModel>[];

                          return _ProviderDashboardContent(
                            user: user,
                            services: services,
                            bookings: bookings,
                            payments: payments,
                            slots: slots,
                            openJobRequests: openJobRequests,
                            onAddService: () => _showAddServiceSheet(user),
                            onAddSlot: () => _showAddSlotSheet(user),
                            onAcceptBooking: (booking) =>
                                _changeBookingStatus(booking, 'accepted'),
                            onDeclineBooking: (booking) =>
                                _changeBookingStatus(booking, 'declined'),
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
      ),
    );
  }

  Future<void> _changeBookingStatus(
    ProviderBookingModel booking,
    String status,
  ) async {
    try {
      await _providerService.updateBookingStatus(
        bookingId: booking.bookingId,
        status: status,
      );

      if (!mounted) {
        return;
      }

      Helpers.showSnackBar(
        context,
        status == 'accepted' ? 'Booking accepted.' : 'Booking declined.',
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

  Future<void> _showAddServiceSheet(UserModel provider) async {
    final formKey = GlobalKey<FormState>();
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    final locationController = TextEditingController(text: provider.address);
    final priceController = TextEditingController();
    var selectedCategory = 'Plumbing';
    var isSaving = false;

    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (sheetContext) {
          return StatefulBuilder(
            builder: (sheetContext, setSheetState) {
              Future<void> saveListing() async {
                if (!formKey.currentState!.validate()) {
                  return;
                }

                final price = double.tryParse(priceController.text.trim());
                if (price == null || price <= 0) {
                  Helpers.showSnackBar(
                    sheetContext,
                    'Enter a valid service price.',
                    isError: true,
                  );
                  return;
                }

                setSheetState(() {
                  isSaving = true;
                });

                try {
                  await _providerService.addServiceListing(
                    provider: provider,
                    title: titleController.text,
                    category: selectedCategory,
                    description: descriptionController.text,
                    location: locationController.text,
                    price: price,
                  );

                  if (!mounted || !sheetContext.mounted) {
                    return;
                  }

                  Navigator.of(sheetContext).pop();
                  Helpers.showSnackBar(context, 'Service listing saved.');
                } catch (error) {
                  if (!sheetContext.mounted) {
                    return;
                  }

                  Helpers.showSnackBar(
                    sheetContext,
                    error.toString().replaceFirst('Exception: ', ''),
                    isError: true,
                  );
                } finally {
                  if (sheetContext.mounted) {
                    setSheetState(() {
                      isSaving = false;
                    });
                  }
                }
              }

              return Padding(
                padding: EdgeInsets.fromLTRB(
                  AppSizes.pagePadding,
                  AppSizes.pagePadding,
                  AppSizes.pagePadding,
                  MediaQuery.of(sheetContext).viewInsets.bottom +
                      AppSizes.pagePadding,
                ),
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Add service listing',
                          style: Theme.of(sheetContext).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: AppSizes.fieldGap),
                        CustomTextField(
                          controller: titleController,
                          label: 'Service title',
                          hintText: 'Residential plumbing repair',
                          prefixIcon: Icons.home_repair_service_outlined,
                          validator: _requiredValidator,
                        ),
                        const SizedBox(height: AppSizes.fieldGap),
                        DropdownButtonFormField<String>(
                          initialValue: selectedCategory,
                          decoration: const InputDecoration(
                            labelText: 'Category',
                            prefixIcon: Icon(Icons.category_outlined),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'Plumbing',
                              child: Text('Plumbing'),
                            ),
                            DropdownMenuItem(
                              value: 'Electrician',
                              child: Text('Electrician'),
                            ),
                            DropdownMenuItem(
                              value: 'Cleaning',
                              child: Text('Cleaning'),
                            ),
                            DropdownMenuItem(
                              value: 'Carpentry',
                              child: Text('Carpentry'),
                            ),
                            DropdownMenuItem(
                              value: 'Masonry',
                              child: Text('Masonry'),
                            ),
                          ],
                          onChanged: isSaving
                              ? null
                              : (value) {
                                  if (value == null) {
                                    return;
                                  }
                                  setSheetState(() {
                                    selectedCategory = value;
                                  });
                                },
                        ),
                        const SizedBox(height: AppSizes.fieldGap),
                        CustomTextField(
                          controller: descriptionController,
                          label: 'Description',
                          hintText: 'Describe scope, inclusions, and limits',
                          prefixIcon: Icons.notes_rounded,
                          maxLines: 4,
                          validator: _requiredValidator,
                        ),
                        const SizedBox(height: AppSizes.fieldGap),
                        CustomTextField(
                          controller: locationController,
                          label: 'Service location',
                          hintText: 'City or covered area',
                          prefixIcon: Icons.location_on_outlined,
                          validator: _requiredValidator,
                        ),
                        const SizedBox(height: AppSizes.fieldGap),
                        CustomTextField(
                          controller: priceController,
                          label: 'Fixed price',
                          hintText: '1500',
                          keyboardType: TextInputType.number,
                          prefixIcon: Icons.payments_outlined,
                          validator: _requiredValidator,
                        ),
                        const SizedBox(height: AppSizes.sectionGap),
                        CustomButton(
                          label: 'Save listing',
                          icon: Icons.save_rounded,
                          isLoading: isSaving,
                          onPressed: saveListing,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      );
    } finally {
      titleController.dispose();
      descriptionController.dispose();
      locationController.dispose();
      priceController.dispose();
    }
  }

  Future<void> _showAddSlotSheet(UserModel provider) async {
    final formKey = GlobalKey<FormState>();
    final dateController = TextEditingController();
    final slotController = TextEditingController();
    var isSaving = false;

    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (sheetContext) {
          return StatefulBuilder(
            builder: (sheetContext, setSheetState) {
              Future<void> saveSlot() async {
                if (!formKey.currentState!.validate()) {
                  return;
                }

                setSheetState(() {
                  isSaving = true;
                });

                try {
                  await _providerService.addAvailabilitySlot(
                    providerId: provider.uid,
                    dateLabel: dateController.text,
                    timeSlot: slotController.text,
                  );

                  if (!mounted || !sheetContext.mounted) {
                    return;
                  }

                  Navigator.of(sheetContext).pop();
                  Helpers.showSnackBar(context, 'Availability slot saved.');
                } catch (error) {
                  if (!sheetContext.mounted) {
                    return;
                  }

                  Helpers.showSnackBar(
                    sheetContext,
                    error.toString().replaceFirst('Exception: ', ''),
                    isError: true,
                  );
                } finally {
                  if (sheetContext.mounted) {
                    setSheetState(() {
                      isSaving = false;
                    });
                  }
                }
              }

              return Padding(
                padding: EdgeInsets.fromLTRB(
                  AppSizes.pagePadding,
                  AppSizes.pagePadding,
                  AppSizes.pagePadding,
                  MediaQuery.of(sheetContext).viewInsets.bottom +
                      AppSizes.pagePadding,
                ),
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Add availability',
                        style: Theme.of(sheetContext).textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: AppSizes.fieldGap),
                      CustomTextField(
                        controller: dateController,
                        label: 'Date label',
                        hintText: 'May 18, 2026',
                        prefixIcon: Icons.calendar_today_outlined,
                        validator: _requiredValidator,
                      ),
                      const SizedBox(height: AppSizes.fieldGap),
                      CustomTextField(
                        controller: slotController,
                        label: 'Time slot',
                        hintText: '09:00 AM - 11:00 AM',
                        prefixIcon: Icons.schedule_rounded,
                        validator: _requiredValidator,
                      ),
                      const SizedBox(height: AppSizes.sectionGap),
                      CustomButton(
                        label: 'Save slot',
                        icon: Icons.event_available_rounded,
                        isLoading: isSaving,
                        onPressed: saveSlot,
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      );
    } finally {
      dateController.dispose();
      slotController.dispose();
    }
  }

  String? _requiredValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'This field is required.';
    }

    return null;
  }
}

class _ProviderDashboardContent extends StatelessWidget {
  const _ProviderDashboardContent({
    required this.user,
    required this.services,
    required this.bookings,
    required this.payments,
    required this.slots,
    required this.openJobRequests,
    required this.onAddService,
    required this.onAddSlot,
    required this.onAcceptBooking,
    required this.onDeclineBooking,
  });

  final UserModel user;
  final List<ServiceListingModel> services;
  final List<ProviderBookingModel> bookings;
  final List<ProviderPaymentModel> payments;
  final List<ProviderAvailabilitySlotModel> slots;
  final List<JobPostModel> openJobRequests;
  final VoidCallback onAddService;
  final VoidCallback onAddSlot;
  final ValueChanged<ProviderBookingModel> onAcceptBooking;
  final ValueChanged<ProviderBookingModel> onDeclineBooking;

  @override
  Widget build(BuildContext context) {
    final pending = bookings.where((booking) => booking.isPending).toList();
    final upcoming = bookings.where((booking) => booking.isAccepted).toList();
    final completed = bookings.where((booking) => booking.isCompleted).toList();
    final paidPayments = payments.where((payment) => payment.status == 'paid');
    final earnings = paidPayments.fold<double>(
      0,
      (sum, payment) => sum + payment.providerEarning,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 900;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(AppSizes.pagePadding),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1180),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ProviderHero(
                    user: user,
                    onAddService: onAddService,
                    onAddSlot: onAddSlot,
                  ),
                  const SizedBox(height: AppSizes.sectionGap),
                  _MetricGrid(
                    isWide: isWide,
                    metrics: [
                      _DashboardMetric(
                        icon: Icons.account_balance_wallet_outlined,
                        label: 'Earnings',
                        value: _formatCurrency(earnings),
                      ),
                      _DashboardMetric(
                        icon: Icons.pending_actions_rounded,
                        label: 'Pending requests',
                        value: pending.length.toString(),
                      ),
                      _DashboardMetric(
                        icon: Icons.event_available_rounded,
                        label: 'Upcoming jobs',
                        value: upcoming.length.toString(),
                      ),
                      _DashboardMetric(
                        icon: Icons.check_circle_outline_rounded,
                        label: 'Completed jobs',
                        value: completed.length.toString(),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSizes.sectionGap),
                  if (isWide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: _BookingRequestsSection(
                            pendingBookings: pending,
                            onAcceptBooking: onAcceptBooking,
                            onDeclineBooking: onDeclineBooking,
                          ),
                        ),
                        const SizedBox(width: AppSizes.sectionGap),
                        Expanded(
                          flex: 2,
                          child: _AvailabilitySection(
                            slots: slots,
                            onAddSlot: onAddSlot,
                          ),
                        ),
                      ],
                    )
                  else ...[
                    _BookingRequestsSection(
                      pendingBookings: pending,
                      onAcceptBooking: onAcceptBooking,
                      onDeclineBooking: onDeclineBooking,
                    ),
                    const SizedBox(height: AppSizes.sectionGap),
                    _AvailabilitySection(slots: slots, onAddSlot: onAddSlot),
                  ],
                  const SizedBox(height: AppSizes.sectionGap),
                  _OpenJobRequestsSection(jobs: openJobRequests),
                  const SizedBox(height: AppSizes.sectionGap),
                  _ServiceListingsSection(
                    services: services,
                    onAddService: onAddService,
                  ),
                  const SizedBox(height: AppSizes.sectionGap),
                  _JobsSection(title: 'Upcoming jobs', bookings: upcoming),
                  const SizedBox(height: AppSizes.sectionGap),
                  _RevenueSection(payments: payments),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ProviderHero extends StatelessWidget {
  const _ProviderHero({
    required this.user,
    required this.onAddService,
    required this.onAddSlot,
  });

  final UserModel user;
  final VoidCallback onAddService;
  final VoidCallback onAddSlot;

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
      child: Wrap(
        spacing: 24,
        runSpacing: 18,
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.spaceBetween,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Provider dashboard',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Welcome back, ${user.firstName}. Manage services, booking requests, schedule, and earnings from one workspace.',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: Colors.white.withValues(alpha: 0.86),
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed: onAddService,
                icon: const Icon(Icons.add_business_rounded),
                label: const Text('Add Service'),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.65)),
                ),
                onPressed: onAddSlot,
                icon: const Icon(Icons.event_available_rounded),
                label: const Text('Add Slot'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OpenJobRequestsSection extends StatelessWidget {
  const _OpenJobRequestsSection({required this.jobs});

  final List<JobPostModel> jobs;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Open customer job requests',
      action: _CountPill(label: jobs.length.toString()),
      child: jobs.isEmpty
          ? const _EmptyState(
              icon: Icons.assignment_outlined,
              title: 'No matching customer job requests yet.',
              description:
                  'Open customer requests that match your service categories will appear here.',
            )
          : Column(
              children: [
                for (final job in jobs.take(5)) ...[
                  _OpenJobRequestTile(job: job),
                  if (job != jobs.take(5).last) const Divider(height: 24),
                ],
              ],
            ),
    );
  }
}

class _OpenJobRequestTile extends StatelessWidget {
  const _OpenJobRequestTile({required this.job});

  final JobPostModel job;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (job.photoUrl.trim().isNotEmpty) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            child: Image.network(
              job.photoUrl,
              height: 180,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return const SizedBox.shrink();
              },
            ),
          ),
          const SizedBox(height: 14),
        ],
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: theme.tokens.primarySoft,
              child: Icon(
                Icons.campaign_outlined,
                color: AppTheme.resolveOnColor(theme.tokens.primarySoft),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    job.customerName,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    job.category,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.textTheme.bodyMedium?.color?.withValues(
                        alpha: 0.72,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          job.title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          job.description,
          style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _MetaChip(icon: Icons.category_outlined, label: job.category),
            _MetaChip(
              icon: Icons.payments_outlined,
              label: 'PHP ${job.budget.toStringAsFixed(0)} budget',
            ),
            _MetaChip(
              icon: Icons.speed_rounded,
              label: 'Difficulty: ${job.difficulty}',
            ),
            _MetaChip(
              icon: Icons.location_on_outlined,
              label: job.readableLocation,
            ),
            if (job.ratingFilter != null)
              _MetaChip(
                icon: Icons.star_rounded,
                label:
                    'Prefers ${job.ratingFilter!.toStringAsFixed(job.ratingFilter! % 1 == 0 ? 0 : 1)}+ stars',
              ),
          ],
        ),
      ],
    );
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.metrics, required this.isWide});

  final List<_DashboardMetric> metrics;
  final bool isWide;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      itemCount: metrics.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isWide ? 4 : 2,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        mainAxisExtent: 128,
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

class _BookingRequestsSection extends StatelessWidget {
  const _BookingRequestsSection({
    required this.pendingBookings,
    required this.onAcceptBooking,
    required this.onDeclineBooking,
  });

  final List<ProviderBookingModel> pendingBookings;
  final ValueChanged<ProviderBookingModel> onAcceptBooking;
  final ValueChanged<ProviderBookingModel> onDeclineBooking;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Booking requests',
      action: _CountPill(label: pendingBookings.length.toString()),
      child: pendingBookings.isEmpty
          ? const _EmptyState(
              icon: Icons.inbox_outlined,
              title: 'No pending booking requests',
              description: 'New customer bookings will appear here.',
            )
          : Column(
              children: [
                for (final booking in pendingBookings.take(5)) ...[
                  _BookingRequestTile(
                    booking: booking,
                    onAccept: () => onAcceptBooking(booking),
                    onDecline: () => onDeclineBooking(booking),
                  ),
                  if (booking != pendingBookings.take(5).last)
                    const Divider(height: 24),
                ],
              ],
            ),
    );
  }
}

class _BookingRequestTile extends StatelessWidget {
  const _BookingRequestTile({
    required this.booking,
    required this.onAccept,
    required this.onDecline,
  });

  final ProviderBookingModel booking;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: theme.tokens.primarySoft,
              child: Icon(
                Icons.person_outline_rounded,
                color: AppTheme.resolveOnColor(theme.tokens.primarySoft),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    booking.customerName,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    booking.serviceTitle,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.textTheme.bodyMedium?.color?.withValues(
                        alpha: 0.72,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            _CountPill(label: booking.paymentStatus),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _MetaChip(
              icon: Icons.calendar_today_outlined,
              label: booking.selectedDate == null
                  ? 'Date not set'
                  : _formatDate(booking.selectedDate!),
            ),
            _MetaChip(
              icon: Icons.schedule_rounded,
              label: booking.selectedTimeSlot.isEmpty
                  ? 'Slot not set'
                  : booking.selectedTimeSlot,
            ),
            _MetaChip(
              icon: Icons.payments_outlined,
              label: _formatCurrency(booking.price),
            ),
          ],
        ),
        if (booking.serviceAddress.trim().isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(booking.serviceAddress, style: theme.textTheme.bodyMedium),
        ],
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            FilledButton.icon(
              onPressed: onAccept,
              icon: const Icon(Icons.check_rounded),
              label: const Text('Accept'),
            ),
            OutlinedButton.icon(
              onPressed: onDecline,
              icon: const Icon(Icons.close_rounded),
              label: const Text('Decline'),
            ),
          ],
        ),
      ],
    );
  }
}

class _ServiceListingsSection extends StatelessWidget {
  const _ServiceListingsSection({
    required this.services,
    required this.onAddService,
  });

  final List<ServiceListingModel> services;
  final VoidCallback onAddService;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Service listings',
      action: TextButton.icon(
        onPressed: onAddService,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add New Service'),
      ),
      child: services.isEmpty
          ? const _EmptyState(
              icon: Icons.home_repair_service_outlined,
              title: 'No service listings yet',
              description:
                  'Publish your first service so customers can book you.',
            )
          : Column(
              children: [
                for (final service in services.take(4)) ...[
                  _ServiceListingTile(service: service),
                  if (service != services.take(4).last)
                    const Divider(height: 24),
                ],
              ],
            ),
    );
  }
}

class _ServiceListingTile extends StatelessWidget {
  const _ServiceListingTile({required this.service});

  final ServiceListingModel service;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          backgroundColor: theme.tokens.accentSoft,
          child: Icon(
            Icons.build_rounded,
            color: AppTheme.resolveOnColor(theme.tokens.accentSoft),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                service.title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text('${service.category} | ${service.location}'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _MetaChip(
                    icon: Icons.star_rounded,
                    label: service.rating == 0
                        ? 'New'
                        : service.rating.toStringAsFixed(1),
                  ),
                  _MetaChip(
                    icon: Icons.payments_outlined,
                    label: _formatCurrency(service.price),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AvailabilitySection extends StatelessWidget {
  const _AvailabilitySection({required this.slots, required this.onAddSlot});

  final List<ProviderAvailabilitySlotModel> slots;
  final VoidCallback onAddSlot;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Schedule',
      action: IconButton(
        tooltip: 'Add availability',
        onPressed: onAddSlot,
        icon: const Icon(Icons.add_rounded),
      ),
      child: slots.isEmpty
          ? const _EmptyState(
              icon: Icons.event_busy_outlined,
              title: 'No availability saved',
              description:
                  'Add slots so customers can find your open schedule.',
            )
          : Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final slot in slots.take(8))
                  _ScheduleChip(
                    label: '${slot.dateLabel} | ${slot.timeSlot}',
                    status: slot.status,
                  ),
              ],
            ),
    );
  }
}

class _JobsSection extends StatelessWidget {
  const _JobsSection({required this.title, required this.bookings});

  final String title;
  final List<ProviderBookingModel> bookings;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: title,
      child: bookings.isEmpty
          ? const _EmptyState(
              icon: Icons.work_outline_rounded,
              title: 'No upcoming jobs',
              description: 'Accepted bookings will be tracked here.',
            )
          : Column(
              children: [
                for (final booking in bookings.take(4)) ...[
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.work_history_outlined),
                    title: Text(booking.serviceTitle),
                    subtitle: Text(
                      '${booking.customerName} | ${booking.selectedTimeSlot}',
                    ),
                    trailing: Text(_formatCurrency(booking.price)),
                  ),
                  if (booking != bookings.take(4).last)
                    const Divider(height: 10),
                ],
              ],
            ),
    );
  }
}

class _RevenueSection extends StatelessWidget {
  const _RevenueSection({required this.payments});

  final List<ProviderPaymentModel> payments;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Revenue tracking',
      child: payments.isEmpty
          ? const _EmptyState(
              icon: Icons.account_balance_wallet_outlined,
              title: 'No payment records yet',
              description: 'Customer booking payments will appear here.',
            )
          : Column(
              children: [
                for (final payment in payments.take(5)) ...[
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.receipt_long_outlined),
                    title: Text(_formatCurrency(payment.providerEarning)),
                    subtitle: Text(
                      'Commission: ${_formatCurrency(payment.platformCommissionAmount)}',
                    ),
                    trailing: _CountPill(label: payment.status),
                  ),
                  if (payment != payments.take(5).last)
                    const Divider(height: 10),
                ],
              ],
            ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child, this.action});

  final String title;
  final Widget child;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                ?action,
              ],
            ),
            const SizedBox(height: 18),
            child,
          ],
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final background = Theme.of(context).tokens.subtleSurface;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: AppTheme.resolveOnColor(background)),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: AppTheme.resolveOnColor(background),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScheduleChip extends StatelessWidget {
  const _ScheduleChip({required this.label, required this.status});

  final String label;
  final String status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: theme.tokens.primarySoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label ($status)',
        style: TextStyle(
          color: AppTheme.resolveOnColor(theme.tokens.primarySoft),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _CountPill extends StatelessWidget {
  const _CountPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Theme.of(context).tokens.subtleSurface,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: AppTheme.resolveOnColor(
            Theme.of(context).tokens.subtleSurface,
          ),
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
      appBar: AppBar(title: const Text('Provider dashboard')),
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
                    'Provider access only',
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
