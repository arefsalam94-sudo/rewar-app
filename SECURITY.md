# SECURITY.md — Security Requirements

*Last verified against current standards: July 2026 (PCI DSS v4.0.1, the
version in effect now — all of its previously "future-dated" requirements
became mandatory as of March 2025). Security standards change; if this
file hasn't been reviewed in 6-12 months, that's a signal to re-check it,
not to assume it's still fully current.*

This is not optional polish — treat every rule here as part of "definition
of done" alongside `CLAUDE.md`. A screen that works but skips the matching
security rule is not finished. **Payment-related screens are held to the
highest bar in this file — see section 5 specifically.**

## 1. Firestore Security Rules — core principles

- **Deny by default.** Every collection starts with no access; each rule
  explicitly grants the minimum access it needs. Never leave a collection
  in Firebase's default test mode (`allow read, write: if true;`) past the
  screen that introduces it.
- **Validate shape, not just auth.** Rules should check that incoming data
  has the right fields/types (e.g. `pricePerNight` is a number, not just
  "any authenticated user can write anything"). Client-side validation is
  for UX; rules are the actual security boundary — assume the client can
  be bypassed entirely.
- **Users can only read/write their own data** for anything user-specific
  (`bookings`, `favorites`, their own `users/{uid}` document). Check
  `request.auth.uid == resource.data.userId` (or the relevant field) on
  every rule that touches personal data.
- **Public read, admin-only write** for catalog data (`hotels`, `cars`,
  `tours`, `flights`, `nature_spots`) — any user can read these to browse
  the app, but only admins can create/update/delete them.
- Write rules for a collection **at the same time** you build the screen
  that uses it — not as cleanup at the end. Add them to version control
  and treat changes to them with the same scrutiny as schema changes.
- **Every rule change must be covered by `rules_test/`** — the emulator-based
  regression suite for `firestore.rules` (201 tests, `cd rules_test && npm test`).
  It runs on a `demo-` project id, so it never touches the live project, and it
  uses a simulated `admin: true` custom claim rather than a real admin account.
  Adding a collection means adding its allow *and* deny cases there in the same
  change; a rule with no test is a rule nobody will notice regressing.

### 1a. `bookings` is owner-read and **client-write-denied**

Stricter than the general "own data" rule above, and deliberately so. A booking
is the record of a completed payment, which makes it the single most valuable
document in this database to forge.

| Operation | Client | Why |
|---|---|---|
| `get` / `list` | owner only | `list` is safe only because the rule pins `resource.data.userId` to the caller, so Firestore rejects any query not provably limited to their own documents. Same mechanism as `favorites` |
| `create` | **denied** | Created only by the checkout Cloud Function, after the payment provider confirms the charge (section 5). A client that could create here could mint itself a confirmed booking it never paid for |
| `update` | **denied** | Status transitions (confirmed → cancelled → completed) reflect real-world state the client does not own |
| `delete` | **denied** | A user must not be able to erase the record of a transaction. Account deletion cascades through a Cloud Function (section 9) |

The Admin SDK bypasses rules entirely, so denying every client write costs the
server nothing.

**`bookingReference` must be generated server-side.** It is quoted to support
and printed as a scannable barcode; a client-chosen value could collide with, or
deliberately impersonate, another user's booking.

**No guest bookings.** `request.auth` must exist, so a signed-out user is shown
a sign-in prompt rather than an empty list — no anonymous mirror of signed-in
data (6.1f).

**Verify by trying to break it**, as this file requires — not by checking that
the UI hides the button:

1. Signed out: `get`/`list` on `bookings` → must be denied.
2. Signed in as user A: `list` filtered to user B's uid → must be denied, not
   return an empty set.
3. Signed in as the owner: `create`, `update` and `delete` on your own booking
   → all three must be denied.
4. Signed in as the owner: `list` filtered to your own uid → must succeed.

> ✅ **Run against the live project 2026-09-12, all four passed.** Two throwaway
> Auth users were created; A could not create, update or delete a booking, and
> could not read B's rows. Signed-out reads were denied. Both users and every
> document written during the test were deleted afterwards.

### 1b. The preview sign-in account — REMOVED 2026-09-12

There was **one hard-coded account** (`kurdistan` / `Asd!@3`) in
`AuthService.previewUsername` / `previewPassword`, so the app could be walked
and design-reviewed before a Firebase project existed. Real sign-in now exists
(`AuthService.signIn`, section 6.1), so per the deletion rule this scaffolding
has been removed outright.

**What was deleted**

- `AuthService.previewUsername` / `previewPassword` / `previewDisplayName` /
  `checkPreviewCredentials`, and `AuthService.isPreviewMode`
- `lib/services/preview_identity.dart` — the locally-stored stand-in identity
- `lib/widgets/preview_mode_banner.dart` and its use on all five auth screens
- The Login screen's preview fallback, including the validator exception that
  let a bare username through where an email is required
- The preview branches in `PasswordResetService`, `EmailVerificationService`,
  `AccountSettingsService`, `ProfileSetupService` and `UserProfileService`
- `BookingsService.currentUserId` no longer returns a fabricated
  `'preview-user'` uid
- `test/screens/login_preview_signin_test.dart`,
  `test/services/preview_identity_test.dart`, and the two preview-dependent
  tests in `test/widget_test.dart` / `email_verification_service_test.dart`

**The most important one was not the password.** `EmailVerificationService`
accepted *any* six digits in preview mode. That is a verification bypass, not
merely a convenience account, and it is gone.

**What deliberately remains, and why it is not an auth backdoor.** Several
catalog services keep an `isPreviewMode` getter
(`kDebugMode && !FirebaseBootstrap.isReady`) that serves **bundled content**
when Firebase is unreachable — `featured`, `nature_spots`, `tours`,
`currency_rates`, `legal_documents`, `favorites`, and the bundled booking
fixtures. These supply data to draw; none of them authenticates anyone, grants
access, or asserts an identity. The mock services behind the unfinished
Hotels, Cars and Flights screens (`PreviewHotelService`,
`PreviewCarRentalService`, `MockFlightResultsService`) are likewise untouched.

The rule going forward: **a preview path may supply content, never an
identity or a credential.**

### 1c. User-generated reviews — the id is the control

Added when the Reviews & Ratings screen was built. This is the first place in
the app where **one user writes content everybody else reads**, which is a
different risk from `bookings` or `favorites`.

