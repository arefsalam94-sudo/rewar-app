import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kurdistan_paradise_travel_guide/l10n/app_localizations.dart';
import 'package:kurdistan_paradise_travel_guide/models/featured_item.dart';
import 'package:kurdistan_paradise_travel_guide/models/tour.dart';
import 'package:kurdistan_paradise_travel_guide/models/tour_filters.dart';
import 'package:kurdistan_paradise_travel_guide/screens/explore_tours_screen.dart';
import 'package:kurdistan_paradise_travel_guide/services/currency_rates_service.dart';
import 'package:kurdistan_paradise_travel_guide/services/device_location_service.dart';
import 'package:kurdistan_paradise_travel_guide/services/favorites_service.dart';
import 'package:kurdistan_paradise_travel_guide/services/tours_service.dart';
import 'package:kurdistan_paradise_travel_guide/services/user_profile_service.dart';
import 'package:kurdistan_paradise_travel_guide/theme/app_theme.dart';
import 'package:kurdistan_paradise_travel_guide/widgets/glass_back_button.dart';
import 'package:kurdistan_paradise_travel_guide/widgets/glass_panel.dart';
import 'package:kurdistan_paradise_travel_guide/widgets/page_background.dart';
import 'package:kurdistan_paradise_travel_guide/widgets/primary_button.dart';

