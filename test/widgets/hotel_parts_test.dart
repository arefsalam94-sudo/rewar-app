import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurdistan_paradise_travel_guide/l10n/app_localizations.dart';
import 'package:kurdistan_paradise_travel_guide/models/hotel_detail.dart';
import 'package:kurdistan_paradise_travel_guide/theme/app_theme.dart';
import 'package:kurdistan_paradise_travel_guide/widgets/hotel_parts.dart';

Widget _host(Widget child, {Locale locale = const Locale('en')}) => MaterialApp(
  locale: locale,
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  theme: AppTheme.lightForLocale(locale),
  home: Scaffold(body: child),
);

void main() {
  test('an unknown facility key falls back rather than guessing a glyph', () {
    expect(hotelFacilityIcon('pool'), Icons.pool_outlined);
    expect(
      hotelFacilityIcon('something-a-provider-invented'),
      Icons.check_rounded,
    );
  });

  test('every facility category and bed type has an icon or label', () {
    for (final type in NearbyPlaceType.values) {
      expect(nearbyPlaceIcon(type), isA<IconData>());
    }
    for (final category in HotelReviewCategory.values) {
      expect(hotelReviewCategoryIcon(category), isA<IconData>());
    }
  });

  testWidgets('labels resolve in all three languages', (tester) async {
    for (final locale in AppLocalizations.supportedLocales) {
      await tester.pumpWidget(_host(const SizedBox.shrink(), locale: locale));
      await tester.pumpAndSettle();
      final l10n = AppLocalizations.of(
        tester.element(find.byType(SizedBox).first),
      );
      for (final category in HotelFacilityCategory.values) {
        expect(hotelFacilityCategoryLabel(l10n, category), isNotEmpty);
      }
      for (final category in HotelReviewCategory.values) {
        expect(hotelReviewCategoryLabel(l10n, category), isNotEmpty);
      }
      for (final bed in BedType.values) {
        expect(hotelBedTypeLabel(l10n, bed), isNotEmpty);
      }
      for (final policy in BreakfastPolicy.values) {
        expect(hotelBreakfastLabel(l10n, policy), isNotEmpty);
      }
      for (final type in CancellationType.values) {
        expect(hotelCancellationLabel(l10n, type), isNotEmpty);
      }
      for (final type in PrepaymentType.values) {
        expect(hotelPrepaymentLabel(l10n, type), isNotEmpty);
      }
      for (final timing in PaymentTiming.values) {
        expect(hotelPaymentTimingLabel(l10n, timing), isNotEmpty);
      }
    }
  });

  testWidgets('a bed configuration reads as a count and a bed', (tester) async {
    await tester.pumpWidget(_host(const SizedBox.shrink()));
    await tester.pumpAndSettle();
    final l10n = AppLocalizations.of(tester.element(find.byType(SizedBox)));
    expect(
      hotelBedConfigurationLabel(
        l10n,
        const BedConfiguration(type: BedType.king),
      ),
      '1 × King bed',
    );
  });

  testWidgets('the counter stops at its minimum and its maximum', (
    tester,
  ) async {
    var value = 2;
    await tester.pumpWidget(
      _host(
        StatefulBuilder(
          builder: (context, setState) => HotelCounterRow(
            icon: Icons.person_outline,
            label: 'Adult',
            value: value,
            minimum: 2,
            maximum: 3,
            controlKey: 'adult',
            onChanged: (next) => setState(() => value = next),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('adult-decrease')));
    await tester.pump();
    expect(value, 2, reason: 'already at the minimum');

    await tester.tap(find.byKey(const ValueKey('adult-increase')));
    await tester.pump();
    expect(value, 3);

    await tester.tap(find.byKey(const ValueKey('adult-increase')));
    await tester.pump();
    expect(value, 3, reason: 'the published ceiling holds');
  });

  testWidgets('a counter with no known ceiling keeps counting', (tester) async {
    var value = 1;
    await tester.pumpWidget(
      _host(
        StatefulBuilder(
          builder: (context, setState) => HotelCounterRow(
            icon: Icons.meeting_room_outlined,
            label: 'Room',
            value: value,
            minimum: 1,
            controlKey: 'room',
            onChanged: (next) => setState(() => value = next),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('room-increase')));
    await tester.pump();
    expect(value, 2);
  });
}
