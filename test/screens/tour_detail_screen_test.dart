import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kurdistan_paradise_travel_guide/l10n/app_localizations.dart';
import 'package:kurdistan_paradise_travel_guide/models/nature_detail.dart';
import 'package:kurdistan_paradise_travel_guide/models/tour.dart';
import 'package:kurdistan_paradise_travel_guide/screens/tour_detail_screen.dart';
import 'package:kurdistan_paradise_travel_guide/services/device_location_service.dart';
import 'package:kurdistan_paradise_travel_guide/screens/booking_traveler_info_screen.dart';
import 'package:kurdistan_paradise_travel_guide/services/tours_service.dart';
import 'package:kurdistan_paradise_travel_guide/services/user_profile_service.dart';
import 'package:kurdistan_paradise_travel_guide/theme/app_theme.dart';
import 'package:kurdistan_paradise_travel_guide/widgets/glass_back_button.dart';
import 'package:kurdistan_paradise_travel_guide/widgets/primary_button.dart';

const tour = Tour(
  id: 'gali-alibag-waterfall',
  names: {
    'en': 'Gali Alibag Waterfall',
    'ku': 'گەلی عەلی بەگ',
    'ar': 'شلال كلي علي بك',
  },
  descriptions: {'en': 'A scenic waterfall tour.'},
  locationLabels: {'en': 'Rawanduz, Erbil'},
  companyTag: 'AB group',
  durationDays: 2,
  features: {'camping', 'food', 'swimming', 'photography'},
  imageAssets: ['assets/images/featured-rawanduz.png'],
  pricePerPerson: 55,
  currency: 'USD',
  reviewScore: 8.7,
  ratingCount: 3,
  capacity: 5,
  bookedCount: 2,
  transportAvailable: true,
  transportPricePerPerson: 5,
);

void main() {
  testWidgets('draws detail sections and offers reservation', (tester) async {
    await _pump(tester);

    expect(find.byType(GlassBackButton), findsOneWidget);
    expect(find.text('AB group'), findsOneWidget);
    expect(find.text('Tour Details'), findsNothing);
    await _scroll(tester, 1);
    expect(find.text('Facilities'), findsOneWidget);
    await _scroll(tester, 1);
    expect(find.text('Weather'), findsOneWidget);
    expect(find.text('Map'), findsOneWidget);
    await _scroll(tester, 1);
    expect(find.text('Ratings & Reviews'), findsOneWidget);
    expect(find.text('Reserve Insight'), findsOneWidget);

    // The CTA is live now that checkout step 1 exists; it gates on sign-in
    // rather than being disabled, which BookingTravelerInfoScreen's own tests
    // and the sign-in test below cover.
    final button = tester.widget<PrimaryButton>(find.byType(PrimaryButton));
    expect(button.onTap, isNotNull);
  });

  testWidgets('a guest tapping Reserve is asked to sign in, not routed', (
    tester,
  ) async {
    await _pump(tester, profile: _SignedOutProfile());
    await tester.tap(find.text('Reserve Insight'));
    await tester.pumpAndSettle();

    expect(find.text('Sign in to reserve'), findsOneWidget);
    expect(find.byType(BookingTravelerInfoScreen), findsNothing);
  });

  testWidgets('a signed-in user reaches checkout step 1', (tester) async {
    await _pump(tester);
    await tester.tap(find.text('Reserve Insight'));
    await tester.pumpAndSettle();

    expect(find.byType(BookingTravelerInfoScreen), findsOneWidget);
    expect(find.text('Traveler Information'), findsOneWidget);
  });
  testWidgets('calculates persons and optional per-person bus price', (
    tester,
  ) async {
    await _pump(tester);
    await _scroll(tester, 5);

    expect(find.text(r'$55'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.add).last);
    await tester.pump();
    expect(find.text(r'$110'), findsOneWidget);

    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    expect(find.text(r'$120'), findsOneWidget);
  });

  testWidgets('renders localized checkout copy in Arabic', (tester) async {
    await _pump(tester, locale: const Locale('ar'));
    await _scroll(tester, 5);
    expect(find.text('حافلة النقل'), findsOneWidget);
    expect(find.text('احجز الجولة'), findsOneWidget);
  });
}

Future<void> _scroll(WidgetTester tester, int times) async {
  for (var index = 0; index < times; index++) {
    await tester.drag(
      find.byKey(const ValueKey('tour-detail-scroll')),
      const Offset(0, -450),
    );
    await tester.pump();
  }
}

Future<void> _pump(
  WidgetTester tester, {
  Locale locale = const Locale('en'),
  UserProfileService? profile,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      theme: AppTheme.lightForLocale(locale),
      home: TourDetailScreen(
        tour: tour,
        toursService: _NoDelayToursService(),
        locationService: const _NoLocation(),
        userProfileService: profile ?? _SignedInProfile(),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 500));
}

class _NoLocation extends DeviceLocationService {
  const _NoLocation();

  @override
  Future<DeviceLocation?> currentLocation() async => null;
}

class _NoDelayToursService extends ToursService {
  @override
  Future<List<NatureReview>> fetchTopReviews(String tourId) async => const [];
}

class _SignedInProfile extends UserProfileService {
  @override
  Future<UserProfile?> fetchProfile() async => UserProfile(
    name: 'Sara Ahmad',
    email: 'sara@example.com',
    phone: '+964 7501234567',
    profileImageUrl: null,
    currency: AppCurrency.usd,
  );
}

class _SignedOutProfile extends UserProfileService {
  @override
  Future<UserProfile?> fetchProfile() async => null;
}
