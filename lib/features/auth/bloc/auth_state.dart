import 'package:equatable/equatable.dart';

import '../data/models/user_model.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

enum AuthFeedbackType { success, error }

class AuthState extends Equatable {
  const AuthState({
    this.status = AuthStatus.unknown,
    this.user,
    this.isSubmitting = false,
    this.message,
    this.feedbackType,
  });

  final AuthStatus status;
  final UserModel? user;
  final bool isSubmitting;
  final String? message;
  final AuthFeedbackType? feedbackType;

  AuthState copyWith({
    AuthStatus? status,
    UserModel? user,
    bool clearUser = false,
    bool? isSubmitting,
    String? message,
    bool clearMessage = false,
    AuthFeedbackType? feedbackType,
    bool clearFeedbackType = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: clearUser ? null : user ?? this.user,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      message: clearMessage ? null : message ?? this.message,
      feedbackType: clearFeedbackType
          ? null
          : feedbackType ?? this.feedbackType,
    );
  }

  @override
  List<Object?> get props => [
    status,
    user,
    isSubmitting,
    message,
    feedbackType,
  ];
}
