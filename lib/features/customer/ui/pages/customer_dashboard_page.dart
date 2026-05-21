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
        toolbarHeight: 72,
        title: Row(
          children: [
            const BrandLogo(size: 36, borderRadius: 10),
            const SizedBox(width: 12),
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
                child: ProfileAvatar(
                  radius: 18,
                  name: user.displayName,
                  imageProvider: user.profilePic.trim().isEmpty
                      ? null
                      : NetworkImage(user.profilePic),
                ),
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
                  Tab(height: 42, text: 'Services'),
                  Tab(height: 42, text: 'My Jobs'),
                  Tab(height: 42, text: 'Bookings'),
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
        backgroundColor: Colors.transparent,
        showDragHandle: false,
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

                final budget = double.tryParse(budgetController.text.trim());
                if (budget == null || budget <= 0) {
                  Helpers.showSnackBar(
                    sheetContext,
                    'Enter a valid budget.',
                    isError: true,
                  );
                  return;
                }

                setSheetState(() {
                  isSaving = true;
                });

                var shouldResetSaving = true;
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

                  shouldResetSaving = false;
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
                  if (shouldResetSaving && sheetContext.mounted) {
                    setSheetState(() {
                      isSaving = false;
                    });
                  }
                }
              }

              final theme = Theme.of(sheetContext);
              final tokens = theme.tokens;

              return SafeArea(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 640),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(30),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.18),
                          blurRadius: 32,
                          offset: const Offset(0, -10),
                        ),
                      ],
                    ),
                    child: Form(
                      key: formKey,
                      child: SingleChildScrollView(
                        padding: EdgeInsets.fromLTRB(
                          AppSizes.pagePadding,
                          14,
                          AppSizes.pagePadding,
                          MediaQuery.of(sheetContext).viewInsets.bottom +
                              AppSizes.pagePadding,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                IconButton(
                                  tooltip: 'Back',
                                  onPressed: isSaving
                                      ? null
                                      : () => Navigator.of(sheetContext).pop(),
                                  icon: const Icon(Icons.arrow_back_rounded),
                                  style: IconButton.styleFrom(
                                    backgroundColor: tokens.primarySoft,
                                    foregroundColor: theme.colorScheme.primary,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Edit posted job',
                                        style: theme.textTheme.titleLarge
                                            ?.copyWith(
                                              fontWeight: FontWeight.w800,
                                              height: 1.1,
                                            ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Update the request details providers will see.',
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                              color: theme
                                                  .textTheme
                                                  .bodyMedium
                                                  ?.color
                                                  ?.withValues(alpha: 0.68),
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: tokens.subtleSurface,
                                borderRadius: BorderRadius.circular(22),
                                border: Border.all(
                                  color: theme.colorScheme.outlineVariant
                                      .withValues(alpha: 0.55),
                                ),
                              ),
                              child: Column(
                                children: [
                                  CustomTextField(
                                    controller: titleController,
                                    label: 'Job title',
                                    prefixIcon: Icons.assignment_outlined,
                                    validator: _requiredValidator,
                                    enabled: !isSaving,
                                  ),
                                  const SizedBox(height: AppSizes.fieldGap),
                                  CustomTextField(
                                    controller: descriptionController,
                                    label: 'Description',
                                    prefixIcon: Icons.notes_rounded,
                                    minLines: 1,
                                    maxLines: 3,
                                    alignPrefixIconToTop: true,
                                    validator: _requiredValidator,
                                    enabled: !isSaving,
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
                                    minLines: 1,
                                    maxLines: 2,
                                    alignPrefixIconToTop: true,
                                    validator: _requiredValidator,
                                    enabled: !isSaving,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surface,
                                borderRadius: BorderRadius.circular(22),
                                border: Border.all(
                                  color: theme.colorScheme.outlineVariant
                                      .withValues(alpha: 0.60),
                                ),
                              ),
                              child: Column(
                                children: [
                                  CustomTextField(
                                    controller: budgetController,
                                    label: 'Budget / Offered price',
                                    hintText: '500',
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    prefixIcon: Icons.payments_outlined,
                                    validator: _budgetValidator,
                                    enabled: !isSaving,
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
                                      prefixIcon: Icon(
                                        Icons.star_outline_rounded,
                                      ),
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
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
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
            150,
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
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide(
                    color: Theme.of(
                      context,
                    ).colorScheme.outlineVariant.withValues(alpha: 0.68),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide(
                    color: Theme.of(context).colorScheme.primary,
                    width: 1.4,
                  ),
                ),
                suffixIcon: searchController.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        onPressed: searchController.clear,
                        icon: const Icon(Icons.close_rounded),
                      ),
              ),
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

class _CustomerBookingsSection extends StatefulWidget {
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
  State<_CustomerBookingsSection> createState() =>
      _CustomerBookingsSectionState();
}

class _CustomerBookingsSectionState extends State<_CustomerBookingsSection> {
  static const List<String> _filters = [
    'All',
    'Pending',
    'Completed',
    'Cancelled',
  ];

  String _selectedFilter = 'All';

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ProviderBookingModel>>(
      stream: widget.bookingsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final bookings = snapshot.data ?? const <ProviderBookingModel>[];
        final filteredBookings = bookings
            .where((booking) => _matchesFilter(booking, _selectedFilter))
            .toList();
        final emptyCopy = _emptyCopyForFilter(_selectedFilter);

        return ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSizes.pagePadding,
            0,
            AppSizes.pagePadding,
            150,
          ),
          children: [
            const _SectionHeader(
              title: 'My bookings',
              description:
                  'Track service requests, contact providers, and cancel active bookings.',
            ),
            const SizedBox(height: 14),
            _BookingStatusFilter(
              selectedFilter: _selectedFilter,
              filters: _filters,
              onChanged: (filter) {
                setState(() {
                  _selectedFilter = filter;
                });
              },
            ),
            const SizedBox(height: 18),
            if (filteredBookings.isEmpty)
              _EmptyFeedCard(
                title: emptyCopy.title,
                description: emptyCopy.description,
              )
            else
              for (final booking in filteredBookings) ...[
                _CustomerBookingCard(
                  booking: booking,
                  onCancel: () => widget.onCancelBooking(booking),
                  onCallProvider: () => widget.onCallProvider(booking),
                  onOpenChat: () => widget.onOpenChat(booking),
                ),
                const SizedBox(height: 16),
              ],
          ],
        );
      },
    );
  }

  bool _matchesFilter(ProviderBookingModel booking, String filter) {
    switch (filter) {
      case 'Pending':
        return booking.isPending || booking.isAccepted;
      case 'Completed':
        return booking.isCompleted;
      case 'Cancelled':
        final status = booking.status.trim().toLowerCase();
        return booking.isCancelled ||
            status == 'declined' ||
            status.startsWith('cancelled');
      case 'All':
      default:
        return true;
    }
  }

  _BookingEmptyCopy _emptyCopyForFilter(String filter) {
    return switch (filter) {
      'Pending' => const _BookingEmptyCopy(
        title: 'No pending bookings.',
        description: 'New requests and accepted bookings will appear here.',
      ),
      'Completed' => const _BookingEmptyCopy(
        title: 'No completed bookings yet.',
        description: 'Finished services will move into this section.',
      ),
      'Cancelled' => const _BookingEmptyCopy(
        title: 'No cancelled bookings.',
        description: 'Cancelled and declined requests will appear here.',
      ),
      _ => const _BookingEmptyCopy(
        title: 'No bookings yet.',
        description:
            'Booked services will appear here with contact and payment status.',
      ),
    };
  }
}

class _BookingEmptyCopy {
  const _BookingEmptyCopy({required this.title, required this.description});

  final String title;
  final String description;
}

class _BookingStatusFilter extends StatelessWidget {
  const _BookingStatusFilter({
    required this.selectedFilter,
    required this.filters,
    required this.onChanged,
  });

  final String selectedFilter;
  final List<String> filters;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final background = theme.tokens.primarySoft;
    final unselectedColor = theme.textTheme.bodyMedium?.color;

    return LayoutBuilder(
      builder: (context, constraints) {
        final useCompactLayout = constraints.maxWidth < 390;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: theme.colorScheme.primary.withValues(alpha: 0.10),
            ),
          ),
          child: Row(
            children: [
              for (final filter in filters) ...[
                Expanded(
                  child: _BookingStatusFilterButton(
                    label: filter,
                    selected: filter == selectedFilter,
                    unselectedColor: unselectedColor,
                    compact: useCompactLayout,
                    onPressed: () => onChanged(filter),
                  ),
                ),
                if (filter != filters.last) const SizedBox(width: 4),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _BookingStatusFilterButton extends StatelessWidget {
  const _BookingStatusFilterButton({
    required this.label,
    required this.selected,
    required this.unselectedColor,
    required this.compact,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final Color? unselectedColor;
  final bool compact;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: selected ? theme.colorScheme.primary : Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 6 : 10,
            vertical: 10,
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: theme.textTheme.labelLarge?.copyWith(
              color: selected ? theme.colorScheme.onPrimary : unselectedColor,
              fontSize: compact ? 12 : null,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
            ),
          ),
        ),
      ),
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
    final tokens = theme.tokens;

    return Container(
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
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: tokens.primarySoft,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: theme.colorScheme.primary.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Icon(
                    Icons.calendar_month_rounded,
                    color: theme.colorScheme.primary,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        booking.serviceTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          height: 1.12,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        booking.providerName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.textTheme.bodyMedium?.color?.withValues(
                            alpha: 0.68,
                          ),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                _BookingStatusPill(status: booking.status),
              ],
            ),
            const SizedBox(height: 18),
            Divider(
              height: 1,
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.70),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _BookingMetaPill(
                  icon: Icons.calendar_today_outlined,
                  label: booking.selectedDate == null
                      ? 'Date not set'
                      : _formatDate(booking.selectedDate!),
                ),
                _BookingMetaPill(
                  icon: Icons.schedule_rounded,
                  label: booking.selectedTimeSlot.trim().isEmpty
                      ? 'Slot not set'
                      : booking.selectedTimeSlot,
                ),
                _BookingMetaPill(
                  icon: Icons.account_balance_wallet_outlined,
                  label:
                      'Payment: ${_formatPaymentStatus(booking.paymentStatus)}',
                ),
                _BookingMetaPill(
                  icon: Icons.payments_outlined,
                  label: _formatCurrency(booking.totalAmount),
                ),
              ],
            ),
            if (booking.serviceAddress.trim().isNotEmpty) ...[
              const SizedBox(height: 18),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: tokens.primarySoft,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.location_on_outlined,
                      size: 20,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      booking.serviceAddress,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        height: 1.45,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (booking.notes.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Notes: ${booking.notes}',
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
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                  border: Border.all(
                    color: theme.colorScheme.error.withValues(alpha: 0.16),
                  ),
                ),
                child: Text(
                  'Cancellation fees: provider ${_formatCurrency(booking.providerCancellationFee)}, platform ${_formatCurrency(booking.platformCancellationFee)}.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _showBookingDetails(context),
                icon: const Icon(Icons.receipt_long_outlined),
                label: const Text('View booking details'),
              ),
            ),
            if (!booking.isCancelled) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _BookingOutlinedAction(
                      icon: Icons.call_outlined,
                      label: 'Call',
                      onPressed: onCallProvider,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _BookingOutlinedAction(
                      icon: Icons.chat_bubble_outline_rounded,
                      label: 'Chat',
                      onPressed: onOpenChat,
                    ),
                  ),
                ],
              ),
              if (booking.canCustomerCancel) ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.colorScheme.error,
                      side: BorderSide(
                        color: theme.colorScheme.error.withValues(alpha: 0.45),
                      ),
                    ),
                    onPressed: onCancel,
                    icon: const Icon(Icons.cancel_outlined),
                    label: const Text('Cancel booking'),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  void _showBookingDetails(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      showDragHandle: false,
      builder: (sheetContext) {
        return _CustomerBookingDetailsSheet(
          booking: booking,
          onCancel: onCancel,
          onCallProvider: onCallProvider,
          onOpenChat: onOpenChat,
        );
      },
    );
  }
}

class _CustomerBookingDetailsSheet extends StatelessWidget {
  const _CustomerBookingDetailsSheet({
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
    final tokens = theme.tokens;

    void closeThen(VoidCallback action) {
      Navigator.of(context).pop();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        action();
      });
    }

    return SafeArea(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 640),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 32,
                offset: const Offset(0, -10),
              ),
            ],
          ),
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              AppSizes.pagePadding,
              14,
              AppSizes.pagePadding,
              MediaQuery.of(context).viewInsets.bottom + AppSizes.pagePadding,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    IconButton(
                      tooltip: 'Back',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back_rounded),
                      style: IconButton.styleFrom(
                        backgroundColor: tokens.primarySoft,
                        foregroundColor: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            booking.serviceTitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            booking.providerName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.textTheme.bodyMedium?.color
                                  ?.withValues(alpha: 0.68),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    _BookingStatusPill(status: booking.status),
                  ],
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: tokens.subtleSurface,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: theme.colorScheme.outlineVariant.withValues(
                        alpha: 0.55,
                      ),
                    ),
                  ),
                  child: Column(
                    children: [
                      _JobDetailRow(
                        icon: Icons.calendar_today_outlined,
                        label: 'Date',
                        value: booking.selectedDate == null
                            ? 'Date not set'
                            : _formatDate(booking.selectedDate!),
                      ),
                      _JobDetailRow(
                        icon: Icons.schedule_rounded,
                        label: 'Time',
                        value: booking.selectedTimeSlot.trim().isEmpty
                            ? 'Slot not set'
                            : booking.selectedTimeSlot,
                      ),
                      _JobDetailRow(
                        icon: Icons.account_balance_wallet_outlined,
                        label: 'Payment',
                        value: _formatPaymentStatus(booking.paymentStatus),
                      ),
                      _JobDetailRow(
                        icon: Icons.payments_outlined,
                        label: 'Total',
                        value: _formatCurrency(booking.totalAmount),
                      ),
                      _JobDetailRow(
                        icon: Icons.location_on_outlined,
                        label: 'Service address',
                        value: booking.serviceAddress.trim().isEmpty
                            ? 'Address not listed'
                            : booking.serviceAddress.trim(),
                        isLast: booking.notes.trim().isEmpty,
                      ),
                      if (booking.notes.trim().isNotEmpty)
                        _JobDetailRow(
                          icon: Icons.notes_rounded,
                          label: 'Notes',
                          value: booking.notes.trim(),
                          isLast: true,
                        ),
                    ],
                  ),
                ),
                if (booking.isCancelled &&
                    (booking.providerCancellationFee > 0 ||
                        booking.platformCancellationFee > 0)) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.error.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                      border: Border.all(
                        color: theme.colorScheme.error.withValues(alpha: 0.16),
                      ),
                    ),
                    child: Text(
                      'Cancellation fees: provider ${_formatCurrency(booking.providerCancellationFee)}, platform ${_formatCurrency(booking.platformCancellationFee)}.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                        fontWeight: FontWeight.w700,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
                if (!booking.isCancelled) ...[
                  const SizedBox(height: AppSizes.sectionGap),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => closeThen(onCallProvider),
                          icon: const Icon(Icons.call_outlined),
                          label: const Text('Call'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => closeThen(onOpenChat),
                          icon: const Icon(Icons.chat_bubble_outline_rounded),
                          label: const Text('Chat'),
                        ),
                      ),
                    ],
                  ),
                  if (booking.canCustomerCancel) ...[
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: theme.colorScheme.error,
                        side: BorderSide(
                          color: theme.colorScheme.error.withValues(
                            alpha: 0.45,
                          ),
                        ),
                      ),
                      onPressed: () => closeThen(onCancel),
                      icon: const Icon(Icons.cancel_outlined),
                      label: const Text('Cancel booking'),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BookingStatusPill extends StatelessWidget {
  const _BookingStatusPill({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final normalizedStatus = status.trim().toLowerCase();
    final background = switch (normalizedStatus) {
      'accepted' => theme.tokens.primarySoft,
      'completed' => theme.tokens.successSoft,
      'cancelled_by_customer' ||
      'declined' => theme.colorScheme.error.withValues(alpha: 0.10),
      _ => theme.tokens.subtleSurface,
    };
    final foreground =
        normalizedStatus == 'cancelled_by_customer' ||
            normalizedStatus == 'declined'
        ? theme.colorScheme.error
        : AppTheme.resolveOnColor(background);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _formatBookingStatus(status),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: foreground,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _BookingMetaPill extends StatelessWidget {
  const _BookingMetaPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final background = theme.tokens.subtleSurface;
    final maxLabelWidth = (MediaQuery.sizeOf(context).width - 150)
        .clamp(90.0, 420.0)
        .toDouble();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.primary),
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
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BookingOutlinedAction extends StatelessWidget {
  const _BookingOutlinedAction({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Flexible(
            child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ],
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
        ...?(action == null ? null : [action!]),
      ],
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
    final locationLabel = service.location.trim().isEmpty
        ? 'Location not listed'
        : service.location.trim();

    return Container(
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
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: tokens.primarySoft,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: theme.colorScheme.primary.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Icon(
                    Icons.home_repair_service_rounded,
                    color: theme.colorScheme.primary,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        service.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          height: 1.12,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        '${service.providerName} | ${service.category}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.textTheme.bodyMedium?.color?.withValues(
                            alpha: 0.68,
                          ),
                          fontWeight: FontWeight.w600,
                          height: 1.28,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                _ServiceRatingPill(rating: service.rating),
              ],
            ),
            const SizedBox(height: 18),
            Divider(
              height: 1,
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.70),
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
                _ServiceMetaPill(
                  icon: Icons.payments_outlined,
                  label: 'PHP ${service.price.toStringAsFixed(0)} fixed',
                ),
                _ServiceMetaPill(
                  icon: Icons.location_on_outlined,
                  label: locationLabel,
                ),
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

class _ServiceRatingPill extends StatelessWidget {
  const _ServiceRatingPill({required this.rating});

  final double rating;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: theme.tokens.subtleSurface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.50),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star_rounded, size: 16, color: theme.colorScheme.primary),
          const SizedBox(width: 5),
          Text(
            '${rating.toStringAsFixed(1)} stars',
            style: TextStyle(
              color: AppTheme.resolveOnColor(theme.tokens.subtleSurface),
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _ServiceMetaPill extends StatelessWidget {
  const _ServiceMetaPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final background = theme.tokens.subtleSurface;
    final maxLabelWidth = (MediaQuery.sizeOf(context).width - 150)
        .clamp(90.0, 420.0)
        .toDouble();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.primary),
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
              ),
            ),
          ),
        ],
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

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showDetailsSheet(context),
        borderRadius: BorderRadius.circular(24),
        child: Ink(
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
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (job.photoUrl.trim().isNotEmpty) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                    child: Image.network(
                      job.photoUrl,
                      height: 160,
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
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: tokens.accentSoft,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.campaign_outlined,
                        color: AppTheme.resolveOnColor(tokens.accentSoft),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            job.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              height: 1.12,
                            ),
                          ),
                          const SizedBox(height: 7),
                          Text(
                            job.description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.textTheme.bodyMedium?.color
                                  ?.withValues(alpha: 0.70),
                              height: 1.38,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    _JobStatusPill(label: job.status),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      'View details',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 18,
                      color: theme.colorScheme.primary,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showDetailsSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      showDragHandle: false,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        final tokens = theme.tokens;

        return SafeArea(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 640),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(30),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 32,
                    offset: const Offset(0, -10),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  AppSizes.pagePadding,
                  14,
                  AppSizes.pagePadding,
                  MediaQuery.of(sheetContext).viewInsets.bottom +
                      AppSizes.pagePadding,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          tooltip: 'Back',
                          onPressed: () => Navigator.of(sheetContext).pop(),
                          icon: const Icon(Icons.arrow_back_rounded),
                          style: IconButton.styleFrom(
                            backgroundColor: tokens.primarySoft,
                            foregroundColor: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Job details',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              height: 1.1,
                            ),
                          ),
                        ),
                        _JobStatusPill(label: job.status),
                      ],
                    ),
                    const SizedBox(height: 18),
                    if (job.photoUrl.trim().isNotEmpty) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(22),
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
                      const SizedBox(height: 18),
                    ],
                    Text(
                      job.title,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        height: 1.1,
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
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: tokens.subtleSurface,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: theme.colorScheme.outlineVariant.withValues(
                            alpha: 0.55,
                          ),
                        ),
                      ),
                      child: Column(
                        children: [
                          _JobDetailRow(
                            icon: Icons.category_outlined,
                            label: 'Category',
                            value: job.category,
                          ),
                          _JobDetailRow(
                            icon: Icons.payments_outlined,
                            label: 'Budget',
                            value: '${_formatCurrency(job.budget)} budget',
                          ),
                          _JobDetailRow(
                            icon: Icons.speed_rounded,
                            label: 'Difficulty',
                            value: job.difficulty,
                          ),
                          _JobDetailRow(
                            icon: Icons.location_on_outlined,
                            label: 'Location',
                            value: job.readableLocation,
                            isLast: job.ratingFilter == null,
                          ),
                          if (job.ratingFilter != null)
                            _JobDetailRow(
                              icon: Icons.star_rounded,
                              label: 'Provider rating',
                              value:
                                  '${job.ratingFilter!.toStringAsFixed(job.ratingFilter! % 1 == 0 ? 0 : 1)}+ stars',
                              isLast: true,
                            ),
                        ],
                      ),
                    ),
                    if (canManage) ...[
                      const SizedBox(height: AppSizes.sectionGap),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: () {
                                Navigator.of(sheetContext).pop();
                                WidgetsBinding.instance.addPostFrameCallback((
                                  _,
                                ) {
                                  onEdit();
                                });
                              },
                              icon: const Icon(Icons.edit_outlined),
                              label: const Text('Edit post'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: theme.colorScheme.error,
                                side: BorderSide(
                                  color: theme.colorScheme.error.withValues(
                                    alpha: 0.45,
                                  ),
                                ),
                              ),
                              onPressed: () {
                                Navigator.of(sheetContext).pop();
                                WidgetsBinding.instance.addPostFrameCallback((
                                  _,
                                ) {
                                  onDelete();
                                });
                              },
                              icon: const Icon(Icons.delete_outline_rounded),
                              label: const Text('Delete'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _JobStatusPill extends StatelessWidget {
  const _JobStatusPill({required this.label});

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
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: AppTheme.resolveOnColor(background),
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _JobDetailRow extends StatelessWidget {
  const _JobDetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.isLast = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: theme.tokens.primarySoft,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 18, color: theme.colorScheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.textTheme.bodySmall?.color?.withValues(
                          alpha: 0.62,
                        ),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      value,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (!isLast) ...[
            const SizedBox(height: 14),
            Divider(
              height: 1,
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.65),
            ),
          ],
        ],
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

String _formatCurrency(double value) => 'PHP ${value.toStringAsFixed(2)}';

String _formatBookingStatus(String status) {
  return switch (status.trim().toLowerCase()) {
    'pending' => 'Pending',
    'accepted' => 'Accepted',
    'completed' => 'Completed',
    'declined' => 'Declined',
    'cancelled_by_customer' => 'Cancelled',
    _ => _titleizeStatus(status),
  };
}

String _formatPaymentStatus(String status) {
  return switch (status.trim().toLowerCase()) {
    'pending' => 'Pending',
    'paid' => 'Paid',
    'failed' => 'Failed',
    'refunded' => 'Refunded',
    'cancelled_fee_charged' => 'Fee charged',
    _ => _titleizeStatus(status),
  };
}

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
