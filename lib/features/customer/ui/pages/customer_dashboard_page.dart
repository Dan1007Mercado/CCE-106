import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/services/job_photo_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/helpers.dart';
import '../../../../core/widgets/brand_logo.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/custom_textfield.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../../../core/widgets/profile_avatar.dart';
import '../../../../routes/app_router.dart';
import '../../../auth/bloc/auth_bloc.dart';
import '../../../auth/data/models/user_model.dart';
import '../../../chat/data/services/chat_service.dart';
import '../../../chat/ui/pages/chat_page.dart';
import '../../../provider/data/models/provider_booking_model.dart';
import '../../data/models/job_post_model.dart';
import '../../data/models/service_listing_model.dart';
import '../../data/services/booking_service.dart';
import '../../data/services/customer_service.dart';

class CustomerDashboardPage extends StatefulWidget {
  const CustomerDashboardPage({super.key});

  @override
  State<CustomerDashboardPage> createState() => _CustomerDashboardPageState();
}

class _CustomerDashboardPageState extends State<CustomerDashboardPage>
    with SingleTickerProviderStateMixin {
  static const List<String> _categories = [
    'All',
    'Electrician',
    'Masonry',
    'Plumbing',
    'Cleaning',
    'Carpentry',
  ];

  static const List<String> _jobCategories = [
    'Electrician',
    'Masonry',
    'Plumbing',
    'Cleaning',
    'Carpentry',
  ];

  static const List<String> _difficulties = [
    'Easy',
    'Moderate',
    'Hard',
    'Expert',
  ];

  static const List<double> _ratings = [3, 4, 4.5];

  final CustomerService _customerService = CustomerService();
  final BookingService _bookingService = BookingService();
  final ChatService _chatService = ChatService();
  final JobPhotoService _jobPhotoService = JobPhotoService();
  final TextEditingController _searchController = TextEditingController();
  late final TabController _tabController;
  Timer? _welcomeTimer;

  String _selectedCategory = 'All';
  double? _selectedRating;
  String _searchQuery = '';
  bool _showWelcomePanel = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _welcomeTimer = Timer(const Duration(seconds: 2), _hideWelcomePanel);
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _welcomeTimer?.cancel();
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.select((AuthBloc bloc) => bloc.state.user);
    final theme = Theme.of(context);
    final tokens = theme.tokens;

    if (user == null) {
      return const Scaffold(
        body: Center(
          child: LoadingIndicator(message: 'Loading your dashboard...'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).pushNamed(AppRouter.postJobRoute);
        },
        icon: const Icon(Icons.add_task_rounded),
        label: const Text('Post a Job'),
      ),
      appBar: AppBar(
        titleSpacing: AppSizes.pagePadding,
        title: Row(
          children: [
            const BrandLogo(size: 36, borderRadius: 10),

            const SizedBox(width: 12), // reduce slightly
            const Flexible(
              child: Text(
                AppStrings.appName,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        actions: [
          _ActionIcon(
            icon: Icons.notifications_none_rounded,
            tooltip: 'Notifications',
            onTap: () => _handleNotificationsTap(user),
          ),
          Padding(
            padding: const EdgeInsets.only(right: AppSizes.pagePadding),
            child: InkWell(
              onTap: () {
                Navigator.of(context).pushNamed(AppRouter.customerProfileRoute);
              },
              borderRadius: BorderRadius.circular(24),
              child: ProfileAvatar(
                radius: 18,
                name: user.displayName,
                imageProvider: user.profilePic.trim().isEmpty
                    ? null
                    : NetworkImage(user.profilePic),
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(66),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSizes.pagePadding,
              0,
              AppSizes.pagePadding,
              12,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: tokens.primarySoft,
                borderRadius: BorderRadius.circular(999),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(999),
                ),
                tabs: const [
                  Tab(text: 'Services'),
                  Tab(text: 'My Jobs'),
                  Tab(text: 'Bookings'),
                ],
              ),
            ),
          ),
        ),
      ),
      body: Column(
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
            child: _showWelcomePanel
                ? Padding(
                    key: const ValueKey('welcome-panel'),
                    padding: const EdgeInsets.fromLTRB(
                      AppSizes.pagePadding,
                      16,
                      AppSizes.pagePadding,
                      18,
                    ),
                    child: _WelcomePanel(user: user),
                  )
                : const SizedBox.shrink(key: ValueKey('hidden-welcome-panel')),
          ),
          Expanded(
            child: NotificationListener<ScrollNotification>(
              onNotification: _handleScrollNotification,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _ServicesFeedSection(
                    serviceStream: _customerService.streamServices(
                      category: _selectedCategory,
                      minRating: _selectedRating,
                    ),
                    searchController: _searchController,
                    searchQuery: _searchQuery,
                    selectedCategory: _selectedCategory,
                    selectedRating: _selectedRating,
                    onOpenFilters: _showServiceFilterSheet,
                    onOpenDetails: (service) {
                      Navigator.of(context).pushNamed(
                        AppRouter.serviceDetailRoute,
                        arguments: service,
                      );
                    },
                  ),
                  _CustomerJobsSection(
                    currentUser: user,
                    jobsStream: _customerService.streamCustomerJobs(user.uid),
                    onEditJob: (job) => _showEditJobSheet(user, job),
                    onDeleteJob: (job) => _confirmDeleteJob(user, job),
                  ),
                  _CustomerBookingsSection(
                    bookingsStream: _bookingService.streamCustomerBookings(
                      user.uid,
                    ),
                    onCancelBooking: (booking) =>
                        _confirmCancelBooking(user, booking),
                    onCallProvider: _callProvider,
                    onOpenChat: _openBookingChat,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    if (notification.metrics.pixels > 10) {
      _hideWelcomePanel();
    }

    return false;
  }

  void _hideWelcomePanel() {
    if (!mounted || !_showWelcomePanel) {
      return;
    }

    _welcomeTimer?.cancel();
    _welcomeTimer = null;
    setState(() {
      _showWelcomePanel = false;
    });
  }

  Future<void> _showServiceFilterSheet() async {
    var tempCategory = _selectedCategory;
    double? tempRating = _selectedRating;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                AppSizes.pagePadding,
                AppSizes.pagePadding,
                AppSizes.pagePadding,
                MediaQuery.of(context).viewInsets.bottom + AppSizes.pagePadding,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Filter services',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Category',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _categories
                        .map(
                          (category) => ChoiceChip(
                            label: Text(category),
                            selected: tempCategory == category,
                            onSelected: (_) {
                              setModalState(() {
                                tempCategory = category;
                              });
                            },
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Minimum rating',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('Any rating'),
                        selected: tempRating == null,
                        onSelected: (_) {
                          setModalState(() {
                            tempRating = null;
                          });
                        },
                      ),
                      ..._ratings.map(
                        (rating) => ChoiceChip(
                          label: Text(
                            '${rating.toStringAsFixed(rating % 1 == 0 ? 0 : 1)}+ stars',
                          ),
                          selected: tempRating == rating,
                          onSelected: (_) {
                            setModalState(() {
                              tempRating = rating;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            setState(() {
                              _selectedCategory = 'All';
                              _selectedRating = null;
                            });
                            Navigator.of(context).pop();
                          },
                          child: const Text('Clear'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _selectedCategory = tempCategory;
                              _selectedRating = tempRating;
                            });
                            Navigator.of(context).pop();
                          },
                          child: const Text('Apply'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showEditJobSheet(UserModel user, JobPostModel job) async {
    if (job.customerId != user.uid) {
      Helpers.showSnackBar(
        context,
        'You can only edit your own job post.',
        isError: true,
      );
      return;
    }

    final formKey = GlobalKey<FormState>();
    final titleController = TextEditingController(text: job.title);
    final descriptionController = TextEditingController(text: job.description);
    final locationController = TextEditingController(text: job.location);
    final budgetController = TextEditingController(
      text: job.budget == 0 ? '' : job.budget.toStringAsFixed(0),
    );
    var selectedCategory = _jobCategories.contains(job.category)
        ? job.category
        : _jobCategories.first;
    var selectedDifficulty = _difficulties.contains(job.difficulty)
        ? job.difficulty
        : 'Moderate';
    double? selectedRating = _ratings.contains(job.ratingFilter)
        ? job.ratingFilter
        : null;
    var photoUrl = job.photoUrl;
    XFile? selectedPhoto;
    Uint8List? selectedPhotoBytes;
    var isPickingPhoto = false;
    var isSaving = false;

    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (sheetContext) {
          return StatefulBuilder(
            builder: (sheetContext, setSheetState) {
              Future<void> pickPhoto() async {
                setSheetState(() {
                  isPickingPhoto = true;
                });

                try {
                  final photo = await _jobPhotoService.pickJobPhoto();
                  if (photo == null) {
                    return;
                  }

                  final bytes = await photo.readAsBytes();
                  if (!sheetContext.mounted) {
                    return;
                  }

                  setSheetState(() {
                    selectedPhoto = photo;
                    selectedPhotoBytes = bytes;
                  });
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
                      isPickingPhoto = false;
                    });
                  }
                }
              }

              Future<void> save() async {
                if (!formKey.currentState!.validate()) {
                  return;
                }

                final budget = double.parse(budgetController.text.trim());
                setSheetState(() {
                  isSaving = true;
                });

                try {
                  var updatedPhotoUrl = photoUrl;
                  if (selectedPhoto != null) {
                    updatedPhotoUrl = await _jobPhotoService.uploadJobPhoto(
                      userId: user.uid,
                      image: selectedPhoto!,
                    );
                  }

                  await _customerService.updateJob(
                    jobId: job.jobId,
                    currentUserId: user.uid,
                    title: titleController.text,
                    description: descriptionController.text,
                    category: selectedCategory,
                    location: locationController.text,
                    budget: budget,
                    difficulty: selectedDifficulty,
                    ratingFilter: selectedRating,
                    photoUrl: updatedPhotoUrl,
                  );

                  if (!mounted || !sheetContext.mounted) {
                    return;
                  }

                  Navigator.of(sheetContext).pop();
                  Helpers.showSnackBar(context, 'Job post updated.');
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

              return SafeArea(
                child: Padding(
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
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Edit job post',
                            style: Theme.of(sheetContext).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: AppSizes.fieldGap),
                          CustomTextField(
                            controller: titleController,
                            label: 'Job title',
                            prefixIcon: Icons.assignment_outlined,
                            validator: _requiredValidator,
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
                          DropdownButtonFormField<String>(
                            initialValue: selectedCategory,
                            decoration: const InputDecoration(
                              labelText: 'Category',
                              prefixIcon: Icon(Icons.category_outlined),
                            ),
                            items: _jobCategories
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
                            controller: locationController,
                            label: 'Location',
                            prefixIcon: Icons.location_on_outlined,
                            maxLines: 2,
                            validator: _requiredValidator,
                          ),
                          const SizedBox(height: AppSizes.fieldGap),
                          CustomTextField(
                            controller: budgetController,
                            label: 'Budget / Offered price',
                            hintText: '500',
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            prefixIcon: Icons.payments_outlined,
                            validator: _budgetValidator,
                          ),
                          const SizedBox(height: AppSizes.fieldGap),
                          DropdownButtonFormField<String>(
                            initialValue: selectedDifficulty,
                            decoration: const InputDecoration(
                              labelText: 'Difficulty',
                              prefixIcon: Icon(Icons.speed_rounded),
                            ),
                            items: _difficulties
                                .map(
                                  (difficulty) => DropdownMenuItem(
                                    value: difficulty,
                                    child: Text(difficulty),
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
                                      selectedDifficulty = value;
                                    });
                                  },
                          ),
                          const SizedBox(height: AppSizes.fieldGap),
                          DropdownButtonFormField<double?>(
                            initialValue: selectedRating,
                            decoration: const InputDecoration(
                              labelText: 'Preferred rating filter',
                              prefixIcon: Icon(Icons.star_outline_rounded),
                            ),
                            items: const [
                              DropdownMenuItem<double?>(
                                value: null,
                                child: Text('No preference'),
                              ),
                              DropdownMenuItem<double?>(
                                value: 3,
                                child: Text('3 stars and above'),
                              ),
                              DropdownMenuItem<double?>(
                                value: 4,
                                child: Text('4 stars and above'),
                              ),
                              DropdownMenuItem<double?>(
                                value: 4.5,
                                child: Text('4.5 stars and above'),
                              ),
                            ],
                            onChanged: isSaving
                                ? null
                                : (value) {
                                    setSheetState(() {
                                      selectedRating = value;
                                    });
                                  },
                          ),
                          const SizedBox(height: AppSizes.fieldGap),
                          _EditableJobPhoto(
                            photoUrl: photoUrl,
                            selectedPhotoBytes: selectedPhotoBytes,
                            isPicking: isPickingPhoto,
                            onPick: isSaving ? null : pickPhoto,
                            onRemove: isSaving
                                ? null
                                : () {
                                    setSheetState(() {
                                      photoUrl = '';
                                      selectedPhoto = null;
                                      selectedPhotoBytes = null;
                                    });
                                  },
                          ),
                          const SizedBox(height: AppSizes.sectionGap),
                          CustomButton(
                            label: 'Save changes',
                            icon: Icons.save_rounded,
                            isLoading: isSaving,
                            onPressed: save,
                          ),
                        ],
                      ),
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
      budgetController.dispose();
    }
  }

  Future<void> _confirmDeleteJob(UserModel user, JobPostModel job) async {
    if (job.customerId != user.uid) {
      Helpers.showSnackBar(
        context,
        'You can only delete your own job post.',
        isError: true,
      );
      return;
    }

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete job post?'),
          content: const Text(
            'This will permanently remove your posted job request.',
          ),
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

    if (shouldDelete != true) {
      return;
    }

    try {
      await _customerService.deleteJob(
        jobId: job.jobId,
        currentUserId: user.uid,
      );

      if (!mounted) {
        return;
      }

      Helpers.showSnackBar(context, 'Job post deleted.');
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

  Future<void> _confirmCancelBooking(
    UserModel user,
    ProviderBookingModel booking,
  ) async {
    if (!booking.canCustomerCancel) {
      Helpers.showSnackBar(
        context,
        'This booking can no longer be cancelled.',
        isError: true,
      );
      return;
    }

    final shouldCancel = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Cancel booking?'),
          content: const Text(
            'Cancelling will charge 3% for the service provider and 1% platform fee.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Keep booking'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Cancel booking'),
            ),
          ],
        );
      },
    );

    if (shouldCancel != true) {
      return;
    }

    try {
      await _bookingService.cancelBookingByCustomer(
        bookingId: booking.bookingId,
        customerId: user.uid,
      );

      if (!mounted) {
        return;
      }

      Helpers.showSnackBar(
        context,
        'Booking cancelled. Cancellation fee applied.',
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

  Future<void> _callProvider(ProviderBookingModel booking) async {
    final phone = booking.providerPhone.trim();
    if (phone.isEmpty) {
      Helpers.showSnackBar(
        context,
        'Provider phone number is not available.',
        isError: true,
      );
      return;
    }

    final uri = Uri(scheme: 'tel', path: phone);
    final opened = await launchUrl(uri);
    if (!opened && mounted) {
      Helpers.showSnackBar(
        context,
        'Could not open the phone app.',
        isError: true,
      );
    }
  }

  Future<void> _openBookingChat(ProviderBookingModel booking) async {
    try {
      await _chatService.ensureBookingChat(
        bookingId: booking.bookingId,
        customerId: booking.customerId,
        providerId: booking.providerId,
        customerName: booking.customerName,
        providerName: booking.providerName,
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

  String? _requiredValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'This field is required.';
    }

    return null;
  }

  String? _budgetValidator(String? value) {
    final parsed = double.tryParse(value?.trim() ?? '');
    if (parsed == null || parsed <= 0) {
      return 'Enter a valid budget.';
    }

    return null;
  }

  void _handleNotificationsTap(UserModel user) {
    if (!user.notificationsPermission.isGranted) {
      Helpers.showSnackBar(
        context,
        'Enable notification permission in Settings to receive push alerts.',
        isError: true,
      );
      return;
    }

    _showComingSoon('Notifications');
  }

  void _showComingSoon(String label) {
    Helpers.showSnackBar(context, '$label coming soon');
  }
}

class _ActionIcon extends StatelessWidget {
  const _ActionIcon({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(onPressed: onTap, tooltip: tooltip, icon: Icon(icon));
  }
}

class _WelcomePanel extends StatelessWidget {
  const _WelcomePanel({required this.user});

  final UserModel user;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
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
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _StatusBadge(
                label: user.hasContactNumber
                    ? 'Contact ready'
                    : 'Add 09XXXXXXXXX',
                isActive: user.hasContactNumber,
              ),
              _StatusBadge(
                label: user.hasBookingLocation
                    ? 'GPS ready'
                    : 'Capture location',
                isActive: user.hasBookingLocation,
              ),
              _StatusBadge(
                label: user.notificationsPermission.isGranted
                    ? 'Alerts on'
                    : 'Alerts off',
                isActive: user.notificationsPermission.isGranted,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.isActive});

  final String label;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isActive
            ? Theme.of(context).tokens.successSoft
            : Theme.of(context).tokens.warningSoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: AppTheme.resolveOnColor(
            isActive
                ? Theme.of(context).tokens.successSoft
                : Theme.of(context).tokens.warningSoft,
          ),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ServicesFeedSection extends StatelessWidget {
  const _ServicesFeedSection({
    required this.serviceStream,
    required this.searchController,
    required this.searchQuery,
    required this.selectedCategory,
    required this.selectedRating,
    required this.onOpenFilters,
    required this.onOpenDetails,
  });

  final Stream<List<ServiceListingModel>> serviceStream;
  final TextEditingController searchController;
  final String searchQuery;
  final String selectedCategory;
  final double? selectedRating;
  final VoidCallback onOpenFilters;
  final ValueChanged<ServiceListingModel> onOpenDetails;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ServiceListingModel>>(
      stream: serviceStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final services = snapshot.data ?? const [];
        final filteredServices = searchQuery.isEmpty
            ? services
            : services.where((service) {
                final source =
                    '${service.title} ${service.providerName} ${service.category} ${service.location}'
                        .toLowerCase();
                return source.contains(searchQuery);
              }).toList();

        return ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSizes.pagePadding,
            0,
            AppSizes.pagePadding,
            100,
          ),
          children: [
            _SectionHeader(
              title: 'Find local services',
              description:
                  'Search provider listings without mixing in job posts.',
              action: IconButton(
                onPressed: onOpenFilters,
                icon: const Icon(Icons.filter_list_rounded),
                tooltip: 'Filter services',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: searchController,
              decoration: InputDecoration(
                hintText: 'Search services, providers, category, or location',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: searchController.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        onPressed: searchController.clear,
                        icon: const Icon(Icons.close_rounded),
                      ),
              ),
            ),
            const SizedBox(height: 12),
            _ActiveFiltersSummary(
              selectedCategory: selectedCategory,
              selectedRating: selectedRating,
            ),
            const SizedBox(height: 18),
            if (filteredServices.isEmpty)
              const _EmptyFeedCard(
                title: 'No services match your search yet.',
                description:
                    'Try a different keyword, category, or rating filter.',
              )
            else
              for (final service in filteredServices) ...[
                _ServiceFeedCard(
                  service: service,
                  onOpenDetails: () => onOpenDetails(service),
                ),
                const SizedBox(height: 16),
              ],
          ],
        );
      },
    );
  }
}

class _CustomerJobsSection extends StatelessWidget {
  const _CustomerJobsSection({
    required this.currentUser,
    required this.jobsStream,
    required this.onEditJob,
    required this.onDeleteJob,
  });

  final UserModel currentUser;
  final Stream<List<JobPostModel>> jobsStream;
  final ValueChanged<JobPostModel> onEditJob;
  final ValueChanged<JobPostModel> onDeleteJob;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<JobPostModel>>(
      stream: jobsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final jobs = snapshot.data ?? const [];

        return ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSizes.pagePadding,
            0,
            AppSizes.pagePadding,
            100,
          ),
          children: [
            const _SectionHeader(
              title: 'My posted jobs',
              description: 'Track the job requests you have posted.',
            ),
            const SizedBox(height: 18),
            if (jobs.isEmpty)
              const _EmptyFeedCard(
                title: 'You have not posted any jobs yet.',
                description:
                    'Use Post a Job when you need providers to respond to a request.',
              )
            else
              for (final job in jobs) ...[
                _JobFeedCard(
                  job: job,
                  canManage: job.customerId == currentUser.uid,
                  onEdit: () => onEditJob(job),
                  onDelete: () => onDeleteJob(job),
                ),
                const SizedBox(height: 16),
              ],
          ],
        );
      },
    );
  }
}

class _CustomerBookingsSection extends StatelessWidget {
  const _CustomerBookingsSection({
    required this.bookingsStream,
    required this.onCancelBooking,
    required this.onCallProvider,
    required this.onOpenChat,
  });

  final Stream<List<ProviderBookingModel>> bookingsStream;
  final ValueChanged<ProviderBookingModel> onCancelBooking;
  final ValueChanged<ProviderBookingModel> onCallProvider;
  final ValueChanged<ProviderBookingModel> onOpenChat;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ProviderBookingModel>>(
      stream: bookingsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final bookings = snapshot.data ?? const <ProviderBookingModel>[];

        return ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSizes.pagePadding,
            0,
            AppSizes.pagePadding,
            100,
          ),
          children: [
            const _SectionHeader(
              title: 'My bookings',
              description:
                  'Track service requests, contact providers, and cancel active bookings.',
            ),
            const SizedBox(height: 18),
            if (bookings.isEmpty)
              const _EmptyFeedCard(
                title: 'No bookings yet.',
                description:
                    'Booked services will appear here with contact and payment status.',
              )
            else
              for (final booking in bookings) ...[
                _CustomerBookingCard(
                  booking: booking,
                  onCancel: () => onCancelBooking(booking),
                  onCallProvider: () => onCallProvider(booking),
                  onOpenChat: () => onOpenChat(booking),
                ),
                const SizedBox(height: 16),
              ],
          ],
        );
      },
    );
  }
}

class _CustomerBookingCard extends StatelessWidget {
  const _CustomerBookingCard({
    required this.booking,
    required this.onCancel,
    required this.onCallProvider,
    required this.onOpenChat,
  });

  final ProviderBookingModel booking;
  final VoidCallback onCancel;
  final VoidCallback onCallProvider;
  final VoidCallback onOpenChat;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: theme.tokens.primarySoft,
                  child: Icon(
                    Icons.calendar_month_rounded,
                    color: AppTheme.resolveOnColor(theme.tokens.primarySoft),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        booking.serviceTitle,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        booking.providerName,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.textTheme.bodyMedium?.color?.withValues(
                            alpha: 0.74,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                _InfoPill(label: booking.status),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                if (booking.selectedDate != null)
                  _InfoPill(label: _formatDate(booking.selectedDate!)),
                if (booking.selectedTimeSlot.trim().isNotEmpty)
                  _InfoPill(label: booking.selectedTimeSlot),
                _InfoPill(label: 'Payment: ${booking.paymentStatus}'),
                _InfoPill(label: _formatCurrency(booking.totalAmount)),
              ],
            ),
            if (booking.serviceAddress.trim().isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                booking.serviceAddress,
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
              ),
            ],
            if (booking.notes.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                booking.notes,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.textTheme.bodyMedium?.color?.withValues(
                    alpha: 0.74,
                  ),
                  height: 1.45,
                ),
              ),
            ],
            if (booking.isCancelled &&
                (booking.providerCancellationFee > 0 ||
                    booking.platformCancellationFee > 0)) ...[
              const SizedBox(height: 12),
              Text(
                'Cancellation fees: provider ${_formatCurrency(booking.providerCancellationFee)}, platform ${_formatCurrency(booking.platformCancellationFee)}.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.textTheme.bodySmall?.color?.withValues(
                    alpha: 0.72,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                OutlinedButton.icon(
                  onPressed: onCallProvider,
                  icon: const Icon(Icons.call_outlined),
                  label: const Text('Call provider'),
                ),
                OutlinedButton.icon(
                  onPressed: onOpenChat,
                  icon: const Icon(Icons.chat_bubble_outline_rounded),
                  label: const Text('Chat'),
                ),
                if (booking.canCustomerCancel)
                  FilledButton.icon(
                    onPressed: onCancel,
                    icon: const Icon(Icons.cancel_outlined),
                    label: const Text('Cancel booking'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.description,
    this.action,
  });

  final String title;
  final String description;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                description,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.color?.withValues(alpha: 0.74),
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
        ...switch (action) {
          final action? => [action],
          null => const <Widget>[],
        },
      ],
    );
  }
}

