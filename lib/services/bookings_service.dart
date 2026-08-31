import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/booking.dart';
import 'firebase_bootstrap.dart';

/// Reads the signed-in user's own `bookings` for the My Bookings screen.
///
/// **Read-only by design.** A booking is created only by the checkout Cloud
/// Function after the payment provider confirms the charge, and cancellation is
/// likewise a Cloud Function — see `DATA_MODEL.md` and `SECURITY.md` section 5.
/// If the client could write here, a modified app could mint itself a confirmed
/// booking it never paid for. This service therefore exposes no write method at
/// all, and `firestore.rules` denies client create/update/delete.
///
/// When Firebase is unavailable in a debug build the service serves bundled
/// content instead, so the page stays reviewable — the same preview contract
/// [NatureSpotsService] and [FeaturedService] use.
class BookingsService {
  BookingsService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestoreOverride = firestore,
      _authOverride = auth;

  final FirebaseFirestore? _firestoreOverride;
  final FirebaseAuth? _authOverride;

  FirebaseFirestore get _firestore =>
      _firestoreOverride ?? FirebaseFirestore.instance;

  FirebaseAuth get _auth => _authOverride ?? FirebaseAuth.instance;

  static const String collection = 'bookings';

  /// One read serves the whole screen — both filter dimensions are applied in
  /// Dart. See `DATA_MODEL.md` for why, and for when pagination should replace
  /// this limit.
  static const int fetchLimit = 50;

  /// Session-only records created by the hotel checkout preview. They are
  /// never written to Firestore and disappear when the process exits.
  static final List<Booking> _sessionPreviewBookings = <Booking>[];

  static void addSessionPreviewBooking(Booking booking) {
    assert(kDebugMode, 'Preview bookings must never be created in release.');
    _sessionPreviewBookings.insert(0, booking);
  }

  static bool get isPreviewMode => kDebugMode && !FirebaseBootstrap.isReady;

  /// The uid whose bookings should be shown, or null when nobody is signed in.
  ///
  /// There is no such thing as a guest booking — the rules require an auth uid
  /// — so the screen shows a sign-in prompt rather than an empty list. Same
  /// precedent as favorites and the drawer's Currency row.
  String? get currentUserId {
    if (isPreviewMode) return _previewUserId;
    if (!FirebaseBootstrap.isReady) return null;
    return _auth.currentUser?.uid;
  }

  static const String _previewUserId = 'preview-user';

  /// Every booking belonging to the signed-in user, newest trip first.
  ///
  /// Needs the `userId + startAt` composite index declared in
  /// `firestore.indexes.json`.
  Future<List<Booking>> fetchMyBookings() async {
    if (isPreviewMode) {
      debugPrint(
        'PREVIEW MODE: serving bundled bookings. '
        'Seed the "$collection" collection for live content.',
      );
      await Future<void>.delayed(const Duration(milliseconds: 300));
      return <Booking>[..._sessionPreviewBookings, ...bundledBookings()];
    }
    if (!FirebaseBootstrap.isReady) {
      throw StateError('Firebase is not configured — see FIREBASE_SETUP.md');
    }

    final uid = _auth.currentUser?.uid;
    if (uid == null) return const [];

    final snapshot = await _firestore
        .collection(collection)
        .where('userId', isEqualTo: uid)
        .orderBy('startAt', descending: true)
        .limit(fetchLimit)
        .get();

    return snapshot.docs
        .map((doc) => Booking.fromMap(doc.id, doc.data()))
        .whereType<Booking>()
        .toList(growable: false);
  }

