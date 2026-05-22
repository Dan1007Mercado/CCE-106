import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/helpers.dart';
import '../../../../core/widgets/brand_logo.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/custom_textfield.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../../../core/widgets/profile_avatar.dart';
import '../../../../routes/app_router.dart';
import '../../../auth/bloc/auth_bloc.dart';
import '../../../auth/bloc/auth_event.dart';
import '../../../auth/data/models/user_model.dart';
import '../../../chat/data/services/chat_service.dart';
import '../../../chat/ui/pages/chat_page.dart';
import '../../../customer/data/models/job_post_model.dart';
import '../../../customer/data/models/service_listing_model.dart';
import '../../../customer/data/services/customer_service.dart';
import '../widgets/provider_application_form.dart';
import '../widgets/provider_application_status_sheet.dart';
import '../widgets/provider_verification_banner.dart';
import '../../data/models/provider_application_model.dart';
import '../../data/models/provider_availability_slot_model.dart';
import '../../data/models/provider_booking_model.dart';
import '../../data/services/provider_application_service.dart';
import '../../data/services/provider_service.dart';

class ProviderDashboardPage extends StatefulWidget {
  const ProviderDashboardPage({super.key});

  @override
  State<ProviderDashboardPage> createState() => _ProviderDashboardPageState();
}

