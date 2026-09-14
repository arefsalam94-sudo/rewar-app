import 'package:cloud_functions/cloud_functions.dart';

import 'password_reset_service.dart' show ResetErrorKind, ResetException;

/// Proves the user controls the email address they registered with.
///
/// Registration collects an email but had no way of knowing it was real: a
/// typo, or someone else's address, produced an account that could never
/// receive a password reset. This closes that gap by requiring a six-digit
/// code before the flow continues.
///
/// ## Why a code rather than Firebase's link
///
/// `sendEmailVerification()` sends a clickable *link*, which on a phone means
/// leaving the app mid-registration and hoping the user comes back. A code
/// keeps the user in the flow, and the app already has a designed code screen
/// and Cloud Function pattern for exactly this (`sendEmailChangeCode`), so
/// there is now one verification experience rather than two.
///
/// ## Security
///
/// See `SECURITY.md` 6.1a — the same properties as the other code flows:
///
/// - The destination address is **read server-side from Firebase Auth**, not
///   taken from the request. A client cannot aim a code at an address it does
///   not own.
/// - Only a salted hash of the code is stored; the plaintext is never
///   persisted and never returned to the client.
/// - `email_verify_codes` is fully closed to clients in `firestore.rules`.
/// - Sends are rate limited, verify attempts are capped, codes expire after
///   ten minutes and are burned on first successful use.
/// - `emailVerified` is written by the Admin SDK only — it is on no
///   client-writable allow-list (`SECURITY.md` 6.1c).
///
/// Reuses [ResetException] / [ResetErrorKind] so the shared Verification Code
/// screen maps failures to the same localized strings for every flow.
class EmailVerificationService {
  EmailVerificationService({FirebaseFunctions? functions})
    : _functionsOverride = functions;

  final FirebaseFunctions? _functionsOverride;

  FirebaseFunctions get _functions =>
      _functionsOverride ?? FirebaseFunctions.instance;

  /// Sends (or resends) the code to the address on the signed-in account.
  Future<void> sendCode() async {
    try {
      await _functions
          .httpsCallable('sendRegistrationEmailCode')
          .call<Map<Object?, Object?>>();
    } on FirebaseFunctionsException catch (e) {
      throw ResetException(_kindFor(e), '${e.code}: ${e.message}');
    } catch (e) {
      throw ResetException(ResetErrorKind.unknown, '$e');
    }
  }

  /// Confirms [code]. Returns normally on success; throws otherwise.
  Future<void> verifyCode(String code) async {
    try {
      await _functions
          .httpsCallable('confirmRegistrationEmailCode')
          .call<Map<Object?, Object?>>({'code': code});
    } on FirebaseFunctionsException catch (e) {
      throw ResetException(_kindFor(e), '${e.code}: ${e.message}');
    } catch (e) {
      throw ResetException(ResetErrorKind.unknown, '$e');
    }
  }

  /// Maps the function's `details` string (set alongside each `HttpsError`)
  /// onto the shared error kinds, falling back to the gRPC code.
  static ResetErrorKind _kindFor(FirebaseFunctionsException e) {
    switch (e.details) {
      case 'incorrect-code':
        return ResetErrorKind.incorrectCode;
      case 'expired-code':
        return ResetErrorKind.expiredCode;
      case 'too-many-attempts':
        return ResetErrorKind.tooManyAttempts;
    }
    switch (e.code) {
      case 'unauthenticated':
        return ResetErrorKind.sessionExpired;
      case 'unavailable':
      case 'deadline-exceeded':
        return ResetErrorKind.network;
      default:
        return ResetErrorKind.unknown;
    }
  }
}
