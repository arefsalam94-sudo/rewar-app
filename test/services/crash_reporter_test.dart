import 'package:flutter_test/flutter_test.dart';
import 'package:kurdistan_paradise_travel_guide/services/crash_reporter.dart';

/// Nothing in this file touches Firebase — `redact` is pure, which is the
/// whole point: the one piece that must never be wrong is testable without a
/// project, a network or a plan.
void main() {
  String redact(String s) => CrashReporter.redact(s);

  /// Fails if any part of [secret] survives redaction.
  void expectGone(String input, String secret, {String? becomes}) {
    final out = redact(input);
    expect(
      out.contains(secret),
      isFalse,
      reason: 'the secret survived redaction:\n  in:  $input\n  out: $out',
    );
    if (becomes != null) expect(out, contains(becomes));
  }

  group('passwords never reach Crashlytics (SECURITY.md 6.1b)', () {
    test('password: value', () {
      expectGone('Auth failed password: Hunter2Hunter', 'Hunter2Hunter',
          becomes: '[redacted]');
    });

    test('password=value', () {
      expectGone('signIn(password=Str0ng!Pass9)', 'Str0ng!Pass9');
    });

    test('quoted JSON field', () {
      expectGone('{"password":"Str0ng!Pass9"}', 'Str0ng!Pass9');
    });

    test('newPassword and currentPassword', () {
      expectGone('newPassword: Abcdefg1', 'Abcdefg1');
      expectGone('currentPassword=OldPass123', 'OldPass123');
    });

    test('the key name is case-insensitive', () {
      expectGone('PASSWORD: Secret99xyz', 'Secret99xyz');
      expectGone('PassWord = Secret99xyz', 'Secret99xyz');
    });
  });

  group('card data never reaches Crashlytics (SECURITY.md 5.1)', () {
    test('a bare 16-digit PAN', () {
      expectGone('charge failed for 4111111111111111', '4111111111111111',
          becomes: '[redacted:card]');
    });

    test('a spaced PAN', () {
      expectGone('card 4111 1111 1111 1111 declined', '4111 1111 1111 1111');
    });

    test('a dashed PAN', () {
      expectGone('card 4111-1111-1111-1111 declined', '4111-1111-1111-1111');
    });

    test('a 13-digit PAN, the shortest real one', () {
      expectGone('pan 4111111111111 bad', '4111111111111');
    });

    test('cvv and expiry by key', () {
      expectGone('cvv: 123', '123');
      expectGone('expiry=12/29', '12/29');
    });
  });

  group('verification and reset codes (SECURITY.md 6.1a, 6.1g)', () {
    test('a standalone six-digit code', () {
      expectGone('code 482913 rejected', '482913', becomes: '[redacted:code]');
    });

    test('by key name', () {
      expectGone('verificationCode: 482913', '482913');
      expectGone('smsCode=482913', '482913');
      expectGone('otp: 482913', '482913');
    });

    test('a six-digit run is redacted even without a keyword', () {
      // Deliberately broad. A redacted order number is a nuisance; a leaked
      // reset code is an account takeover.
      expectGone('reference 482913 not found', '482913');
    });
  });

  group('tokens', () {
    test('a JWT / Firebase ID token', () {
      const jwt =
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NSJ9.abc123def';
      expectGone('auth failed with $jwt', jwt, becomes: '[redacted:token]');
    });

    test('by key name', () {
      expectGone('idToken: abcdefghijklmnop', 'abcdefghijklmnop');
      expectGone('access_token=abcdefghijklmnop', 'abcdefghijklmnop');
      expectGone('Authorization: Bearer abcdefghij', 'abcdefghij');
    });

    test('an api key by name', () {
      expectGone('apiKey: AIzaSyCPpx9hPpdQWhjcjxlmw', 'AIzaSyCPpx9hPpdQWhjcjxlmw');
    });
  });

  group('personal identifiers (SECURITY.md 9)', () {
    test('email addresses', () {
      expectGone('no user for alice@example.com', 'alice@example.com',
          becomes: '[redacted:email]');
    });

    test('an email with a plus tag', () {
      expectGone('user a.b+tag@example.co.uk missing', 'a.b+tag@example.co.uk');
    });

    test('E.164 phone numbers', () {
      expectGone('verify +9647501234567 failed', '+9647501234567',
          becomes: '[redacted:phone]');
    });

    test('a spaced phone number', () {
      expectGone('sms to +964 750 123 4567 failed', '+964 750 123 4567');
    });
  });

  group('what redaction must NOT destroy', () {
    test('the exception type and shape survive', () {
      final out = redact('FirebaseAuthException: wrong-password');
      expect(out, contains('FirebaseAuthException'));
      // An error CODE is not a credential and is the useful part.
      expect(out, contains('wrong-password'));
    });

    test('short numbers are left alone', () {
      // Line numbers, counts, HTTP statuses.
      expect(redact('failed at line 42 with status 403'), contains('42'));
      expect(redact('failed at line 42 with status 403'), contains('403'));
    });

    test('a five-digit number is not treated as a code', () {
      expect(redact('offset 12345 invalid'), contains('12345'));
    });

    test('an empty message stays empty', () {
      expect(redact(''), isEmpty);
    });

    test('an already-safe message is unchanged', () {
      const safe = 'Could not load nature spots: Bad state: simulated failure';
      expect(redact(safe), safe);
    });
  });

  group('combined and adversarial inputs', () {
    test('several secrets in one message all go', () {
      const input =
          'signup failed email=alice@example.com password=Str0ng!Pass9 '
          'code 482913 card 4111111111111111';
      final out = redact(input);
      for (final secret in [
        'alice@example.com',
        'Str0ng!Pass9',
        '482913',
        '4111111111111111',
      ]) {
        expect(out.contains(secret), isFalse, reason: '$secret survived: $out');
      }
    });

    test('a PAN is redacted whole, not split into code fragments', () {
      final out = redact('4111111111111111');
      expect(out, '[redacted:card]');
      expect(out, isNot(contains('[redacted:code]')));
    });

    test('redaction is idempotent', () {
      final once = redact('password: Str0ng!Pass9');
      expect(redact(once), once);
    });

    test('a very long message does not throw', () {
      expect(() => redact('x' * 20000), returnsNormally);
    });
  });

  group('collection is off where it must be', () {
    test('disabled under flutter test', () {
      // kDebugMode is true and Firebase is never initialised here, so a test
      // run cannot post to the live dashboard.
      expect(CrashReporter.isEnabled, isFalse);
    });

    test('report() does not throw when disabled', () async {
      await expectLater(
        CrashReporter().report(StateError('boom'), StackTrace.current),
        completes,
      );
    });
  });
}
