import 'package:flutter/material.dart';

import '../../../../core/constants/app_sizes.dart';
import '../../data/models/provider_application_model.dart';

class ProviderApplicationStatusSheet extends StatelessWidget {
  const ProviderApplicationStatusSheet({
    required this.application,
    this.onResubmit,
    super.key,
  });

  final ProviderApplicationModel application;
  final VoidCallback? onResubmit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = application.status.trim().toLowerCase();
    final isRejected = status == 'rejected';

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          AppSizes.pagePadding,
          8,
          AppSizes.pagePadding,
          MediaQuery.of(context).viewInsets.bottom + AppSizes.pagePadding,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  status == 'approved'
                      ? Icons.verified_rounded
                      : Icons.assignment_ind_outlined,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Application Status',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSizes.sectionGap),
            _StatusRow(label: 'Status', value: _formatStatus(status)),
            _StatusRow(label: 'Full name', value: application.fullName),
            _StatusRow(label: 'Valid ID type', value: application.validIdType),
            _StatusRow(
              label: 'Masked ID',
              value: application.maskedValidIdNumber,
            ),
            _StatusRow(
              label: 'Skill category',
              value: application.skillCategory,
            ),
            _StatusRow(
              label: 'Experience',
              value: '${application.experienceYears} years',
            ),
            _StatusRow(
              label: 'Coverage area',
              value: application.serviceLocationCoverage,
            ),
            _StatusRow(
              label: 'Submitted',
              value: _formatDate(application.createdAt),
            ),
            _StatusRow(
              label: 'Consent',
              value: application.verificationConsentAccepted
                  ? 'Accepted'
                  : 'Not recorded',
            ),
            _StatusRow(
              label: 'Reviewed',
              value: application.reviewedAt == null
                  ? 'Not reviewed yet'
                  : _formatDate(application.reviewedAt!),
            ),
            if (application.adminRemarks.trim().isNotEmpty)
              _StatusRow(
                label: 'Admin remarks',
                value: application.adminRemarks,
              ),
            const SizedBox(height: AppSizes.sectionGap),
            if (isRejected && onResubmit != null)
              FilledButton.icon(
                onPressed: onResubmit,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Resubmit Application'),
              )
            else
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded),
                label: const Text('Close'),
              ),
          ],
        ),
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final isEmpty = value.trim().isEmpty;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 132,
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(isEmpty ? 'Not provided' : value),
          ),
        ],
      ),
    );
  }
}

String _formatStatus(String status) {
  return switch (status) {
    'pending' => 'Pending Super Admin approval',
    'approved' => 'Approved',
    'rejected' => 'Rejected',
    _ => 'No application',
  };
}

String _formatDate(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}-$month-$day';
}
