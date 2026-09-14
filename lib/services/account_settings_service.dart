import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'profile_setup_service.dart';

class AccountSettingsService {
  AccountSettingsService({
    FirebaseAuth? auth,
    FirebaseFunctions? functions,
    ProfileSetupService? profileSetup,
  }) : _authOverride = auth,
       _functionsOverride = functions,
       _profileSetup = profileSetup ?? ProfileSetupService();

  final FirebaseAuth? _authOverride;
  final FirebaseFunctions? _functionsOverride;
  final ProfileSetupService _profileSetup;

  FirebaseAuth get _auth => _authOverride ?? FirebaseAuth.instance;
  FirebaseFunctions get _functions =>
      _functionsOverride ?? FirebaseFunctions.instance;

  Future<void> updateProfile({required String fullName, File? image}) async {
    await _profileSetup.completeSetup(displayName: fullName, imageFile: image);
  }

  // `changeUsername` was removed with the username feature. A user is
  // identified by their display name and email; the display name is edited
  // through [updateProfile] above.

  /// Confirms that the user knows the credentials for the currently signed-in
  /// app account. The email is checked explicitly so a stale/autofilled value
  /// cannot silently authenticate a different account.
  Future<void> confirmEmailIdentity({
    required String currentEmail,
    required String currentPassword,
  }) async {
    final user = _requireUser();
    final signedInEmail = user.email;
    if (signedInEmail == null) {
      throw StateError('No email account is signed in.');
    }
    if (currentEmail.trim().toLowerCase() !=
        signedInEmail.trim().toLowerCase()) {
      throw StateError('The current email does not match the signed-in user.');
    }
    await user.reauthenticateWithCredential(
      EmailAuthProvider.credential(
        email: signedInEmail,
        password: currentPassword,
      ),
    );
    // Ensure the callable functions receive the new `auth_time`, rather than
    // a cached token issued before this reauthentication.
    await user.getIdToken(true);
  }

  /// Sends a six-digit verification code to the proposed new email address.
  Future<void> sendEmailChangeCode(String newEmail) async {
    await _functions.httpsCallable('sendEmailChangeCode').call<void>(
      <String, dynamic>{'newEmail': newEmail.trim().toLowerCase()},
    );
  }

  /// Verifies the code and atomically promotes the new address to the
  /// Firebase Auth identity and the user's profile document.
  Future<void> confirmEmailChangeCode({
    required String newEmail,
    required String code,
  }) async {
    await _functions.httpsCallable('confirmEmailChangeCode').call<void>(
      <String, dynamic>{
        'newEmail': newEmail.trim().toLowerCase(),
        'code': code,
      },
    );
    await _requireUser().reload();
    await _requireUser().getIdToken(true);
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _requireUser();
    final email = user.email;
    if (email == null) throw StateError('Password login is not available.');
    await user.reauthenticateWithCredential(
      EmailAuthProvider.credential(email: email, password: currentPassword),
    );
    await user.updatePassword(newPassword);
    await _functions
        .httpsCallable('recordPasswordChange')
        .call<Map<Object?, Object?>>();
  }

  Future<void> startPhoneVerification({
    required String phone,
    required void Function(String verificationId) codeSent,
    required VoidCallback completed,
    required void Function(FirebaseAuthException error) failed,
  }) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phone.trim(),
      verificationCompleted: (credential) async {
        await _requireUser().updatePhoneNumber(credential);
        await _functions
            .httpsCallable('syncPhoneNumber')
            .call<Map<Object?, Object?>>();
        completed();
      },
      verificationFailed: failed,
      codeSent: (verificationId, _) => codeSent(verificationId),
      codeAutoRetrievalTimeout: (_) {},
    );
  }

  Future<void> confirmPhoneCode({
    required String verificationId,
    required String code,
  }) async {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: code,
    );
    await _requireUser().updatePhoneNumber(credential);
    await _functions
        .httpsCallable('syncPhoneNumber')
        .call<Map<Object?, Object?>>();
  }

  User _requireUser() {
    final user = _auth.currentUser;
    if (user == null) throw StateError('No signed-in user.');
    return user;
  }
}
