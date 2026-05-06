import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/services/device_permission_service.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/utils/helpers.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../routes/app_router.dart';
import '../../../auth/bloc/auth_bloc.dart';
import '../../../auth/bloc/auth_event.dart';
import '../../../auth/data/models/user_model.dart';
import '../../data/services/customer_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final CustomerService _customerService = CustomerService();
  final DevicePermissionService _permissionService = DevicePermissionService();
  final LocationService _locationService = LocationService();

  UserPermissionStatus? _photosPermission;
  UserPermissionStatus? _notificationsPermission;
  UserPermissionStatus? _locationPermission;

  bool _didLoadDeviceStatuses = false;
  bool _isUpdatingTheme = false;
  bool _isRefreshingStatuses = false;
  bool _isUpdatingPhotos = false;
  bool _isUpdatingNotifications = false;
  bool _isUpdatingLocation = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final user = context.read<AuthBloc>().state.user;

    if (!_didLoadDeviceStatuses && user != null) {
      _didLoadDeviceStatuses = true;
      _photosPermission = user.photosPermission;
      _notificationsPermission = user.notificationsPermission;
      _locationPermission = user.locationPermission;
      _refreshDeviceStatuses();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.select((AuthBloc bloc) => bloc.state.user);
    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(AppSizes.pagePadding),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSizes.cardPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Theme',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Your theme mode is stored on your account and applied across the app.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  for (final option in AppThemePreference.values)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(option.label),
                      subtitle: Text(_themeDescription(option)),
                      trailing: user.themeMode == option
                          ? const Icon(
                              Icons.check_circle_rounded,
                              color: AppColors.success,
                            )
                          : null,
                      onTap: _isUpdatingTheme || user.themeMode == option
                          ? null
                          : () => _updateThemeMode(user, option),
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
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Permissions',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _isRefreshingStatuses
                            ? null
                            : _refreshDeviceStatuses,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Refresh'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'These permissions control real app behavior for photo upload, push alerts, and GPS-based booking.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 18),
                  _PermissionTile(
                    title: 'Photos',
                    subtitle:
                        'Required before the app can pick and upload a profile image.',
                    status: _photosPermission ?? user.photosPermission,
                    isLoading: _isUpdatingPhotos,
                    onPressed: () => _requestPhotosPermission(user),
                    onOpenSettings: _openDeviceSettings,
                  ),
                  const SizedBox(height: 12),
                  _PermissionTile(
                    title: 'Notifications',
                    subtitle:
                        'Push alerts stay off until notification permission is granted.',
                    status:
                        _notificationsPermission ?? user.notificationsPermission,
                    isLoading: _isUpdatingNotifications,
                    onPressed: () => _requestNotificationsPermission(user),
                    onOpenSettings: _openDeviceSettings,
                  ),
                  const SizedBox(height: 12),
                  _PermissionTile(
                    title: 'Location',
                    subtitle:
                        'Required for saving GPS coordinates and unlocking booking.',
                    status: _locationPermission ?? user.locationPermission,
                    isLoading: _isUpdatingLocation,
                    onPressed: () => _requestLocationPermission(user),
                    onOpenSettings: _openDeviceSettings,
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
                    'Account',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    user.displayName,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user.email,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pushNamed(AppRouter.editProfileRoute);
                    },
                    icon: const Icon(Icons.manage_accounts_outlined),
                    label: const Text('Manage profile'),
                  ),
                  const SizedBox(height: 12),
                  CustomButton(
                    label: 'Log out',
                    icon: Icons.logout_rounded,
                    onPressed: _logout,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _themeDescription(AppThemePreference preference) {
    switch (preference) {
      case AppThemePreference.light:
        return 'Always use the light interface.';
      case AppThemePreference.dark:
        return 'Always use the dark interface.';
      case AppThemePreference.system:
        return 'Match the device appearance automatically.';
    }
  }

  Future<void> _refreshDeviceStatuses() async {
    setState(() {
      _isRefreshingStatuses = true;
    });

    try {
      final photos = await _permissionService.getPhotosPermissionStatus();
      final notifications =
          await _permissionService.getNotificationsPermissionStatus();
      final location = await _locationService.getPermissionStatus();

      if (!mounted) {
        return;
      }

      setState(() {
        _photosPermission = photos;
        _notificationsPermission = notifications;
        _locationPermission = location;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshingStatuses = false;
        });
      }
    }
  }

  Future<void> _updateThemeMode(
    UserModel currentUser,
    AppThemePreference preference,
  ) async {
    setState(() {
      _isUpdatingTheme = true;
    });

    try {
      final latestUser = context.read<AuthBloc>().state.user ?? currentUser;
      final updatedUser = await _customerService.updateUserPreferences(
        currentUser: latestUser,
        themeMode: preference,
      );

      if (!mounted) {
        return;
      }

      context.read<AuthBloc>().add(AuthUserProfileUpdated(updatedUser));
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
          _isUpdatingTheme = false;
        });
      }
    }
  }

  Future<void> _requestPhotosPermission(UserModel currentUser) async {
    setState(() {
      _isUpdatingPhotos = true;
    });

    try {
      final status = await _permissionService.requestPhotosPermission();
      await _persistPermissionUpdate(
        currentUser: currentUser,
        photosPermission: status,
      );
      if (!mounted) {
        return;
      }

      setState(() {
        _photosPermission = status;
      });
      _showPermissionFeedback(
        status,
        grantedMessage: 'Photo access updated.',
        deniedMessage:
            'Photo upload stays unavailable until gallery access is granted.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingPhotos = false;
        });
      }
    }
  }

  Future<void> _requestNotificationsPermission(UserModel currentUser) async {
    setState(() {
      _isUpdatingNotifications = true;
    });

    try {
      final status = await _permissionService.requestNotificationsPermission();
      await _persistPermissionUpdate(
        currentUser: currentUser,
        notificationsPermission: status,
      );
      if (!mounted) {
        return;
      }

      setState(() {
        _notificationsPermission = status;
      });
      _showPermissionFeedback(
        status,
        grantedMessage: 'Notification access updated.',
        deniedMessage:
            'Push alerts stay disabled until notification permission is granted.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingNotifications = false;
        });
      }
    }
  }

  Future<void> _requestLocationPermission(UserModel currentUser) async {
    setState(() {
      _isUpdatingLocation = true;
    });

    try {
      final status = await _locationService.requestPermission();
      await _persistPermissionUpdate(
        currentUser: currentUser,
        locationPermission: status,
      );
      if (!mounted) {
        return;
      }

      setState(() {
        _locationPermission = status;
      });
      _showPermissionFeedback(
        status,
        grantedMessage: 'Location access updated.',
        deniedMessage:
            'Booking stays locked until GPS access is allowed and coordinates are saved.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingLocation = false;
        });
      }
    }
  }

  Future<void> _persistPermissionUpdate({
    required UserModel currentUser,
    UserPermissionStatus? photosPermission,
    UserPermissionStatus? notificationsPermission,
    UserPermissionStatus? locationPermission,
  }) async {
    try {
      final latestUser = context.read<AuthBloc>().state.user ?? currentUser;
      final updatedUser = await _customerService.updateUserPreferences(
        currentUser: latestUser,
        photosPermission: photosPermission,
        notificationsPermission: notificationsPermission,
        locationPermission: locationPermission,
      );

      if (!mounted) {
        return;
      }

      context.read<AuthBloc>().add(AuthUserProfileUpdated(updatedUser));
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

  void _showPermissionFeedback(
    UserPermissionStatus status, {
    required String grantedMessage,
    required String deniedMessage,
  }) {
    if (!mounted) {
      return;
    }

    if (status == UserPermissionStatus.granted) {
      Helpers.showSnackBar(context, grantedMessage);
      return;
    }

    Helpers.showSnackBar(context, deniedMessage, isError: true);
  }

  Future<void> _openDeviceSettings() async {
    final opened = await _permissionService.openSettings();
    if (!mounted || !opened) {
      return;
    }

    Helpers.showSnackBar(
      context,
      'Device settings opened. Return here and tap Refresh after updating permissions.',
    );
  }

  void _logout() {
    context.read<AuthBloc>().add(const AuthSignOutRequested());
    Navigator.of(context).popUntil((route) => route.isFirst);
  }
}

class _PermissionTile extends StatelessWidget {
  const _PermissionTile({
    required this.title,
    required this.subtitle,
    required this.status,
    required this.isLoading,
    required this.onPressed,
    required this.onOpenSettings,
  });

  final String title;
  final String subtitle;
  final UserPermissionStatus status;
  final bool isLoading;
  final VoidCallback onPressed;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (status) {
      UserPermissionStatus.granted => AppColors.success,
      UserPermissionStatus.permanentlyDenied => AppColors.error,
      UserPermissionStatus.denied => AppColors.accent,
      UserPermissionStatus.unknown => AppColors.textSecondary,
    };

    final actionLabel = switch (status) {
      UserPermissionStatus.granted => 'Check again',
      UserPermissionStatus.permanentlyDenied => 'Open settings',
      UserPermissionStatus.denied => 'Allow',
      UserPermissionStatus.unknown => 'Allow',
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  status.label,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: isLoading
                  ? null
                  : status == UserPermissionStatus.permanentlyDenied
                  ? onOpenSettings
                  : onPressed,
              icon: isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.chevron_right_rounded),
              label: Text(actionLabel),
            ),
          ),
        ],
      ),
    );
  }
}