- **The review document id is the author's uid.** This is the whole design.
  It makes "one review per person per place" enforceable in a rule
  (`reviewId == request.auth.uid`) rather than merely intended — without it, a
  modified client could post the same opinion a hundred times and move a
  place's average wherever it wanted, and no rule could distinguish that from
  a hundred honest visitors. Rate limiting would not have fixed this; a patient
  attacker just waits.
- **`rating` is validated as a half-step number**, `0.5 ≤ r ≤ 5` and
  `r * 2 == round(r * 2)`. The step check matters as much as the range: 3.7 is
  inside the range but is a value no UI in this app can produce, so accepting
  it means accepting something that only came from a hand-rolled client.
- **The aggregates are not writable, at all.** `reviewScore`, `ratingCount` and
  `ratingBreakdown` live on `nature_spots` or `tours`, which stay admin-only
  write, and are derived by a Cloud Function. A client that could write an average
  score could give a competitor a 2.0 without ever leaving a review.
- **`helpfulCount` is server-owned** and is on no client allow-list. For both
  nature and tour reviews, the client writes `reviews/{id}/votes/{uid}` — a
  document keyed by the voter, which
  cannot be created twice by the same person — and a trigger counts them. An
  incrementable counter can be sent in a loop; a document cannot.
- **`list` on `votes` is denied.** Nobody needs to enumerate who liked a
  review, and allowing it would turn "helpful" into a public record of who read
  what. The screen reads only the viewer's own vote, by known id.
- **Updates compare only changed keys** (`diff().affectedKeys().hasOnly(...)`),
  so `helpfulCount` can sit on the document without the author having to send
  it back and without becoming writable — the same mechanism `users` uses for
  `hasPaymentMethod`.
- **`createdAt` is pinned to its existing value on update**, so an author
  cannot re-date an old review to push it back to the top of "Most recent".

Reviews **publish immediately** (`status: 'published'`), which was a confirmed
decision. The consequence is on the record: abusive text is live until someone
removes it, and there is no moderation queue in the admin panel yet. `status`
exists so one can be added without a migration, and `delete` is already allowed
to both the author and an admin.

**Verify by trying to break it**, not by checking the UI hides the button:

1. Signed out: `create` on `nature_spots/{id}/reviews/{anything}` and
   `tours/{id}/reviews/{anything}` → denied.
2. Signed in as A: `create` at `reviews/{B's uid}` → denied.
3. Signed in as A: `create` at `reviews/{A's uid}` with `rating: 3.7` → denied.
   With `rating: 6`, `rating: 0` → denied.
4. Signed in as A: `update` your own review setting `helpfulCount: 9999` →
   denied. Setting `createdAt` to now → denied.
5. Signed in as A: `create` at `reviews/{A}/votes/{B}` → denied.
6. Signed in as A: `list` on `reviews/{any}/votes` → denied.
7. Any client: `update` on `nature_spots/{id}` or `tours/{id}` setting
   `reviewScore` → denied.

> ✅ **Run against the live project 2026-09-12, all seven passed.** A could not
> write a review at B's uid, could not use `rating: 3.7` or `rating: 6`, could
> not set `helpfulCount`, could not vote as B, could not list the `votes`
> subcollection, and could not set `reviewScore` on a `nature_spots` or `tours`
> document. Writing a review at A's own uid succeeded, so the denials above are
> the rules working rather than the whole path being broken. All test data was
> deleted afterwards.

> ⚠️ **Two more billing-surface reads to watch.** Each page of reviews costs
> one small read per review for the viewer's own votes, and each review write
> costs the aggregate function one read per existing review on that place.
> Both are bounded and acceptable now; both are reasons App Check (6.3) should
> be on before launch, and reasons to watch the usage dashboard (section 10).

## 2. Firebase Storage Security Rules

> 🚫 **`storage.rules` is NOT deployed, and cannot be — verified 2026-09-12.**
> The bucket does not exist: `storage.googleapis.com` reports
> "The specified bucket does not exist" for both
> `rewar-app-1c10e.firebasestorage.app` and `rewar-app-1c10e.appspot.com`.
> **Firebase Storage has never been initialized on this project**, so there is
> no release target to attach a ruleset to — the release call fails with
> "The caller does not have permission".
>
> The rules file itself is correct and compiles cleanly (it was uploaded as a
> valid ruleset; only the release step failed). Fix order:
> 1. Firebase Console → Storage → **Get started** (creates the bucket).
> 2. Re-run `firebase deploy --only storage`.
> 3. Re-verify: an unauthenticated write to `profile_images/{uid}/avatar.jpg`
>    must be denied, a >5 MB image must be denied, a non-image content type
>    must be denied, and a signed-in user writing to another uid's path must
>    be denied.
>
> Until then **any Storage-dependent feature is blocked**, notably the Account
> Setup screen's avatar upload (6.1e). Note the default-deny is not protecting
> you here — there is simply nothing to protect yet.

Same principles as Firestore, applied to file uploads:
- Users can only upload to their own path (e.g. `profile_images/{uid}/`).
- Admin-only write for catalog images (`hotel_images/`, `car_images/`,
  `tour_images/`), public read.
- Enforce file size limits and content-type checks (images only) in the
  rules themselves, not just client-side — a malicious client could
  otherwise upload arbitrary files.

## 3. Admin access control

The admin panel must never rely on hiding UI elements as its only
protection — that only stops accidental access, not a deliberate one.

- Grant admin status via a **Firebase custom claim** on the user's Auth
  token, set through a Cloud Function (never set directly from a client,
  and never store "isAdmin" as a plain editable Firestore field a user
  could write to themselves).
- Every Firestore/Storage rule that gates admin-only writes checks
  `request.auth.token.admin == true`, not a client-supplied value.
- The admin panel's own login is a normal Firebase Auth login — the
  custom claim is what elevates that specific account, not a separate
  password system.
- Log admin actions (who changed what, when) — at minimum a
  `createdBy`/`updatedBy` field per document (already required by
  `DATA_MODEL.md`), ideally an `admin_activity_log` collection for
  higher-risk actions like deletes.

### 3.1 The mechanism — `tool/admin_claim.js` (added 2026-09-13)

**No account holds the admin claim yet.** The mechanism is built and tested;
granting it to a real person is a deliberate, separate act.

```
GOOGLE_APPLICATION_CREDENTIALS=/path/to/key.json node tool/admin_claim.js inspect <uid>
GOOGLE_APPLICATION_CREDENTIALS=/path/to/key.json node tool/admin_claim.js grant  <uid> --yes
GOOGLE_APPLICATION_CREDENTIALS=/path/to/key.json node tool/admin_claim.js revoke <uid> --yes
```

