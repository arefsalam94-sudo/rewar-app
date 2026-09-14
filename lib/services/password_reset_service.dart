import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/reset_target.dart';
import 'firebase_bootstrap.dart';

/// Why a send/verify attempt failed. The screen maps these to localized
/// strings — never show a raw Firebase message to the user.
enum ResetErrorKind {
  /// Firebase isn't configured yet (see `FIREBASE_SETUP.md`).
  backendUnavailable,
  incorrectCode,
  expiredCode,
  tooManyAttempts,
  network,

  /// Firebase Auth rejected the new password against its own policy.
  weakPassword,

  /// The verified session/token is gone — the user has to start over.
  sessionExpired,
  unknown,
}

class ResetException implements Exception {
  ResetException(this.kind, [this.debugMessage]);

  final ResetErrorKind kind;
  final String? debugMessage;

  @override
  String toString() => 'ResetException($kind): $debugMessage';
}

/// The result of a successfully verified code — the proof the *next* screen
/// (Set New Password) needs in order to actually change the password.
///
/// Deliberately not a raw password-change call: this screen only proves the
/// user controls the phone/email. Changing the password belongs to the next
/// screen, once its design is handed over.
class VerifiedReset {
  const VerifiedReset({this.phoneCredentialUser, this.emailResetToken});

  /// Phone flow: the user is now signed in via their SMS credential, so
  /// `user.updatePassword(...)` will be permitted on the next screen.
  final User? phoneCredentialUser;

  /// Email flow: a short-lived server-signed token. The next screen passes it
  /// back to the `confirmPasswordResetWithCode` Cloud Function along with the
  /// new password. The client never gains elevated rights from holding it.
  final String? emailResetToken;
}

/// Drives the two password-reset code flows:
///
/// * **Phone** — Firebase Authentication's own phone verification. Firebase
///   generates and sends the 6-digit SMS itself; we never see or store it.
/// * **Email** — Firebase Auth has no built-in *code* reset (its
///   `sendPasswordResetEmail` sends a link instead), so this goes through the
///   `sendPasswordResetCode` / `verifyPasswordResetCode` Cloud Functions in
///   `functions/`. Codes are hashed server-side and never returned to the
///   client — see `SECURITY.md` and the `password_reset_codes` collection in
///   `DATA_MODEL.md`.
class PasswordResetService {
  PasswordResetService({FirebaseAuth? auth, FirebaseFunctions? functions})
    : _authOverride = auth,
      _functionsOverride = functions;

  final FirebaseAuth? _authOverride;
  final FirebaseFunctions? _functionsOverride;

  FirebaseAuth get _auth => _authOverride ?? FirebaseAuth.instance;
  FirebaseFunctions get _functions =>
      _functionsOverride ?? FirebaseFunctions.instance;

  /// Set by the phone flow; required to build the SMS credential later.
  String? _verificationId;

  /// Lets Firebase reuse its rate-limit state across resends instead of
  /// treating each resend as a brand-new request.
  int? _resendToken;

  /// Sends (or resends) a 6-digit code to [target].
  ///
  /// Throws [ResetException] on failure.
  Future<void> sendCode(ResetTarget target) async {
    if (!FirebaseBootstrap.isReady) {
      throw ResetException(ResetErrorKind.backendUnavailable);
    }
    if (target.isPhone) {
      await _sendPhoneCode(target.value);
    } else {
      await _sendEmailCode(target.value);
    }
  }

