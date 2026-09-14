import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

import 'firebase_bootstrap.dart';

/// Crash reporting (`SECURITY.md` 10), with every report scrubbed first.
///
/// Crashlytics is free on the Spark plan — no Blaze upgrade is involved.
///
/// ## Why reports are rewritten rather than forwarded
///
/// `SECURITY.md` 5.1 names Crashlytics explicitly as somewhere card data must
/// never reach — "not in Crashlytics, not 'temporarily for debugging'" — and
/// 6.1b applies the same absolute rule to passwords. An exception message is
/// assembled by whatever threw it, which includes Firebase SDKs and any future
/// payment SDK, so it cannot be assumed safe.
///
/// So nothing is forwarded verbatim. [redact] rewrites the message first, and
/// the report carries the exception's **type** plus that redacted text. Type
/// names describe code, never values.
///
/// Over-redaction is the intended failure mode: a report that is harder to
/// read costs debugging time, while a leaked credential costs an account.
///
/// Stack traces are forwarded unmodified — frames carry file, line and
/// function names, never argument values.
class CrashReporter {
  CrashReporter({FirebaseCrashlytics? crashlytics})
    : _crashlyticsOverride = crashlytics;

  final FirebaseCrashlytics? _crashlyticsOverride;

  FirebaseCrashlytics get _crashlytics =>
      _crashlyticsOverride ?? FirebaseCrashlytics.instance;

  /// Collection is off in debug so developer crashes never reach the live
  /// dashboard, and so `flutter test` cannot post anything.
  static bool get isEnabled => !kDebugMode && FirebaseBootstrap.isReady;

  /// Installs the two global error handlers.
  ///
  /// Both are installed even when [isEnabled] is false, so the console output
  /// a developer relies on keeps working; only the upload is skipped.
  Future<void> initialize() async {
    final previousOnError = FlutterError.onError;

    // Errors thrown inside the Flutter framework — build, layout, paint.
    FlutterError.onError = (details) {
      // Keeps the red screen and console dump in debug.
      previousOnError?.call(details);
      report(
        details.exception,
        details.stack,
        fatal: true,
        context: details.context?.toString(),
      );
    };

    // Uncaught asynchronous and platform errors that never reach the
    // framework — a failed Future with no catch, or a platform-channel throw.
    PlatformDispatcher.instance.onError = (error, stack) {
      report(error, stack, fatal: true);
      // True = handled; returning false would let the platform terminate the
      // isolate, losing the very report we just filed.
      return true;
    };

    if (!isEnabled) return;
    try {
      await _crashlytics.setCrashlyticsCollectionEnabled(true);
    } catch (error) {
      debugPrint('Could not enable Crashlytics collection: $error');
    }
  }

  /// Files one report, redacted.
  ///
  /// Never throws: a crash reporter that crashes while reporting a crash is
  /// worse than one that stays quiet.
  Future<void> report(
    Object error,
    StackTrace? stack, {
    bool fatal = false,
    String? context,
  }) async {
    final safe = '${error.runtimeType}: ${redact(error.toString())}';
    if (!isEnabled) {
      debugPrint('[crash${fatal ? ' fatal' : ''}] $safe');
      return;
    }
    try {
      await _crashlytics.recordError(
        safe,
        stack,
        reason: context == null ? null : redact(context),
        fatal: fatal,
      );
    } catch (reportingError) {
      debugPrint('Could not file a crash report: $reportingError');
    }
  }

  // --- redaction ----------------------------------------------------------

  /// What a redacted span is replaced with, by kind.
  static const String _card = '[redacted:card]';
  static const String _code = '[redacted:code]';
  static const String _token = '[redacted:token]';
  static const String _email = '[redacted:email]';
  static const String _phone = '[redacted:phone]';
  static const String _secret = '[redacted]';

  /// Keys whose *value* is sensitive wherever it appears, in any of the
  /// shapes an SDK might format them: `password: x`, `token=x`, `"cvv":"x"`.
  static const List<String> _sensitiveKeys = [
    'password',
    'newpassword',
    'currentpassword',
    'passcode',
    'pin',
    'cvv',
    'cvc',
    'cardnumber',
    'card_number',
    'pan',
    'expiry',
    'idtoken',
    'id_token',
    'accesstoken',
    'access_token',
    'refreshtoken',
    'refresh_token',
    'apikey',
    'api_key',
    'secret',
    'authorization',
    'otp',
    'verificationcode',
    'verification_code',
    'smscode',
    'sms_code',
  ];

  /// Rewrites anything that could be a credential or personal identifier.
  ///
  /// Ordered most specific first: a key/value pair is redacted before the
  /// looser digit-run patterns get a chance to partially match inside it.
  @visibleForTesting
  static String redact(String input) {
    if (input.isEmpty) return input;
    var out = input;

    // 1. key: value / key=value / "key":"value"
    for (final key in _sensitiveKeys) {
      out = out.replaceAllMapped(
        RegExp(
          '("?\\b$key"?\\s*[:=]\\s*)'
          // An auth scheme is a label, not the secret. Without this,
          // "Authorization: Bearer <token>" loses only the word "Bearer".
          '((?:Bearer|Basic|Token)\\s+)?'
          '("[^"]*"|\'[^\']*\'|[^,;}\\s]+)',
          caseSensitive: false,
        ),
        (m) => '${m[1]}${m[2] ?? ''}$_secret',
      );
    }

    // 2. JWTs and Firebase ID tokens.
    out = out.replaceAll(
      RegExp(r'\beyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]+\.?[A-Za-z0-9_-]*'),
      _token,
    );

    // 3. E.164-ish phone numbers, BEFORE the card rule: a +964 number is
    //    thirteen digits, so the card pattern would otherwise claim it —
    //    mislabelling it and swallowing the surrounding spacing.
    out = out.replaceAll(RegExp(r'\+\d[\d\s-]{7,17}\d'), _phone);

    // 4. Card-like digit runs, 13–19 digits with optional spaces or dashes.
    //    Checked before the 6-digit code rule so a PAN is never chopped into
    //    "code" fragments.
    out = out.replaceAll(
      RegExp(r'\b(?:\d[ -]?){13,19}\b'),
      _card,
    );

    // 5. Email addresses. Not a credential, but it identifies a person and
    //    SECURITY.md 9 says not to collect more than a screen needs.
    out = out.replaceAll(
      RegExp(r'\b[\w.+-]+@[\w-]+\.[\w.-]+\b'),
      _email,
    );

    // 6. Standalone 6-digit runs — the shape of every verification and
    //    password-reset code in this app (6.1a, 6.1g). Deliberately broad:
    //    a redacted order number is a nuisance, a leaked reset code is an
    //    account takeover.
    out = out.replaceAll(RegExp(r'(?<![\w.])\d{6}(?![\w.])'), _code);

    return out;
  }
}