class _ActiveFiltersSummary extends StatelessWidget {
  const _ActiveFiltersSummary({
    required this.selectedCategory,
    required this.selectedRating,
  });

  final String selectedCategory;
  final double? selectedRating;

  @override
  Widget build(BuildContext context) {
    final filters = <String>[
      if (selectedCategory != 'All') selectedCategory,
      if (selectedRating != null)
        '${selectedRating!.toStringAsFixed(selectedRating! % 1 == 0 ? 0 : 1)}+ stars',
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).tokens.subtleSurface,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      ),
      child: Text(
        filters.isEmpty
            ? 'Showing all service listings.'
            : 'Active filters: ${filters.join(' | ')}',
        style: TextStyle(
          color: AppTheme.resolveOnColor(
            Theme.of(context).tokens.subtleSurface,
          ),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _EmptyFeedCard extends StatelessWidget {
  const _EmptyFeedCard({required this.title, required this.description});

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.cardPadding),
        child: Column(
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 40,
              color: Theme.of(
                context,
              ).textTheme.bodyMedium?.color?.withValues(alpha: 0.74),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              description,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(
                  context,
                ).textTheme.bodyMedium?.color?.withValues(alpha: 0.74),
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ServiceFeedCard extends StatelessWidget {
  const _ServiceFeedCard({required this.service, required this.onOpenDetails});

  final ServiceListingModel service;
  final VoidCallback onOpenDetails;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.tokens;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: CircleAvatar(
                    backgroundColor: tokens.primarySoft,
                    child: Icon(
                      Icons.home_repair_service_rounded,
                      color: AppTheme.resolveOnColor(tokens.primarySoft),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        service.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        service.providerName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        service.category,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.textTheme.bodyMedium?.color?.withValues(
                            alpha: 0.74,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                _InfoPill(label: '${service.rating.toStringAsFixed(1)} stars'),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              service.description,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.textTheme.bodyLarge?.color?.withValues(
                  alpha: 0.74,
                ),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _InfoPill(
                  label: 'PHP ${service.price.toStringAsFixed(0)} fixed',
                ),
                if (service.location.trim().isNotEmpty)
                  _InfoPill(label: service.location),
              ],
            ),
            const SizedBox(height: 18),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onOpenDetails,
                icon: const Icon(Icons.arrow_forward_rounded),
                label: const Text('View details'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _JobFeedCard extends StatelessWidget {
  const _JobFeedCard({
    required this.job,
    required this.canManage,
    required this.onEdit,
    required this.onDelete,
  });

  final JobPostModel job;
  final bool canManage;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.tokens;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.cardPadding),
        child: Column(
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
              const SizedBox(height: 16),
            ],
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: CircleAvatar(
                    backgroundColor: tokens.accentSoft,
                    child: Icon(
                      Icons.campaign_outlined,
                      color: AppTheme.resolveOnColor(tokens.accentSoft),
                    ),
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
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Posted request',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.textTheme.bodyMedium?.color?.withValues(
                            alpha: 0.74,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (canManage)
                  PopupMenuButton<String>(
                    tooltip: 'Job actions',
                    onSelected: (value) {
                      switch (value) {
                        case 'edit':
                          onEdit();
                          break;
                        case 'delete':
                          onDelete();
                          break;
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'edit', child: Text('Edit')),
                      PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
                  ),
                _InfoPill(label: job.status),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              job.title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              job.description,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.textTheme.bodyLarge?.color?.withValues(
                  alpha: 0.74,
                ),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _InfoPill(label: job.category),
                _InfoPill(label: 'PHP ${job.budget.toStringAsFixed(0)} budget'),
                _InfoPill(label: 'Difficulty: ${job.difficulty}'),
                _InfoPill(label: job.readableLocation),
                if (job.ratingFilter != null)
                  _InfoPill(
                    label:
                        'Prefers ${job.ratingFilter!.toStringAsFixed(job.ratingFilter! % 1 == 0 ? 0 : 1)}+ stars',
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EditableJobPhoto extends StatelessWidget {
  const _EditableJobPhoto({
    required this.photoUrl,
    required this.selectedPhotoBytes,
    required this.isPicking,
    required this.onPick,
    required this.onRemove,
  });

  final String photoUrl;
  final Uint8List? selectedPhotoBytes;
  final bool isPicking;
  final VoidCallback? onPick;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final hasExistingPhoto = photoUrl.trim().isNotEmpty;
    final hasPhoto = selectedPhotoBytes != null || hasExistingPhoto;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (selectedPhotoBytes != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            child: Image.memory(
              selectedPhotoBytes!,
              height: 180,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          )
        else if (hasExistingPhoto)
          ClipRRect(
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            child: Image.network(
              photoUrl,
              height: 180,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return const SizedBox.shrink();
              },
            ),
          ),
        if (hasPhoto) const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: isPicking ? null : onPick,
          icon: isPicking
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.add_photo_alternate_outlined),
          label: Text(hasPhoto ? 'Change photo' : 'Add job photo'),
        ),
        if (hasPhoto) ...[
          const SizedBox(height: 6),
          TextButton.icon(
            onPressed: isPicking ? null : onRemove,
            icon: const Icon(Icons.delete_outline_rounded),
            label: const Text('Remove photo'),
          ),
        ],
      ],
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final background = Theme.of(context).tokens.subtleSurface;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: AppTheme.resolveOnColor(background),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
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
