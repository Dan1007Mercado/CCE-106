import 'package:flutter/material.dart';

import '../../../../core/constants/app_sizes.dart';
import '../../../../core/utils/helpers.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/custom_textfield.dart';
import '../../../auth/data/models/user_model.dart';
import '../../data/models/provider_application_model.dart';
import '../../data/services/provider_application_service.dart';

class ProviderApplicationForm extends StatefulWidget {
  const ProviderApplicationForm({
    required this.provider,
    required this.application,
    required this.onSubmitted,
    super.key,
  });

  final UserModel provider;
  final ProviderApplicationModel? application;
  final VoidCallback onSubmitted;

  @override
  State<ProviderApplicationForm> createState() =>
      _ProviderApplicationFormState();
}

class _ProviderApplicationFormState extends State<ProviderApplicationForm> {
  static const List<String> _validIdTypes = [
    "Driver's License",
    'National ID',
    'Passport',
    'UMID',
    "Voter's ID",
    'PhilHealth ID',
    'Postal ID',
    'SSS ID',
    'PRC ID',
    'TIN ID',
    'Barangay ID',
    'Other',
  ];

  static const List<String> _skillCategories = [
    'Plumbing',
    'Electrician',
    'Cleaning',
    'Carpentry',
    'Masonry',
  ];

  final _formKey = GlobalKey<FormState>();
  final _applicationService = ProviderApplicationService();
  late final TextEditingController _fullNameController;
  late final TextEditingController _firstNameController;
  late final TextEditingController _middleNameController;
  late final TextEditingController _lastNameController;
  late final TextEditingController _suffixController;
  late final TextEditingController _ageController;
  late final TextEditingController _birthDateController;
  late final TextEditingController _genderController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _addressController;
  late final TextEditingController _cityController;
  late final TextEditingController _provinceController;
  late final TextEditingController _validIdNumberController;
  late final TextEditingController _validIdDetailsController;
  late final TextEditingController _experienceController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _previousWorkController;
  late final TextEditingController _coverageController;
  late final TextEditingController _expectedRateController;

  late String _validIdType;
  late String _skillCategory;
  DateTime? _birthDate;
  bool _isSaving = false;
  bool _verificationConsentAccepted = false;

