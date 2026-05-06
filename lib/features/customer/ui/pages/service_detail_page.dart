import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/utils/helpers.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../routes/app_router.dart';
import '../../../auth/bloc/auth_bloc.dart';
import '../../../auth/data/models/user_model.dart';
import '../../data/models/service_listing_model.dart';
import '../../data/services/customer_service.dart';

class ServiceDetailPage extends StatefulWidget {
  const ServiceDetailPage({required this.service, super.key});

  final ServiceListingModel? service;

  @override
  State<ServiceDetailPage> createState() => _ServiceDetailPageState();
}

class _ServiceDetailPageState extends State<ServiceDetailPage> {
  final CustomerService _customerService = CustomerService();
  bool _isBooking = false;

  @override
  Widget build(BuildContext context) {
    final service = widget.service;
    final user = context.select((AuthBloc bloc) => bloc.state.user);

    if (service == null) {
      return const Scaffold(
        body: Center(child: Text('Service details are unavailable right now.')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Service details')),
      body: ListView(
        padding: const EdgeInsets.all(AppSizes.pagePadding),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSizes.cardPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: AppColors.primary.withValues(
                          alpha: 0.14,
                        ),
                        child: const Icon(
                          Icons.engineering_rounded,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              service.providerName,
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              service.category,
                              style: Theme.of(context).textTheme.bodyLarge
                                  ?.copyWith(color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    service.title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    service.description,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _DetailRow(
                    label: 'Rating',
                    value: '${service.rating.toStringAsFixed(1)} stars',
                  ),
                  _DetailRow(
                    label: 'Fixed price',
                    value: 'PHP ${service.price.toStringAsFixed(0)}',
                  ),
                  _DetailRow(
                    label: 'Location',
                    value: service.location.trim().isEmpty
                        ? 'Provider location not listed'
                        : service.location,
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
                    'Booking rules',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'This uses fixed pricing. Once you tap Book, the booking is created immediately with no bidding or negotiation step.',
                  ),
                  const SizedBox(height: 12),
                  Text(
                    user != null && user.isReadyForBooking
                        ? 'Your customer profile is ready for booking.'
                        : 'Add your 09XXXXXXXXX mobile number and capture your GPS location in Profile before booking.',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSizes.sectionGap),
          CustomButton(
            label: 'Book service',
            icon: Icons.calendar_month_rounded,
            isLoading: _isBooking,
            onPressed: user == null || !user.isReadyForBooking
                ? null
                : () => _book(user, service),
          ),
          if (user != null && !user.isReadyForBooking) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).pushNamed(AppRouter.editProfileRoute);
              },
              icon: const Icon(Icons.person_outline_rounded),
              label: const Text('Complete profile'),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _book(UserModel user, ServiceListingModel service) async {
    setState(() {
      _isBooking = true;
    });

    try {
      await _customerService.createBooking(customer: user, service: service);

      if (!mounted) {
        return;
      }

      Helpers.showSnackBar(context, 'Successful');
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
          _isBooking = false;
        });
      }
    }
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
