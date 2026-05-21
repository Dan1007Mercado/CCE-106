import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/helpers.dart';
import '../../../../core/widgets/brand_logo.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../../../core/widgets/profile_avatar.dart';
import '../../../../routes/app_router.dart';
import '../../../auth/bloc/auth_bloc.dart';
import '../../../auth/data/models/user_model.dart';
import '../../data/models/job_post_model.dart';
import '../../data/models/service_listing_model.dart';
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

  static const List<double> _ratings = [3, 4, 4.5];

  final CustomerService _customerService = CustomerService();
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
    _tabController = TabController(length: 2, vsync: this);
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
                    jobsStream: _customerService.streamCustomerJobs(user.uid),
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
  const _CustomerJobsSection({required this.jobsStream});

  final Stream<List<JobPostModel>> jobsStream;

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
                _JobFeedCard(job: job),
                const SizedBox(height: 16),
              ],
          ],
        );
      },
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
              children: [
                CircleAvatar(
                  backgroundColor: tokens.primarySoft,
                  child: Icon(
                    Icons.home_repair_service_rounded,
                    color: AppTheme.resolveOnColor(tokens.primarySoft),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        service.providerName,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        service.category,
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
            const SizedBox(height: 16),
            Text(
              service.title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
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
  const _JobFeedCard({required this.job});

  final JobPostModel job;

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
              children: [
                CircleAvatar(
                  backgroundColor: tokens.accentSoft,
                  child: Icon(
                    Icons.campaign_outlined,
                    color: AppTheme.resolveOnColor(tokens.accentSoft),
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