  @override
  void initState() {
    super.initState();
    final user = widget.provider;
    final application = widget.application;
    _fullNameController = TextEditingController(
      text: application?.fullName ?? user.legalName,
    );
    _firstNameController = TextEditingController(
      text: application?.firstName ?? user.firstName,
    );
    _middleNameController = TextEditingController(
      text: application?.middleName ?? user.middleName,
    );
    _lastNameController = TextEditingController(
      text: application?.lastName ?? user.lastName,
    );
    _suffixController = TextEditingController(
      text: application?.suffix ?? user.suffix,
    );
    _ageController = TextEditingController(
      text: (application?.age ?? 0) == 0 ? '' : application!.age.toString(),
    );
    _birthDate = application?.birthDate;
    _birthDateController = TextEditingController(
      text: _birthDate == null ? '' : _formatDate(_birthDate!),
    );
    _genderController = TextEditingController(text: application?.gender ?? '');
    _phoneController = TextEditingController(
      text: application?.phoneNumber ?? user.phone,
    );
    _emailController = TextEditingController(
      text: application?.email ?? user.email,
    );
    _addressController = TextEditingController(
      text: application?.address ?? user.address,
    );
    _cityController = TextEditingController(text: application?.city ?? '');
    _provinceController = TextEditingController(
      text: application?.province ?? '',
    );
    _validIdNumberController = TextEditingController(
      text: application?.validIdNumber ?? '',
    );
    _validIdDetailsController = TextEditingController(
      text: application?.validIdDetails ?? '',
    );
    _experienceController = TextEditingController(
      text: application == null ? '' : application.experienceYears.toString(),
    );
    _descriptionController = TextEditingController(
      text: application?.serviceDescription ?? '',
    );
    _previousWorkController = TextEditingController(
      text: application?.previousWorkDescription ?? '',
    );
    _coverageController = TextEditingController(
      text: application?.serviceLocationCoverage ?? user.locationLabel,
    );
    _expectedRateController = TextEditingController(
      text: application?.expectedRate?.toStringAsFixed(0) ?? '',
    );
    _validIdType = _validIdTypes.contains(application?.validIdType)
        ? application!.validIdType
        : _validIdTypes.first;
    _skillCategory = _skillCategories.contains(application?.skillCategory)
        ? application!.skillCategory
        : _skillCategories.first;
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _firstNameController.dispose();
    _middleNameController.dispose();
    _lastNameController.dispose();
    _suffixController.dispose();
    _ageController.dispose();
    _birthDateController.dispose();
    _genderController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _provinceController.dispose();
    _validIdNumberController.dispose();
    _validIdDetailsController.dispose();
    _experienceController.dispose();
    _descriptionController.dispose();
    _previousWorkController.dispose();
    _coverageController.dispose();
    _expectedRateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Form(
      key: _formKey,
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
            Text(
              'Provider Verification',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Submit text-based identity and service details for Super Admin review. Image uploads are disabled on the free plan.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.textTheme.bodyMedium?.color?.withValues(
                  alpha: 0.72,
                ),
                height: 1.4,
              ),
            ),
            const SizedBox(height: AppSizes.sectionGap),
            _SectionTitle(label: 'Personal details'),
            const SizedBox(height: AppSizes.fieldGap),
            CustomTextField(
              controller: _fullNameController,
              label: 'Full name',
              prefixIcon: Icons.badge_outlined,
              validator: _required,
            ),
            const SizedBox(height: AppSizes.fieldGap),
            _ResponsiveFieldRow(
              children: [
                CustomTextField(
                  controller: _firstNameController,
                  label: 'First name',
                  validator: _required,
                ),
                CustomTextField(
                  controller: _lastNameController,
                  label: 'Last name',
                  validator: _required,
                ),
              ],
            ),
            const SizedBox(height: AppSizes.fieldGap),
            _ResponsiveFieldRow(
              children: [
                CustomTextField(
                  controller: _middleNameController,
                  label: 'Middle name',
                  hintText: 'Optional',
                ),
                CustomTextField(
                  controller: _suffixController,
                  label: 'Suffix',
                  hintText: 'Optional',
                ),
              ],
            ),
            const SizedBox(height: AppSizes.fieldGap),
            _ResponsiveFieldRow(
              children: [
                CustomTextField(
                  controller: _ageController,
                  label: 'Age',
                  keyboardType: TextInputType.number,
                  validator: _ageValidator,
                ),
                CustomTextField(
                  controller: _genderController,
                  label: 'Gender',
                  hintText: 'Optional',
                ),
              ],
            ),
            const SizedBox(height: AppSizes.fieldGap),
            TextFormField(
              controller: _birthDateController,
              readOnly: true,
              enabled: !_isSaving,
              decoration: InputDecoration(
                labelText: 'Birth date',
                hintText: 'Optional',
                prefixIcon: const Icon(Icons.cake_outlined),
                suffixIcon: _birthDate == null
                    ? null
                    : IconButton(
                        tooltip: 'Clear birth date',
                        onPressed: _isSaving ? null : _clearBirthDate,
                        icon: const Icon(Icons.close_rounded),
                      ),
              ),
              onTap: _isSaving ? null : _pickBirthDate,
            ),
            const SizedBox(height: AppSizes.fieldGap),
            CustomTextField(
              controller: _phoneController,
              label: 'Phone number',
              keyboardType: TextInputType.phone,
              prefixIcon: Icons.phone_outlined,
              validator: _required,
            ),
            const SizedBox(height: AppSizes.fieldGap),
            CustomTextField(
              controller: _emailController,
              label: 'Email',
              keyboardType: TextInputType.emailAddress,
              prefixIcon: Icons.mail_outline_rounded,
              validator: _required,
            ),
            const SizedBox(height: AppSizes.fieldGap),
            CustomTextField(
              controller: _addressController,
              label: 'Address',
              prefixIcon: Icons.location_on_outlined,
              maxLines: 2,
              validator: _required,
            ),
            const SizedBox(height: AppSizes.fieldGap),
            _ResponsiveFieldRow(
              children: [
                CustomTextField(
                  controller: _cityController,
                  label: 'City',
                  validator: _required,
                ),
                CustomTextField(
                  controller: _provinceController,
                  label: 'Province',
                  validator: _required,
                ),
              ],
            ),
            const SizedBox(height: AppSizes.sectionGap),
            _SectionTitle(label: 'Valid ID details'),
            const SizedBox(height: AppSizes.fieldGap),
            DropdownButtonFormField<String>(
              value: _validIdType,
              decoration: const InputDecoration(
                labelText: 'Valid ID type',
                prefixIcon: Icon(Icons.credit_card_outlined),
              ),
              items: _validIdTypes
                  .map(
                    (type) => DropdownMenuItem(value: type, child: Text(type)),
                  )
                  .toList(),
              onChanged: _isSaving
                  ? null
                  : (value) {
                      if (value != null) {
                        setState(() => _validIdType = value);
                      }
                    },
            ),
            const SizedBox(height: AppSizes.fieldGap),
            CustomTextField(
              controller: _validIdNumberController,
              label: _validIdNumberLabel(_validIdType),
              prefixIcon: Icons.badge_outlined,
              validator: _required,
            ),
            const SizedBox(height: AppSizes.fieldGap),
            CustomTextField(
              controller: _validIdDetailsController,
              label: _validIdDetailsLabel(_validIdType),
              hintText: 'Optional',
              prefixIcon: Icons.notes_rounded,
              maxLines: 2,
            ),
            const SizedBox(height: AppSizes.sectionGap),
            _SectionTitle(label: 'Service details'),
            const SizedBox(height: AppSizes.fieldGap),
            DropdownButtonFormField<String>(
              value: _skillCategory,
              decoration: const InputDecoration(
                labelText: 'Skill category',
                prefixIcon: Icon(Icons.category_outlined),
              ),
              items: _skillCategories
                  .map(
                    (category) => DropdownMenuItem(
                      value: category,
                      child: Text(category),
                    ),
                  )
                  .toList(),
              onChanged: _isSaving
                  ? null
                  : (value) {
                      if (value != null) {
                        setState(() => _skillCategory = value);
                      }
                    },
            ),
            const SizedBox(height: AppSizes.fieldGap),
            CustomTextField(
              controller: _experienceController,
              label: 'Experience years',
              keyboardType: TextInputType.number,
              validator: _experienceValidator,
            ),
            const SizedBox(height: AppSizes.fieldGap),
            CustomTextField(
              controller: _descriptionController,
              label: 'Service description',
              maxLines: 3,
              validator: _required,
            ),
            const SizedBox(height: AppSizes.fieldGap),
            CustomTextField(
              controller: _previousWorkController,
              label: 'Previous work',
              hintText: 'Optional',
              maxLines: 2,
            ),
            const SizedBox(height: AppSizes.fieldGap),
            CustomTextField(
              controller: _coverageController,
              label: 'Service coverage area',
              validator: _required,
            ),
            const SizedBox(height: AppSizes.fieldGap),
            CustomTextField(
              controller: _expectedRateController,
              label: 'Expected rate',
              hintText: 'Optional',
              keyboardType: TextInputType.number,
              validator: _optionalNonNegativeNumber,
            ),
            const SizedBox(height: AppSizes.sectionGap),
            _ConsentSection(
              value: _verificationConsentAccepted,
              onChanged: _isSaving
                  ? null
                  : (value) {
                      setState(() {
                        _verificationConsentAccepted = value ?? false;
                      });
                    },
            ),
            const SizedBox(height: AppSizes.sectionGap),
            CustomButton(
              label: 'Submit Application',
              icon: Icons.verified_user_outlined,
              isLoading: _isSaving,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final initialDate =
        _birthDate ?? DateTime(now.year - 18, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate.isAfter(now) ? now : initialDate,
      firstDate: DateTime(1900),
      lastDate: now,
    );

    if (picked == null || !mounted) {
      return;
    }

    setState(() {
      _birthDate = picked;
      _birthDateController.text = _formatDate(picked);
    });
  }

  void _clearBirthDate() {
    setState(() {
      _birthDate = null;
      _birthDateController.clear();
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (!_verificationConsentAccepted) {
      Helpers.showSnackBar(
        context,
        'Accept the data collection consent before submitting.',
        isError: true,
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await _applicationService.submitApplication(
        provider: widget.provider,
        submission: ProviderApplicationSubmission(
          fullName: _fullNameController.text,
          firstName: _firstNameController.text,
          middleName: _middleNameController.text,
          lastName: _lastNameController.text,
          suffix: _suffixController.text,
          age: int.parse(_ageController.text.trim()),
          birthDate: _birthDate,
          gender: _genderController.text,
          phoneNumber: _phoneController.text,
          email: _emailController.text,
          address: _addressController.text,
          city: _cityController.text,
          province: _provinceController.text,
          validIdType: _validIdType,
          validIdNumber: _validIdNumberController.text,
          validIdDetails: _validIdDetailsController.text,
          skillCategory: _skillCategory,
          experienceYears: int.parse(_experienceController.text.trim()),
          serviceDescription: _descriptionController.text,
          previousWorkDescription: _previousWorkController.text,
          serviceLocationCoverage: _coverageController.text,
          expectedRate: double.tryParse(_expectedRateController.text.trim()),
          verificationConsentAccepted: _verificationConsentAccepted,
        ),
      );

      if (!mounted) {
        return;
      }

      Helpers.showSnackBar(context, 'Provider application submitted.');
      widget.onSubmitted();
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
          _isSaving = false;
        });
      }
    }
  }

  String? _required(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'This field is required.';
    }

    return null;
  }

