import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../features/auth/data/models/user_model.dart';

class DevicePermissionService {
  Future<UserPermissionStatus> getPhotosPermissionStatus() {
    return _readCombinedStatus(_photoPermissions);
  }

  Future<UserPermissionStatus> requestPhotosPermission() {
    return _requestCombinedPermissions(_photoPermissions);
  }

  Future<UserPermissionStatus> getNotificationsPermissionStatus() {
    return _readCombinedStatus(const [Permission.notification]);
  }

  Future<UserPermissionStatus> requestNotificationsPermission() {
    return _requestCombinedPermissions(const [Permission.notification]);
  }

  Future<UserPermissionStatus> getCameraPermissionStatus() {
    return _readCombinedStatus(const [Permission.camera]);
  }

  Future<UserPermissionStatus> requestCameraPermission() {
    return _requestCombinedPermissions(const [Permission.camera]);
  }

  Future<bool> openSettings() => openAppSettings();

  List<Permission> get _photoPermissions {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return const [Permission.photos, Permission.storage];
    }

    return const [Permission.photos];
  }

  Future<UserPermissionStatus> _readCombinedStatus(
    List<Permission> permissions,
  ) async {
    final states = await Future.wait(
      permissions.map((permission) => _mapPermission(permission.status)),
    );

    return _combine(states);
  }

  Future<UserPermissionStatus> _requestCombinedPermissions(
    List<Permission> permissions,
  ) async {
    final statuses = await Future.wait(
      permissions.map((permission) => permission.request()),
    );

    return _combine(statuses.map(_mapPermissionValue).toList());
  }

  Future<UserPermissionStatus> _mapPermission(
    Future<PermissionStatus> permissionStatus,
  ) async {
    return _mapPermissionValue(await permissionStatus);
  }

  UserPermissionStatus _mapPermissionValue(PermissionStatus status) {
    if (status.isGranted || status.isLimited) {
      return UserPermissionStatus.granted;
    }

    if (status.isPermanentlyDenied || status.isRestricted) {
      return UserPermissionStatus.permanentlyDenied;
    }

    if (status.isDenied) {
      return UserPermissionStatus.denied;
    }

    return UserPermissionStatus.unknown;
  }

  UserPermissionStatus _combine(List<UserPermissionStatus> statuses) {
    if (statuses.contains(UserPermissionStatus.granted)) {
      return UserPermissionStatus.granted;
    }

    if (statuses.contains(UserPermissionStatus.permanentlyDenied)) {
      return UserPermissionStatus.permanentlyDenied;
    }

    if (statuses.contains(UserPermissionStatus.denied)) {
      return UserPermissionStatus.denied;
    }

    return UserPermissionStatus.unknown;
  }
}
