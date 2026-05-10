import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/repositories/auth_repository.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc({required AuthRepository authRepository})
    : _authRepository = authRepository,
      super(const AuthState()) {
    on<AuthStarted>(_onStarted);
    on<AuthStatusChanged>(_onStatusChanged);
    on<AuthLoginRequested>(_onLoginRequested);
    on<AuthRegisterRequested>(_onRegisterRequested);
    on<AuthPasswordResetRequested>(_onPasswordResetRequested);
    on<AuthSignOutRequested>(_onSignOutRequested);
    on<AuthUserProfileUpdated>(_onUserProfileUpdated);
  }

  final AuthRepository _authRepository;
  StreamSubscription<User?>? _authSubscription;
  String? _pendingUnauthenticatedMessage;
  AuthFeedbackType? _pendingUnauthenticatedFeedbackType;

  Future<void> _onStarted(AuthStarted event, Emitter<AuthState> emit) async {
    await _authSubscription?.cancel();
    _authSubscription = _authRepository.authStateChanges().listen((user) {
      add(AuthStatusChanged(user));
    });
  }

  Future<void> _onStatusChanged(
    AuthStatusChanged event,
    Emitter<AuthState> emit,
  ) async {
    if (event.user == null) {
      final message = _pendingUnauthenticatedMessage;
      final feedbackType = _pendingUnauthenticatedFeedbackType;
      _clearPendingUnauthenticatedFeedback();

      emit(
        state.copyWith(
          status: AuthStatus.unauthenticated,
          clearUser: true,
          isSubmitting: false,
          message: message,
          clearMessage: message == null,
          feedbackType: feedbackType,
          clearFeedbackType: feedbackType == null,
        ),
      );
      return;
    }

    _clearPendingUnauthenticatedFeedback();

    try {
      final user = await _authRepository.loadUserProfile(event.user!);

      if (user == null) {
        emit(
          state.copyWith(
            status: AuthStatus.unauthenticated,
            clearUser: true,
            isSubmitting: false,
            message: 'We could not load your account details.',
            feedbackType: AuthFeedbackType.error,
          ),
        );
        return;
      }

      emit(
        state.copyWith(
          status: AuthStatus.authenticated,
          user: user,
          isSubmitting: false,
          clearMessage: true,
          clearFeedbackType: true,
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          status: AuthStatus.unauthenticated,
          clearUser: true,
          isSubmitting: false,
          message: _readableError(error),
          feedbackType: AuthFeedbackType.error,
        ),
      );
    }
  }

  Future<void> _onLoginRequested(
    AuthLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    _clearPendingUnauthenticatedFeedback();
    emit(
      state.copyWith(
        isSubmitting: true,
        clearMessage: true,
        clearFeedbackType: true,
      ),
    );

    try {
      await _authRepository.signIn(
        email: event.email,
        password: event.password,
      );
      emit(
        state.copyWith(
          isSubmitting: false,
          message: 'Successful',
          feedbackType: AuthFeedbackType.success,
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          status: AuthStatus.unauthenticated,
          clearUser: true,
          isSubmitting: false,
          message: _readableError(error),
          feedbackType: AuthFeedbackType.error,
        ),
      );
    }
  }

  Future<void> _onRegisterRequested(
    AuthRegisterRequested event,
    Emitter<AuthState> emit,
  ) async {
    _clearPendingUnauthenticatedFeedback();
    emit(
      state.copyWith(
        isSubmitting: true,
        clearMessage: true,
        clearFeedbackType: true,
      ),
    );

    try {
      await _authRepository.register(
        firstName: event.firstName,
        middleName: event.middleName,
        lastName: event.lastName,
        suffix: event.suffix,
        email: event.email,
        password: event.password,
        role: event.role,
      );
      _setPendingUnauthenticatedFeedback(
        message: 'Account created successfully',
        feedbackType: AuthFeedbackType.success,
      );
      emit(
        state.copyWith(
          status: AuthStatus.unauthenticated,
          clearUser: true,
          isSubmitting: false,
          message: 'Account created successfully',
          feedbackType: AuthFeedbackType.success,
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          status: AuthStatus.unauthenticated,
          clearUser: true,
          isSubmitting: false,
          message: _readableError(error),
          feedbackType: AuthFeedbackType.error,
        ),
      );
    }
  }

  Future<void> _onPasswordResetRequested(
    AuthPasswordResetRequested event,
    Emitter<AuthState> emit,
  ) async {
    _clearPendingUnauthenticatedFeedback();
    emit(
      state.copyWith(
        isSubmitting: true,
        clearMessage: true,
        clearFeedbackType: true,
      ),
    );

    try {
      await _authRepository.sendPasswordResetEmail(event.email);
      emit(
        state.copyWith(
          status: AuthStatus.unauthenticated,
          clearUser: true,
          isSubmitting: false,
          message: 'Password reset email sent. Check your inbox.',
          feedbackType: AuthFeedbackType.success,
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          status: AuthStatus.unauthenticated,
          clearUser: true,
          isSubmitting: false,
          message: _readableError(error),
          feedbackType: AuthFeedbackType.error,
        ),
      );
    }
  }

  Future<void> _onSignOutRequested(
    AuthSignOutRequested event,
    Emitter<AuthState> emit,
  ) async {
    try {
      if (event.message != null && event.feedbackType != null) {
        _setPendingUnauthenticatedFeedback(
          message: event.message!,
          feedbackType: event.feedbackType!,
        );
      } else {
        _clearPendingUnauthenticatedFeedback();
      }
      await _authRepository.signOut();
    } catch (error) {
      _clearPendingUnauthenticatedFeedback();
      emit(
        state.copyWith(
          isSubmitting: false,
          message: _readableError(error),
          feedbackType: AuthFeedbackType.error,
        ),
      );
    }
  }

  void _onUserProfileUpdated(
    AuthUserProfileUpdated event,
    Emitter<AuthState> emit,
  ) {
    emit(
      state.copyWith(
        status: AuthStatus.authenticated,
        user: event.user,
        isSubmitting: false,
        clearMessage: true,
        clearFeedbackType: true,
      ),
    );
  }

  String _readableError(Object error) {
    return error.toString().replaceFirst('Exception: ', '');
  }

  void _setPendingUnauthenticatedFeedback({
    required String message,
    required AuthFeedbackType feedbackType,
  }) {
    _pendingUnauthenticatedMessage = message;
    _pendingUnauthenticatedFeedbackType = feedbackType;
  }

  void _clearPendingUnauthenticatedFeedback() {
    _pendingUnauthenticatedMessage = null;
    _pendingUnauthenticatedFeedbackType = null;
  }

  @override
  Future<void> close() async {
    await _authSubscription?.cancel();
    return super.close();
  }
}