  String? _ageValidator(String? value) {
    final parsed = int.tryParse(value?.trim() ?? '');
    if (parsed == null) {
      return 'Age is required.';
    }

    if (parsed < 18) {
      return 'Service providers must be at least 18 years old.';
    }

    return null;
  }

  String? _experienceValidator(String? value) {
    final parsed = int.tryParse(value?.trim() ?? '');
    if (parsed == null || parsed < 0) {
      return 'Experience years must be 0 or higher.';
    }

    return null;
  }

  String? _optionalNonNegativeNumber(String? value) {
    final cleaned = value?.trim() ?? '';
    if (cleaned.isEmpty) {
      return null;
    }

    final parsed = double.tryParse(cleaned);
    if (parsed == null || parsed < 0) {
      return 'Enter 0 or higher.';
    }

    return null;
  }

  String _formatDate(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }

  String _validIdNumberLabel(String type) {
    return switch (type) {
      "Driver's License" => "Driver's License Number",
      'National ID' => 'National ID Number / PSN or PCN',
      'Passport' => 'Passport Number',
      'UMID' => 'UMID CRN',
      "Voter's ID" => "Voter's ID Number",
      'PhilHealth ID' => 'PhilHealth Number',
      'Postal ID' => 'Postal ID Number',
      'SSS ID' => 'SSS Number',
      'PRC ID' => 'PRC License Number',
      'TIN ID' => 'TIN',
      'Barangay ID' => 'Barangay ID Number',
      _ => 'ID Number / Reference Number',
    };
  }