**Why a local script and not a Cloud Function**, as the bullet above asks for:
the binding requirement in that bullet is the parenthetical — *a client must
never set this*. A local operator script satisfies it more strictly than a
callable, because there is no deployed endpoint to attack, guess, or forget to
protect; the only way to run it is to already hold a service-account key. It is
also the only option on the Spark plan. When a callable is eventually added it
must itself be gated on `request.auth.token.admin`, and **the first admin will
still have to be created with this script** — a bootstrap cannot be performed
by an endpoint that requires an admin to call it.

Properties that matter:

- **UID only.** Email and display name are rejected as selectors; both are
  mutable, and "make the account called X an admin" is exactly the instruction
  that elevates the wrong person. `inspect` prints email, display name and
  disabled state so the operator can confirm the UID before writing.
- **Unrelated claims are preserved.** Grant and revoke merge rather than
  replace, so a future `region` or `tier` claim survives. Revoke deletes the
  `admin` key rather than setting it false.
- **Mutations refuse to run without `--yes`**, and always print before/after.
- **`inspect` never writes.**
- Nothing in `lib/` can set a claim. The client SDK has no such API.

#### A claim does not reach the client until its ID token refreshes

A custom claim is baked into the ID token when it is issued. A signed-in user
keeps their old token — and their old permissions — until it refreshes
(automatically about hourly, or immediately on `getIdToken(true)` or a fresh
sign-in).

| | effect |
|---|---|
| **Grant** | the new admin must sign out and back in before the rules let them write |
| **Revoke** | ⚠️ the ex-admin **keeps admin** until their current ID token expires — up to ~1 hour |

`revoke` calls `revokeRefreshTokens`, which stops them obtaining a *new* token,
but cannot invalidate the one already in their hand. **If a revoke is a
security response to a compromised or hostile account, disable the account as
well** — that takes effect immediately.

#### A Firestore field can never grant admin

`isAdmin()` reads `request.auth.token.admin`, and `firestore.rules` contains
**no `get()` or `exists()` lookup anywhere** — no document can influence any
access decision. `rules_test/admin_bypass.test.js` pins both: a static check
that no document lookup has been introduced into the rules, plus behavioural
tests that plant `role: "admin"`, `admin: true`, `isAdmin: true`,
`claims.admin`, `token.admin`, `customClaims.admin` and `permissions: ["admin"]`
on a user's own profile — first proving the client cannot even write them
(6.1c), then planting them server-side with rules disabled and confirming every
admin-only write is still refused. A control test confirms a real token claim
*does* grant the same writes, so the denials are not passing vacuously.

#### Still missing

An `admin_activity_log` collection (the "ideally" in the bullet list above) is
not implemented — the script prints an auditable before/after to the operator's
terminal, but nothing is persisted. Adding it means a new collection in
`DATA_MODEL.md` first.

## 4. Secrets & API keys

- Third-party API keys (for the admin panel's API-import feature, or any
  future payment/maps/weather integration) live in **Cloud Functions
  environment config**, never in the Flutter client code — anything
  shipped in the app bundle can be extracted by a determined user.
- Firebase's own client config (`google-services.json` /
  `GoogleService-Info.plist`) is safe to ship in the app — it's not a
  secret, it's a public project identifier. Security comes from the rules
  above, not from hiding this file. Don't confuse the two.
- `.gitignore` any local `.env` files used for Cloud Functions development
  secrets; never commit real API keys to the repo, including in commit
  history.

### 4.1 Account-setting changes

- **Usernames were removed from the app.** A user is identified by their
  display name and email alone. `claimUsername`, the `usernames/{name}`
  collection and `users.username` / `users.usernameNormalized` are all gone —
  see `DATA_MODEL.md`. This removed an entire uniqueness-reservation surface
  rather than hardening it, which is the better outcome: the safest namespace
  is the one that does not exist. Nothing needs re-adding to `firestore.rules`;
  deny-by-default (section 1) covers the deleted collection.
- Email changes require recent Firebase reauthentication. The server sends a
  hashed, expiring six-digit code to the proposed address; only
  `confirmEmailChangeCode` can promote that verified address into Firebase
  Auth and mirror it to the profile. The unverified address must never replace
  the current sign-in identity.
- Phone changes use Firebase SMS verification and update Auth with the issued
  credential before `syncPhoneNumber` mirrors it to Firestore.
- Password changes require the current password, use Firebase Auth directly,
  and call `recordPasswordChange`; plaintext passwords never enter Firestore
  or Cloud Function logs.

## 5. Payment security (online payments — highest priority section)

Payments change your risk profile significantly — a breach here means
real financial and legal exposure, not just an inconvenience. Follow
every rule below; none of these are optional.

### 5.1 The single most important rule: keep card data out of your app entirely
The safest card data is the data your app never touches. Use:
- **Tokenization / hosted payment fields** — card numbers go straight
  from the user's device to the payment processor (Stripe, etc.), never
  through your own servers or Firestore, via the processor's official
  SDK (e.g. `flutter_stripe`'s prebuilt Payment Sheet, or web Stripe
  Elements for the admin panel if it ever needs payment UI).
- **Apple Pay / Google Pay** where possible — these are effectively
  out of PCI scope entirely since your app never sees card details at
  all.
- Never write code that reads, logs, stores, or caches a raw card
  number, CVV, or expiry date, anywhere — not in Firestore, not in
  Cloud Function logs, not in Crashlytics, not "temporarily for
  debugging." There is no safe way to do this even briefly.

Following this one rule correctly is what keeps your PCI DSS compliance
burden small (tokenized/hosted-field integrations can qualify for a
much simpler self-assessment than an app that handles raw card data
directly) — it's the highest-leverage security decision in the whole
payment flow.

### 5.2 Recommended Firebase integration pattern
Use the **"Run Payments with Stripe" Firebase Extension** (Firestore +
Cloud Functions + webhooks, maintained by Invertase) rather than
building a custom Stripe integration from scratch:
- Card entry happens through Stripe's own SDK/Payment Sheet — never
  through custom-built input fields.
- The extension manages Stripe customers, checkout sessions, and
  subscription/payment status sync into Firestore automatically.
- Firestore rules for the extension's collections should follow the
  same "users can only read their own" pattern as the rest of this
  file — e.g. a user can read their own `stripe-customers/{uid}`
  document and its subcollections, never anyone else's.

