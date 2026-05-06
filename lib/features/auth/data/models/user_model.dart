import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

enum AppUserRole {
  admin,
  service,
  customer;

  String get value => switch (this) {
    AppUserRole.admin => 'admin',
    AppUserRole.service => 'services',
    AppUserRole.customer => 'customer',
  };

  String get label => switch (this) {
    AppUserRole.admin => 'Admin',
    AppUserRole.service => 'Services',
    AppUserRole.customer => 'Customer',
  };

  String get dashboardTitle => switch (this) {
    AppUserRole.admin => 'Admin overview',
    AppUserRole.service => 'Service dashboard',
    AppUserRole.customer => 'Customer dashboard',
  };

  String get description => switch (this) {
    AppUserRole.admin =>
      'Manage users, operations, and platform-wide decisions.',
    AppUserRole.service =>
      'Track bookings, manage offers, and respond to requests quickly.',
    AppUserRole.customer =>
      'Browse services, manage bookings, and follow your requests.',
  };

  static AppUserRole fromValue(String? value) {
    switch (value?.trim().toLowerCase()) {
      case 'admin':
        return AppUserRole.admin;
      case 'service':
      case 'services':
      case 'service_provider':
        return AppUserRole.service;
      case 'customer':
      default:
        return AppUserRole.customer;
    }
  }
}

enum UserPermissionStatus {
  unknown,
  granted,
  denied,
  permanentlyDenied;

  String get value => switch (this) {
    UserPermissionStatus.unknown => 'unknown',
    UserPermissionStatus.granted => 'granted',
    UserPermissionStatus.denied => 'denied',
    UserPermissionStatus.permanentlyDenied => 'permanently_denied',
  };

  String get label => switch (this) {
    UserPermissionStatus.unknown => 'Not requested',
    UserPermissionStatus.granted => 'Allowed',
    UserPermissionStatus.denied => 'Denied',
    UserPermissionStatus.permanentlyDenied => 'Blocked',
  };

  bool get isGranted => this == UserPermissionStatus.granted;

  bool get isBlocked =>
      this == UserPermissionStatus.denied ||
      this == UserPermissionStatus.permanentlyDenied;

  static UserPermissionStatus fromValue(String? value) {
    switch (value?.trim().toLowerCase()) {
      case 'granted':
        return UserPermissionStatus.granted;
      case 'denied':
        return UserPermissionStatus.denied;
      case 'permanently_denied':
      case 'permanentlydenied':
      case 'blocked':
        return UserPermissionStatus.permanentlyDenied;
      case 'unknown':
      default:
        return UserPermissionStatus.unknown;
    }
  }
}

enum AppThemePreference {
  light,
  dark,
  system;

  String get value => name;

  String get label => switch (this) {
    AppThemePreference.light => 'Light',
    AppThemePreference.dark => 'Dark',
    AppThemePreference.system => 'System',
  };

  ThemeMode get themeMode => switch (this) {
    AppThemePreference.light => ThemeMode.light,
    AppThemePreference.dark => ThemeMode.dark,
    AppThemePreference.system => ThemeMode.system,
  };

  static AppThemePreference fromValue(String? value) {
    switch (value?.trim().toLowerCase()) {
      case 'light':
        return AppThemePreference.light;
      case 'dark':
        return AppThemePreference.dark;
      case 'system':
      default:
        return AppThemePreference.system;
    }
  }
}

class UserModel extends Equatable {
  const UserModel({
    required this.uid,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.role,
    this.middleName = '',
    this.suffix = '',
    this.phone = '',
    this.latitude,
    this.longitude,
    this.address = '',
    this.profilePic = '',
    this.photosPermission = UserPermissionStatus.unknown,
    this.notificationsPermission = UserPermissionStatus.unknown,
    this.locationPermission = UserPermissionStatus.unknown,
    this.themeMode = AppThemePreference.system,
    this.profileUpdatedAt,
  });

  final String uid;
  final String email;
  final String firstName;
  final String middleName;
  final String lastName;
  final String suffix;
  final AppUserRole role;
  final String phone;
  final double? latitude;
  final double? longitude;
  final String address;
  final String profilePic;
  final UserPermissionStatus photosPermission;
  final UserPermissionStatus notificationsPermission;
  final UserPermissionStatus locationPermission;
  final AppThemePreference themeMode;
  final DateTime? profileUpdatedAt;

