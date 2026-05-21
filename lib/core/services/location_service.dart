import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

import '../../features/auth/data/models/user_model.dart';

enum LocationCaptureState {
  success,
  servicesDisabled,
  denied,
  permanentlyDenied,
}

class LocationCaptureResult {
  const LocationCaptureResult({
    required this.state,
    required this.permissionStatus,
    required this.message,
    this.latitude,
    this.longitude,
    this.address = '',
  });

  final LocationCaptureState state;
  final UserPermissionStatus permissionStatus;
  final String message;
  final double? latitude;
  final double? longitude;
  final String address;

  bool get isSuccess => state == LocationCaptureState.success;
}

class LocationService {
  Future<UserPermissionStatus> getPermissionStatus() async {
    final permission = await Geolocator.checkPermission();
    return _mapPermission(permission);
  }

  Future<UserPermissionStatus> requestPermission() async {
    final permission = await Geolocator.requestPermission();
    return _mapPermission(permission);
  }

  Future<LocationCaptureResult> captureCurrentLocation() async {
    final servicesEnabled = await Geolocator.isLocationServiceEnabled();
    if (!servicesEnabled) {
      return const LocationCaptureResult(
        state: LocationCaptureState.servicesDisabled,
        permissionStatus: UserPermissionStatus.denied,
        message:
            'Turn on device location services to capture your booking address.',
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    final permissionStatus = _mapPermission(permission);
    if (permission == LocationPermission.denied) {
      return LocationCaptureResult(
        state: LocationCaptureState.denied,
        permissionStatus: permissionStatus,
        message:
            'Location permission was denied. You can add a fallback address, but booking still needs GPS coordinates.',
      );
    }

    if (permission == LocationPermission.deniedForever) {
      return LocationCaptureResult(
        state: LocationCaptureState.permanentlyDenied,
        permissionStatus: permissionStatus,
        message:
            'Location permission is blocked. Open device settings to enable GPS-based booking.',
      );
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
    final address = await _reverseGeocode(
      latitude: position.latitude,
      longitude: position.longitude,
    );

    return LocationCaptureResult(
      state: LocationCaptureState.success,
      permissionStatus: permissionStatus,
      message: 'Current location captured.',
      latitude: position.latitude,
      longitude: position.longitude,
      address: address,
    );
  }

  UserPermissionStatus _mapPermission(LocationPermission permission) {
    switch (permission) {
      case LocationPermission.always:
      case LocationPermission.whileInUse:
        return UserPermissionStatus.granted;
      case LocationPermission.denied:
        return UserPermissionStatus.denied;
      case LocationPermission.deniedForever:
        return UserPermissionStatus.permanentlyDenied;
      case LocationPermission.unableToDetermine:
        return UserPermissionStatus.unknown;
    }
  }

  Future<String> _reverseGeocode({
    required double latitude,
    required double longitude,
  }) async {
    try {
      final placemarks = await placemarkFromCoordinates(latitude, longitude);
      if (placemarks.isEmpty) {
        return '';
      }

      final placemark = placemarks.first;
      final parts =
          [
                placemark.street,
                placemark.subLocality,
                placemark.locality,
                placemark.administrativeArea,
                placemark.country,
              ]
              .map((part) => part?.trim() ?? '')
              .where((part) => part.isNotEmpty)
              .toList();

      return parts.join(', ');
    } catch (_) {
      return '';
    }
  }
}