void main() {
  group('Tour', () {
    test('falls back to English when a locale is missing', () {
      const tour = Tour(
        id: 'x',
        names: {'en': 'Gali Sherana'},
        descriptions: {'en': 'Quiet.'},
      );
      expect(tour.name('ku'), 'Gali Sherana');
      expect(tour.description('ar'), 'Quiet.');
      // No location label at all is an empty string, never a crash.
      expect(tour.locationLabel('en'), '');
    });

    test('fromMap skips a document with no name', () {
      expect(Tour.fromMap('x', <String, dynamic>{'pricePerPerson': 55}), null);
      expect(Tour.fromMap('x', null), null);
    });

    test('fromMap reads every field the card draws', () {
      final tour = Tour.fromMap('gali-alibag', <String, dynamic>{
        'name': {'en': 'Gali Alibag Waterfall', 'ku': 'ئاوشاری گەلی عەلی بەگ'},
        'description': {'en': 'A popular scenic waterfall.'},
        'locationLabel': {'en': 'Rawanduz, Erbil'},
        'companyTag': 'AB group',
        'durationDays': 2,
        'features': ['camping', 'guide', 42, ''],
        'imageUrls': ['https://example.test/a.jpg', ''],
        'pricePerPerson': 55,
        'currency': 'USD',
        'startAt': '2026-08-14T00:00:00.000',
        'endAt': '2026-08-16T00:00:00.000',
        'reviewScore': 8.7,
        'ratingCount': 128,
        'ratingBreakdown': {'5': 90, '4': 30, '3': 8},
        'capacity': 24,
        'bookedCount': 21,
        'cancellationPolicy': 'free_48h',
        'guideLanguages': ['en', 'ku'],
        'transportAvailable': true,
        'transportPricePerPerson': 5,
        'trending': true,
        'trendingOrder': 1,
        'highlighted': true,
        'highlightOrder': 3,
      });

      expect(tour, isNotNull);
      expect(tour!.name('ku'), 'ئاوشاری گەلی عەلی بەگ');
      expect(tour.companyTag, 'AB group');
      expect(tour.durationDays, 2);
      // Empty strings and non-strings are dropped rather than drawn.
      expect(tour.features, {'camping', 'guide'});
      expect(tour.imageUrls, ['https://example.test/a.jpg']);
      expect(tour.pricePerPerson, 55);
      expect(tour.startAt, DateTime(2026, 8, 14));
      expect(tour.reviewScore, 8.7);
      expect(tour.ratingCount, 128);
      expect(tour.ratingBreakdown.countFor(5), 90);
      expect(tour.spotsLeft, 3);
      expect(tour.cancellationPolicy, TourCancellationPolicy.free48h);
      expect(tour.guideLanguages, {'en', 'ku'});
      expect(tour.transportAvailable, isTrue);
      expect(tour.transportPricePerPerson, 5);
      expect(tour.trending, isTrue);
      expect(tour.highlightOrder, 3);
    });

    test('drops feature and language ids the app cannot draw', () {
      const tour = Tour(
        id: 'x',
        names: {'en': 'X'},
        features: {'camping', 'scuba_diving', 'food'},
        guideLanguages: {'en', 'zz', 'ar'},
      );
      expect(tour.knownFeatures, [TourFeature.camping, TourFeature.food]);
      expect(tour.knownGuideLanguages, [
        TourGuideLanguage.english,
        TourGuideLanguage.arabic,
      ]);
    });

    test('availability is derived, clamped, and absent without a capacity', () {
      const noCapacity = Tour(id: 'x', names: {'en': 'X'});
      expect(noCapacity.spotsLeft, isNull);
      expect(noCapacity.isLowAvailability, isFalse);
      // A tour whose operator published no capacity is assumed bookable —
      // hiding a good tour over a blank field would be worse.
      expect(noCapacity.hasRoomFor(8), isTrue);

      const nearlyFull = Tour(
        id: 'x',
        names: {'en': 'X'},
        capacity: 24,
        bookedCount: 21,
      );
      expect(nearlyFull.spotsLeft, 3);
      expect(nearlyFull.isLowAvailability, isTrue);
      expect(nearlyFull.hasRoomFor(3), isTrue);
      expect(nearlyFull.hasRoomFor(4), isFalse);

      // Over-booked is sold out, not negative.
      const oversold = Tour(
        id: 'x',
        names: {'en': 'X'},
        capacity: 10,
        bookedCount: 12,
      );
      expect(oversold.spotsLeft, 0);
      expect(oversold.isSoldOut, isTrue);
      expect(oversold.isLowAvailability, isFalse);

      // A big departure is not nagged about.
      const plentyLeft = Tour(
        id: 'x',
        names: {'en': 'X'},
        capacity: 60,
        bookedCount: 4,
      );
      expect(plentyLeft.isLowAvailability, isFalse);
    });

    test('search matches name, location and operator in any language', () {
      const tour = Tour(
        id: 'x',
        names: {'en': 'Gali Alibag Waterfall', 'ar': 'شلال كلي علي بك'},
        locationLabels: {'en': 'Rawanduz, Erbil'},
        companyTag: 'AB group',
      );
      expect(tour.matchesQuery(''), isTrue);
      expect(tour.matchesQuery('waterfall'), isTrue);
      // Someone browsing in Arabic may still type the English spelling.
      expect(tour.matchesQuery('شلال'), isTrue);
      expect(tour.matchesQuery('erbil'), isTrue);
      expect(tour.matchesQuery('AB'), isTrue);
      expect(tour.matchesQuery('duhok'), isFalse);
    });

    test('a date range matches by overlap, not containment', () {
      final tour = Tour(
        id: 'x',
        names: const {'en': 'X'},
        startAt: DateTime(2026, 8, 14, 9),
        endAt: DateTime(2026, 8, 16, 18),
      );
      // Entirely inside the window.
      expect(
        tour.runsBetween(DateTime(2026, 8, 1), DateTime(2026, 8, 31)),
        isTrue,
      );
      // Overlapping at each end — someone searching 16–20 August wants this.
      expect(
        tour.runsBetween(DateTime(2026, 8, 16), DateTime(2026, 8, 20)),
        isTrue,
      );
      expect(
        tour.runsBetween(DateTime(2026, 8, 10), DateTime(2026, 8, 14)),
        isTrue,
      );
      // A single day inside the run.
      expect(tour.runsBetween(DateTime(2026, 8, 15), null), isTrue);
      // Clear of it on both sides.
      expect(
        tour.runsBetween(DateTime(2026, 8, 17), DateTime(2026, 8, 20)),
        isFalse,
      );
      expect(
        tour.runsBetween(DateTime(2026, 8, 1), DateTime(2026, 8, 13)),
        isFalse,
      );
    });

    test('a tour with no start date never matches a date filter', () {
      const tour = Tour(id: 'x', names: {'en': 'X'});
      expect(tour.runsOn(DateTime(2026, 8, 14)), isFalse);
      expect(
        tour.runsBetween(DateTime(2026, 8, 1), DateTime(2026, 8, 31)),
        isFalse,
      );
    });
  });

  group('TourFilters', () {
    const camping = Tour(
      id: 'camping',
      names: {'en': 'Camping trip'},
      features: {'camping', 'food'},
      guideLanguages: {'ku'},
      pricePerPerson: 30,
      reviewScore: 7.0,
      capacity: 10,
      bookedCount: 8,
    );
    const hiking = Tour(
      id: 'hiking',
      names: {'en': 'Hiking trip'},
      features: {'hiking'},
      guideLanguages: {'en'},
      pricePerPerson: 90,
      reviewScore: 9.4,
    );

    test('OR within a group, AND across groups', () {
      const both = TourFilters(features: {'camping', 'hiking'});
      expect(both.matches(camping), isTrue);
      expect(both.matches(hiking), isTrue);

      // Adding a language group narrows: hiking's guide speaks English only.
      const narrowed = TourFilters(
        features: {'camping', 'hiking'},
        guideLanguages: {'ku'},
      );
      expect(narrowed.matches(camping), isTrue);
      expect(narrowed.matches(hiking), isFalse);
    });

    test('an empty group means no filter, not match-nothing', () {
      const none = TourFilters();
      expect(none.matches(camping), isTrue);
      expect(none.matches(hiking), isTrue);
    });

    test('party size hides a departure that cannot seat it', () {
      // Two places left on the camping trip.
      expect(const TourFilters(travellers: 2).matches(camping), isTrue);
      expect(const TourFilters(travellers: 3).matches(camping), isFalse);
      // The hiking trip published no capacity, so it stays.
      expect(const TourFilters(travellers: 3).matches(hiking), isTrue);
    });

    test('sorting puts a missing value last, never first', () {
      const priced = Tour(id: 'p', names: {'en': 'P'}, pricePerPerson: 10);
      const unpriced = Tour(id: 'u', names: {'en': 'U'});

      // Cheapest first must not rank "no price" as free.
      final low = const TourFilters(
        sort: TourSort.priceLowToHigh,
      ).sortedFrom(const [unpriced, priced]);
      expect(low.map((t) => t.id), ['p', 'u']);

      // And "most expensive" must not rank it as infinite either.
      final high = const TourFilters(
        sort: TourSort.priceHighToLow,
      ).sortedFrom(const [unpriced, priced]);
      expect(high.map((t) => t.id), ['p', 'u']);

      // Same for an unrated tour under "Top rated".
      final rated = const TourFilters(
        sort: TourSort.topRated,
      ).sortedFrom(const [camping, hiking]);
      expect(rated.map((t) => t.id), ['hiking', 'camping']);
    });

    test('"nearest" falls back to soonest without a device position', () {
      final near = Tour(
        id: 'near',
        names: const {'en': 'Near'},
        latitude: 36.19,
        longitude: 44.01,
        startAt: DateTime(2026, 9, 1),
      );
      final far = Tour(
        id: 'far',
        names: const {'en': 'Far'},
        latitude: 37.05,
        longitude: 43.09,
        startAt: DateTime(2026, 8, 1),
      );

      const filters = TourFilters(sort: TourSort.nearest);
      // No fix: chronological, not an arbitrary order presented as "nearest".
      expect(filters.sortedFrom([near, far]).map((t) => t.id), ['far', 'near']);
      // With a fix, actually nearest first.
      expect(
        filters
            .sortedFrom([far, near], fromLatitude: 36.19, fromLongitude: 44.01)
            .map((t) => t.id),
        ['near', 'far'],
      );
    });

    test('trending pins lead the default order only', () {
      const a = Tour(id: 'a', names: {'en': 'A'});
      const b = Tour(
        id: 'b',
        names: {'en': 'B'},
        trending: true,
        trendingOrder: 2,
        pricePerPerson: 99,
      );
      const d = Tour(
        id: 'd',
        names: {'en': 'D'},
        trending: true,
        trendingOrder: 1,
        pricePerPerson: 50,
      );

      expect(const TourFilters().sortedFrom(const [a, b, d]).map((t) => t.id), [
        'd',
        'b',
        'a',
      ]);
      // Once the user has chosen an order, an editorial pin must not override
      // it — that just looks like a broken sort.
      expect(
        const TourFilters(
          sort: TourSort.priceLowToHigh,
        ).sortedFrom(const [b, d, a]).map((t) => t.id),
        ['d', 'b', 'a'],
      );
    });

    test('isEmpty tracks every narrowing dimension but not the sort', () {
      expect(const TourFilters().isEmpty, isTrue);
      expect(const TourFilters(sort: TourSort.topRated).isEmpty, isTrue);
      expect(const TourFilters(query: 'x').isEmpty, isFalse);
      expect(const TourFilters(features: {'food'}).isEmpty, isFalse);
      expect(const TourFilters(travellers: 2).isEmpty, isFalse);
      expect(TourFilters(rangeStart: DateTime(2026, 8, 1)).isEmpty, isFalse);
    });
  });

  group('CurrencyRates', () {
    const rates = CurrencyRates(
      base: 'USD',
      rates: {'USD': 1, 'IQD': 1310, 'EUR': 0.92},
    );

    test('converts through the base, and is identity on a match', () {
      expect(rates.convert(10, from: 'USD', to: 'USD'), 10);
      expect(rates.convert(1, from: 'USD', to: 'IQD'), 1310);
      // Cross-rate, not a base-only conversion.
      expect(rates.convert(1310, from: 'IQD', to: 'USD'), closeTo(1, 0.0001));
      expect(rates.convert(1310, from: 'IQD', to: 'EUR'), closeTo(0.92, 0.001));
    });

    test('returns null rather than guessing at an unknown currency', () {
      expect(rates.convert(10, from: 'GBP', to: 'USD'), isNull);
      expect(rates.convert(10, from: 'USD', to: 'JPY'), isNull);
      expect(CurrencyRates.empty.convert(10, from: 'USD', to: 'IQD'), isNull);
    });

    test('fromMap drops non-positive and non-numeric rates', () {
      final parsed = CurrencyRates.fromMap(<String, dynamic>{
        'base': 'usd',
        'rates': {'USD': 1, 'IQD': 1310, 'EUR': 0, 'GBP': 'nope'},
      });
      expect(parsed.base, 'USD');
      expect(parsed.supports('IQD'), isTrue);
      expect(parsed.supports('EUR'), isFalse);
      expect(parsed.supports('GBP'), isFalse);
    });
  });

  group('formatMoney', () {
    test('groups thousands and keeps a symbol tight but a code spaced', () {
      expect(formatMoney(55, 'USD'), r'$55');
      expect(formatMoney(55.5, 'USD'), r'$55.50');
      expect(formatMoney(1240, 'EUR'), '€1,240');
      expect(formatMoney(72049.6, 'IQD'), 'IQD 72,050');
    });
  });

  group('TourPricing', () {
    const rates = CurrencyRates(base: 'USD', rates: {'USD': 1, 'IQD': 1310});

    test('leaves a matching currency alone', () {
      const pricing = TourPricing(rates: rates, displayCurrency: 'USD');
      expect(pricing.isConverted('USD'), isFalse);
      expect(pricing.perPerson(55, 'USD'), r'$55');
      expect(pricing.total(55, 'USD'), isNull);
    });

    test('marks a converted price approximate', () {
      const pricing = TourPricing(rates: rates, displayCurrency: 'IQD');
      expect(pricing.isConverted('USD'), isTrue);
      expect(pricing.perPerson(55, 'USD'), '≈ IQD 72,050');
    });

    test('falls back to the operator currency when no rate exists', () {
      const pricing = TourPricing(
        rates: CurrencyRates.empty,
        displayCurrency: 'IQD',
      );
      expect(pricing.isConverted('USD'), isFalse);
      // An unconverted true price beats a converted invented one.
      expect(pricing.perPerson(55, 'USD'), r'$55');
    });

    test('the party total appears only above one traveller', () {
      const one = TourPricing(
        rates: rates,
        displayCurrency: 'USD',
        travellers: 1,
      );
      const four = TourPricing(
        rates: rates,
        displayCurrency: 'USD',
        travellers: 4,
      );
      expect(one.total(55, 'USD'), isNull);
      expect(four.total(55, 'USD'), r'$220');
    });
  });

  group('AppLocalizations tour formatting', () {
    test('collapses a same-month range and spells out a crossing one', () {
      const en = AppLocalizations(Locale('en'));
      expect(
        en.tourDateRange(DateTime(2026, 8, 14), DateTime(2026, 8, 16)),
        'Aug 14 - 16',
      );
      expect(
        en.tourDateRange(DateTime(2026, 8, 30), DateTime(2026, 9, 2)),
        'Aug 30 - Sep 2',
      );
      // A one-day tour is a single date, not "Aug 14 - Aug 14".
      expect(en.tourDateRange(DateTime(2026, 8, 14), null), 'Aug 14');
    });

    test('Kurdish and Arabic put the day first and spell the month out', () {
      const ku = AppLocalizations(Locale('ku'));
      const ar = AppLocalizations(Locale('ar'));
      // No invented three-letter abbreviation — the full month name is used.
      expect(ku.tourDateRange(DateTime(2026, 8, 14), null), '14 ئاب');
      expect(
        ar.tourDateRange(DateTime(2026, 8, 14), DateTime(2026, 8, 16)),
        '14 - 16 أغسطس',
      );
    });

    test('counted strings have a real singular in all three languages', () {
      for (final locale in AppLocalizations.supportedLocales) {
        final l10n = AppLocalizations(locale);
        expect(l10n.tourDuration(1), isNot(l10n.tourDuration(2)));
        expect(l10n.tourReviewCount(1), isNot(l10n.tourReviewCount(2)));
        expect(l10n.tourSpotsLeft(1), isNot(l10n.tourSpotsLeft(3)));
        expect(l10n.tourTravellerCount(1), isNot(l10n.tourTravellerCount(2)));
      }
      expect(
        const AppLocalizations(Locale('en')).tourReviewCount(128),
        '128 reviews',
      );
      expect(
        const AppLocalizations(Locale('en')).tourSpotsLeft(3),
        'Only 3 spots left',
      );
    });

    test('every tour string exists in all three languages', () {
      const english = AppLocalizations(Locale('en'));
      for (final locale in AppLocalizations.supportedLocales) {
        final l10n = AppLocalizations(locale);
        for (final value in [
          l10n.toursSearchHint,
          l10n.toursDateRangeHint,
          l10n.toursApply,
          l10n.trendingTours,
          l10n.toursLoadFailed,
          l10n.toursEmpty,
          l10n.toursHighlightedEmpty,
          l10n.tourPerPerson,
          l10n.tourNoReviews,
          l10n.tourTravellers,
          l10n.tourGuideLanguages,
          l10n.toursSortLabel,
          l10n.toursIncludes,
          l10n.toursPriceApprox,
          l10n.toursClearAll,
        ]) {
          expect(value, isNotEmpty);
        }
        for (final feature in TourFeature.values) {
          expect(l10n.tourFeatureLabel(feature), isNotEmpty);
        }
        for (final policy in TourCancellationPolicy.values) {
          expect(l10n.tourCancellationLabel(policy), isNotEmpty);
        }
        for (final language in TourGuideLanguage.values) {
          expect(l10n.tourGuideLanguageLabel(language), isNotEmpty);
        }
        for (final sort in TourSort.values) {
          expect(l10n.tourSortLabel(sort), isNotEmpty);
        }
        if (locale.languageCode != 'en') {
          // A missing translation would silently fall through to English.
          expect(l10n.toursApply, isNot(english.toursApply));
          expect(l10n.toursSortLabel, isNot(english.toursSortLabel));
          expect(l10n.tourNoReviews, isNot(english.tourNoReviews));
        }
      }
    });
  });

  group('formatTourDistance', () {
    test('metres, then one decimal, then whole kilometres', () {
      expect(formatTourDistance(340), '340 m');
      expect(formatTourDistance(2300), '2.3 km');
      expect(formatTourDistance(127_400), '127 km');
    });
  });

  group('ExploreToursScreen', () {
    testWidgets('uses the supplied background photo under the gradient', (
      tester,
    ) async {
      await _pumpScreen(tester, service: _FakeToursService());

      final background = tester.widget<PageBackground>(
        find.byType(PageBackground),
      );
      expect(background.imageAsset, exploreToursBackgroundAsset);
      // The design-standard σ2 blur and 45% gradient, not a per-screen recipe.
      expect(background.blurSigma, isNull);
      expect(background.gradientOpacity, isNull);
    });

    testWidgets('draws the back button and title on one row', (tester) async {
      await _pumpScreen(tester, service: _FakeToursService());

      expect(find.byType(GlassBackButton), findsOneWidget);
      expect(find.text('Explore Tours'), findsOneWidget);

      final button = tester.getRect(find.byType(GlassBackButton));
      final title = tester.getRect(find.text('Explore Tours'));
      // Same row: the title's vertical centre sits inside the button's height.
      expect(title.center.dy, greaterThan(button.top));
      expect(title.center.dy, lessThan(button.bottom));
      // And after it, not above it.
      expect(title.left, greaterThan(button.right));
    });

    testWidgets('the carousel rating sits trailing, above the tour name', (
      tester,
    ) async {
      await _pumpScreen(tester, service: _FakeToursService());

      final slide = tester.getRect(find.byType(PageView));
      final score = tester.getRect(find.text('8.7').first);
      final name = tester.getRect(find.text('Gali Alibag Waterfall').first);
      final tag = tester.getRect(find.text('AB group').first);

      // Trailing half of the slide, and above the name — as asked.
      expect(score.left, greaterThan(slide.center.dx));
      expect(score.bottom, lessThan(name.top));
      // The operator tag sits under the rating, not beside it.
      expect(tag.top, greaterThan(score.bottom - 1));
    });

    testWidgets(
      'the card puts the heart on the photo and the operator on top',
      (tester) async {
        // No rating at all on a list card now — neither the number nor the
        // stars. The favourite took the stars' place over the photo, and the
        // operator tag took the corner the favourite used to hold.
        await _pumpScreen(tester, service: _FakeToursService());

        final photo = tester.getRect(
          find.byKey(tourCardThumbnailKey('gali-alibag-waterfall')),
        );
        final card = tester.getRect(
          find
              .ancestor(
                of: find.byKey(tourCardThumbnailKey('gali-alibag-waterfall')),
                matching: find.byType(GlassPanel),
              )
              .first,
        );

        // No score anywhere on a card — 8.5 belongs to Gali Sherana, which has
        // no carousel slide, so finding it at all would mean a card drew it.
        expect(find.text('8.5'), findsNothing);
        // And no stars either: the only ones on screen belong to the carousel.
        expect(
          find.descendant(
            of: find.byKey(tourCardThumbnailKey('gali-alibag-waterfall')),
            matching: find.byWidgetPredicate(
              (widget) =>
                  widget is Icon &&
                  (widget.icon == Icons.star_rounded ||
                      widget.icon == Icons.star_outline_rounded),
            ),
          ),
          findsNothing,
        );

        final heart = tester.getRect(
          find
              .descendant(
                of: find.byKey(tourCardThumbnailKey('gali-alibag-waterfall')),
                matching: find.byWidgetPredicate(
                  (widget) =>
                      widget is Icon &&
                      (widget.icon == Icons.favorite_rounded ||
                          widget.icon == Icons.favorite_border_rounded),
                ),
              )
              .first,
        );
        // Over the photo, near its top, where the stars used to be.
        expect(heart.left, greaterThan(photo.left));
        expect(heart.right, lessThan(photo.right));
        expect(heart.top, lessThan(photo.top + photo.height / 4));

        final operator = tester.getRect(
          find
              .descendant(
                of: find
                    .ancestor(
                      of: find.byKey(
                        tourCardThumbnailKey('gali-alibag-waterfall'),
                      ),
                      matching: find.byType(GlassPanel),
                    )
                    .first,
                matching: find.text('AB group'),
              )
              .first,
        );
        // Top trailing corner of the card, clear of the photo entirely.
        expect(operator.left, greaterThan(photo.right));
        expect(operator.right, lessThan(card.right));
        expect(operator.top, lessThan(card.top + card.height / 4));
      },
    );

    testWidgets('the carousel stands 308dp tall at the default font size', (
      tester,
    ) async {
      // Grown by 100 on request. Asserted rather than left to the eye, because
      // it is the one number the slide's whole internal layout is budgeted
      // against.
      await _pumpScreen(tester, service: _FakeToursService());
      expect(tester.getRect(find.byType(PageView)).height, 308);
    });

    testWidgets('the card photo is inset from the rim on all four sides', (
      tester,
    ) async {
      await _pumpScreen(tester, service: _FakeToursService());

      final thumb = find.byKey(tourCardThumbnailKey('gali-alibag-waterfall'));
      final photo = tester.getRect(thumb);
      final card = tester.getRect(
        find.ancestor(of: thumb, matching: find.byType(GlassPanel)).first,
      );

      // The approved reference draws the photo as its own rounded panel
      // floating inside the card, not bled to the rim.
      expect(photo.left, greaterThan(card.left));
      expect(photo.top, greaterThan(card.top));
      expect(photo.bottom, lessThan(card.bottom));
      expect(photo.right, lessThan(card.right));
      // Leading third of the card, at the reference's proportion.
      expect(photo.width / card.width, closeTo(110 / 360, 0.03));
    });

    testWidgets('every card holds the reference proportions at any width', (
      tester,
    ) async {
      // The card is laid out once at its base size and scaled to fit, so the
      // *shape* is identical on every phone — which is what was approved.
      for (final width in <double>[320, 360, 430]) {
        await _pumpScreen(tester, service: _FakeToursService(), width: width);
        expect(tester.takeException(), isNull);

        final card = tester.getRect(
          find
              .ancestor(
                of: find.byKey(tourCardThumbnailKey('gali-alibag-waterfall')),
                matching: find.byType(GlassPanel),
              )
              .first,
        );
        expect(
          card.width / card.height,
          closeTo(360 / 184, 0.02),
          reason: 'card aspect ratio drifted at ${width}dp',
        );
      }
    });

    testWidgets('the place block straddles the card\'s vertical middle', (
      tester,
    ) async {
      await _pumpScreen(tester, service: _FakeToursService());

      final card = tester.getRect(
        find
            .ancestor(
              of: find.byKey(tourCardThumbnailKey('gali-alibag-waterfall')),
              matching: find.byType(GlassPanel),
            )
            .first,
      );
      final cardFinder = find
          .ancestor(
            of: find.byKey(tourCardThumbnailKey('gali-alibag-waterfall')),
            matching: find.byType(GlassPanel),
          )
          .first;
      // Two tours depart from Rawanduz, so the lines are read off this card.
      final place = tester.getRect(
        find
            .descendant(of: cardFinder, matching: find.text('Rawanduz, Erbil'))
            .first,
      );
      final spots = tester.getRect(
        find
            .descendant(
              of: cardFinder,
              matching: find.text('Only 3 spots left'),
            )
            .first,
      );

      // Centred on the card as a block: the place line above the middle, the
      // availability line below it.
      expect(place.top, lessThan(card.center.dy));
      expect(spots.bottom, greaterThan(card.center.dy));
      expect(
        ((place.top + spots.bottom) / 2 - card.center.dy).abs(),
        lessThan(6),
      );
    });

    testWidgets('the facility grid is centred and clears the date', (
      tester,
    ) async {
      await _pumpScreen(tester, service: _FakeToursService());

      final cardFinder = find
          .ancestor(
            of: find.byKey(tourCardThumbnailKey('gali-alibag-waterfall')),
            matching: find.byType(GlassPanel),
          )
          .first;
      final card = tester.getRect(cardFinder);
      // Each facility circle carries a Tooltip with its name, which is what
      // makes them findable now that the labels are gone.
      final circles = tester
          .widgetList(
            find.descendant(of: cardFinder, matching: find.byType(Tooltip)),
          )
          .length;
      expect(circles, greaterThan(1));

      final grid = find.descendant(
        of: cardFinder,
        matching: find.byType(Tooltip),
      );
      final top = tester.getRect(grid.first).top;
      final bottom = tester.getRect(grid.last).bottom;

      // Sits on the card's middle rather than under the operator tag.
      expect(((top + bottom) / 2 - card.center.dy).abs(), lessThan(10));
      // And stops short of the date above the price badge.
      final tour = ToursService.bundledTours().firstWhere(
        (tour) => tour.pricePerPerson == 55,
      );
      const en = AppLocalizations(Locale('en'));
      expect(
        bottom,
        lessThan(
          tester
              .getRect(find.text(en.tourDateRange(tour.startAt!, tour.endAt)))
              .top,
        ),
      );
    });

    testWidgets('the departure dates sit directly over the price badge', (
      tester,
    ) async {
      await _pumpScreen(tester, service: _FakeToursService());

      // The bundled tours depart relative to today, so the label is built the
      // same way the card builds it rather than hard-coded.
      final tour = ToursService.bundledTours().firstWhere(
        (tour) => tour.pricePerPerson == 55,
      );
      const en = AppLocalizations(Locale('en'));

      final price = tester.getRect(find.text(r'$55'));
      final date = tester.getRect(
        find.text(en.tourDateRange(tour.startAt!, tour.endAt)),
      );
      // Directly above the badge, inside its horizontal span — the amount
      // itself sits on the badge's leading half, so the badge is what the
      // date is measured against.
      final badge = tester.getRect(
        find
            .ancestor(of: find.text(r'$55'), matching: find.byType(GlassPanel))
            .first,
      );
      expect(date.bottom, lessThan(price.top));
      expect(date.left, greaterThanOrEqualTo(badge.left));
      expect(date.right, lessThan(badge.right));
    });

    testWidgets('both search boxes share a row, with Apply centred below', (
      tester,
    ) async {
      await _pumpScreen(tester, service: _FakeToursService());

      final search = tester.getRect(find.byKey(exploreToursSearchFieldKey));
      final date = tester.getRect(find.byKey(exploreToursDateFieldKey));
      final apply = tester.getRect(find.byType(PrimaryButton));
      final page = tester.getRect(find.byType(PageBackground));

      // Same row, search first.
      expect(search.center.dy, closeTo(date.center.dy, 1));
      expect(date.left, greaterThan(search.right - 1));
      // Apply below both, centred between them.
      expect(apply.top, greaterThan(search.bottom));
      expect(apply.center.dx, closeTo(page.center.dx, 1));
      expect(apply.center.dx, greaterThan(search.center.dx));
      expect(apply.center.dx, lessThan(date.center.dx));
    });

    testWidgets('the price and its label share a row on a card', (
      tester,
    ) async {
      await _pumpScreen(tester, service: _FakeToursService());

      final price = tester.getRect(find.text(r'$55'));
      final label = tester.getRect(find.text('Per Person').first);
      // Amount on the leading side, label beside it — the same shape the
      // full-size badge on a carousel slide uses.
      expect(label.left, greaterThan(price.right - 1));
      expect((label.center.dy - price.center.dy).abs(), lessThan(8));
    });

    testWidgets('lays out on a phone-width screen without overflowing', (
      tester,
    ) async {
      // The default 900dp test surface is far wider than any phone; the card
      // is at its tightest at 360dp, which is where a resize regression would
      // show up first.
      await _pumpScreen(tester, service: _FakeToursService(), width: 360);
      expect(tester.takeException(), isNull);
      expect(find.text('Gali Sherana'), findsOneWidget);
    });

    testWidgets('at a large system font the search fields stack instead', (
      tester,
    ) async {
      await _pumpScreen(
        tester,
        service: _FakeToursService(),
        width: 360,
        textScale: 1.6,
      );
      expect(tester.takeException(), isNull);

      final search = tester.getRect(find.byKey(exploreToursSearchFieldKey));
      final date = tester.getRect(find.byKey(exploreToursDateFieldKey));
      // Two half-width fields cannot hold a legible hint at this size, so they
      // go one above the other rather than clipping.
      expect(date.top, greaterThan(search.bottom - 1));
    });

    testWidgets('an unrated tour draws no badge rather than showing a zero', (
      tester,
    ) async {
      await _pumpScreen(tester, service: _FakeToursService());
      // Korek has no reviews seeded: it gets no score and no stars, rather
      // than a 0.0 that reads as a bad tour.
      expect(find.text('0.0'), findsNothing);
      expect(find.text('No reviews yet'), findsNothing);
    });

    testWidgets('facilities are icon-only, capped at six', (tester) async {
      // The approved card draws them as a 2x3 grid of bare circles — the
      // labelled list belongs on the Tour Detail screen.
      await _pumpScreen(tester, service: _FakeToursService());

      expect(find.text('Guide'), findsNothing);
      expect(find.text('Food'), findsNothing);

      final card = find
          .ancestor(
            of: find.byKey(tourCardThumbnailKey('gali-alibag-waterfall')),
            matching: find.byType(GlassPanel),
          )
          .first;
      final facilityIcons = tester
          .widgetList<Icon>(
            find.descendant(of: card, matching: find.byType(Icon)),
          )
          .where((icon) => icon.icon == Icons.person_outline_rounded);
      expect(facilityIcons.length, lessThanOrEqualTo(1));
    });

    testWidgets('low availability is called out; a roomy departure is not', (
      tester,
    ) async {
      await _pumpScreen(tester, service: _FakeToursService());
      // Gali Alibag: 24 capacity, 21 booked. Korek: 30/28.
      expect(find.text('Only 3 spots left'), findsOneWidget);
      expect(find.text('Only 2 spots left'), findsOneWidget);
      // Gali Sherana has 12 places left, and is not nagged about.
      expect(find.textContaining('12 spots'), findsNothing);
    });

    testWidgets('the card carries no cancellation tier or language list', (
      tester,
    ) async {
      // Both were removed from the list card on request. They are still on the
      // tour and still drawn on the Tour Detail screen — this asserts the card
      // stays clear of them, so a future edit cannot quietly put them back.
      await _pumpScreen(tester, service: _FakeToursService());

      expect(find.text('Free cancellation until 48h before'), findsNothing);
      expect(find.text('Non-refundable'), findsNothing);
      expect(find.text('English · Kurdish · Arabic'), findsNothing);
      expect(find.text('English · Turkish'), findsNothing);
    });

    testWidgets('draws the carousel, the controls and a card per tour', (
      tester,
    ) async {
      await _pumpScreen(tester, service: _FakeToursService());

      // Carousel slide plus its own list card.
      expect(find.text('Gali Alibag Waterfall'), findsNWidgets(2));
      expect(find.text('Gali Sherana'), findsOneWidget);

      // Controls.
      expect(find.byKey(exploreToursSearchFieldKey), findsOneWidget);
      expect(find.byKey(exploreToursDateFieldKey), findsOneWidget);
      expect(find.byType(PrimaryButton), findsOneWidget);
      expect(find.text('Apply'), findsOneWidget);
      expect(find.text('Trending Tours'), findsOneWidget);
      expect(find.text(r'$55'), findsOneWidget);
      expect(find.text('Per Person'), findsNWidgets(3));
    });

    testWidgets('prices convert, are marked approximate, and are disclosed', (
      tester,
    ) async {
      await _pumpScreen(
        tester,
        service: _FakeToursService(),
        profile: _FakeUserProfileService(AppCurrency.iqd),
      );

      // $55 at 1310 IQD/USD.
      expect(find.text('≈ IQD 72,050'), findsOneWidget);
      expect(find.textContaining('indicative rate'), findsOneWidget);
    });

    testWidgets('no rate table means the operator price, not a guess', (
      tester,
    ) async {
      await _pumpScreen(
        tester,
        service: _FakeToursService(),
        profile: _FakeUserProfileService(AppCurrency.iqd),
        rates: _FakeCurrencyRatesService(CurrencyRates.empty),
      );

      expect(find.text(r'$55'), findsOneWidget);
      // And no disclosure, because nothing on screen was converted.
      expect(find.textContaining('indicative rate'), findsNothing);
    });

    testWidgets('a guest tapping the heart is asked to sign in', (
      tester,
    ) async {
      final favorites = _FakeFavoritesService();
      await _pumpScreen(
        tester,
        service: _FakeToursService(signedIn: false),
        favorites: favorites,
      );

      await tester.tap(find.byIcon(Icons.favorite_border_rounded).first);
      await tester.pumpAndSettle();

      expect(find.text('Sign in to save favourites'), findsOneWidget);
      // Nothing was written — a favourite is tied to an account.
      expect(favorites.toggles, 0);
    });

    testWidgets('a signed-in user can save a tour', (tester) async {
      final favorites = _FakeFavoritesService();
      await _pumpScreen(
        tester,
        service: _FakeToursService(signedIn: true),
        favorites: favorites,
      );

      await tester.tap(find.byIcon(Icons.favorite_border_rounded).first);
      await tester.pumpAndSettle();

      expect(favorites.toggles, 1);
      expect(favorites.lastType, FeaturedType.tour);
      expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
    });

    testWidgets('hides the distance line when location is unavailable', (
      tester,
    ) async {
      await _pumpScreen(
        tester,
        service: _FakeToursService(),
        location: const _FakeLocationService(null),
      );
      expect(find.textContaining('from current location'), findsNothing);
    });

    testWidgets('shows the distance line once a fix arrives', (tester) async {
      await _pumpScreen(
        tester,
        service: _FakeToursService(),
        location: const _FakeLocationService(DeviceLocation(36.6289, 44.5311)),
      );
      expect(find.textContaining('from current location'), findsNWidgets(3));
    });

    testWidgets('search narrows the list only after Apply, and costs no read', (
      tester,
    ) async {
      final service = _FakeToursService();
      await _pumpScreen(tester, service: service);
      expect(service.catalogReads, 1);

      await tester.enterText(find.byKey(exploreToursSearchFieldKey), 'sherana');
      await tester.pumpAndSettle();
      // Nothing has changed yet — the reference has an explicit Apply button.
      expect(find.text('Korek Mountain Day Trip'), findsOneWidget);

      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(find.text('Gali Sherana'), findsOneWidget);
      expect(find.text('Korek Mountain Day Trip'), findsNothing);
      // Still one read: filtering happens in Dart over the catalog in memory.
      expect(service.catalogReads, 1);
    });

    testWidgets('an empty result offers to clear everything', (tester) async {
      await _pumpScreen(tester, service: _FakeToursService());

      await tester.enterText(
        find.byKey(exploreToursSearchFieldKey),
        'antarctica',
      );
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();

      expect(find.text('No tours match your search'), findsOneWidget);
      await tester.tap(find.text('Clear all'));
      await tester.pumpAndSettle();
      expect(find.text('Gali Sherana'), findsOneWidget);
    });

    testWidgets('a load failure shows the error and retries', (tester) async {
      final service = _FakeToursService(failFirstList: true);
      await _pumpScreen(tester, service: service);

      expect(find.text("Couldn't load tours"), findsOneWidget);
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('Gali Sherana'), findsOneWidget);
    });

    testWidgets('an empty catalog says so without offering a clear', (
      tester,
    ) async {
      await _pumpScreen(tester, service: _FakeToursService(emptyList: true));
      expect(find.text('No tours match your search'), findsOneWidget);
      expect(find.text('Clear all'), findsNothing);
    });

    testWidgets('an empty carousel says so without failing the page', (
      tester,
    ) async {
      await _pumpScreen(tester, service: _FakeToursService(noHighlights: true));
      expect(find.text('No tours are highlighted yet'), findsOneWidget);
      // The list below is unaffected.
      expect(find.text('Gali Sherana'), findsOneWidget);
    });

    testWidgets('the carousel dots stay left-to-right in Arabic', (
      tester,
    ) async {
      await _pumpScreen(
        tester,
        service: _FakeToursService(),
        locale: const Locale('ar'),
      );
      final dots = tester.widget<Directionality>(
        find
            .ancestor(
              of: find.byKey(exploreToursDotsKey),
              matching: find.byType(Directionality),
            )
            .first,
      );
      expect(dots.textDirection, TextDirection.ltr);
    });

    testWidgets('renders in Kurdish and Arabic, right to left', (tester) async {
      for (final locale in const [Locale('ku'), Locale('ar')]) {
        await _pumpScreen(tester, service: _FakeToursService(), locale: locale);
        final l10n = AppLocalizations(locale);
        expect(find.text(l10n.trendingTours), findsOneWidget);
        expect(find.text(l10n.toursApply), findsOneWidget);
        expect(
          Directionality.of(tester.element(find.byType(PrimaryButton))),
          TextDirection.rtl,
        );
      }
    });

    testWidgets('renders in dark mode', (tester) async {
      await _pumpScreen(tester, service: _FakeToursService(), dark: true);
      expect(find.text('Trending Tours'), findsOneWidget);
      expect(find.text('Gali Sherana'), findsOneWidget);
    });
  });
}

