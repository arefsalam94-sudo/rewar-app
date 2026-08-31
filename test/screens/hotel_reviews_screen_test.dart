import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurdistan_paradise_travel_guide/l10n/app_localizations.dart';
import 'package:kurdistan_paradise_travel_guide/screens/hotel_reviews_screen.dart';
import 'package:kurdistan_paradise_travel_guide/screens/nature_reviews_screen.dart';
import 'package:kurdistan_paradise_travel_guide/services/hotel_service.dart';
import 'package:kurdistan_paradise_travel_guide/theme/app_theme.dart';

final _hotel = PreviewHotelService.hotels.first;

Widget _app({Locale locale = const Locale('en')}) => MaterialApp(
  locale: locale,
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  theme: AppTheme.lightForLocale(locale),
  darkTheme: AppTheme.darkForLocale(locale),
  home: HotelReviewsScreen(hotel: _hotel),
);

void main() {
  testWidgets('hotels reuse the shared Reviews & Ratings screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(420, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    // Not a second comment system: the Explore Nature screen itself.
    expect(find.byType(NatureReviewsScreen), findsOneWidget);
    expect(find.text('Divan Erbil'), findsWidgets);
    expect(find.text('Aland Karim'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  test('the hotel is presented with its own review aggregate', () {
    final subject = hotelAsNatureSpot(_hotel);

    expect(subject.id, _hotel.id);
    expect(subject.names['ku'], _hotel.name.ku);
    expect(subject.locationLabels['ar'], _hotel.address!.ar);
    expect(subject.imageAssets, _hotel.galleryImages);
    expect(subject.latitude, _hotel.latitude);
    // Derived from the reviews the list will show, not from Hotel.reviewScore,
    // so the header cannot disagree with the list beneath it.
    expect(subject.ratingCount, 3);
    expect(subject.reviewScore, closeTo(9.0, 0.001));
  });

  test('a hotel with no reviews yet carries no score', () {
    final subject = hotelAsNatureSpot(PreviewHotelService.hotels.last);
    expect(subject.ratingCount, 0);
    expect(subject.reviewScore, isNull);
  });
}
