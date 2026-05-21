import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/user_model.dart';

class AuthService {
  AuthService({FirebaseAuth? firebaseAuth, FirebaseFirestore? firestore})
    : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _firebaseAuth;
  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _usersCollection =>
      _firestore.collection('users');

  Stream<User?> authStateChanges() => _firebaseAuth.authStateChanges();

  Future<void> signIn({required String email, required String password}) async {
    try {
      await _firebaseAuth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (error) {
      throw Exception(_messageFromAuthError(error));
    }
  }

  Future<void> register({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    required AppUserRole role,
    String middleName = '',
    String suffix = '',
  }) async {
    User? createdUser;
    var profileSaved = false;

    try {
      final credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      createdUser = credential.user;
      if (createdUser == null) {
        throw Exception('We could not create your account right now.');
      }

      final appUser = UserModel(
        uid: createdUser.uid,
        email: email.trim(),
        firstName: firstName.trim(),
        middleName: middleName.trim(),
        lastName: lastName.trim(),
        suffix: suffix.trim(),
        role: role,
      );

      await createdUser.updateDisplayName(appUser.displayName);

      await _usersCollection.doc(createdUser.uid).set({
        ...appUser.toMap(),
        'authUid': createdUser.uid,
        'authProvider': 'password',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      profileSaved = true;

      await _firebaseAuth.signOut();
    } on FirebaseAuthException catch (error) {
      throw Exception(_messageFromAuthError(error));
    } on FirebaseException catch (error) {
      if (createdUser != null && !profileSaved) {
        await _deleteAuthUserSilently(createdUser);
      }
      throw Exception(error.message ?? 'We could not save your profile.');
    } catch (error) {
      if (createdUser != null && !profileSaved) {
        await _deleteAuthUserSilently(createdUser);
      }
      rethrow;
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (error) {
      throw Exception(_messageFromAuthError(error));
    }
  }

  Future<void> signOut() async {
    await _firebaseAuth.signOut();
  }

  Future<UserModel?> loadUserProfile(User firebaseUser) async {
    try {
      final document = await _usersCollection.doc(firebaseUser.uid).get();
      final data = document.data();

      if (data != null) {
        return UserModel.fromMap(data, firebaseUser.uid);
      }

      final tokenResult = await firebaseUser.getIdTokenResult();
      final fallbackName = _fallbackNameFromDisplayName(
        firebaseUser.displayName,
      );
      final fallbackUser = UserModel(
        uid: firebaseUser.uid,
        email: firebaseUser.email ?? '',
        firstName: fallbackName.firstName,
        lastName: fallbackName.lastName,
        role: AppUserRole.fromValue(tokenResult.claims?['role'] as String?),
      );

      await _usersCollection.doc(firebaseUser.uid).set({
        ...fallbackUser.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      return fallbackUser;
    } on FirebaseException catch (error) {
      throw Exception(error.message ?? 'We could not load your profile.');
    }
  }

  String _messageFromAuthError(FirebaseAuthException error) {
    switch (error.code) {
      case 'email-already-in-use':
        return 'Email already in use.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'invalid-credential':
      case 'user-not-found':
      case 'wrong-password':
        return 'Incorrect email or password.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'weak-password':
        return 'Choose a stronger password with at least 6 characters.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment and try again.';
      case 'network-request-failed':
        return 'Network error. Check your connection and try again.';
      default:
        return error.message ?? 'Authentication failed. Please try again.';
    }
  }

  Future<void> _deleteAuthUserSilently(User user) async {
    try {
      await user.delete();
    } catch (_) {
      try {
        await _firebaseAuth.signOut();
      } catch (_) {}
    }
  }

  _FallbackNameParts _fallbackNameFromDisplayName(String? displayName) {
    final cleaned = displayName?.trim() ?? '';
    if (cleaned.isEmpty) {
      return const _FallbackNameParts(
        firstName: 'HandyMarket',
        lastName: 'User',
      );
    }

    final pieces = cleaned.split(RegExp(r'\s+'));
    if (pieces.length == 1) {
      return _FallbackNameParts(firstName: cleaned, lastName: '');
    }

    return _FallbackNameParts(
      firstName: pieces.first,
      lastName: pieces.skip(1).join(' '),
    );
  }
}

class _FallbackNameParts {
  const _FallbackNameParts({required this.firstName, required this.lastName});

  final String firstName;
  final String lastName;
}
