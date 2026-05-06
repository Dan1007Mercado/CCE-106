import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../data/models/user_model.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

class AuthStarted extends AuthEvent {
  const AuthStarted();
}

class AuthStatusChanged extends AuthEvent {
  const AuthStatusChanged(this.user);

  final User? user;

  @override
  List<Object?> get props => [user];
}

class AuthLoginRequested extends AuthEvent {
  const AuthLoginRequested({required this.email, required this.password});

  final String email;
  final String password;

  @override
  List<Object?> get props => [email, password];
}

class AuthRegisterRequested extends AuthEvent {
  const AuthRegisterRequested({
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.password,
    required this.role,
    this.middleName = '',
    this.suffix = '',
  });

  final String firstName;
  final String middleName;
  final String lastName;
  final String suffix;
  final String email;
  final String password;
  final AppUserRole role;

  @override
  List<Object?> get props => [
    firstName,
    middleName,
    lastName,
    suffix,
    email,
    password,
    role,
  ];
}

class AuthPasswordResetRequested extends AuthEvent {
  const AuthPasswordResetRequested(this.email);

  final String email;

  @override
  List<Object?> get props => [email];
}

class AuthSignOutRequested extends AuthEvent {
  const AuthSignOutRequested();
}

class AuthUserProfileUpdated extends AuthEvent {
  const AuthUserProfileUpdated(this.user);

  final UserModel user;

  @override
  List<Object?> get props => [user];
}