class _ProviderDashboardPageState extends State<ProviderDashboardPage>
    with SingleTickerProviderStateMixin {
  static const List<String> _serviceCategories = [
    'Plumbing',
    'Electrician',
    'Cleaning',
    'Carpentry',
    'Masonry',
  ];

  final ProviderService _providerService = ProviderService();
  final CustomerService _customerService = CustomerService();
  final ChatService _chatService = ChatService();
  final ProviderApplicationService _applicationService =
      ProviderApplicationService();
  late final TabController _tabController;
  Timer? _statusPanelTimer;
  bool _showStatusPanels = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _statusPanelTimer = Timer(const Duration(seconds: 5), () {
      if (!mounted) {
        return;
      }

      setState(() {
        _showStatusPanels = false;
      });
    });
  }

  @override
  void dispose() {
    _statusPanelTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

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

    final theme = Theme.of(context);
    final tokens = theme.tokens;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        titleSpacing: AppSizes.pagePadding,
        toolbarHeight: 72,
        title: const Row(
          children: [
            BrandLogo(size: 36, borderRadius: 10),
            SizedBox(width: 12),
            Flexible(
              child: Text(
                AppStrings.appName,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        actions: [
          _ProviderActionIcon(
            icon: Icons.notifications_none_rounded,
            tooltip: 'Notifications',
            onTap: () => _showComingSoon('Notifications'),
          ),
          Padding(
            padding: const EdgeInsets.only(right: AppSizes.pagePadding),
            child: InkWell(
              onTap: () {
                Navigator.of(context).pushNamed(AppRouter.providerProfileRoute);
              },
              borderRadius: BorderRadius.circular(24),
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: tokens.subtleSurface,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: theme.colorScheme.outlineVariant.withValues(
                      alpha: 0.55,
                    ),
                  ),
                ),
                child: ProfileAvatar(radius: 18, name: user.displayName),
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(68),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSizes.pagePadding,
              0,
              AppSizes.pagePadding,
              12,
            ),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: tokens.primarySoft,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: theme.colorScheme.primary.withValues(alpha: 0.10),
                ),
              ),
              child: TabBar(
                controller: _tabController,
                isScrollable: true,
                dividerColor: Colors.transparent,
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(999),
                ),
                labelColor: theme.colorScheme.onPrimary,
                unselectedLabelColor: AppTheme.resolveOnColor(
                  tokens.primarySoft,
                ).withValues(alpha: 0.72),
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
                splashBorderRadius: BorderRadius.circular(999),
                tabs: const [
                  Tab(height: 42, text: 'Overview'),
                  Tab(height: 42, text: 'Services'),
                  Tab(height: 42, text: 'Bookings'),
                  Tab(height: 42, text: 'Schedule'),
                  Tab(height: 42, text: 'Revenue'),
                  Tab(height: 42, text: 'Jobs'),
                ],
              ),
            ),
          ),
        ),
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

                      return StreamBuilder<ProviderApplicationModel?>(
                        stream: _applicationService.streamLatestForProvider(
                          user.uid,
                        ),
                        builder: (context, applicationSnapshot) {
                          final application = applicationSnapshot.data;
                          return StreamBuilder<List<JobPostModel>>(
                            stream: _customerService.streamOpenJobsForProviders(
                              categories: serviceCategories,
                              excludeCustomerId: user.uid,
                            ),
                            builder: (context, jobSnapshot) {
                              final openJobRequests =
                                  jobSnapshot.data ?? const <JobPostModel>[];

                              return _ProviderDashboardContent(
                                tabController: _tabController,
                                showStatusPanels: _showStatusPanels,
                                user: user,
                                application: application,
                                services: services,
                                bookings: bookings,
                                payments: payments,
                                slots: slots,
                                openJobRequests: openJobRequests,
                                onAddService: () => _showAddServiceSheet(user),
                                onAddSlot: () => _showAddSlotSheet(user),
                                onOpenApplication: () =>
                                    _showProviderApplicationSheet(
                                      user,
                                      application,
                                    ),
                                onEditService: (service) =>
                                    _showEditServiceSheet(user, service),
                                onDeleteService: (service) =>
                                    _confirmDeleteService(user, service),
                                onToggleServiceStatus: (service) =>
                                    _toggleServiceStatus(user, service),
                                onAcceptBooking: (booking) =>
                                    _changeBookingStatus(booking, 'accepted'),
                                onDeclineBooking: (booking) =>
                                    _changeBookingStatus(booking, 'declined'),
                                onMarkBookingDone: (booking) =>
                                    _markBookingAsDone(user, booking),
                                onOpenChat: _openBookingChat,
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
      ),
    );
  }

  void _showComingSoon(String label) {
    Helpers.showSnackBar(context, '$label coming soon');
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

  Future<void> _markBookingAsDone(
    UserModel provider,
    ProviderBookingModel booking,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Mark this service as done?'),
          content: const Text(
            'This will complete the booking and release the pending payment.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Mark done'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      await _providerService.markBookingAsDone(
        bookingId: booking.bookingId,
        providerId: provider.uid,
      );

      if (!mounted) {
        return;
      }

      Helpers.showSnackBar(context, 'Booking completed. Payment released.');
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

  Future<void> _openBookingChat(ProviderBookingModel booking) async {
    final currentUserId = context.read<AuthBloc>().state.user?.uid ?? '';

    try {
      await _chatService.ensureBookingChat(
        bookingId: booking.bookingId,
        customerId: booking.customerId,
        providerId: booking.providerId,
        customerName: booking.customerName,
        providerName: booking.providerName,
        currentUserId: currentUserId,
      );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pushNamed(
        AppRouter.chatRoute,
        arguments: ChatPageArgs(
          bookingId: booking.bookingId,
          customerId: booking.customerId,
          providerId: booking.providerId,
          customerName: booking.customerName,
          providerName: booking.providerName,
        ),
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
    var selectedCategory = _serviceCategories.first;
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

                var shouldResetSaving = true;
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

                  shouldResetSaving = false;
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
                  if (shouldResetSaving && sheetContext.mounted) {
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
                          items: _serviceCategories
                              .map(
                                (category) => DropdownMenuItem(
                                  value: category,
                                  child: Text(category),
                                ),
                              )
                              .toList(),
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

  Future<void> _showEditServiceSheet(
    UserModel provider,
    ServiceListingModel service,
  ) async {
    final formKey = GlobalKey<FormState>();
    final titleController = TextEditingController(text: service.title);
    final descriptionController = TextEditingController(
      text: service.description,
    );
    final locationController = TextEditingController(text: service.location);
    final priceController = TextEditingController(
      text: service.price.toStringAsFixed(0),
    );
    var selectedCategory = _serviceCategories.contains(service.category)
        ? service.category
        : _serviceCategories.first;
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

                var shouldResetSaving = true;
                try {
                  await _providerService.updateServiceListing(
                    serviceId: service.serviceId,
                    providerId: provider.uid,
                    title: titleController.text,
                    category: selectedCategory,
                    description: descriptionController.text,
                    location: locationController.text,
                    price: price,
                  );

                  if (!mounted || !sheetContext.mounted) {
                    return;
                  }

                  shouldResetSaving = false;
                  Navigator.of(sheetContext).pop();
                  Helpers.showSnackBar(context, 'Service listing updated.');
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
                  if (shouldResetSaving && sheetContext.mounted) {
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
                          'Edit service listing',
                          style: Theme.of(sheetContext).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: AppSizes.fieldGap),
                        CustomTextField(
                          controller: titleController,
                          label: 'Service title',
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
                          items: _serviceCategories
                              .map(
                                (category) => DropdownMenuItem(
                                  value: category,
                                  child: Text(category),
                                ),
                              )
                              .toList(),
                          onChanged: isSaving
                              ? null
                              : (value) {
                                  if (value != null) {
                                    setSheetState(() {
                                      selectedCategory = value;
                                    });
                                  }
                                },
                        ),
                        const SizedBox(height: AppSizes.fieldGap),
                        CustomTextField(
                          controller: descriptionController,
                          label: 'Description',
                          prefixIcon: Icons.notes_rounded,
                          maxLines: 4,
                          validator: _requiredValidator,
                        ),
                        const SizedBox(height: AppSizes.fieldGap),
                        CustomTextField(
                          controller: locationController,
                          label: 'Service location',
                          prefixIcon: Icons.location_on_outlined,
                          validator: _requiredValidator,
                        ),
                        const SizedBox(height: AppSizes.fieldGap),
                        CustomTextField(
                          controller: priceController,
                          label: 'Fixed price',
                          keyboardType: TextInputType.number,
                          prefixIcon: Icons.payments_outlined,
                          validator: _requiredValidator,
                        ),
                        const SizedBox(height: AppSizes.sectionGap),
                        CustomButton(
                          label: 'Save changes',
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

  Future<void> _confirmDeleteService(
    UserModel provider,
    ServiceListingModel service,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete service listing?'),
          content: Text('This will remove "${service.title}" from services.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      await _providerService.deleteServiceListing(
        serviceId: service.serviceId,
        providerId: provider.uid,
      );
      if (mounted) {
        Helpers.showSnackBar(context, 'Service listing deleted.');
      }
    } catch (error) {
      if (mounted) {
        Helpers.showSnackBar(
          context,
          error.toString().replaceFirst('Exception: ', ''),
          isError: true,
        );
      }
    }
  }

  Future<void> _toggleServiceStatus(
    UserModel provider,
    ServiceListingModel service,
  ) async {
    try {
      await _providerService.setServiceActive(
        serviceId: service.serviceId,
        providerId: provider.uid,
        isActive: service.status.trim().toLowerCase() != 'active',
      );
      if (mounted) {
        Helpers.showSnackBar(context, 'Service status updated.');
      }
    } catch (error) {
      if (mounted) {
        Helpers.showSnackBar(
          context,
          error.toString().replaceFirst('Exception: ', ''),
          isError: true,
        );
      }
    }
  }

  Future<void> _showProviderApplicationSheet(
    UserModel provider,
    ProviderApplicationModel? application,
  ) async {
    final status = application?.status.trim().toLowerCase();
    if (application != null && status != 'rejected') {
      await _showProviderApplicationStatusSheet(provider, application);
      return;
    }

    await _showProviderApplicationForm(provider, application);
  }

  Future<void> _showProviderApplicationStatusSheet(
    UserModel provider,
    ProviderApplicationModel application,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return ProviderApplicationStatusSheet(
          application: application,
          onResubmit: application.isRejected
              ? () {
                  Navigator.of(sheetContext).pop();
                  Future<void>.microtask(() {
                    if (mounted) {
                      _showProviderApplicationForm(provider, application);
                    }
                  });
                }
              : null,
        );
      },
    );
  }

  Future<void> _showProviderApplicationForm(
    UserModel provider,
    ProviderApplicationModel? application,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return ProviderApplicationForm(
          provider: provider,
          application: application,
          onSubmitted: () {
            context.read<AuthBloc>().add(
              AuthUserProfileUpdated(
                provider.copyWith(
                  providerVerificationStatus: 'pending',
                  verifiedProvider: false,
                ),
              ),
            );
            Navigator.of(sheetContext).pop();
          },
        );
      },
    );
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

                var shouldResetSaving = true;
                try {
                  await _providerService.addAvailabilitySlot(
                    providerId: provider.uid,
                    dateLabel: dateController.text,
                    timeSlot: slotController.text,
                  );

                  if (!mounted || !sheetContext.mounted) {
                    return;
                  }

                  shouldResetSaving = false;
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
                  if (shouldResetSaving && sheetContext.mounted) {
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
    required this.tabController,
    required this.showStatusPanels,
    required this.user,
    required this.application,
    required this.services,
    required this.bookings,
    required this.payments,
    required this.slots,
    required this.openJobRequests,
    required this.onAddService,
    required this.onAddSlot,
    required this.onOpenApplication,
    required this.onEditService,
    required this.onDeleteService,
    required this.onToggleServiceStatus,
    required this.onAcceptBooking,
    required this.onDeclineBooking,
    required this.onMarkBookingDone,
    required this.onOpenChat,
  });

  final TabController tabController;
  final bool showStatusPanels;
  final UserModel user;
  final ProviderApplicationModel? application;
  final List<ServiceListingModel> services;
  final List<ProviderBookingModel> bookings;
  final List<ProviderPaymentModel> payments;
  final List<ProviderAvailabilitySlotModel> slots;
  final List<JobPostModel> openJobRequests;
  final VoidCallback onAddService;
  final VoidCallback onAddSlot;
  final VoidCallback onOpenApplication;
  final ValueChanged<ServiceListingModel> onEditService;
  final ValueChanged<ServiceListingModel> onDeleteService;
  final ValueChanged<ServiceListingModel> onToggleServiceStatus;
  final ValueChanged<ProviderBookingModel> onAcceptBooking;
  final ValueChanged<ProviderBookingModel> onDeclineBooking;
  final ValueChanged<ProviderBookingModel> onMarkBookingDone;
  final ValueChanged<ProviderBookingModel> onOpenChat;

  @override
  Widget build(BuildContext context) {
    final pending = bookings.where((booking) => booking.isPending).toList();
    final upcoming = bookings.where((booking) => booking.isAccepted).toList();
    final completed = bookings.where((booking) => booking.isCompleted).toList();
    final declinedOrCancelled = bookings
        .where(
          (booking) =>
              booking.status == 'declined' ||
              booking.status == 'cancelled_by_customer',
        )
        .toList();
    final isApproved =
        user.isApprovedProvider || application?.isApproved == true;
    final paidPayments = payments.where((payment) => payment.status == 'paid');
    final earnings = paidPayments.fold<double>(
      0,
      (sum, payment) => sum + payment.providerEarning,
    );

    return Stack(
      children: [
        TabBarView(
          controller: tabController,
          children: [
            _ProviderTabPage(
              children: [
                AnimatedSwitcher(
                  duration: AppTheme.motionDuration,
                  reverseDuration: AppTheme.motionReverseDuration,
                  switchInCurve: AppTheme.motionCurve,
                  switchOutCurve: AppTheme.motionCurve,
                  transitionBuilder: (child, animation) {
                    return SizeTransition(
                      sizeFactor: animation,
                      axisAlignment: -1,
                      child: FadeTransition(opacity: animation, child: child),
                    );
                  },
                  child: showStatusPanels
                      ? Column(
                          key: const ValueKey('provider-status-panels'),
                          children: [
                            _ProviderWelcomePanel(
                              user: user,
                              application: application,
                              serviceCount: services.length,
                              pendingBookingCount: pending.length,
                            ),
                            const SizedBox(height: AppSizes.sectionGap),
                            ProviderVerificationBanner(
                              user: user,
                              application: application,
                              onApply: onOpenApplication,
                            ),
                            const SizedBox(height: AppSizes.sectionGap),
                          ],
                        )
                      : const SizedBox.shrink(
                          key: ValueKey('provider-status-panels-hidden'),
                        ),
                ),
                _ProviderMetricGrid(
                  metrics: [
                    _DashboardMetric(
                      icon: Icons.home_repair_service_outlined,
                      label: 'Services listed',
                      value: services.length.toString(),
                    ),
                    _DashboardMetric(
                      icon: Icons.pending_actions_rounded,
                      label: 'Pending bookings',
                      value: pending.length.toString(),
                    ),
                    _DashboardMetric(
                      icon: Icons.check_circle_outline_rounded,
                      label: 'Completed',
                      value: completed.length.toString(),
                    ),
                    _DashboardMetric(
                      icon: Icons.account_balance_wallet_outlined,
                      label: 'Earnings',
                      value: _formatCurrency(earnings),
                    ),
                  ],
                ),
                const SizedBox(height: AppSizes.sectionGap),
                _ProviderQuickActions(
                  isApproved: isApproved,
                  onAddService: onAddService,
                  onAddSlot: onAddSlot,
                  onOpenApplication: onOpenApplication,
                ),
                const SizedBox(height: AppSizes.sectionGap),
                _ProviderSectionHeader(
                  title: 'Recent booking requests',
                  description: 'Review new customer bookings as they arrive.',
                  trailing: _ProviderStatusPill(label: pending.length.toString()),
                ),
                const SizedBox(height: 12),
                if (pending.isEmpty)
                  const _ProviderEmptyCard(
                    icon: Icons.inbox_outlined,
                    title: 'No pending booking requests',
                    description: 'New customer bookings will appear here.',
                  )
                else
                  for (final booking in pending.take(3)) ...[
                    _ProviderBookingCard(
                      booking: booking,
                      currentUserId: user.uid,
                      canAccept: isApproved,
                      onAccept: () => onAcceptBooking(booking),
                      onDecline: () => onDeclineBooking(booking),
                      onMarkDone: () => onMarkBookingDone(booking),
                      onOpenChat: () => onOpenChat(booking),
                    ),
                    const SizedBox(height: 12),
                  ],
              ],
            ),
            _ProviderTabPage(
              children: [
                _ProviderSectionHeader(
                  title: 'My services',
                  description: 'Manage the services customers can book.',
                ),
                const SizedBox(height: 12),
                if (services.isEmpty)
                  const _ProviderEmptyCard(
                    icon: Icons.home_repair_service_outlined,
                    title: 'No service listings yet',
                    description:
                        'Publish your first service after verification approval.',
                  )
                else
                  for (final service in services) ...[
                    _ProviderServiceCard(
                      service: service,
                      canEditService: isApproved,
                      onEdit: () => onEditService(service),
                      onDelete: () => onDeleteService(service),
                      onToggleStatus: () => onToggleServiceStatus(service),
                    ),
                    const SizedBox(height: 12),
                  ],
              ],
            ),
            _ProviderBookingsTab(
              bookings: bookings,
              pending: pending,
              accepted: upcoming,
              completed: completed,
              closed: declinedOrCancelled,
              currentUserId: user.uid,
              canAccept: isApproved,
              onAcceptBooking: onAcceptBooking,
              onDeclineBooking: onDeclineBooking,
              onMarkBookingDone: onMarkBookingDone,
              onOpenChat: onOpenChat,
            ),
            _ProviderTabPage(
              children: [
                _ProviderSectionHeader(
                  title: 'Availability',
                  description: 'Keep your open schedule clear for customers.',
                  trailing: TextButton.icon(
                    onPressed: onAddSlot,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Add slot'),
                  ),
                ),
                const SizedBox(height: 12),
                if (slots.isEmpty)
                  const _ProviderEmptyCard(
                    icon: Icons.event_busy_outlined,
                    title: 'No availability saved',
                    description:
                        'Add slots so customers can find your open schedule.',
                  )
                else
                  for (final slot in slots) ...[
                    _ProviderScheduleCard(slot: slot),
                    const SizedBox(height: 12),
                  ],
              ],
            ),
            _ProviderTabPage(
              children: [
                _ProviderSectionHeader(
                  title: 'Revenue',
                  description: 'Monitor earnings and platform commissions.',
                ),
                const SizedBox(height: 12),
                _ProviderRevenueSummary(
                  earnings: earnings,
                  payments: payments,
                ),
                const SizedBox(height: AppSizes.sectionGap),
                _ProviderSectionHeader(
                  title: 'Recent payments',
                  description: 'Latest customer payment records.',
                  trailing: _ProviderStatusPill(label: payments.length.toString()),
                ),
                const SizedBox(height: 12),
                if (payments.isEmpty)
                  const _ProviderEmptyCard(
                    icon: Icons.account_balance_wallet_outlined,
                    title: 'No payment records yet',
                    description: 'Customer booking payments will appear here.',
                  )
                else
                  for (final payment in payments) ...[
                    _ProviderPaymentCard(payment: payment),
                    const SizedBox(height: 12),
                  ],
              ],
            ),
            _ProviderTabPage(
              children: [
                _ProviderSectionHeader(
                  title: 'Open customer job requests',
                  description:
                      'Browse public requests that match your service categories.',
                  trailing:
                      _ProviderStatusPill(label: openJobRequests.length.toString()),
                ),
                const SizedBox(height: 12),
                if (openJobRequests.isEmpty)
                  const _ProviderEmptyCard(
                    icon: Icons.assignment_outlined,
                    title: 'No matching job requests yet',
                    description:
                        'Open customer requests that match your services will appear here.',
                  )
                else
                  for (final job in openJobRequests) ...[
                    _ProviderJobRequestCard(job: job),
                    const SizedBox(height: 12),
                  ],
              ],
            ),
          ],
        ),
        Positioned(
          right: AppSizes.pagePadding,
          bottom: AppSizes.pagePadding,
          child: FloatingActionButton.extended(
            onPressed: isApproved ? onAddService : onOpenApplication,
            icon: Icon(
              isApproved
                  ? Icons.add_business_rounded
                  : Icons.assignment_ind_outlined,
            ),
            label: Text(isApproved ? 'List Service' : 'Apply'),
          ),
        ),
      ],
    );
  }
}

class _ProviderActionIcon extends StatelessWidget {
  const _ProviderActionIcon({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.tokens.subtleSurface,
          shape: BoxShape.circle,
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.55),
          ),
        ),
        child: IconButton(
          onPressed: onTap,
          tooltip: tooltip,
          icon: Icon(icon),
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}

class _ProviderTabPage extends StatelessWidget {
  const _ProviderTabPage({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.pagePadding,
        AppSizes.pagePadding,
        AppSizes.pagePadding,
        96,
      ),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 920),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ),
      ],
    );
  }
}

class _ProviderWelcomePanel extends StatelessWidget {
  const _ProviderWelcomePanel({
    required this.user,
    required this.application,
    required this.serviceCount,
    required this.pendingBookingCount,
  });

  final UserModel user;
  final ProviderApplicationModel? application;
  final int serviceCount;
  final int pendingBookingCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = application?.status ?? user.providerVerificationStatus;
    final normalizedStatus = status.trim().toLowerCase();
    final isVerified = user.isApprovedProvider || normalizedStatus == 'approved';

    final verificationLabel = switch (normalizedStatus) {
      'approved' => 'Verified Provider',
      'pending' => 'Pending Approval',
      'rejected' => 'Application Rejected',
      _ => isVerified ? 'Verified Provider' : 'Apply for Verification',
    };

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
            'Welcome back, ${user.firstName}',
            style: theme.textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Manage services, booking requests, schedule, and earnings from one provider workspace.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: Colors.white.withValues(alpha: 0.86),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _ProviderStatusBadge(
                label: verificationLabel,
                isActive: isVerified,
              ),
              _ProviderStatusBadge(
                label: user.hasContactNumber
                    ? 'Contact ready'
                    : 'Add phone number',
                isActive: user.hasContactNumber,
              ),
              _ProviderStatusBadge(
                label: user.hasBookingLocation
                    ? 'Location ready'
                    : 'Add location',
                isActive: user.hasBookingLocation,
              ),
              _ProviderStatusBadge(
                label: '$serviceCount services',
                isActive: serviceCount > 0,
              ),
              _ProviderStatusBadge(
                label: '$pendingBookingCount pending',
                isActive: pendingBookingCount == 0,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProviderStatusBadge extends StatelessWidget {
  const _ProviderStatusBadge({required this.label, required this.isActive});

  final String label;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final background = isActive
        ? Theme.of(context).tokens.successSoft
        : Theme.of(context).tokens.warningSoft;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: AppTheme.resolveOnColor(background),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ProviderSectionHeader extends StatelessWidget {
  const _ProviderSectionHeader({
    required this.title,
    required this.description,
    this.trailing,
  });

  final String title;
  final String description;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.textTheme.bodyMedium?.color?.withValues(
                    alpha: 0.68,
                  ),
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 12),
          trailing!,
        ],
      ],
    );
  }
}

class _ProviderMetricGrid extends StatelessWidget {
  const _ProviderMetricGrid({required this.metrics});

  final List<_DashboardMetric> metrics;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth >= 760 ? 4 : 2;
        final cardHeight = crossAxisCount == 2 ? 148.0 : 132.0;

        return GridView.builder(
          itemCount: metrics.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            mainAxisExtent: cardHeight,
          ),
          itemBuilder: (context, index) {
            final metric = metrics[index];
            return _ProviderDashboardCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ProviderIconCircle(icon: metric.icon),
                  const Spacer(),
                  Text(
                    metric.value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    metric.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).textTheme.bodyMedium?.color
                          ?.withValues(alpha: 0.68),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _ProviderQuickActions extends StatelessWidget {
  const _ProviderQuickActions({
    required this.isApproved,
    required this.onAddService,
    required this.onAddSlot,
    required this.onOpenApplication,
  });

  final bool isApproved;
  final VoidCallback onAddService;
  final VoidCallback onAddSlot;
  final VoidCallback onOpenApplication;

  @override
  Widget build(BuildContext context) {
    return _ProviderDashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ProviderSectionHeader(
            title: 'Quick actions',
            description: 'Common provider tasks are available here.',
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed: isApproved ? onAddService : null,
                icon: const Icon(Icons.add_business_rounded),
                label: const Text('Add Service'),
              ),
              OutlinedButton.icon(
                onPressed: onAddSlot,
                icon: const Icon(Icons.event_available_rounded),
                label: const Text('Add Schedule'),
              ),
              TextButton.icon(
                onPressed: onOpenApplication,
                icon: const Icon(Icons.assignment_ind_outlined),
                label: const Text('Verification'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProviderDashboardCard extends StatelessWidget {
  const _ProviderDashboardCard({
    required this.child,
    this.padding = const EdgeInsets.all(AppSizes.cardPadding),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.60),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _ProviderIconCircle extends StatelessWidget {
  const _ProviderIconCircle({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final background = theme.tokens.accentSoft;

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(color: background, shape: BoxShape.circle),
      child: Icon(icon, color: AppTheme.resolveOnColor(background)),
    );
  }
}

class _ProviderStatusPill extends StatelessWidget {
  const _ProviderStatusPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final normalized = label.trim().toLowerCase();
    final background = switch (normalized) {
      'active' ||
      'accepted' ||
      'approved' ||
      'paid' ||
      'available' => theme.tokens.successSoft,
      'pending' || 'inactive' => theme.tokens.warningSoft,
      'declined' || 'rejected' || 'cancelled_by_customer' => theme
          .colorScheme
          .errorContainer,
      _ => theme.tokens.subtleSurface,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _titleizeStatus(label),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: AppTheme.resolveOnColor(background),
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _ProviderMetaPill extends StatelessWidget {
  const _ProviderMetaPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final background = Theme.of(context).tokens.subtleSurface;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final double maxLabelWidth;
    if (screenWidth < 360) {
      maxLabelWidth = 108;
    } else if (screenWidth < 480) {
      maxLabelWidth = 156;
    } else {
      maxLabelWidth = 240;
    }

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
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxLabelWidth),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppTheme.resolveOnColor(background),
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProviderEmptyCard extends StatelessWidget {
  const _ProviderEmptyCard({
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

    return _ProviderDashboardCard(
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

enum _ProviderBookingFilter { all, pending, accepted, completed, closed }

class _ProviderBookingsTab extends StatefulWidget {
  const _ProviderBookingsTab({
    required this.bookings,
    required this.pending,
    required this.accepted,
    required this.completed,
    required this.closed,
    required this.currentUserId,
    required this.canAccept,
    required this.onAcceptBooking,
    required this.onDeclineBooking,
    required this.onMarkBookingDone,
    required this.onOpenChat,
  });

  final List<ProviderBookingModel> bookings;
  final List<ProviderBookingModel> pending;
  final List<ProviderBookingModel> accepted;
  final List<ProviderBookingModel> completed;
  final List<ProviderBookingModel> closed;
  final String currentUserId;
  final bool canAccept;
  final ValueChanged<ProviderBookingModel> onAcceptBooking;
  final ValueChanged<ProviderBookingModel> onDeclineBooking;
  final ValueChanged<ProviderBookingModel> onMarkBookingDone;
  final ValueChanged<ProviderBookingModel> onOpenChat;

  @override
  State<_ProviderBookingsTab> createState() => _ProviderBookingsTabState();
}

class _ProviderBookingsTabState extends State<_ProviderBookingsTab> {
  _ProviderBookingFilter _filter = _ProviderBookingFilter.all;

  @override
  Widget build(BuildContext context) {
    final visibleBookings = switch (_filter) {
      _ProviderBookingFilter.all => widget.bookings,
      _ProviderBookingFilter.pending => widget.pending,
      _ProviderBookingFilter.accepted => widget.accepted,
      _ProviderBookingFilter.completed => widget.completed,
      _ProviderBookingFilter.closed => widget.closed,
    };

    return _ProviderTabPage(
      children: [
        _ProviderSectionHeader(
          title: 'Booking requests',
          description: 'Track pending, active, and finished bookings.',
          trailing: _ProviderStatusPill(label: widget.bookings.length.toString()),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _BookingFilterChip(
                label: 'All ${widget.bookings.length}',
                selected: _filter == _ProviderBookingFilter.all,
                onSelected: () {
                  setState(() => _filter = _ProviderBookingFilter.all);
                },
              ),
              _BookingFilterChip(
                label: 'Pending ${widget.pending.length}',
                selected: _filter == _ProviderBookingFilter.pending,
                onSelected: () {
                  setState(() => _filter = _ProviderBookingFilter.pending);
                },
              ),
              _BookingFilterChip(
                label: 'Accepted ${widget.accepted.length}',
                selected: _filter == _ProviderBookingFilter.accepted,
                onSelected: () {
                  setState(() => _filter = _ProviderBookingFilter.accepted);
                },
              ),
              _BookingFilterChip(
                label: 'Completed ${widget.completed.length}',
                selected: _filter == _ProviderBookingFilter.completed,
                onSelected: () {
                  setState(() => _filter = _ProviderBookingFilter.completed);
                },
              ),
              _BookingFilterChip(
                label: 'Closed ${widget.closed.length}',
                selected: _filter == _ProviderBookingFilter.closed,
                onSelected: () {
                  setState(() => _filter = _ProviderBookingFilter.closed);
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (visibleBookings.isEmpty)
          const _ProviderEmptyCard(
            icon: Icons.work_outline_rounded,
            title: 'No bookings in this view',
            description: 'Customer bookings will appear here.',
          )
        else
          for (final booking in visibleBookings) ...[
            _ProviderBookingCard(
              booking: booking,
              currentUserId: widget.currentUserId,
              canAccept: widget.canAccept,
              onAccept: () => widget.onAcceptBooking(booking),
              onDecline: () => widget.onDeclineBooking(booking),
              onMarkDone: () => widget.onMarkBookingDone(booking),
              onOpenChat: () => widget.onOpenChat(booking),
            ),
            const SizedBox(height: 12),
          ],
      ],
    );
  }
}

class _BookingFilterChip extends StatelessWidget {
  const _BookingFilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onSelected(),
      ),
    );
  }
}

class _ProviderServiceCard extends StatelessWidget {
  const _ProviderServiceCard({
    required this.service,
    required this.canEditService,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleStatus,
  });

  final ServiceListingModel service;
  final bool canEditService;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggleStatus;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isActive = service.status.trim().toLowerCase() == 'active';

    return _ProviderDashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _ProviderIconCircle(icon: Icons.build_rounded),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      service.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${service.category} | ${service.location}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.textTheme.bodyMedium?.color?.withValues(
                          alpha: 0.70,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _ProviderStatusPill(label: service.status),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _ProviderMetaPill(
                icon: Icons.payments_outlined,
                label: _formatCurrency(service.price),
              ),
              _ProviderMetaPill(
                icon: Icons.star_rounded,
                label:
                    service.rating == 0 ? 'New' : service.rating.toStringAsFixed(1),
              ),
              _ProviderMetaPill(
                icon: Icons.location_on_outlined,
                label: service.location.trim().isEmpty
                    ? 'Location not set'
                    : service.location,
              ),
            ],
          ),
          const Divider(height: 24),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              TextButton.icon(
                onPressed: canEditService ? onEdit : null,
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Edit'),
              ),
              TextButton.icon(
                onPressed: canEditService ? onToggleStatus : null,
                icon: Icon(
                  isActive
                      ? Icons.pause_circle_outline
                      : Icons.play_circle_outline,
                ),
                label: Text(isActive ? 'Deactivate' : 'Activate'),
              ),
              TextButton.icon(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('Delete'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProviderBookingCard extends StatelessWidget {
  const _ProviderBookingCard({
    required this.booking,
    required this.currentUserId,
    required this.canAccept,
    required this.onAccept,
    required this.onDecline,
    required this.onMarkDone,
    required this.onOpenChat,
  });

  final ProviderBookingModel booking;
  final String currentUserId;
  final bool canAccept;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final VoidCallback onMarkDone;
  final VoidCallback onOpenChat;

  static final ChatService _chatService = ChatService();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return _ProviderDashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _ProviderIconCircle(icon: Icons.work_history_outlined),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      booking.serviceTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      booking.customerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.textTheme.bodyMedium?.color?.withValues(
                          alpha: 0.70,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _ProviderStatusPill(label: booking.status),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _ProviderMetaPill(
                icon: Icons.calendar_today_outlined,
                label: booking.selectedDate == null
                    ? 'Date not set'
                    : _formatDate(booking.selectedDate!),
              ),
              _ProviderMetaPill(
                icon: Icons.schedule_rounded,
                label: booking.selectedTimeSlot.isEmpty
                    ? 'Slot not set'
                    : booking.selectedTimeSlot,
              ),
              _ProviderMetaPill(
                icon: Icons.payments_outlined,
                label: _formatCurrency(booking.totalAmount),
              ),
              _ProviderMetaPill(
                icon: Icons.receipt_long_outlined,
                label: _titleizeStatus(booking.paymentStatus),
              ),
            ],
          ),
          if (booking.serviceAddress.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              booking.serviceAddress,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium,
            ),
          ],
          if (booking.notes.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              booking.notes,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.textTheme.bodyMedium?.color?.withValues(
                  alpha: 0.72,
                ),
              ),
            ),
          ],
          const Divider(height: 24),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (booking.isPending)
                FilledButton.icon(
                  onPressed: canAccept ? onAccept : null,
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('Accept'),
                ),
              if (booking.isPending)
                OutlinedButton.icon(
                  onPressed: onDecline,
                  icon: const Icon(Icons.close_rounded),
                  label: const Text('Decline'),
                ),
              if (booking.canProviderMarkDone)
                FilledButton.icon(
                  onPressed: onMarkDone,
                  icon: const Icon(Icons.check_circle_outline_rounded),
                  label: const Text('Mark done'),
                ),
              TextButton.icon(
                onPressed: onOpenChat,
                icon: StreamBuilder<int>(
                  stream: _chatService.streamUnreadCount(
                    chatId: booking.bookingId,
                    userId: currentUserId,
                  ),
                  builder: (context, snapshot) {
                    return _ChatActionIconWithBadge(
                      unreadCount: snapshot.data ?? 0,
                    );
                  },
                ),
                label: const Text('Chat'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChatActionIconWithBadge extends StatelessWidget {
  const _ChatActionIconWithBadge({required this.unreadCount});

  final int unreadCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final count = unreadCount < 0 ? 0 : unreadCount;
    final label = count > 99 ? '99+' : count.toString();

    return SizedBox(
      width: 28,
      height: 24,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          const Positioned(
            left: 0,
            bottom: 0,
            child: Icon(Icons.chat_bubble_outline_rounded),
          ),
          if (count > 0)
            Positioned(
              right: -2,
              top: -5,
              child: Container(
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.error,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: theme.colorScheme.surface,
                    width: 1.5,
                  ),
                ),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onError,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    height: 1.25,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ProviderScheduleCard extends StatelessWidget {
  const _ProviderScheduleCard({required this.slot});

  final ProviderAvailabilitySlotModel slot;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return _ProviderDashboardCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _ProviderIconCircle(icon: Icons.event_available_rounded),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  slot.dateLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  slot.timeSlot,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _ProviderStatusPill(label: slot.status),
        ],
      ),
    );
  }
}

class _ProviderRevenueSummary extends StatelessWidget {
  const _ProviderRevenueSummary({
    required this.earnings,
    required this.payments,
  });

  final double earnings;
  final List<ProviderPaymentModel> payments;

  @override
  Widget build(BuildContext context) {
    final commission = payments.fold<double>(
      0,
      (sum, payment) => sum + payment.platformCommissionAmount,
    );

    return _ProviderDashboardCard(
      child: Wrap(
        spacing: 18,
        runSpacing: 18,
        children: [
          _RevenueFigure(label: 'Total earnings', value: _formatCurrency(earnings)),
          _RevenueFigure(
            label: 'Platform commission',
            value: _formatCurrency(commission),
          ),
          _RevenueFigure(label: 'Payment records', value: payments.length.toString()),
        ],
      ),
    );
  }
}

class _RevenueFigure extends StatelessWidget {
  const _RevenueFigure({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 160),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(label),
        ],
      ),
    );
  }
}

class _ProviderPaymentCard extends StatelessWidget {
  const _ProviderPaymentCard({required this.payment});

  final ProviderPaymentModel payment;

  @override
  Widget build(BuildContext context) {
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _formatCurrency(payment.providerEarning),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _ProviderMetaPill(
              icon: Icons.price_change_outlined,
              label:
                  'Commission ${_formatCurrency(payment.platformCommissionAmount)}',
            ),
            _ProviderMetaPill(
              icon: Icons.calendar_today_outlined,
              label: _formatDate(payment.createdAt),
            ),
          ],
        ),
      ],
    );

    return _ProviderDashboardCard(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 360;

          if (isCompact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const _ProviderIconCircle(
                      icon: Icons.receipt_long_outlined,
                    ),
                    const Spacer(),
                    _ProviderStatusPill(label: payment.status),
                  ],
                ),
                const SizedBox(height: 12),
                details,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _ProviderIconCircle(icon: Icons.receipt_long_outlined),
              const SizedBox(width: 14),
              Expanded(child: details),
              const SizedBox(width: 10),
              _ProviderStatusPill(label: payment.status),
            ],
          );
        },
      ),
    );
  }
}

class _ProviderJobRequestCard extends StatelessWidget {
  const _ProviderJobRequestCard({required this.job});

  final JobPostModel job;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return _ProviderDashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _ProviderIconCircle(icon: Icons.campaign_outlined),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      job.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      job.customerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.textTheme.bodyMedium?.color?.withValues(
                          alpha: 0.70,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _ProviderStatusPill(label: job.status),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            job.description,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _ProviderMetaPill(icon: Icons.category_outlined, label: job.category),
              _ProviderMetaPill(
                icon: Icons.payments_outlined,
                label: '${_formatCurrency(job.budget)} budget',
              ),
              _ProviderMetaPill(
                icon: Icons.speed_rounded,
                label: 'Difficulty: ${job.difficulty}',
              ),
              _ProviderMetaPill(
                icon: Icons.location_on_outlined,
                label: job.readableLocation,
              ),
              if (job.ratingFilter != null)
                _ProviderMetaPill(
                  icon: Icons.star_rounded,
                  label:
                      'Prefers ${job.ratingFilter!.toStringAsFixed(job.ratingFilter! % 1 == 0 ? 0 : 1)}+ stars',
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ignore: unused_element
class _ProviderHero extends StatelessWidget {
  const _ProviderHero({
    required this.user,
    required this.onAddService,
    required this.onAddSlot,
    required this.canAddService,
  });

  final UserModel user;
  final VoidCallback onAddService;
  final VoidCallback onAddSlot;
  final bool canAddService;

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
                onPressed: canAddService ? onAddService : null,
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

// ignore: unused_element
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

// ignore: unused_element
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

// ignore: unused_element
class _BookingRequestsSection extends StatelessWidget {
  const _BookingRequestsSection({
    required this.pendingBookings,
    required this.canAcceptBookings,
    required this.onAcceptBooking,
    required this.onDeclineBooking,
    required this.onOpenChat,
  });

  final List<ProviderBookingModel> pendingBookings;
  final bool canAcceptBookings;
  final ValueChanged<ProviderBookingModel> onAcceptBooking;
  final ValueChanged<ProviderBookingModel> onDeclineBooking;
  final ValueChanged<ProviderBookingModel> onOpenChat;

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
                    canAccept: canAcceptBookings,
                    onAccept: () => onAcceptBooking(booking),
                    onDecline: () => onDeclineBooking(booking),
                    onOpenChat: () => onOpenChat(booking),
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
    required this.canAccept,
    required this.onAccept,
    required this.onDecline,
    required this.onOpenChat,
  });

  final ProviderBookingModel booking;
  final bool canAccept;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final VoidCallback onOpenChat;

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
              onPressed: canAccept ? onAccept : null,
              icon: const Icon(Icons.check_rounded),
              label: const Text('Accept'),
            ),
            OutlinedButton.icon(
              onPressed: onDecline,
              icon: const Icon(Icons.close_rounded),
              label: const Text('Decline'),
            ),
            TextButton.icon(
              onPressed: onOpenChat,
              icon: const Icon(Icons.chat_bubble_outline_rounded),
              label: const Text('Chat'),
            ),
          ],
        ),
      ],
    );
  }
}

