import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kurdistan_paradise_travel_guide/models/featured_item.dart';
import 'package:kurdistan_paradise_travel_guide/services/car_rental_service.dart';
import 'package:kurdistan_paradise_travel_guide/services/featured_service.dart';
import 'package:kurdistan_paradise_travel_guide/services/hotel_service.dart';
import 'package:kurdistan_paradise_travel_guide/services/nature_spots_service.dart';
import 'package:kurdistan_paradise_travel_guide/services/tours_service.dart';

/// The ids each `FeaturedType` may legally point at.
///
/// These come from the bundled catalogues, which the exporters keep identical
/// to the live collections — `tours/gali-alibag-waterfall` and
/// `nature_spots/rawanduz-canyon` exist in Firestore under exactly these ids.
/// That is what lets a unit test assert a reference resolves without a
/// network call.
///
/// `flights` is deliberately an EMPTY set: the collection has no documents and
/// flights are release-gated as Coming Soon, so no flight slide can be valid.
Map<FeaturedType, Set<String>> liveIds() => {
  FeaturedType.natureSpot: {
    for (final spot in NatureSpotsService.bundledSpots()) spot.id,
  },
  FeaturedType.tour: {for (final tour in ToursService.bundledTours()) tour.id},
  FeaturedType.hotel: {for (final hotel in PreviewHotelService.hotels) hotel.id},
  FeaturedType.car: {
    for (final car in PreviewCarRentalService.vehicles) car.id,
  },
  FeaturedType.flight: <String>{},
};

/// Names that must never appear on the front page of a Kurdistan travel app.
///
/// Every one of these actually shipped in `featured` or `bundledFeatured()`
/// before the 2026-09-15 cleanup, so this is a regression list, not a
/// hypothetical one. "Moraine Lake" is in Banff, Canada.
const _placeholders = [
  'Moraine Lake',
  'Zagros Highland Camp',
  'GreenWheels Rentals',
  'Astra Airlines',
];