### 5.3 Local Iraqi payment providers, alongside Stripe (not instead of it)
Confirmed as real, regulated options, added per request — Stripe/Apple
Pay/Google Pay is not exclusive; these are additional methods offered at
checkout, not a restriction on which cards are accepted (see 5.1 — Stripe
already accepts Visa/Mastercard/etc., these are separate local rails
some users will prefer):

- **FIB (First Iraqi Bank)** — has public, documented SDKs (Node.js,
  Python, PHP/Laravel, Android, WordPress) and a REST API using OAuth2
  client-credentials authentication, a sandbox environment for testing,
  and webhook/callback support for payment status. Default currency is
  IQD. Same architecture rule applies as with Stripe: the integration
  runs through a **Cloud Function** holding the `client_id`/
  `client_secret` (via `integration@fib.iq` for production credentials)
  — never in the Flutter client. Verify webhook payloads the same way
  as Stripe's.
- **NassWallet** — a Central Bank of Iraq-licensed digital wallet
  (PCI DSS compliant), supporting QR-code payments and a Visa-branded
  prepaid card (NassPay). Public self-serve API documentation wasn't
  found alongside FIB's — contact NASS directly (nass.iq) for merchant/
  developer integration docs and credentials before building against
  it, and re-verify the exact auth/webhook pattern they provide rather
  than assuming it matches FIB's or Stripe's shape.
- Whichever of these gets built, the same core rules from 5.1 and 5.4-5.7
  apply without exception — provider name changes, the security
  requirements don't.
- Add a `paymentProvider` field to the `bookings` schema in
  `DATA_MODEL.md` (`"stripe"` | `"fib"` | `"nasswallet"`) so bookings
  paid through different rails are still queryable/reportable together.

### 5.4 Critical: real-world bookings vs. digital content are treated differently by Apple/Google
This distinction can get your app **rejected from app store review** if
missed, so it's worth being explicit:
- **Real-world services** — hotel stays, car rentals, tour bookings,
  flight tickets (everything this app currently sells) — are generally
  **allowed to use Stripe/PayPal/other processors directly**. This is
  the "physical goods and services" exception to Apple's and Google's
  in-app purchase requirements.
- **Digital-only content** — subscriptions to app features, virtual
  currency, unlockable premium content, anything consumed *within* the
  app rather than in the real world — **must** use Apple's In-App
  Purchase system and Google Play Billing instead of Stripe/PayPal, per
  both platforms' store policies. Using a third-party processor for
  this category of purchase is a common and serious app-rejection
  reason.
- If a future feature blurs this line (e.g. a "premium membership" tier
  with in-app perks), flag it and ask before building the payment flow
  — don't assume which payment path applies.

### 5.5 Webhook security
- Every Stripe (or other processor) webhook handler must **verify the
  webhook signature** using the processor's secret before trusting the
  payload — an unverified webhook endpoint lets anyone fake a "payment
  succeeded" event.
- Webhook handlers run as Cloud Functions, never as client-side code.

### 5.6 Idempotency
- Payment-creating operations (charging a card, creating a booking with
  a charge attached) must use idempotency keys so a network retry or a
  double-tap doesn't create two charges for one booking.

### 5.7 Encryption and transport
- Enforce TLS 1.2 minimum, TLS 1.3 preferred, for anything payment-
  related — Firebase's own services enforce this by default; if any
  custom Cloud Function calls an external payment API directly, confirm
  it's also using TLS 1.3 where the provider supports it.
- Any payment-adjacent data actually stored (e.g. last 4 digits of a
  card for display purposes, subscription status) should be the
  minimum needed for the feature — never full card numbers, ever.
- The Billing/Payment empty state reads only the server-owned
  `users.hasPaymentMethod` boolean. The client cannot write that field; a
  verified processor webhook/backend updates it after the reusable method is
  created or removed. It is not proof that a charge succeeded.

### 5.8 Access control and monitoring specific to payments
- MFA (multi-factor authentication) should be required for **your own**
  admin/owner access to the Stripe dashboard and any Firebase Console
  access with billing/payments visibility — this is standard practice
  under PCI DSS v4.0.1's "MFA everywhere" requirement for anyone who can
  reach cardholder-adjacent systems, not just for end users.
- Monitor for anomalous transaction patterns (unusual volume, repeated
  failed charges, mismatched geography) — Stripe's own Radar fraud
  tooling covers a lot of this out of the box; don't disable or ignore
  it.
- Data minimization applies to your own team too: support staff,
  developers, and analytics tools should never have access to full
  card data — there should be no path in the app or admin panel that
  displays it, because there should be no path where your systems ever
  receive it in the first place (see 5.1).

## 6. Authentication hardening — registration, login, and verification

### 6.1 What the registration/login screens must capture and verify
Per the confirmed requirement: registration collects full account info and
offers **three verification factors** — email, mobile number (SMS), and
an authenticator app (TOTP). Specifics:

- **Email verification** — required for every account, via Firebase
  Auth's built-in `sendEmailVerification()`. This is also a hard
  prerequisite for enabling any further MFA factor (Firebase requires a
  verified email before a second factor can be added — this prevents an
  attacker registering with someone else's email and then locking the
  real owner out by adding their own second factor).
- **Phone/SMS verification** — via Firebase Authentication's phone-based
  MFA. **Important nuance, not just a checkbox**: Firebase's own
  documentation explicitly cautions against relying on SMS alone,
  since SMS can be intercepted or spoofed. Support it (it's what most
  users expect and is a real requirement here), but the UI should
  encourage the authenticator app as the stronger option rather than
  treating both as equally secure.
- **Authenticator app (TOTP)** — Google Authenticator/Authy/Microsoft
  Authenticator compatible, via Firebase Auth's TOTP MFA support. This
  is real and documented, but is a newer, still-actively-updated part
  of the Firebase/FlutterFire SDK compared to SMS MFA — **re-verify its
  current maturity/support status on both Android and iOS specifically
  at the time this is actually implemented**, rather than assuming
  today's exact API surface. Enrollment flow: generate a TOTP secret,
  show it as a QR code, user scans it with their authenticator app,
  user enters the generated code once to confirm enrollment.
- Both SMS and TOTP MFA require **Firebase Authentication with Identity
  Platform** (an upgrade from base Firebase Auth) — confirm this is
  enabled in Phase 0, and note it may have billing implications beyond
  the free tier; flag the cost impact before enabling it.

