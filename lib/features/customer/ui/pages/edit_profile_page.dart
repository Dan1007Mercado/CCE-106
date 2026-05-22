import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_sizes.dart';
import '../../../../core/services/device_permission_service.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/helpers.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/custom_textfield.dart';
import '../../../../core/widgets/profile_avatar.dart';
import '../../../auth/bloc/auth_bloc.dart';
import '../../../auth/bloc/auth_event.dart';
import '../../../auth/data/models/user_model.dart';
import '../../data/services/customer_service.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({
    super.key,
    this.title = 'Manage profile',
    this.locationDescription =
        'Bookings require device GPS coordinates. You can still enter a fallback address if location access is denied.',
    this.locationUpdatedMessage =
        'Profile updated. Capture GPS location to unlock booking.',
  });

  final String title;
  final String locationDescription;
  final String locationUpdatedMessage;

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _middleNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _suffixController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();

  final CustomerService _customerService = CustomerService();
  final DevicePermissionService _permissionService = DevicePermissionService();
  final LocationService _locationService = LocationService();

  double? _latitude;
  double? _longitude;
  UserPermissionStatus _locationPermission = UserPermissionStatus.unknown;

  bool _didInitialize = false;
  bool _isSaving = false;
  bool _isLocating = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final user = context.read<AuthBloc>().state.user;

    if (!_didInitialize && user != null) {
      _didInitialize = true;
      _firstNameController.text = user.firstName;
      _middleNameController.text = user.middleName;
      _lastNameController.text = user.lastName;
      _suffixController.text = user.suffix;
      _phoneController.text = user.phone;
      _addressController.text = user.address;
      _latitude = user.latitude;
      _longitude = user.longitude;
      _locationPermission = user.locationPermission;
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _middleNameController.dispose();
    _lastNameController.dispose();
    _suffixController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.select((AuthBloc bloc) => bloc.state.user);
    final theme = Theme.of(context);
    final tokens = theme.tokens;

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSizes.pagePadding),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSizes.cardPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Profile avatar',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          ProfileAvatar(
                            radius: 34,
                            name: _previewDisplayName(user),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              'Your avatar uses your initials. Image uploads are disabled on the free plan.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.textTheme.bodyMedium?.color
                                    ?.withValues(alpha: 0.74),
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
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
                    children: [
                      CustomTextField(
                        controller: _firstNameController,
                        label: 'First name',
                        prefixIcon: Icons.person_outline_rounded,
                        validator: Validators.name,
                      ),
                      const SizedBox(height: AppSizes.fieldGap),
                      CustomTextField(
                        controller: _middleNameController,
                        label: 'Middle name',
                        hintText: 'Optional',
                        prefixIcon: Icons.badge_outlined,
                      ),
                      const SizedBox(height: AppSizes.fieldGap),
                      CustomTextField(
                        controller: _lastNameController,
                        label: 'Last name',
                        prefixIcon: Icons.person_pin_outlined,
                        validator: Validators.name,
                      ),
                      const SizedBox(height: AppSizes.fieldGap),
                      CustomTextField(
                        controller: _suffixController,
                        label: 'Suffix',
                        hintText: 'Optional: Jr, Sr, II',
                        prefixIcon: Icons.label_outline_rounded,
                      ),
                      const SizedBox(height: AppSizes.fieldGap),
                      CustomTextField(
                        controller: _phoneController,
                        label: 'Phone number',
                        hintText: '09171234567',
                        keyboardType: TextInputType.phone,
                        prefixIcon: Icons.phone_outlined,
                        validator: Validators.phone,
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
                        'Location',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        widget.locationDescription,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.textTheme.bodyMedium?.color?.withValues(
                            alpha: 0.74,
                          ),
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 16),
                      CustomTextField(
                        controller: _addressController,
                        label: 'Address',
                        hintText: 'Auto-filled from GPS or typed as fallback',
                        prefixIcon: Icons.location_on_outlined,
                        maxLines: 2,
                      ),
                      const SizedBox(height: 12),
                      if (_latitude != null && _longitude != null)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: tokens.primarySoft,
                            borderRadius: BorderRadius.circular(
                              AppSizes.radiusMd,
                            ),
                          ),
                          child: Text(
                            'GPS saved: ${_locationPreviewLabel()}',
                            style: TextStyle(
                              color: AppTheme.resolveOnColor(
                                tokens.primarySoft,
                              ),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      if (_latitude != null && _longitude != null)
                        const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: _isLocating || _isSaving
                                ? null
                                : () => _captureCurrentLocation(user),
                            icon: _isLocating
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.my_location_rounded),
                            label: const Text('Use current location'),
                          ),
                          if (_locationPermission ==
                              UserPermissionStatus.permanentlyDenied)
                            TextButton(
                              onPressed: _openDeviceSettings,
                              child: const Text('Open settings'),
                            ),
                          if (_latitude != null && _longitude != null)
                            TextButton(
                              onPressed: _isSaving ? null : _clearCoordinates,
                              child: const Text('Clear GPS'),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Profile edits are limited to once every 24 hours.',
                ),
              ),
              const SizedBox(height: AppSizes.sectionGap),
              CustomButton(
                label: 'Save profile',
                isLoading: _isSaving,
                onPressed: () => _save(user),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _captureCurrentLocation(UserModel currentUser) async {
    setState(() {
      _isLocating = true;
    });

    try {
      final result = await _locationService.captureCurrentLocation();
      await _syncProfilePreferences(
        currentUser: currentUser,
        locationPermission: result.permissionStatus,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _locationPermission = result.permissionStatus;
        if (result.isSuccess) {
          _latitude = result.latitude;
          _longitude = result.longitude;
          _addressController.text = result.address;
        }
      });

      Helpers.showSnackBar(context, result.message, isError: !result.isSuccess);
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
          _isLocating = false;
        });
      }
    }
  }

  void _clearCoordinates() {
    setState(() {
      _latitude = null;
      _longitude = null;
    });
  }

  Future<void> _save(UserModel currentUser) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final latestUser = context.read<AuthBloc>().state.user ?? currentUser;
      final updatedUser = await _customerService.updateCustomerProfile(
        currentUser: latestUser,
        firstName: _firstNameController.text,
        middleName: _middleNameController.text,
        lastName: _lastNameController.text,
        suffix: _suffixController.text,
        phone: _phoneController.text,
        address: _addressController.text,
        latitude: _latitude,
        longitude: _longitude,
        profilePic: '',
        locationPermission: _locationPermission,
      );

      if (!mounted) {
        return;
      }

      context.read<AuthBloc>().add(AuthUserProfileUpdated(updatedUser));
      Helpers.showSnackBar(
        context,
        updatedUser.hasBookingLocation
            ? 'Profile updated.'
            : widget.locationUpdatedMessage,
      );
      Navigator.of(context).pop();
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

  Future<void> _syncProfilePreferences({
    required UserModel currentUser,
    UserPermissionStatus? locationPermission,
  }) async {
    final latestUser = context.read<AuthBloc>().state.user ?? currentUser;
    final updatedUser = await _customerService.updateUserPreferences(
      currentUser: latestUser,
      locationPermission: locationPermission,
    );

    if (!mounted) {
      return;
    }

    context.read<AuthBloc>().add(AuthUserProfileUpdated(updatedUser));
  }

  Future<void> _openDeviceSettings() async {
    final opened = await _permissionService.openSettings();
    if (!mounted || !opened) {
      return;
    }

    Helpers.showSnackBar(
      context,
      'Device settings opened. Return here after updating permissions.',
    );
  }

  String _previewDisplayName(UserModel user) {
    final draftName = [
      _firstNameController.text,
      _middleNameController.text,
      _lastNameController.text,
      _suffixController.text,
    ].where((part) => part.trim().isNotEmpty).join(' ').trim();

    if (draftName.isNotEmpty) {
      return draftName;
    }

    return user.displayName;
  }

  String _locationPreviewLabel() {
    final address = _addressController.text.trim();
    if (address.isNotEmpty) {
      return address;
    }

    return 'Location captured, address unavailable';
  }
}