  Future<void> _sendPhoneCode(String phoneNumber) async {
    final completer = Completer<void>();
    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        forceResendingToken: _resendToken,
        // Android can auto-read the SMS. We still want the user to land on
        // the code screen, so we only capture the id — we don't auto-sign-in.
        verificationCompleted: (PhoneAuthCredential credential) {
          debugPrint('Phone code auto-retrieved by the OS.');
        },
        verificationFailed: (FirebaseAuthException e) {
          if (!completer.isCompleted) {
            completer.completeError(_mapAuthError(e));
          }
        },
        codeSent: (String verificationId, int? resendToken) {
          _verificationId = verificationId;
          _resendToken = resendToken;
          if (!completer.isCompleted) completer.complete();
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
          if (!completer.isCompleted) completer.complete();
        },
      );
    } on FirebaseAuthException catch (e) {
      throw _mapAuthError(e);
    } catch (e) {
      throw ResetException(ResetErrorKind.unknown, '$e');
    }
    return completer.future;
  }

  Future<void> _sendEmailCode(String email) async {
    try {
      await _functions.httpsCallable('sendPasswordResetCode').call<void>(
        <String, dynamic>{'email': email},
      );
    } on FirebaseFunctionsException catch (e) {
      throw _mapFunctionsError(e);
    } catch (e) {
      throw ResetException(ResetErrorKind.unknown, '$e');
    }
  }

  /// Checks [code] against [target]. Returns the proof the next screen needs.
  ///
  /// Throws [ResetException] on failure.
  Future<VerifiedReset> verifyCode(ResetTarget target, String code) async {
    if (!FirebaseBootstrap.isReady) {
      throw ResetException(ResetErrorKind.backendUnavailable);
    }
    return target.isPhone
        ? _verifyPhoneCode(code)
        : _verifyEmailCode(target.value, code);
  }

  Future<VerifiedReset> _verifyPhoneCode(String code) async {
    final verificationId = _verificationId;
    if (verificationId == null) {
      throw ResetException(
        ResetErrorKind.expiredCode,
        'No verificationId — sendCode was never completed.',
      );
    }
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: code,
      );
      final result = await _auth.signInWithCredential(credential);
      return VerifiedReset(phoneCredentialUser: result.user);
    } on FirebaseAuthException catch (e) {
      throw _mapAuthError(e);
    } catch (e) {
      throw ResetException(ResetErrorKind.unknown, '$e');
    }
  }

  Future<VerifiedReset> _verifyEmailCode(String email, String code) async {
    try {
      final response = await _functions
          .httpsCallable('verifyPasswordResetCode')
          .call<Map<String, dynamic>>(<String, dynamic>{
            'email': email,
            'code': code,
          });
      final token = response.data['resetToken'] as String?;
      if (token == null || token.isEmpty) {
        throw ResetException(
          ResetErrorKind.unknown,
          'Function returned no resetToken.',
        );
      }
      return VerifiedReset(emailResetToken: token);
    } on FirebaseFunctionsException catch (e) {
      throw _mapFunctionsError(e);
    } on ResetException {
      rethrow;
    } catch (e) {
      throw ResetException(ResetErrorKind.unknown, '$e');
    }
  }

  /// Final step — actually set the new password.
  ///
  /// The password is sent straight to Firebase Auth (phone flow) or to the
  /// Admin SDK inside a Cloud Function (email flow). It is never written to
  /// Firestore, never logged, and never cached — Firestore only records
  /// *when* the change happened, via `users/{uid}.passwordChangedAt`.
  ///
  /// Both paths revoke the account's other refresh tokens server-side, so a
  /// session an attacker already had is killed by the reset.
  Future<void> completePasswordReset({
    required ResetTarget target,
    required VerifiedReset verified,
    required String newPassword,
  }) async {
    if (!FirebaseBootstrap.isReady) {
      throw ResetException(ResetErrorKind.backendUnavailable);
    }

    if (target.isPhone) {
      final user = verified.phoneCredentialUser ?? _auth.currentUser;
      if (user == null) {
        throw ResetException(ResetErrorKind.sessionExpired);
      }
      try {
        await user.updatePassword(newPassword);
      } on FirebaseAuthException catch (e) {
        throw _mapAuthError(e);
      } catch (e) {
        throw ResetException(ResetErrorKind.unknown, '$e');
      }
      // Stamp Firestore + revoke other sessions. Done in a function so the
      // client needs no write access to `users` at all.
      try {
        await _functions.httpsCallable('recordPasswordChange').call<void>();
      } on FirebaseFunctionsException catch (e) {
        // The password itself already changed — don't fail the user's reset
        // over the bookkeeping call.
        debugPrint('recordPasswordChange failed: ${e.code} ${e.message}');
      }
      return;
    }

    final token = verified.emailResetToken;
    if (token == null || token.isEmpty) {
      throw ResetException(ResetErrorKind.sessionExpired);
    }
    try {
      await _functions.httpsCallable('confirmPasswordResetWithCode').call<void>(
        <String, dynamic>{
          'email': target.value,
          'resetToken': token,
          'newPassword': newPassword,
        },
      );
    } on FirebaseFunctionsException catch (e) {
      throw _mapFunctionsError(e);
    } catch (e) {
      throw ResetException(ResetErrorKind.unknown, '$e');
    }
  }

  ResetException _mapAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-verification-code':
        return ResetException(ResetErrorKind.incorrectCode, e.message);
      case 'session-expired':
      case 'invalid-verification-id':
      case 'code-expired':
        return ResetException(ResetErrorKind.expiredCode, e.message);
      case 'too-many-requests':
      case 'quota-exceeded':
        return ResetException(ResetErrorKind.tooManyAttempts, e.message);
      case 'network-request-failed':
        return ResetException(ResetErrorKind.network, e.message);
      case 'weak-password':
      case 'password-does-not-meet-requirements':
        return ResetException(ResetErrorKind.weakPassword, e.message);
      case 'requires-recent-login':
      case 'user-token-expired':
        return ResetException(ResetErrorKind.sessionExpired, e.message);
      default:
        return ResetException(
          ResetErrorKind.unknown,
          '${e.code}: ${e.message}',
        );
    }
  }

  ResetException _mapFunctionsError(FirebaseFunctionsException e) {
    // These `details` values are set deliberately by our own Cloud Functions
    // so the client can localize without the server leaking specifics.
    switch (e.details) {
      case 'incorrect-code':
        return ResetException(ResetErrorKind.incorrectCode, e.message);
      case 'expired-code':
        return ResetException(ResetErrorKind.expiredCode, e.message);
      case 'too-many-attempts':
        return ResetException(ResetErrorKind.tooManyAttempts, e.message);
      case 'weak-password':
        return ResetException(ResetErrorKind.weakPassword, e.message);
      case 'invalid-reset-token':
        return ResetException(ResetErrorKind.sessionExpired, e.message);
    }
    switch (e.code) {
      case 'resource-exhausted':
        return ResetException(ResetErrorKind.tooManyAttempts, e.message);
      case 'unavailable':
      case 'deadline-exceeded':
        return ResetException(ResetErrorKind.network, e.message);
      default:
        return ResetException(
          ResetErrorKind.unknown,
          '${e.code}: ${e.message}',
        );
    }
  }
}