### 6.1a Password reset by 6-digit code — the two branches are not alike
Added when the Verification Code screen was built. Worth stating explicitly
because the asymmetry is easy to get wrong:

- **Phone/SMS branch** — Firebase Auth generates, sends and verifies the code
  itself. We never see it, never store it, and there is no collection
  involved. Use `verifyPhoneNumber` → `PhoneAuthProvider.credential`.
- **Email branch** — Firebase Auth has **no** built-in code-based reset;
  `sendPasswordResetEmail()` sends a *link*. A 6-digit email code therefore
  has to be implemented in Cloud Functions. Non-negotiable properties:
  - Store only a **salted hash** of the code, never the plaintext, and never
    return the code to the client.
  - The client gets **no read or write access** to `password_reset_codes`
    (see `firestore.rules`) — the Admin SDK bypasses rules, so the functions
    still work.
  - Compare codes in **constant time** (`crypto.timingSafeEqual`) so a timing
    side channel can't leak them.
  - **Never reveal whether an email is registered.** Return the same success
    response either way, or the endpoint becomes an account-enumeration
    oracle.
  - Rate-limit **both** directions: a cooldown between sends, and a hard cap
    on failed verify attempts. Enforce this on the server — a client-side
    countdown is UX, not security.
  - Expire codes (10 minutes) and burn them on first successful use so they
    can't be replayed.
  - SMTP credentials belong to the "Trigger Email from Firestore" extension's
    config, never to this repo (section 4).
- **App Check matters more here than almost anywhere else**: an unprotected
  send endpoint lets anyone burn your SMS and email quota, which is a direct
  billing attack. Both functions ship with `enforceAppCheck: false` and must
  be flipped to `true` once App Check is live — tracked in
  `FIREBASE_SETUP.md`.

### 6.1b Actually changing the password — what must and must not happen
Added when the Reset Password screen was built.

- **The password never touches Firestore.** It goes to Firebase Auth
  directly (phone flow, via the signed-in credential) or to the Admin SDK
  inside a Cloud Function (email flow). Never log it, never cache it, never
  put it in a document — the same absolute rule as card data in section 5.1.
  Firestore records only *when* it changed (`users.passwordChangedAt`).
- **Revoke refresh tokens on every password change.** This is the step most
  often missed: without `revokeRefreshTokens(uid)`, a session an attacker
  already holds keeps working after the real owner "recovers" the account,
  which defeats the point of the reset. Both
  `confirmPasswordResetWithCode` and `recordPasswordChange` do this.
- **The reset token is single-use and short-lived.** It is stored hashed,
  compared in constant time, and its document is deleted the moment the
  password changes, so a replayed token cannot set the password twice.
- **Validate the password policy on the server as well as the client.**
  `isStrongEnough()` in `functions/index.js` mirrors the rule shown on
  screen. Client validation is UX; this is the boundary (section 7). Also
  configure the same policy in Firebase Auth's own password-policy settings
  so it applies to registration too, not just reset.

  > ✅ **Fixed and verified live 2026-09-12.** The policy is now
  > `enforcementState: ENFORCE`. (It was previously `OFF` — configured but not
  > enforced — so a direct `accounts:signUp` with a 6-character password
  > succeeded. That hole is closed.)

#### The one password policy, stated once

This is the **authoritative** wording. Firebase Auth is the boundary; every
other copy exists to mirror it and must not add or drop a rule.

| Rule | Required |
|---|---|
| Minimum length | **8** |
| Uppercase letter | **yes** |
| Lowercase letter | **yes** |
| Number | **yes** |
| Special character | **no** — deliberately not required |
| Maximum length | 4096 (Firebase default) |

Five places encode it. They drifted once already and must be changed together:

1. Firebase Console → Authentication → Settings → Password policy *(the
   boundary for registration and any client-side password set)*
2. `isStrongEnough()` in `functions/index.js` *(the boundary for the reset
   flow — the Admin SDK **bypasses** the Auth policy, so without this check
   that path would have no policy at all)*
3. `_validatePassword` in `lib/screens/register_screen.dart`
4. `_validatePassword` in `lib/screens/reset_password_screen.dart`
5. the inline check in `ChangePasswordScreen._save`
   (`lib/screens/account_edit_screens.dart`)

Plus the two user-facing descriptions, `passwordHint` and
`passwordChangeRules`, in all three languages.

> **Why a client rule that is *stricter* than Firebase is also a bug**, not a
> safe default: it rejects passwords the backend would accept, so the user is
> blocked by a rule no real boundary enforces. Until 2026-09-12 all three
> client validators required a special character Firebase did not, while none
> of them required the number Firebase did — wrong in both directions at once.
- **The client needs no write access to `users`.** Both stamping functions
  run under the Admin SDK, so `users` stays fully closed in
  `firestore.rules` rather than being opened up for one field.

### 6.1c Registration — the field allow-list is the whole point
Added when the Register screen was built. The client now creates its own
`users/{uid}` document, which is the first time app code writes to Firestore
at all. The risk is not *whether* it can write, but *which fields*:

- `firestore.rules` restricts create and update to an explicit **allow-list**
  (`name`, `email`, `phone`, `dateOfBirth`, `gender`, `profileImageUrl`,
  `preferredLanguage`, `termsAcceptedAt`, `createdAt`, `updatedAt`,
  `source`). Anything outside it is rejected whatever its value.
- **`role` is not on that list.** Without this, a modified client could write
  `role: "admin"` to its own document and grant itself the admin panel. Same
  reasoning for `emailVerified` / `phoneVerified` — a client that can set
  those can claim a verification it never passed.
- Rules validate **shape as well as ownership**: name length, field types,
  and `gender` restricted to the three permitted values.
- `list` is not granted on `users` — nobody may enumerate the user base.
- `delete` is denied outright; account deletion must go through a Cloud
  Function so Auth, Firestore and Storage are cleaned up together
  (section 9).
- The registration password goes straight to
  `createUserWithEmailAndPassword` and is never placed on a model object,
  logged, or written to Firestore.
- **Terms/Privacy consent is captured at registration** (`termsAcceptedAt`).
  Both app stores require explicit consent at account creation; without it,
  review can reject the app.

### 6.1d Consent — record the version, not just the moment
Added when the Terms of Service screen was built.

- Consent is captured on its own screen, as a **required gate** between
  account creation and phone verification. Continue stays disabled until the
  checkbox is ticked, and the checkbox sits at the end of the scrollable
  document so it cannot be reached without scrolling past the text.