Future<void> _pumpScreen(
  WidgetTester tester, {
  required ToursService service,
  DeviceLocationService location = const _FakeLocationService(null),
  FavoritesService? favorites,
  UserProfileService? profile,
  CurrencyRatesService? rates,
  Locale locale = const Locale('en'),
  bool dark = false,
  double width = 900,
  double textScale = 1.0,
}) async {
  // Tall enough that the whole page is laid out; several assertions read
  // positions, which requires the widget to be on screen.
  tester.view.physicalSize = Size(width, 3400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      theme: AppTheme.lightForLocale(locale),
      darkTheme: AppTheme.darkForLocale(locale),
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: ExploreToursScreen(
        toursService: service,
        locationService: location,
        favoritesService: favorites ?? _FakeFavoritesService(),
        userProfileService: profile ?? _FakeUserProfileService(AppCurrency.usd),
        currencyRatesService:
            rates ??
            _FakeCurrencyRatesService(CurrencyRatesService.bundledRates),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Stands in for the Firestore-backed catalog source, and counts reads so a
/// test can prove that searching and refining cost none.
class _FakeToursService extends ToursService {
  _FakeToursService({
    this.failFirstList = false,
    this.emptyList = false,
    this.noHighlights = false,
    this.signedIn = false,
  });

  /// Fails the first catalog read only, so a retry can be shown to succeed.
  bool failFirstList;
  final bool emptyList;
  final bool noHighlights;
  final bool signedIn;

  int catalogReads = 0;

  @override
  bool get isSignedIn => signedIn;

  @override
  Future<List<Tour>> fetchHighlighted() async {
    if (noHighlights) return const <Tour>[];
    return ToursService.bundledTours()
        .where((tour) => tour.highlighted)
        .toList();
  }

  @override
  Future<List<Tour>> fetchCatalog() async {
    catalogReads++;
    if (failFirstList) {
      failFirstList = false;
      throw StateError('simulated failure');
    }
    if (emptyList) return const <Tour>[];
    return ToursService.bundledTours();
  }
}

class _FakeLocationService extends DeviceLocationService {
  const _FakeLocationService(this.location);

  final DeviceLocation? location;

  @override
  Future<DeviceLocation?> currentLocation() async => location;
}

class _FakeFavoritesService extends FavoritesService {
  _FakeFavoritesService();

  int toggles = 0;
  FeaturedType? lastType;
  final Set<String> saved = <String>{};

  @override
  Future<Set<String>> fetchFavoriteItemIds() async => saved;

  @override
  Future<bool> toggle({
    required FeaturedType itemType,
    required String itemId,
    required bool currentlyFavorite,
  }) async {
    toggles++;
    lastType = itemType;
    if (currentlyFavorite) {
      saved.remove(itemId);
      return false;
    }
    saved.add(itemId);
    return true;
  }
}

class _FakeUserProfileService extends UserProfileService {
  _FakeUserProfileService(this.currency);

  final AppCurrency currency;

  @override
  Future<UserProfile?> fetchProfile() async => UserProfile(
    name: 'Test',
    email: 'test@example.test',
    phone: '',
    profileImageUrl: null,
    currency: currency,
  );
}

class _FakeCurrencyRatesService extends CurrencyRatesService {
  _FakeCurrencyRatesService(this.rates);

  final CurrencyRates rates;

  @override
  Future<CurrencyRates> fetchLatest() async => rates;
}
