import 'package:flutter/material.dart';

import '../../../../core/constants/app_sizes.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/data/models/user_model.dart';
import '../../data/models/provider_application_model.dart';

class ProviderVerificationBanner extends StatelessWidget {
  const ProviderVerificationBanner({
    required this.user,
    required this.application,
    required this.onApply,
    super.key,
  });

  final UserModel user;
  final ProviderApplicationModel? application;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = (application?.status ?? user.providerVerificationStatus)
        .trim()
        .toLowerCase();
    final isApproved = user.isApprovedProvider || status == 'approved';
    final background = isApproved
        ? theme.tokens.successSoft
        : status == 'rejected'
        ? theme.colorScheme.error.withValues(alpha: 0.10)
        : theme.tokens.warningSoft;
    final foreground = AppTheme.resolveOnColor(background);
    final title = switch (status) {
      'approved' => 'Verified Service Provider',
      'pending' => 'Application pending',
      'rejected' => 'Application rejected',
      _ => 'Provider verification required',
    };
    final description = switch (status) {
      'approved' =>
        'You can post services, accept bookings, and complete provider work.',
      'pending' =>
        'Your application is pending Super Admin approval. Posting services and accepting bookings are locked.',
      'rejected' =>
        application?.adminRemarks.trim().isEmpty ?? true
            ? 'Please review your details and resubmit your application.'
            : application!.adminRemarks,
      _ =>
        'Submit a provider verification application before posting services or accepting bookings.',
    };
    final actionLabel = switch (status) {
      'approved' => 'View Application Status',
      'pending' => 'View Application Status',
      'rejected' => 'Resubmit Application',
      _ => 'Apply for Provider Verification',
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSizes.cardPadding),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
      ),
      child: Wrap(
        spacing: 16,
        runSpacing: 14,
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.spaceBetween,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isApproved
                          ? Icons.verified_rounded
                          : Icons.verified_user_outlined,
                      color: foreground,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: foreground,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: foreground.withValues(alpha: 0.82),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: foreground,
              side: BorderSide(color: foreground.withValues(alpha: 0.42)),
            ),
            onPressed: onApply,
            icon: const Icon(Icons.assignment_ind_outlined),
            label: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}