- Store **`termsVersion` as well as `termsAcceptedAt`**. A timestamp alone
  cannot answer "did this user agree to the current wording?", which is the
  only question that matters when the terms change. With the version stored,
  you can re-prompt exactly the users who haven't seen the latest text.
- `legal_documents` is **public read, admin-only write**. Public because a
  user must be able to read the terms before they have an account;
  admin-only write because a client that could edit this collection could
  rewrite the agreement it is about to accept.
- **Translated legal text is a legal risk, not a UI task.** The Kurdish and
  Arabic renderings currently in the repo were produced by translation, not
  by a qualified legal translator. The document carries a `legalReviewed`
  flag and the app shows a visible warning while it is false. Do not ship
  with it false — the language a user reads is the one they are agreeing to.

### 6.1e Profile pictures and OS permissions
Added when the Account Setup screen was built.

- **Storage rules enforce the limits, not the client.** `storage.rules`
  restricts writes to `profile_images/{uid}/` for that uid only, requires
  `contentType` to match `image/.*`, and caps size at 5 MB. Client-side
  checks are UX; a modified client could otherwise upload any file type at
  any size and serve it from your domain — and run up the bill.
- Avatars use a **fixed filename per user** (`avatar.jpg`), so re-uploading
  replaces the old picture instead of leaving orphaned files in Storage.
- Images are **downscaled on device** (1024px, quality 85) before upload. A
  modern phone photo is 4–12 MB; an avatar needs a fraction of that.
- Profile pictures are **public read** — they appear beside reviews and
  bookings, so they must be readable without knowing who is asking.

> ⚠️ **Permission timing — a known review risk, accepted deliberately.**
> Camera, photos, location and notifications are all requested **up front**
> when Account Setup opens. Apple and Google both recommend requesting a
> permission at the point of use with visible context; asking for location
> and notifications on a screen that uses neither is a common App Store
> rejection reason and lowers grant rates for later prompts. This trade-off
> was raised and the up-front approach chosen anyway.
>
> If review pushes back, the change is small: stop calling
> `AppPermissions.requestAll()` in `AccountSetupScreen.initState`, and rely
> on `AppPermissions.requestForImageSource()`, which the screen already
> calls at the moment the user picks a source. The iOS
> `NSLocationWhenInUseUsageDescription` string also currently describes a
> feature that does not exist yet — it must describe a real feature before
> submission.

### 6.1f Guests — the dashboard is public, the user's own data is not
Added when the Home screen was built. This is the first screen a
**not-signed-in** user can reach, which changes what the rules have to allow.

- `featured` and `nature_spots` are **public read, including unauthenticated**
  — a guest browses the whole dashboard. Both grant `list` (unlike
  `legal_documents`, which is fetched by known id) because the screen queries
  them. Both stay **admin-only write**: a client that could write `featured`
  could put arbitrary content on the app's front page.
- `favorites` is the opposite — **owner-only in both directions**. `list` is
  granted only because the rule pins `resource.data.userId` to the caller, so
  Firestore rejects any query not provably limited to that user's own rows.
  Nobody can enumerate someone else's saved places.
- `update` on `favorites` is **denied outright**. A favourite is added or
  removed; allowing update would only add a way to repoint an existing row at
  another user.
- **There is no anonymous favorite.** Rather than storing guest favorites
  locally and merging them later, Where to Stay and Explore Nature prompt the
  guest to sign in (the shared `SignInRequiredSheet`). One source of truth, and
  no second store to keep in sync or leak.
- **`favorites` carries a denormalized snapshot**, and every field of it is
  validated and *size-bounded* in the rules: `title` and `locationLabel` are
  locale maps restricted to `{en, ku, ar}` with ≤200 characters per string, and
  `imageRef` is ≤1000. Without those bounds the collection would be writable
  free storage — a user can create unlimited rows under their own uid, so an
  unbounded string field is an invitation to park payload there. `title` is
  required (a row that cannot be drawn looks like data loss); `locationLabel`
  and `imageRef` are optional so a catalogue entry missing one can still be
  saved.
- **`itemType` was narrowed from five values to two** (`nature_spot`, `hotel`)
  when the heart was consolidated onto Where to Stay and Explore Nature. Note
  that `delete` deliberately checks **ownership only, not shape**, so a legacy
  `car`/`tour`/`flight` row a user saved before the change stays removable — a
  tightening that trapped rows in a user's account would be a worse outcome
  than the loose type it replaced.
- Guest mode is **not** Firebase anonymous auth — it is simply "no user". If
  anonymous auth is introduced later, revisit this: an anonymous uid *would*
  satisfy the favorites rules, which may or may not be intended.

> ⚠️ **The count() aggregation is a read the client controls.** `count()` on
> `nature_spots` requires `list`, which means a client can also run
> unconstrained queries against that collection. That is acceptable for
> catalog data that is public anyway, but it is a real cost surface — add
> App Check (6.3) before launch, and watch the usage dashboard (section 10).

### 6.1g Registration now gates on a verified email — and why by code
Added when the registration email verification step was built.

Registration collected an email but never proved it was reachable. A typo
(`gmial.com`) or someone else's address produced an account that could never
receive a password reset — the user is locked out permanently, and support has
no safe way to fix it. `sendEmailVerification()` was already being called, but
nothing *gated* on the result, so the user walked straight past it.

The flow is now: Register → Terms → **email code** → phone code → Account Setup.
Email is verified before phone because email is the account's recovery channel.

Non-negotiable properties, all mirroring 6.1a:

- **The destination is read server-side from Firebase Auth, never from the
  request.** This is the one place this flow differs from `sendEmailChangeCode`,
  and it matters: if the client could name the address, it could have
  registration codes delivered to an inbox it does not own.
- Only a **salted hash** of the code is stored, never the plaintext, and the
  code is never returned to the client.
- The client has **no read or write access** to `email_verify_codes`. Note the
  document id *is* the uid, so granting read would let a signed-in user fetch
  their own pending code instead of receiving it by email — which defeats the
  whole verification. `email_change_codes` was relying on deny-by-default and
  now has an explicit closed rule too.
- Codes are compared in **constant time** (`safeEqual`), expire after 10
  minutes, are burned on first successful use, and are rate-limited on both
  send (60s cooldown) and verify (5 attempts).
- **`emailVerified` is written only by the Admin SDK.** It is on no
  client-writable allow-list (6.1c) — a client that could set it would be
  claiming a verification it never passed.
- Both functions ship with `enforceAppCheck: false` and **must be flipped to
  `true` once App Check is live**, same as the password-reset pair. An
  unprotected send endpoint is a direct billing attack on your email quota.

