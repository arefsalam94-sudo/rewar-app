import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

/// A reusable payment method as the app is allowed to know it.
///
/// **Presentation-safe metadata only.** `DATA_MODEL.md` → "Saved payment
/// methods": when a provider is wired in, a callable Cloud Function returns
/// the `providerMethodId`, brand, bank label, last four digits, expiry and
/// default status — and nothing else. A PAN or CVC has no field here because
/// it must never reach the client, Firestore, or a log (`SECURITY.md` 5.1).
///
/// Shared by the Billing & Payments screen and checkout step 2, so the two
/// cannot disagree about what a saved card looks like.
class SavedPaymentMethod {
  const SavedPaymentMethod({
    required this.id,
    required this.issuer,
    required this.kind,
    required this.last4,
    required this.expiry,
    required this.brand,
    required this.colors,
  });

  /// Stable handle for Change/Delete and for "which one is default". Two cards
  /// can share a brand and last four, so position and display text are both
  /// unsafe to target by.
  final String id;

  final CardIssuer issuer;
  final CardKind kind;

  /// The last four digits — the most of a card number this app may ever hold.
  final String last4;

  /// `MM/YY`, for display beside the last four.
  final String expiry;

  /// `VISA` / `MC` / `CARD`.
  final String brand;

  /// The card artwork gradient.
  final List<Color> colors;

  String issuerLabel(AppLocalizations l10n) => switch (issuer) {
    CardIssuer.kurdistanInternationalBank => l10n.kurdistanInternationalBank,
    CardIssuer.firstIraqiBank => l10n.firstIraqiBank,
    CardIssuer.saved => l10n.savedCard,
  };

  String kindLabel(AppLocalizations l10n) => switch (kind) {
    CardKind.debit => l10n.debitCard,
    CardKind.credit => l10n.creditCard,
    CardKind.debitOrCredit => l10n.debitOrCreditCard,
  };
}

enum CardIssuer { kurdistanInternationalBank, firstIraqiBank, saved }

enum CardKind { debit, credit, debitOrCredit }

/// Which rail a payment runs on.
///
/// The stored [id] matches `bookings.paymentProvider` in `DATA_MODEL.md`, so a
/// booking paid through either rail stays queryable alongside the other.
/// `nasswallet` exists in that schema but is deliberately not offered in the
/// UI — see `SECURITY.md` 5.3, its integration pattern is still unverified.
enum PaymentRail {
  /// International cards. Settled through the processor's own SDK.
  card('stripe'),

  /// First Iraqi Bank — the local rail, per `SECURITY.md` 5.3.
  fib('fib');

  const PaymentRail(this.id);

  final String id;

  String label(AppLocalizations l10n) => switch (this) {
    PaymentRail.card => l10n.mastercardVisa,
    PaymentRail.fib => l10n.firstIraqiBank,
  };
}

/// The two design fixtures, shared by both screens.
///
/// **Fixture data, not live.** `DATA_MODEL.md` is explicit that the carousel is
/// design-only until the callable that lists a provider customer's real methods
/// exists. Kept in one place so the Billing screen and checkout step 2 show the
/// same cards rather than two different inventions.
List<SavedPaymentMethod> demoSavedPaymentMethods() => const [
  SavedPaymentMethod(
    id: 'seed-1',
    issuer: CardIssuer.kurdistanInternationalBank,
    kind: CardKind.debit,
    last4: '4832',
    expiry: '06/28',
    brand: 'VISA',
    colors: [Color(0xFF57C6C1), Color(0xFF07516B), Color(0xFF092E50)],
  ),
  SavedPaymentMethod(
    id: 'seed-2',
    issuer: CardIssuer.firstIraqiBank,
    kind: CardKind.credit,
    last4: '7219',
    expiry: '11/29',
    brand: 'MC',
    colors: [Color(0xFF254C7E), Color(0xFF112B50), Color(0xFF071C35)],
  ),
];