  String _validIdDetailsLabel(String type) {
    return switch (type) {
      "Driver's License" => 'Restriction code / expiration date / notes',
      'National ID' => 'Additional National ID details',
      'Passport' => 'Expiration date / issuing country',
      'UMID' => 'Additional UMID details',
      "Voter's ID" => 'Precinct / city / notes',
      'PhilHealth ID' => 'Additional PhilHealth details',
      'Postal ID' => 'Expiration date / notes',
      'SSS ID' => 'Additional SSS details',
      'PRC ID' => 'Profession / expiration date',
      'TIN ID' => 'Additional TIN details',
      'Barangay ID' => 'Barangay / city / issue date',
      _ => 'Describe the ID',
    };
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
    );
  }
}

class _ConsentSection extends StatelessWidget {
  const _ConsentSection({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool?>? onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Data collection notice',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'HandyMarket collects your personal details, contact information, service background, and valid ID details only for provider verification and safety review by the Super Admin. Your ID details will not be shown to customers.',
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
          ),
          const SizedBox(height: 10),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: value,
            onChanged: onChanged,
            title: const Text(
              'I confirm that the information I provided is true and I consent to HandyMarket collecting and processing my personal data for provider verification.',
            ),
          ),
        ],
      ),
    );
  }
}

class _ResponsiveFieldRow extends StatelessWidget {
  const _ResponsiveFieldRow({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final useColumns = constraints.maxWidth < 560;

        if (useColumns) {
          return Column(
            children: [
              for (var index = 0; index < children.length; index++) ...[
                children[index],
                if (index != children.length - 1)
                  const SizedBox(height: AppSizes.fieldGap),
              ],
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var index = 0; index < children.length; index++) ...[
              Expanded(child: children[index]),
              if (index != children.length - 1) const SizedBox(width: 10),
            ],
          ],
        );
      },
    );
  }
}
