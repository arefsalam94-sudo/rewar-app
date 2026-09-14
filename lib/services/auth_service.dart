import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/registration.dart';
import 'firebase_bootstrap.dart';

/// Why a registration attempt failed. Screens map these to localized
/// strings — a raw Firebase message is never shown to the user.
enum AuthErrorKind {
  backendUnavailable,
  emailAlreadyInUse,
  invalidEmail,
  weakPassword,
  network,
  tooManyRequests,
  /// Sign-in only. Covers wrong password *and* unknown account as one kind,
  /// on purpose — see [AuthService.signIn].
  invalidCredentials,
  userDisabled,
  unknown,
}

class AuthException implements Exception {
  AuthException(this.kind, [this.debugMessage]);

  final AuthErrorKind kind;
  final String? debugMessage;

  @override
  String toString() => 'AuthException($kind): $debugMessage';
}

/// Account creation for the Register screen.
///
/// The password goes straight to Firebase Auth and is never written to
/// Firestore, logged, or held on a model object (`SECURITY.md` 6.1b).
/// The `users/{uid}` document holds only profile data.
class AuthService {
  AuthService({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _authOverride = auth,
      _firestoreOverride = firestore;

  final FirebaseAuth? _authOverride;
  final FirebaseFirestore? _firestoreOverride;

  FirebaseAuth get _auth => _authOverride ?? FirebaseAuth.instance;
  FirebaseFirestore get _firestore =>
      _firestoreOverride ?? FirebaseFirestore.instance;

  /// Signs an existing user in with email + password (`SECURITY.md` 6.1).
  ///
  /// The password goes straight to Firebase Auth. It is never written to
  /// Firestore, never logged, and never placed on a model object — the same
  /// absolute rule as 6.1b, and as card data in section 5.1.
  ///
  /// ## Why a wrong password and an unknown account are one error
  ///
  /// This project has Firebase's email-enumeration protection enabled, so the
  /// backend answers both with `invalid-credential`. This method preserves
  /// that collapse rather than trying to undo it. Reporting them separately
  /// would turn the Login screen into an account-enumeration oracle — the
  /// exact property `SECURITY.md` 6.1a forbids for the password-reset
  /// endpoint, and it is no more acceptable here.
  ///
  /// Returns the account's display name, or null when Firebase holds none —
  /// the caller decides what to show in its place.
  Future<String?> signIn({
    required String email,
    required String password,
  }) async {
    if (!FirebaseBootstrap.isReady) {
      throw AuthException(AuthErrorKind.backendUnavailable);
    }

    final UserCredential credential;
    try {
      credential = await _auth.signInWithEmailAndPassword(
        // Trimmed because keyboards add trailing spaces. The password is
        // never trimmed — whitespace can be a deliberate part of it.
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw _mapAuthError(e);
    } catch (e) {
      throw AuthException(AuthErrorKind.unknown, '$e');
    }

    final user = credential.user;
    if (user == null) {
      throw AuthException(AuthErrorKind.unknown, 'No user after sign-in.');
    }
    return user.displayName;
  }

  /// Creates the account and its profile document.
  ///
  /// Does **not** verify the phone number — the Register screen sends the
  /// user on to the Verification Code screen for that.
  Future<void> register({
    required RegistrationDetails details,
    required String password,
  }) async {
    if (!FirebaseBootstrap.isReady) {
      throw AuthException(AuthErrorKind.backendUnavailable);
    }

    final UserCredential credential;
    try {
      credential = await _auth.createUserWithEmailAndPassword(
        email: details.email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw _mapAuthError(e);
    } catch (e) {
      throw AuthException(AuthErrorKind.unknown, '$e');
    }

    final user = credential.user;
    if (user == null) {
      throw AuthException(AuthErrorKind.unknown, 'No user after signup.');
    }

    try {
      await user.updateDisplayName(details.fullName);
      // Required before any second factor can be enrolled — SECURITY.md 6.1.
      await user.sendEmailVerification();
    } catch (e) {
      // Non-fatal: the account exists. Surface in logs, not to the user.
      debugPrint('Post-signup profile step failed: $e');
    }

    await _writeProfile(uid: user.uid, details: details);
  }

  /// Writes `users/{uid}`. Only the fields the client is allowed to set —
  /// `role`, `emailVerified`, `phoneVerified` and the MFA flags are
  /// deliberately absent and are rejected by `firestore.rules` if a modified
  /// client tries to send them.
  Future<void> _writeProfile({
    required String uid,
    required RegistrationDetails details,
  }) async {
    try {
      await _firestore.collection('users').doc(uid).set({
        'name': details.fullName,
        'email': details.email,
        'phone': details.phoneE164,
        'dateOfBirth': Timestamp.fromDate(details.dateOfBirth),
        if (details.gender != null) 'gender': details.gender!.value,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'source': 'manual',
      });
    } on FirebaseException catch (e) {
      throw AuthException(AuthErrorKind.unknown, '${e.code}: ${e.message}');
    }
  }

  /// Records consent once the user accepts on the Terms of Service screen.
  ///
  /// [version] is stored alongside the timestamp so that when the wording
  /// changes you can tell who agreed to which text and re-prompt only those
  /// who haven't seen the current version. A timestamp alone can't answer
  /// that question.
  Future<void> recordTermsAcceptance(int version) async {
    if (!FirebaseBootstrap.isReady) {
      throw AuthException(AuthErrorKind.backendUnavailable);
    }
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw AuthException(AuthErrorKind.unknown, 'No signed-in user.');
    }
    try {
      await _firestore.collection('users').doc(uid).set({
        'termsAcceptedAt': FieldValue.serverTimestamp(),
        'termsVersion': version,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } on FirebaseException catch (e) {
      throw AuthException(AuthErrorKind.unknown, '${e.code}: ${e.message}');
    }
  }

  /// Signs the current user out. Used by the Home screen's side drawer.
  Future<void> signOut() async {
    await _auth.signOut();
  }

  AuthException _mapAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return AuthException(AuthErrorKind.emailAlreadyInUse, e.message);
      case 'invalid-email':
        return AuthException(AuthErrorKind.invalidEmail, e.message);
      case 'weak-password':
      case 'password-does-not-meet-requirements':
        return AuthException(AuthErrorKind.weakPassword, e.message);
      case 'network-request-failed':
        return AuthException(AuthErrorKind.network, e.message);
      case 'too-many-requests':
        return AuthException(AuthErrorKind.tooManyRequests, e.message);
      // Sign-in. `invalid-credential` is what Firebase returns while email
      // enumeration protection is on; the older split codes are kept so the
      // mapping still holds if it is ever turned off. All four collapse to
      // one kind deliberately — see [signIn].
      case 'invalid-credential':
      case 'invalid-login-credentials':
      case 'user-not-found':
      case 'wrong-password':
        return AuthException(AuthErrorKind.invalidCredentials, e.message);
      case 'user-disabled':
        return AuthException(AuthErrorKind.userDisabled, e.message);
      default:
        return AuthException(AuthErrorKind.unknown, '${e.code}: ${e.message}');
    }
  }
}