  String get displayName {
    final parts = [firstName, lastName, suffix]
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty);
    return parts.join(' ').trim();
  }

  String get legalName {
    final parts = [firstName, middleName, lastName, suffix]
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty);
    return parts.join(' ').trim();
  }

  String get locationLabel {
    if (address.trim().isNotEmpty) {
      return address.trim();
    }

    if (hasBookingLocation) {
      return 'Lat ${latitude!.toStringAsFixed(5)}, Lng ${longitude!.toStringAsFixed(5)}';
    }

    return '';
  }

  bool get hasContactNumber => phone.trim().isNotEmpty;

  bool get hasBookingLocation => latitude != null && longitude != null;

  bool get isReadyForBooking => hasContactNumber && hasBookingLocation;

  factory UserModel.fromMap(Map<String, dynamic> map, String documentId) {
    final legacyName = _LegacyNameParts.fromValue(
      map['name'] as String? ?? map['displayName'] as String?,
    );

    return UserModel(
      uid: documentId,
      email: map['email'] as String? ?? '',
      firstName: map['firstName'] as String? ?? legacyName.firstName,
      middleName: map['middleName'] as String? ?? '',
      lastName: map['lastName'] as String? ?? legacyName.lastName,
      suffix: map['suffix'] as String? ?? '',
      role: AppUserRole.fromValue(map['role'] as String?),
      phone: map['phone'] as String? ?? '',
      latitude: _readDouble(map['latitude']),
      longitude: _readDouble(map['longitude']),
      address: map['address'] as String? ?? map['location'] as String? ?? '',
      profilePic: map['profilePic'] as String? ?? '',
      photosPermission: UserPermissionStatus.fromValue(
        map['photosPermission'] as String?,
      ),
      notificationsPermission: UserPermissionStatus.fromValue(
        map['notificationsPermission'] as String?,
      ),
      locationPermission: UserPermissionStatus.fromValue(
        map['locationPermission'] as String?,
      ),
      themeMode: AppThemePreference.fromValue(map['themeMode'] as String?),
      profileUpdatedAt: _readDateTime(
        map['profileUpdatedAt'] ?? map['updatedAt'],
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'firstName': firstName,
      'middleName': middleName,
      'lastName': lastName,
      'suffix': suffix,
      'role': role.value,
      'phone': phone,
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'profilePic': profilePic,
      'photosPermission': photosPermission.value,
      'notificationsPermission': notificationsPermission.value,
      'locationPermission': locationPermission.value,
      'themeMode': themeMode.value,
    };
  }

  UserModel copyWith({
    String? uid,
    String? email,
    String? firstName,
    String? middleName,
    String? lastName,
    String? suffix,
    AppUserRole? role,
    String? phone,
    double? latitude,
    double? longitude,
    bool clearCoordinates = false,
    String? address,
    String? profilePic,
    UserPermissionStatus? photosPermission,
    UserPermissionStatus? notificationsPermission,
    UserPermissionStatus? locationPermission,
    AppThemePreference? themeMode,
    DateTime? profileUpdatedAt,
    bool clearProfileUpdatedAt = false,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      firstName: firstName ?? this.firstName,
      middleName: middleName ?? this.middleName,
      lastName: lastName ?? this.lastName,
      suffix: suffix ?? this.suffix,
      role: role ?? this.role,
      phone: phone ?? this.phone,
      latitude: clearCoordinates ? null : latitude ?? this.latitude,
      longitude: clearCoordinates ? null : longitude ?? this.longitude,
      address: address ?? this.address,
      profilePic: profilePic ?? this.profilePic,
      photosPermission: photosPermission ?? this.photosPermission,
      notificationsPermission:
          notificationsPermission ?? this.notificationsPermission,
      locationPermission: locationPermission ?? this.locationPermission,
      themeMode: themeMode ?? this.themeMode,
      profileUpdatedAt: clearProfileUpdatedAt
          ? null
          : profileUpdatedAt ?? this.profileUpdatedAt,
    );
  }

  static DateTime? _readDateTime(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is DateTime) {
      return value;
    }

    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }

    final toDate = (value as dynamic).toDate;
    if (toDate is Function) {
      final result = toDate();
      if (result is DateTime) {
        return result;
      }
    }

    return null;
  }

  static double? _readDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '');
  }

  @override
  List<Object?> get props => [
    uid,
    email,
    firstName,
    middleName,
    lastName,
    suffix,
    role,
    phone,
    latitude,
    longitude,
    address,
    profilePic,
    photosPermission,
    notificationsPermission,
    locationPermission,
    themeMode,
    profileUpdatedAt,
  ];
}

class _LegacyNameParts {
  const _LegacyNameParts({
    required this.firstName,
    required this.lastName,
  });

  final String firstName;
  final String lastName;

  factory _LegacyNameParts.fromValue(String? value) {
    final cleaned = value?.trim() ?? '';
    if (cleaned.isEmpty) {
      return const _LegacyNameParts(firstName: '', lastName: '');
    }

    final pieces = cleaned.split(RegExp(r'\s+'));
    if (pieces.length == 1) {
      return _LegacyNameParts(firstName: cleaned, lastName: '');
    }

    return _LegacyNameParts(
      firstName: pieces.first,
      lastName: pieces.skip(1).join(' '),
    );
  }
}
