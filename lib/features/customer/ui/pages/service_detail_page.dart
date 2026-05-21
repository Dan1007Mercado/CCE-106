import 'package:flutter/material.dart';

import '../../../../core/constants/app_sizes.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../routes/app_router.dart';
import '../../data/models/service_listing_model.dart';

class ServiceDetailPage extends StatefulWidget {
  const ServiceDetailPage({required this.service, super.key});

  final ServiceListingModel? service;

  @override
  State<ServiceDetailPage> createState() => _ServiceDetailPageState();
}

class _ServiceDetailPageState extends State<ServiceDetailPage> {
  @override
  Widget build(BuildContext context) {
    final service = widget.service;
    final theme = Theme.of(context);
    final tokens = theme.tokens;

    if (service == null) {
      return const Scaffold(
        body: Center(child: Text('Service details are unavailable right now.')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Service details')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSizes.pagePadding,
          0,
          AppSizes.pagePadding,
          AppSizes.pagePadding,
        ),
        children: [
          _ServiceBanner(service: service),
          const SizedBox(height: AppSizes.sectionGap),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSizes.cardPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: tokens.primarySoft,
                        child: Icon(
                          Icons.engineering_rounded,
                          color: AppTheme.resolveOnColor(tokens.primarySoft),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              service.providerName,
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              service.location.trim().isEmpty
                                  ? 'Provider location not listed'
                                  : service.location,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.textTheme.bodyMedium?.color
                                    ?.withValues(alpha: 0.72),
                              ),
                            ),
                          ],
                        ),
                      ),
                      _InfoPill(
                        icon: Icons.star_rounded,
                        label: service.rating == 0
                            ? 'New'
                            : service.rating.toStringAsFixed(1),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  Text(
                    'Description',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    service.description,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.textTheme.bodyLarge?.color?.withValues(
                        alpha: 0.76,
                      ),
                      height: 1.55,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSizes.sectionGap),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSizes.cardPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Available slots',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _SlotPill(label: 'Tomorrow morning'),
                      _SlotPill(label: 'Weekday afternoon'),
                      _SlotPill(label: 'Weekend schedule'),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'You can book with a valid service address. Payment stays pending until the provider marks the service as done.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.textTheme.bodyMedium?.color?.withValues(
                        alpha: 0.72,
                      ),
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSizes.sectionGap),
          CustomButton(
            label: 'Book Service',
            icon: Icons.calendar_month_rounded,
            onPressed: () {
              Navigator.of(
                context,
              ).pushNamed(AppRouter.bookingRoute, arguments: service);
            },
          ),
        ],
      ),
    );
  }
}

class _ServiceBanner extends StatelessWidget {
  const _ServiceBanner({required this.service});

  final ServiceListingModel service;

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
          Icon(
            Icons.home_repair_service_rounded,
            size: 44,
            color: Colors.white.withValues(alpha: 0.92),
          ),
          const SizedBox(height: 18),
          Text(
            service.title,
            style: theme.textTheme.headlineMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _HeroPill(label: service.category),
              _HeroPill(label: 'PHP ${service.price.toStringAsFixed(0)}'),
              _HeroPill(
                label: service.rating == 0
                    ? 'New provider'
                    : '${service.rating.toStringAsFixed(1)} rating',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroPill extends StatelessWidget {
  const _HeroPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final background = Theme.of(context).tokens.subtleSurface;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppTheme.resolveOnColor(background)),
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

class _SlotPill extends StatelessWidget {
  const _SlotPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final background = Theme.of(context).tokens.primarySoft;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
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