// ignore: unused_element
class _ServiceListingsSection extends StatelessWidget {
  const _ServiceListingsSection({
    required this.services,
    required this.canAddService,
    required this.onAddService,
    required this.onEditService,
    required this.onDeleteService,
    required this.onToggleServiceStatus,
  });

  final List<ServiceListingModel> services;
  final bool canAddService;
  final VoidCallback onAddService;
  final ValueChanged<ServiceListingModel> onEditService;
  final ValueChanged<ServiceListingModel> onDeleteService;
  final ValueChanged<ServiceListingModel> onToggleServiceStatus;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Service listings',
      action: TextButton.icon(
        onPressed: canAddService ? onAddService : null,
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
                  _ServiceListingTile(
                    service: service,
                    canEditService: canAddService,
                    canActivateService: canAddService,
                    onEdit: () => onEditService(service),
                    onDelete: () => onDeleteService(service),
                    onToggleStatus: () => onToggleServiceStatus(service),
                  ),
                  if (service != services.take(4).last)
                    const Divider(height: 24),
                ],
              ],
            ),
    );
  }
}

class _ServiceListingTile extends StatelessWidget {
  const _ServiceListingTile({
    required this.service,
    required this.canEditService,
    required this.canActivateService,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleStatus,
  });

  final ServiceListingModel service;
  final bool canEditService;
  final bool canActivateService;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggleStatus;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isActive = service.status.trim().toLowerCase() == 'active';
    final canToggleStatus = isActive || canActivateService;

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
                  _MetaChip(
                    icon: Icons.toggle_on_outlined,
                    label: service.status,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  TextButton.icon(
                    onPressed: canEditService ? onEdit : null,
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Edit'),
                  ),
                  TextButton.icon(
                    onPressed: canToggleStatus ? onToggleStatus : null,
                    icon: Icon(
                      isActive
                          ? Icons.pause_circle_outline
                          : Icons.play_circle_outline,
                    ),
                    label: Text(
                      isActive ? 'Deactivate' : 'Activate',
                    ),
                  ),
                  TextButton.icon(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: const Text('Delete'),
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

// ignore: unused_element
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

// ignore: unused_element
class _JobsSection extends StatelessWidget {
  const _JobsSection({
    required this.title,
    required this.bookings,
    required this.emptyTitle,
    required this.emptyDescription,
    required this.onMarkDone,
    required this.onOpenChat,
  });

  final String title;
  final List<ProviderBookingModel> bookings;
  final String emptyTitle;
  final String emptyDescription;
  final ValueChanged<ProviderBookingModel> onMarkDone;
  final ValueChanged<ProviderBookingModel> onOpenChat;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: title,
      child: bookings.isEmpty
          ? _EmptyState(
              icon: Icons.work_outline_rounded,
              title: emptyTitle,
              description: emptyDescription,
            )
          : Column(
              children: [
                for (final booking in bookings.take(4)) ...[
                  _UpcomingBookingTile(
                    booking: booking,
                    onMarkDone: () => onMarkDone(booking),
                    onOpenChat: () => onOpenChat(booking),
                  ),
                  if (booking != bookings.take(4).last)
                    const Divider(height: 10),
                ],
              ],
            ),
    );
  }
}

class _UpcomingBookingTile extends StatelessWidget {
  const _UpcomingBookingTile({
    required this.booking,
    required this.onMarkDone,
    required this.onOpenChat,
  });