> Not yet verified against a live project — there is no Firebase project. In
> debug builds `EmailVerificationService.isPreviewMode` accepts any six digits
> so the flow can be walked; it is guarded by `kDebugMode` **and** the Firebase
> check, so a release build fails closed. Testing this against real Firebase is
> a release blocker for registration.

**Still missing, deliberately:** typo detection (`gmail.co` → `gmail.com`) and
disposable-domain blocking were scoped out. Verification proves an address is
*reachable*, which is the security property; those two are UX quality and can
be added without changing this design.

### 6.2 Platform-specific setup — both Android and iOS need explicit configuration
This isn't automatic just because Flutter is cross-platform — each OS
needs its own setup for phone/SMS verification to work correctly:
- **Android**: the app's SHA-256 signing certificate hash must be added
  in the Firebase console (Project Settings → your Android app) —
  phone auth verification will fail silently without this.
- **iOS**: in Xcode, Push Notifications capability must be enabled, an
  APNs authentication key must be configured and linked to Firebase
  Cloud Messaging, and Background Modes → Remote Notifications must be
  enabled. iOS phone verification relies on a silent push to confirm
  the request came from a real device instead of always falling back to
  a visible SMS challenge.
- Test both platforms' verification flows independently — a
  configuration that works on Android does not guarantee it works on
  iOS, and vice versa, given how differently each platform implements
  the underlying device-attestation step.

### 6.3 App/device integrity — both platforms, via one Firebase feature
- Enable **Firebase App Check** once real user data is involved. Under
  the hood, App Check uses **Play Integrity API on Android** and
  **Apple's App Attest on iOS** — one Firebase integration covers the
  hardware-backed integrity check on both platforms, rather than
  needing separate native code per OS.
- (Historical note, not an action needed: Android's older SafetyNet API
  is deprecated; Play Integrity API is its replacement and is what App
  Check already uses — nothing to migrate here as long as App Check is
  used rather than a hand-rolled SafetyNet integration.)

### 6.4 General hardening
- Store any locally-cached auth tokens using `flutter_secure_storage`
  (backed by Keychain on iOS / Keystore on Android), never
  `shared_preferences` — plain shared preferences are not encrypted at
  rest.
- Rate-limit sensitive actions (login attempts, password resets) —
  Firebase Auth has some of this built in; don't disable or work around
  it.
- Enforce a real password policy (minimum length, mix of character
  types) using Firebase Auth's password policy configuration rather
  than only client-side validation.

## 7. Input validation — both ends

- Validate on the client for good UX (instant feedback, no round trip).
- **Re-validate the same rules in Firestore Security Rules or a Cloud
  Function.** Client validation is convenience, not security — treat every
  client request as potentially hostile when writing rules/functions.

## 8. Dependency hygiene

- Keep Flutter, Dart, and all packages (especially `firebase_*` packages)
  on recent stable versions — security patches land in updates.
- Avoid adding packages with low maintenance activity for anything
  touching auth, storage, or payments.
- Run `flutter pub outdated` periodically and flag anything with a known
  CVE for priority updating.

> **`permission_handler` 12.0.3 → 13.0.2, 2026-09-14.** The only code change
> needed was a build one: `permission_handler_android` 14.x requires
> `compileSdk 37`, so `android/app/build.gradle.kts` now pins that instead of
> deferring to `flutter.compileSdkVersion`. **That raises the compile SDK for
> every plugin in the app, not just this one**, so it was verified with a full
> `flutter build apk --debug` rather than assumed. `app_permissions.dart` was
> not touched — the API surface it uses is unchanged.
>
> 13.0.2 also changes how a **permanently denied** permission is detected on
> Android: `status` alone can no longer distinguish it, and `request()` must be
> called. This app was already doing exactly that, so nothing had to change.
> Worth knowing before anyone adds a `status`-based check.
>
> **Permanently-denied recovery, 2026-09-14.** The gap the upgrade note
> flagged is now closed. `AppPermissions` returns a `PermissionOutcome`
> (`granted` / `denied` / `permanentlyDenied` / `unavailable`) read from the
> **result of `request()`**, never from a prior `status` check, which is what
> 13.x requires on Android. Only `permanentlyDenied` sets `needsSettings`, so a
> normal refusal is never mistaken for a permanent one and the user is never
> told to visit Settings when the OS will simply ask again.
>
> When a permission is permanently denied at its point of use,
> `showPermissionBlockedPrompt` offers an **Open Settings** action alongside
> the explanation the screen already showed. Camera and photos (Account Setup
> avatar) and notifications (Settings toggle) have this path.
> **Nothing opens Settings on its own** — leaving the app unprompted is a
> hostile thing to do, so `openAppSettings()` runs only from that tap.
>
> Request *timing* is deliberately unchanged: `requestAll()` still runs one
> sweep on Account Setup open and still reports plain booleans, because four
> "open settings" nudges on screen open would be worse than useless. The 6.1e
> permission-timing decision is still open and separate.
>
> Location is the exception, by design: its point of use is
> `DeviceLocationService`, which goes through **Geolocator**, not
> `permission_handler`, and deliberately returns `null` on `deniedForever` so
> the card hides its Distance row. Nagging there would contradict that.

> **Simulated flows are release-gated, 2026-09-14.** Two features were
> stand-ins that shipped: `MockFlightResultsService` served five invented
> airlines at invented fares to any release user who searched, and hotel
> checkout ended by showing a "confirmed" booking that held no room and took
> no payment. The `assert(kDebugMode)` guarding the latter was not a guard —
> Dart strips assert bodies from release builds.
>
> `ReleaseGate.previewFeaturesAllowed` (`lib/services/release_gate.dart`) now
> gates both. Its test override lives inside an `assert` body, so it too is
> stripped in release: a shipped build can only ever read `kDebugMode`, and
> there is no flag or environment variable that reopens either flow.
>
> Flights refuse at the source (`isAvailable` false, `search()` throws
> `FlightResultsUnavailable`) as well as at the screen, so no future caller
> can obtain invented offers. Checkout disables its confirm button and states
> that booking is coming soon. Neither change touches `firestore.rules` —
> client booking writes were already denied outright and still are.

## 9. Privacy & compliance

- Since the app collects email, phone, profile photos, and location data,
  a **privacy policy page is required** for both app store submissions —
  build this before submitting to App Store / Play Store, not after.