void main() {
  final slides = FeaturedService.bundledFeatured();
  final catalogue = liveIds();

  group('every featured reference resolves to a real document', () {
    test('the carousel is not empty', () {
      // A guard on the guard: if this list were emptied, every per-slide test
      // below would vacuously pass.
      expect(slides, isNotEmpty);
    });

    for (final slide in slides) {
      test('${slide.id} → ${slide.type.id}/${slide.referenceId} exists', () {
        final ids = catalogue[slide.type];
        expect(
          ids,
          isNotNull,
          reason: '${slide.type.id} names no collection',
        );
        expect(
          ids,
          contains(slide.referenceId),
          reason:
              'featured/${slide.id} points at ${slide.referenceId}, which is '
              'not in the live catalogue. A slide naming a document that does '
              'not exist is a dead front-page card.',
        );
      });
    }
  });

  group('no unsupported or missing type / id', () {
    for (final slide in slides) {
      test('${slide.id} has a usable type and reference', () {
        expect(FeaturedType.values, contains(slide.type));
        expect(slide.referenceId, isNotEmpty);
        expect(slide.titles['en'], isNotNull);
        expect(slide.titles['en'], isNotEmpty);
      });
    }

    test('no slide references the empty flights collection', () {
      // Flights are release-gated Coming Soon and there is no inventory. A
      // flight slide would advertise a product the app cannot sell.
      expect(
        slides.where((s) => s.type == FeaturedType.flight),
        isEmpty,
        reason: 'a flight slide cannot resolve — `flights` has no documents',
      );
    });

    test('orders are unique and ascending', () {
      final orders = [for (final s in slides) s.order];
      expect(orders, orders.toSet().toList(), reason: 'duplicate order');
      final sorted = [...orders]..sort();
      expect(orders, sorted);
    });

    test('ids are unique', () {
      expect(slides.map((s) => s.id).toSet().length, slides.length);
    });
  });

  group('no placeholder content', () {
    for (final name in _placeholders) {
      test('"$name" is not on the front page', () {
        for (final slide in slides) {
          for (final title in slide.titles.values) {
            expect(
              title,
              isNot(contains(name)),
              reason: '$name was removed on 2026-09-15 and must not return',
            );
          }
        }
      });
    }

    test('no slide references a moraine-lake or zagros-camp document', () {
      final refs = [for (final s in slides) s.referenceId];
      expect(refs, isNot(contains('moraine-lake')));
      expect(refs, isNot(contains('zagros-camp')));
      expect(refs, isNot(contains('greenwheels-rentals')));
      expect(refs, isNot(contains('astra-ebl-ist')));
    });

    test('no slide carries an unbacked rating', () {
      // The referenced documents have no rating aggregate — those are
      // server-owned and the Cloud Function is not deployed — so any number
      // here would be invented. Null hides the pill, which is the honest
      // rendering of "not rated yet".
      for (final slide in slides) {
        expect(
          slide.rating,
          isNull,
          reason: '${slide.id} has rating ${slide.rating} with nothing behind it',
        );
      }
    });
  });

  group('the seeder and the bundled fallback stay in sync', () {
    // SEED_DATA.md requires it, and they had silently drifted: the live
    // collection carried `moraine-lake` while the bundled set carried
    // `zagros-camp`, so preview mode and production showed different front
    // pages — and both were broken in different ways.
    final source = File('tool/seed_home_screen.js').readAsStringSync();

    test('the seed script exists and is readable', () {
      expect(source, isNotEmpty);
    });

    for (final slide in slides) {
      test('${slide.referenceId} is seeded too', () {
        expect(
          source,
          contains('referenceId: "${slide.referenceId}"'),
          reason:
              'bundledFeatured() serves ${slide.referenceId} but '
              'tool/seed_home_screen.js does not write it',
        );
      });
    }

    test('the seeder writes no more slides than the bundle serves', () {
      final seeded = RegExp(r'referenceId: "([^"]+)"')
          .allMatches(source)
          .map((m) => m.group(1))
          .toSet();
      expect(seeded, slides.map((s) => s.referenceId).toSet());
    });

    test('the seeder writes no flight slide', () {
      expect(source, isNot(contains('type: "flight"')));
    });
  });

  group('FeaturedItem.fromMap rejects what it cannot draw', () {
    Map<String, dynamic> doc({
      Object? type = 'tour',
      Object? referenceId = 'korek-mountain-day',
      Object? title = const {'en': 'Korek Mountain Day Trip'},
    }) => {
      'type': ?type,
      'referenceId': ?referenceId,
      'title': ?title,
      'order': 1,
    };

    test('a valid document maps', () {
      final item = FeaturedItem.fromMap('a', doc());
      expect(item, isNotNull);
      expect(item!.referenceId, 'korek-mountain-day');
      expect(item.rating, isNull);
    });

    for (final bad in ['restaurant', '', 'Tour', 'nature-spot']) {
      test('an unsupported type "$bad" is dropped', () {
        expect(FeaturedItem.fromMap('a', doc(type: bad)), isNull);
      });
    }

    test('a missing type is dropped', () {
      expect(FeaturedItem.fromMap('a', doc(type: null)), isNull);
    });

    test('a missing or empty referenceId is dropped', () {
      expect(FeaturedItem.fromMap('a', doc(referenceId: null)), isNull);
      expect(FeaturedItem.fromMap('a', doc(referenceId: '')), isNull);
      expect(FeaturedItem.fromMap('a', doc(referenceId: 7)), isNull);
    });

    test('a missing title is dropped rather than drawn blank', () {
      expect(FeaturedItem.fromMap('a', doc(title: null)), isNull);
      expect(FeaturedItem.fromMap('a', doc(title: const {})), isNull);
    });

    test('a null document is dropped', () {
      expect(FeaturedItem.fromMap('a', null), isNull);
    });

    test('one malformed document does not take the others with it', () {
      // The service maps then filters nulls, so a bad slide costs one card,
      // never the whole carousel.
      final mapped = [
        FeaturedItem.fromMap('good', doc()),
        FeaturedItem.fromMap('bad', doc(type: 'restaurant')),
        FeaturedItem.fromMap('good2', doc(referenceId: 'gali-sherana')),
      ].whereType<FeaturedItem>().toList();
      expect(mapped.length, 2);
    });
  });
}