  final ProviderBookingModel booking;
  final VoidCallback onMarkDone;
  final VoidCallback onOpenChat;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.work_history_outlined),
          title: Text(booking.serviceTitle),
          subtitle: Text(
            '${booking.customerName} | ${booking.selectedTimeSlot}',
          ),
          trailing: Text(_formatCurrency(booking.price)),
        ),
        if (booking.serviceAddress.trim().isNotEmpty)
          Text(
            booking.serviceAddress,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.72),
            ),
          ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            if (booking.canProviderMarkDone)
              FilledButton.icon(
                onPressed: onMarkDone,
                icon: const Icon(Icons.check_circle_outline_rounded),
                label: const Text('Mark as done'),
              ),
            OutlinedButton.icon(
              onPressed: onOpenChat,
              icon: const Icon(Icons.chat_bubble_outline_rounded),
              label: const Text('Chat'),
            ),
          ],
        ),
      ],
    );
  }
}

// ignore: unused_element
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

String _titleizeStatus(String status) {
  final words = status.trim().replaceAll('_', ' ').split(RegExp(r'\s+'));
  if (words.isEmpty || words.first.isEmpty) {
    return 'Pending';
  }

  return words
      .map((word) {
        if (word.isEmpty) {
          return word;
        }

        final lower = word.toLowerCase();
        return '${lower[0].toUpperCase()}${lower.substring(1)}';
      })
      .join(' ');
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
