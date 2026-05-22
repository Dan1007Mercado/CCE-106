import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_sizes.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../../../core/widgets/profile_avatar.dart';
import '../../../../routes/app_router.dart';
import '../../../auth/bloc/auth_bloc.dart';
import '../../../auth/bloc/auth_event.dart';
import '../../../auth/data/models/user_model.dart';
import '../../data/models/provider_application_model.dart';
import '../../data/services/provider_application_service.dart';
import '../widgets/provider_application_form.dart';
import '../widgets/provider_application_status_sheet.dart';

class ProviderProfilePage extends StatelessWidget {
  const ProviderProfilePage({super.key});

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

    final applicationService = ProviderApplicationService();
    return StreamBuilder<ProviderApplicationModel?>(
      stream: applicationService.streamLatestForProvider(user.uid),
      builder: (context, snapshot) {
        final application = snapshot.data;
        return _ProviderProfileContent(user: user, application: application);
      },
    );
  }
}

class _ProviderProfileContent extends StatelessWidget {
  const _ProviderProfileContent({
    required this.user,
    required this.application,
  });

  final UserModel user;
  final ProviderApplicationModel? application;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final secondaryText = theme.textTheme.bodyMedium?.color?.withValues(
      alpha: 0.74,
    );
    final status = application?.status ?? user.providerVerificationStatus;

    return Scaffold(
      appBar: AppBar(title: const Text('Provider profile')),
      body: ListView(
        padding: const EdgeInsets.all(AppSizes.pagePadding),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSizes.cardPadding),
              child: Column(
                children: [
                  ProfileAvatar(
                    radius: 40,
                    name: user.displayName,
                    imageProvider: user.profilePic.trim().isEmpty
                        ? null
                        : NetworkImage(user.profilePic),
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
                      color: secondaryText,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 18),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(
                            context,
                          ).pushNamed(AppRouter.editProviderProfileRoute);
                        },
                        icon: const Icon(Icons.tune_rounded),
                        label: const Text('Edit profile'),
                      ),
                      FilledButton.icon(
                        onPressed: () => _openApplicationAction(context),
                        icon: const Icon(Icons.assignment_ind_outlined),
                        label: Text(_applicationActionLabel(status)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSizes.sectionGap),
          _ProfileInfoCard(
            title: 'Provider summary',
            children: [
              _ProfileRow(label: 'Role', value: 'Service Provider'),
              _ProfileRow(
                label: 'Phone',
                value: user.phone,
                emptyLabel: 'Add a phone number',
              ),
              _ProfileRow(
                label: 'Address',
                value: user.locationLabel,
                emptyLabel: 'Add a provider address',
              ),
              _ProfileRow(
                label: 'Provider verification',
                value: _formatStatus(status),
              ),
              _ProfileRow(
                label: 'Verified provider',
                value:
                    user.isApprovedProvider || application?.isApproved == true
                    ? 'Yes'
                    : 'No',
              ),
              if (application != null) ...[
                _ProfileRow(
                  label: 'Skill category',
                  value: application!.skillCategory,
                ),
                _ProfileRow(
                  label: 'Experience',
                  value: '${application!.experienceYears} years',
                ),
                if (application!.isRejected)
                  _ProfileRow(
                    label: 'Admin remarks',
                    value: application!.adminRemarks,
                    emptyLabel: 'No remarks provided',
                  ),
              ],
            ],
          ),
          const SizedBox(height: AppSizes.sectionGap),
          _ProfileInfoCard(
            title: 'System preferences',
            children: [
              _ProfileRow(label: 'Theme', value: user.themeMode.label),
              _ProfileRow(label: 'Photos', value: user.photosPermission.label),
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
        ],
      ),
    );
  }

  void _openApplicationAction(BuildContext context) {
    final status = application?.status.trim().toLowerCase();
    if (application != null && status != 'rejected') {
      _openApplicationStatus(context, application!);
      return;
    }

    _openApplicationForm(context);
  }

  void _openApplicationStatus(
    BuildContext context,
    ProviderApplicationModel selectedApplication,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return ProviderApplicationStatusSheet(
          application: selectedApplication,
          onResubmit: selectedApplication.isRejected
              ? () {
                  Navigator.of(sheetContext).pop();
                  Future<void>.microtask(() {
                    _openApplicationForm(context);
                  });
                }
              : null,
        );
      },
    );
  }

  void _openApplicationForm(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return ProviderApplicationForm(
          provider: user,
          application: application,
          onSubmitted: () {
            context.read<AuthBloc>().add(
              AuthUserProfileUpdated(
                user.copyWith(
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

  String _applicationActionLabel(String status) {
    return switch (status.trim().toLowerCase()) {
      'pending' => 'View Application Status',
      'approved' => 'View Application Status',
      'rejected' => 'Resubmit Application',
      _ => 'Apply for Provider Verification',
    };
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
    final secondaryText = Theme.of(
      context,
    ).textTheme.bodyLarge?.color?.withValues(alpha: 0.74);

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
                color: isEmpty ? secondaryText : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _formatStatus(String status) {
  return switch (status.trim().toLowerCase()) {
    'pending' => 'Pending',
    'approved' => 'Approved',
    'rejected' => 'Rejected',
    _ => 'No application',
  };
}