  /// Bundled stand-ins for preview mode, mirroring the five documents that
  /// `tool/seed_bookings.js` writes. **Keep the two in sync** — the same rule
  /// as the bundled nature spots, featured slides and Terms text.
  ///
  /// Dates are relative to "now" so the Upcoming/Past split stays demonstrable
  /// no matter when the app is opened: four trips ahead, one behind.
  ///
  /// Tours appear twice — one upcoming, one completed — because the screen
  /// opens on Upcoming, and a tour that only exists in the past leaves the
  /// Tours chip empty on the segment users land on.
  static List<Booking> bundledBookings() {
    final now = DateTime.now();
    DateTime inDays(int days, {int hour = 0, int minute = 0}) =>
        DateTime(now.year, now.month, now.day + days, hour, minute);

    return [
      Booking(
        id: 'preview-hotel',
        userId: _previewUserId,
        type: BookingType.hotel,
        status: BookingStatus.confirmed,
        bookingReference: 'HTL-7845123',
        startAt: inDays(11, hour: 14),
        endAt: inDays(14, hour: 12),
        referenceId: 'divan-erbil',
        totalPrice: 420,
        currency: 'USD',
        cancellable: true,
        display: const BookingDisplay(
          titles: {
            'en': 'Divan Erbil Hotel',
            'ku': 'هوتێلی دیڤان هەولێر',
            'ar': 'فندق ديوان أربيل',
          },
          locationLabels: {
            'en': 'Erbil, Iraq',
            'ku': 'هەولێر، عێراق',
            'ar': 'أربيل، العراق',
          },
          imageAsset: 'assets/images/journey-stay.png',
          guestCount: 2,
          roomName: 'Deluxe Twin',
        ),
      ),
      Booking(
        id: 'preview-flight',
        userId: _previewUserId,
        type: BookingType.flight,
        status: BookingStatus.confirmed,
        bookingReference: 'FL-9856217',
        startAt: inDays(10, hour: 9, minute: 35),
        endAt: inDays(10, hour: 12, minute: 20),
        referenceId: 'ebl-ist-0935',
        totalPrice: 310,
        currency: 'USD',
        display: const BookingDisplay(
          titles: {
            'en': 'Iraqi Airways',
            'ku': 'هێڵی ئاسمانی عێراقی',
            'ar': 'الخطوط الجوية العراقية',
          },
          locationLabels: {
            'en': 'Erbil International Airport',
            'ku': 'فڕۆکەخانەی نێودەوڵەتی هەولێر',
            'ar': 'مطار أربيل الدولي',
          },
          guestCount: 1,
          fromCode: 'EBL',
          toCode: 'IST',
          fromCities: {'en': 'Erbil', 'ku': 'هەولێر', 'ar': 'أربيل'},
          toCities: {'en': 'Istanbul', 'ku': 'ئەستەنبووڵ', 'ar': 'إسطنبول'},
          durationMinutes: 165,
          seat: '16A',
          cabinClass: CabinClass.economy,
        ),
      ),
      Booking(
        id: 'preview-car',
        userId: _previewUserId,
        type: BookingType.car,
        status: BookingStatus.confirmed,
        bookingReference: 'CR-6623148',
        startAt: inDays(15, hour: 10),
        endAt: inDays(17, hour: 10),
        referenceId: 'suv-premium',
        totalPrice: 180,
        currency: 'USD',
        cancellable: true,
        display: const BookingDisplay(
          titles: {
            'en': 'SUV – Premium',
            'ku': 'ئێس یو ڤی – پرێمیۆم',
            'ar': 'دفع رباعي – ممتاز',
          },
          locationLabels: {
            'en': 'Erbil International Airport',
            'ku': 'فڕۆکەخانەی نێودەوڵەتی هەولێر',
            'ar': 'مطار أربيل الدولي',
          },
          imageAsset: 'assets/images/journey-car.png',
          guestCount: 1,
          pickupLocations: {
            'en': 'Erbil International Airport',
            'ku': 'فڕۆکەخانەی نێودەوڵەتی هەولێر',
            'ar': 'مطار أربيل الدولي',
          },
          carClass: 'SUV – Premium',
        ),
      ),
      Booking(
        id: 'preview-tour-upcoming',
        userId: _previewUserId,
        type: BookingType.tour,
        status: BookingStatus.confirmed,
        bookingReference: 'TO-4471908',
        startAt: inDays(6, hour: 7),
        endAt: inDays(6, hour: 17),
        referenceId: 'lalish-amedi-heritage-tour',
        totalPrice: 140,
        currency: 'USD',
        cancellable: true,
        display: const BookingDisplay(
          titles: {
            'en': 'Lalish & Amedi Heritage Tour',
            'ku': 'گەشتی کەلەپووری لالش و ئامێدی',
            'ar': 'جولة لالش وآميدي التراثية',
          },
          locationLabels: {
            'en': 'Duhok, Iraq',
            'ku': 'دهۆک، عێراق',
            'ar': 'دهوك، العراق',
          },
          imageAsset: 'assets/images/journey-tours.png',
          guestCount: 3,
          durationHours: 10,
        ),
      ),
      Booking(
        id: 'preview-tour',
        userId: _previewUserId,
        type: BookingType.tour,
        status: BookingStatus.completed,
        bookingReference: 'TO-122534',
        startAt: inDays(-21, hour: 8),
        endAt: inDays(-21, hour: 16),
        referenceId: 'rawanduz-day-tour',
        totalPrice: 95,
        currency: 'USD',
        display: const BookingDisplay(
          titles: {
            'en': 'Rawanduz & Bekhal Day Tour',
            'ku': 'گەشتی ڕۆژانەی ڕەواندز و بێخاڵ',
            'ar': 'جولة يوم راوندوز وبيخال',
          },
          locationLabels: {
            'en': 'Rawanduz, Erbil',
            'ku': 'ڕەواندز، هەولێر',
            'ar': 'راوندوز، أربيل',
          },
          imageAsset: 'assets/images/journey-tours.png',
          guestCount: 2,
          durationHours: 8,
        ),
      ),
    ];
  }
}
