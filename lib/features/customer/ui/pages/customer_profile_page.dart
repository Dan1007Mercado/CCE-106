import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../../../routes/app_router.dart';
import '../../../auth/bloc/auth_bloc.dart';

class CustomerProfilePage extends StatelessWidget {
  const CustomerProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.select((AuthBloc bloc) => bloc.state.user);

    if (user == null) {
      return const Scaffold(
        body: Center(
          child: LoadingIndicator(message: 'Loading your profile...'),
        ),
      );
    }

    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.of(context).pushNamed(AppRouter.settingsRoute);
            },
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSizes.pagePadding),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSizes.cardPadding),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.14),
                    backgroundImage: user.profilePic.trim().isEmpty
                        ? null
                        : NetworkImage(user.profilePic),
                    child: user.profilePic.trim().isEmpty
                        ? const Icon(
                            Icons.person_outline_rounded,
                            size: 36,
                            color: AppColors.primary,
                          )
                        : null,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    user.displayName,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    user.email,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 18),
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pushNamed(AppRouter.editProfileRoute);
                    },
                    icon: const Icon(Icons.tune_rounded),
                    label: const Text('Edit profile'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSizes.sectionGap),
          _ProfileInfoCard(
            title: 'Profile summary',
            children: [
              _ProfileRow(label: 'First name', value: user.firstName),
              _ProfileRow(
                label: 'Middle name',
                value: user.middleName,
                emptyLabel: 'Not provided',
              ),
              _ProfileRow(label: 'Last name', value: user.lastName),
              _ProfileRow(
                label: 'Suffix',
                value: user.suffix,
                emptyLabel: 'Not provided',
              ),
              _ProfileRow(
                label: 'Phone',
                value: user.phone,
                emptyLabel: 'Add a 09XXXXXXXXX number',
              ),
              _ProfileRow(
                label: 'Location',
                value: user.locationLabel,
                emptyLabel: 'Capture your GPS location from Manage profile',
              ),
              if (user.hasBookingLocation)
                _ProfileRow(
                  label: 'Coordinates',
                  value:
                      '${user.latitude!.toStringAsFixed(5)}, ${user.longitude!.toStringAsFixed(5)}',
                ),
              _ProfileRow(label: 'Role', value: user.role.label),
            ],
          ),
          const SizedBox(height: AppSizes.sectionGap),
          _ProfileInfoCard(
            title: 'System preferences',
            children: [
              _ProfileRow(label: 'Theme', value: user.themeMode.label),
              _ProfileRow(
                label: 'Photos',
                value: user.photosPermission.label,
              ),
              _ProfileRow(
                label: 'Notifications',
                value: user.notificationsPermission.label,
              ),
              _ProfileRow(
                label: 'Location permission',
                value: user.locationPermission.label,
              ),
            ],
          ),
          const SizedBox(height: AppSizes.sectionGap),
          _ProfileInfoCard(
            title: 'Booking readiness',
            children: [
              Text(
                user.isReadyForBooking
                    ? 'Your profile is ready for fixed-price booking.'
                    : 'Bookings stay disabled until your 09XXXXXXXXX mobile number and device GPS coordinates are saved.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Profile editing lives in Settings > Manage profile.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProfileInfoCard extends StatelessWidget {
  const _ProfileInfoCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

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
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({
    required this.label,
    required this.value,
    this.emptyLabel,
  });

  final String label;
  final String value;
  final String? emptyLabel;

  @override
  Widget build(BuildContext context) {
    final isEmpty = value.trim().isEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
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
              isEmpty ? (emptyLabel ?? 'Not provided yet') : value,
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: isEmpty
                    ? AppColors.textSecondary
                    : AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
