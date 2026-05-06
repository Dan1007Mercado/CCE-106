import 'package:firebase_auth/firebase_auth.dart';

import '../models/user_model.dart';
import '../services/auth_service.dart';

class AuthRepository {
  AuthRepository({required AuthService authService})
    : _authService = authService;

  final AuthService _authService;

  Stream<User?> authStateChanges() => _authService.authStateChanges();

  Future<void> signIn({required String email, required String password}) {
    return _authService.signIn(email: email, password: password);
  }

  Future<void> register({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    required AppUserRole role,
    String middleName = '',
    String suffix = '',
  }) {
    return _authService.register(
      firstName: firstName,
      middleName: middleName,
      lastName: lastName,
      suffix: suffix,
      email: email,
      password: password,
      role: role,
    );
  }

  Future<void> sendPasswordResetEmail(String email) {
    return _authService.sendPasswordResetEmail(email);
  }

  Future<void> signOut() {
    return _authService.signOut();
  }

  Future<UserModel?> loadUserProfile(User firebaseUser) {
    return _authService.loadUserProfile(firebaseUser);
  }
}