- Support account/data deletion (a user can request their `users/{uid}`
  document, bookings, and storage files be deleted) — required by both
  Apple and Google's app review guidelines if accounts can be created in
  the app.
- Don't collect more data than a screen actually needs — if a field isn't
  in `DATA_MODEL.md` and isn't being used by an approved screen, don't
  add it "just in case."

## 10. Monitoring

- Enable **Firebase Crashlytics** early — catching real crashes in
  production is part of security, not just stability (a crash can be a
  symptom of someone probing for weaknesses).
- Watch Firebase Console's usage/billing dashboards after launch —
  unexpected spikes in reads/writes can indicate a security rule gap
  being exploited (or just a bug), and Firestore's pay-per-read model
  means this is also a cost issue.

### 10.1 Crashlytics — what is captured, and what is scrubbed first

*(implemented 2026-09-14)* Crashlytics is **free on the Spark plan**; no Blaze
upgrade was involved.

**Captured**

- Flutter framework errors, via `FlutterError.onError` — build, layout, paint.
- Uncaught asynchronous and platform errors, via
  `PlatformDispatcher.instance.onError` — a failed `Future` with no catch, a
  platform-channel throw. The handler returns `true`, because returning `false`
  lets the platform terminate the isolate and lose the report just filed.
- Native Android crashes and ANRs, through the Crashlytics Gradle plugin, which
  also uploads mapping files so release stack traces stay readable.

**Collection is off in debug** (`!kDebugMode && FirebaseBootstrap.isReady`), so
developer crashes never reach the live dashboard and `flutter test` cannot post
anything. Handlers are still installed in debug, so console output is unchanged.

**Nothing is forwarded verbatim.** Section 5.1 names Crashlytics explicitly as
somewhere card data must never reach, and 6.1b says the same of passwords. An
exception message is assembled by whoever threw it — a Firebase SDK, or a
future payment SDK — so it cannot be assumed safe. `CrashReporter.redact`
rewrites it first, and the report carries the exception **type** plus the
redacted text. Type names describe code, never values.

Redacted before upload:

| Kind | Examples |
|---|---|
| Passwords | `password:`, `newPassword=`, `"currentPassword":"…"` |
| Card data | 13–19 digit PANs (spaced or dashed), `cvv`, `cvc`, `expiry` |
| Verification / reset codes | any standalone 6-digit run, `otp`, `smsCode`, `verificationCode` |
| Tokens | JWT/`eyJ…` strings, `idToken`, `access_token`, `Authorization: Bearer …`, `apiKey` |
| Personal identifiers | email addresses, E.164 phone numbers |

Over-redaction is the intended failure mode: a harder-to-read report costs
debugging time, a leaked credential costs an account. Stack traces are
forwarded unmodified — frames carry file, line and function names, never
argument values.

`redact` is pure and covered by 31 tests, including adversarial and combined
inputs. Two real defects were caught by those tests during implementation: a
`Authorization: Bearer <token>` pair that lost only the word "Bearer", and a
`+964…` phone number being claimed by the card pattern.

**Existing logging was audited before any of this was wired.** No `debugPrint`
in the auth, reset, verification, account-settings or profile services
interpolates a password, code or token — the closest is
`'Phone code auto-retrieved by the OS.'`, which reports the event and not the
code.

> ⚠️ **One manual step:** Firebase Console → Crashlytics → **Get started** for
> `rewar-app-1c10e`. The dashboard does not activate until it has been opened
> once and received a first report.

## 11. Pre-launch security checklist (before App Store/Play Store submission)

- [ ] Every Firestore collection has explicit rules — no collection is
      left in test/open mode
- [ ] Every Storage bucket path has explicit rules
- [x] Admin custom claim mechanism implemented (`tool/admin_claim.js`, 3.1)
      and verified in rules. **No account holds it yet** — granting the first
      real admin is still a manual step
- [ ] App Check enabled
- [ ] No API keys or secrets anywhere in the Flutter client codebase
- [ ] Auth tokens stored via `flutter_secure_storage`, not
      `shared_preferences`
- [ ] Privacy policy page live and linked from both the app and store
      listings
- [ ] `legal_documents/terms_of_service` seeded, and **`legalReviewed` set
      to true** only after a qualified translator/lawyer has signed off all
      three languages (see 6.1d)
- [ ] Account/data deletion flow implemented and tested
- [x] Crashlytics enabled — `firebase_crashlytics` + the Android Gradle
      plugin are wired and the APK builds; every report is scrubbed by
      `CrashReporter.redact` (section 10.1). **One manual step remains:**
      Firebase Console → Crashlytics → Get started
- [ ] `flutter pub outdated` run, no known-vulnerable packages in use
- [x] `PreviewIdentity` deleted along with the preview sign-in account (1b) —
      done 2026-09-12; no preview authentication path remains
- [ ] **Auth/verification-specific:**
  - [ ] Email verification required and tested — registration cannot be
        completed without a verified address (6.1g)
  - [ ] `sendRegistrationEmailCode` / `confirmRegistrationEmailCode` flipped to
        `enforceAppCheck: true`
  - [ ] SMS/phone MFA tested on a real Android device
  - [ ] SMS/phone MFA tested on a real iOS device (do not assume Android
        testing covers iOS — platform setup differs)
  - [ ] Authenticator app (TOTP) enrollment and verification tested on
        both platforms; current SDK support status re-confirmed since
        this is a newer/actively-changing feature
  - [ ] Android SHA-256 certificate hash registered in Firebase console
  - [ ] iOS Push Notifications + APNs key + Background Modes configured
        in Xcode
  - [ ] Firebase App Check enabled and confirmed working on both
        platforms (Play Integrity on Android, App Attest on iOS)
- [ ] **Payment-specific:**
  - [ ] Confirmed no raw card data ever touches the app, Firestore, or
        Cloud Function logs — card entry goes through Stripe's own SDK/
        Payment Sheet or Apple Pay/Google Pay only
  - [ ] Webhook signature verification implemented and tested on every
        payment webhook handler
  - [ ] Idempotency keys used on all charge-creating operations
  - [ ] Confirmed real-world bookings use Stripe/PayPal directly, and
        any digital-only content (if added later) uses Apple/Google's
        in-app purchase systems instead — not mixed up
  - [ ] MFA enabled on the Stripe dashboard account and any Firebase
        Console access with billing visibility
  - [ ] Re-check this section's guidance against current PCI DSS
        requirements if more than 6-12 months have passed since the
        "last verified" date at the top of this file — standards do
        get updated
