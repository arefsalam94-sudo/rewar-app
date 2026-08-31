import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kurdistan_paradise_travel_guide/l10n/app_localizations.dart';
import 'package:kurdistan_paradise_travel_guide/models/nature_detail.dart';
import 'package:kurdistan_paradise_travel_guide/models/nature_spot.dart';
import 'package:kurdistan_paradise_travel_guide/screens/nature_reviews_screen.dart';
import 'package:kurdistan_paradise_travel_guide/services/nature_spots_service.dart';
import 'package:kurdistan_paradise_travel_guide/services/user_profile_service.dart';
import 'package:kurdistan_paradise_travel_guide/theme/app_theme.dart';
import 'package:kurdistan_paradise_travel_guide/widgets/glass_back_button.dart';
import 'package:kurdistan_paradise_travel_guide/widgets/page_background.dart';
import 'package:kurdistan_paradise_travel_guide/widgets/primary_button.dart';

/// A spot with the aggregates a real one carries. These are **server-owned**
/// in production — the point of pinning them here is that the screen draws
/// what the document says and never recomputes them from the page it loaded.
const _spot = NatureSpot(
  id: 'bekhal-waterfall',
  names: {'en': 'Bekhal Waterfall', 'ku': 'تاڤگەی بێخاڵ', 'ar': 'شلال بيخال'},
  locationLabels: {
    'en': 'Rawanduz, Kurdistan',
    'ku': 'ڕەواندز، کوردستان',
    'ar': 'رواندوز، كردستان',
  },
  imageAssets: ['assets/images/featured-rawanduz.png'],
  reviewScore: 8.6,
  ratingCount: 128,
  ratingBreakdown: RatingBreakdown({5: 87, 4: 26, 3: 10, 2: 3, 1: 2}),
);

class _FakeReviewsService extends NatureSpotsService {
  _FakeReviewsService({
    this.signedIn = true,
    this.failList = false,
    List<NatureReview>? reviews,
    this.pageSize = 10,
  }) : _reviews = reviews ?? _defaultReviews();

  final bool signedIn;
  final bool failList;
  final int pageSize;
  List<NatureReview> _reviews;

  final Set<String> votes = <String>{};
  int listCalls = 0;
  ReviewSort? lastSort;
  ({double rating, String comment, String userName})? submitted;

  static List<NatureReview> _defaultReviews() {
    final now = DateTime(2026, 8, 15, 12);
    return [
      NatureReview(
        id: 'seed-elena',
        userId: 'seed-elena',
        userName: 'Elena P.',
        comment: 'The view is absolutely stunning!',
        rating: 4.5,
        helpfulCount: 4,
        createdAt: now.subtract(const Duration(hours: 3)),
      ),
      NatureReview(
        id: 'seed-hassan',
        userId: 'seed-hassan',
        userName: 'Hassan S.',
        comment: 'Great place for hiking and photography.',
        rating: 4,
        helpfulCount: 7,
        createdAt: now.subtract(const Duration(days: 1)),
      ),
      NatureReview(
        id: 'seed-priya',
        userId: 'seed-priya',
        userName: 'Priya N.',
        comment: 'Beautiful waterfall and clean area.',
        rating: 3.5,
        helpfulCount: 3,
        createdAt: now.subtract(const Duration(days: 4)),
      ),
    ];
  }

  @override
  String? get currentUid => signedIn ? 'viewer-uid' : null;

  @override
  Future<NatureReviewPage> fetchReviewPage({
    required String spotId,
    ReviewSort sort = ReviewSort.mostRecent,
    Object? startAfter,
  }) async {
    listCalls += 1;
    lastSort = sort;
    if (failList) throw StateError('simulated failure');

    final ordered = [..._reviews];
    switch (sort) {
      case ReviewSort.highestRated:
        ordered.sort((a, b) => b.rating.compareTo(a.rating));
      case ReviewSort.lowestRated:
        ordered.sort((a, b) => a.rating.compareTo(b.rating));
      case ReviewSort.mostHelpful:
        ordered.sort((a, b) => b.helpfulCount.compareTo(a.helpfulCount));
      case ReviewSort.mostRecent:
        break;
    }
    final offset = startAfter is int ? startAfter : 0;
    final page = ordered.skip(offset).take(pageSize).toList();
    final consumed = offset + page.length;
    return NatureReviewPage(
      reviews: page,
      hasMore: consumed < ordered.length,
      cursor: consumed,
    );
  }

  @override
  Future<NatureSpot?> fetchSpot(String spotId) async => _spot;

  @override
  Future<NatureReview?> fetchViewerReview(String spotId) async => null;

  @override
  Future<Set<String>> fetchViewerVotes(
    String spotId,
    Iterable<String> reviewIds,
  ) async => votes.intersection(reviewIds.toSet());

  @override
  Future<void> setHelpful({
    required String spotId,
    required String reviewId,
    required bool helpful,
  }) async {
    if (helpful) {
      votes.add(reviewId);
    } else {
      votes.remove(reviewId);
    }
  }

  @override
  Future<void> submitReview({
    required String spotId,
    required double rating,
    required String comment,
    required String userName,
    String? avatarUrl,
  }) async {
    submitted = (rating: rating, comment: comment, userName: userName);
    _reviews = [
      NatureReview(
        id: 'viewer-uid',
        userId: 'viewer-uid',
        userName: userName,
        comment: comment,
        rating: rating,
        createdAt: DateTime.now(),
      ),
      ..._reviews,
    ];
  }
}

class _FakeProfileService extends UserProfileService {
  @override
  Future<UserProfile?> fetchProfile() async => const UserProfile(
    name: 'Sara Ahmad',
    email: 'sara@example.com',
    phone: null,
    profileImageUrl: null,
    currency: AppCurrency.usd,
  );
}

Future<void> _pump(
  WidgetTester tester, {
  required NatureSpotsService service,
  Locale locale = const Locale('en'),
  ThemeMode themeMode = ThemeMode.light,
  Size size = const Size(420, 1400),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: AppTheme.lightForLocale(locale),
      darkTheme: AppTheme.darkForLocale(locale),
      themeMode: themeMode,
      home: NatureReviewsScreen(
        spot: _spot,
        natureSpotsService: service,
        userProfileService: _FakeProfileService(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('header, place name and location sit on the hero', (
    tester,
  ) async {
    await _pump(tester, service: _FakeReviewsService());

    // The title shares its row with the back button, as specified — not
    // stacked below it and not over the bottom of the photo.
    expect(find.text('Reviews & Ratings'), findsOneWidget);
    expect(find.byType(GlassBackButton), findsOneWidget);
    final backButton = tester.getTopLeft(find.byType(GlassBackButton));
    final title = tester.getTopLeft(find.text('Reviews & Ratings'));
    expect(title.dx, greaterThan(backButton.dx));
    expect((title.dy - backButton.dy).abs(), lessThan(40));

    // Place name as the header at the bottom of the image, location under it.
    expect(find.text('Bekhal Waterfall'), findsOneWidget);
    expect(find.text('Rawanduz, Kurdistan'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Rawanduz, Kurdistan')).dy,
      greaterThan(tester.getTopLeft(find.text('Bekhal Waterfall')).dy),
    );
  });

  testWidgets('the rating badge from the detail hero is NOT drawn here', (
    tester,
  ) async {
    await _pump(tester, service: _FakeReviewsService());

    // 8.6 belongs to the Average Rating card only. If it appeared twice the
    // removed hero badge would have come back.
    expect(find.text('8.6'), findsOneWidget);
  });

  testWidgets('average card shows the server-owned score, count and bars', (
    tester,
  ) async {
    await _pump(tester, service: _FakeReviewsService());

    expect(find.text('Average Rating'), findsOneWidget);
    expect(find.text('8.6'), findsOneWidget);
    // The real count from `ratingCount`, not the three reviews on screen.
    expect(find.text('128 reviews'), findsOneWidget);
    expect(find.text('68%'), findsOneWidget); // 87 / 128
    expect(find.text('20%'), findsOneWidget); // 26 / 128
    expect(find.text('8%'), findsOneWidget); //  10 / 128
    expect(find.text('2%'), findsNWidgets(2)); // 3 and 2 / 128
  });

  testWidgets('draws every review with its author, score and heart count', (
    tester,
  ) async {
    await _pump(tester, service: _FakeReviewsService());

    expect(find.text('Elena P.'), findsOneWidget);
    expect(find.text('Hassan S.'), findsOneWidget);
    expect(find.text('Priya N.'), findsOneWidget);

    // rating × 2, so a half star is a whole point out of ten.
    expect(find.text('9.0'), findsOneWidget);
    expect(find.text('8.0'), findsOneWidget);
    expect(find.text('7.0'), findsOneWidget);

    // Scoped to each heart: a bare find.text('4') also matches the "4 ★" row
    // label in the distribution bars.
    for (final (id, count) in const [
      ('seed-elena', '4'),
      ('seed-hassan', '7'),
      ('seed-priya', '3'),
    ]) {
      expect(
        find.descendant(
          of: find.byKey(ValueKey('review-helpful-$id')),
          matching: find.text(count),
        ),
        findsOneWidget,
      );
    }
  });

  testWidgets('changing the sort re-queries rather than reordering locally', (
    tester,
  ) async {
    final service = _FakeReviewsService();
    await _pump(tester, service: service);
    expect(service.listCalls, 1);
    expect(service.lastSort, ReviewSort.mostRecent);

    await tester.tap(find.byKey(const ValueKey('reviews-sort-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Highest Rated').last);
    await tester.pumpAndSettle();

    // A second read, not a Dart sort of the page already downloaded — sorting
    // a page would rank the newest ten and call them the highest of 128.
    expect(service.listCalls, 2);
    expect(service.lastSort, ReviewSort.highestRated);
  });

  testWidgets('the heart writes a vote and fills optimistically', (
    tester,
  ) async {
    final service = _FakeReviewsService();
    await _pump(tester, service: service);

    await tester.tap(find.byKey(const ValueKey('review-helpful-seed-elena')));
    await tester.pump();

    expect(service.votes, contains('seed-elena'));
    // 4 → 5 without waiting for a round trip.
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('review-helpful-seed-elena')),
        matching: find.text('5'),
      ),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
  });

  testWidgets('posting requires a rating, then a long enough comment', (
    tester,
  ) async {
    final service = _FakeReviewsService();
    await _pump(tester, service: service);

    await tester.ensureVisible(find.text('Post Review'));
    await tester.tap(find.text('Post Review'));
    await tester.pumpAndSettle();
    expect(find.text('Choose a star rating first'), findsOneWidget);
    expect(service.submitted, isNull);

    await tester.tap(find.byKey(const ValueKey('review-star-3')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Post Review'));
    await tester.pumpAndSettle();
    expect(find.text('Write at least 3 characters'), findsOneWidget);
    expect(service.submitted, isNull);
  });

  testWidgets('a valid review is submitted and the page reloads', (
    tester,
  ) async {
    final service = _FakeReviewsService();
    await _pump(tester, service: service);

    // The RIGHT half of the fifth star is a full 5.0 — its centre is the
    // half-star boundary, so tapping dead centre would give 4.5.
    final fifth = tester.getRect(find.byKey(const ValueKey('review-star-4')));
    await tester.tapAt(Offset(fifth.right - 2, fifth.center.dy));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('review-comment-field')),
      'One of the best spots I have visited in Kurdistan.',
    );
    await tester.ensureVisible(find.text('Post Review'));
    await tester.tap(find.text('Post Review'));
    await tester.pumpAndSettle();

    expect(service.submitted, isNotNull);
    // Tapping the right half of the 5th star is a full 5.0.
    expect(service.submitted!.rating, 5.0);
    expect(service.submitted!.userName, 'Sara Ahmad');
    // Reloaded, so the new review is on screen rather than only in the draft.
    expect(service.listCalls, greaterThan(1));
    expect(find.text('Your review'), findsOneWidget);
  });

  testWidgets('the star input lands half stars', (tester) async {
    final service = _FakeReviewsService();
    await _pump(tester, service: service);

    // The left half of the fourth star is 3.5.
    final star = tester.getRect(find.byKey(const ValueKey('review-star-3')));
    await tester.tapAt(Offset(star.left + 2, star.center.dy));
    await tester.pumpAndSettle();
    expect(find.text('7.0'), findsNWidgets(2)); // Priya's, and the draft.
  });

  testWidgets('a guest is asked to sign in instead of shown a composer', (
    tester,
  ) async {
    await _pump(tester, service: _FakeReviewsService(signedIn: false));

    expect(find.text('Post Review'), findsNothing);
    expect(
      find.text(
        'Reviews are tied to your account, so everyone can see who visited.',
      ),
      findsOneWidget,
    );
    expect(find.byType(PrimaryButton), findsOneWidget); // the Log In button
  });

  testWidgets('a load failure is shown with a retry, not thrown', (
    tester,
  ) async {
    await _pump(tester, service: _FakeReviewsService(failList: true));

    expect(find.text("Couldn't load visitor reviews"), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('an unreviewed place is an empty state, not a zero score', (
    tester,
  ) async {
    await _pump(
      tester,
      service: _FakeReviewsService(reviews: const <NatureReview>[]),
    );

    expect(
      find.text('No reviews yet. Be the first to share your visit.'),
      findsOneWidget,
    );
  });

  testWidgets('a second page is fetched rather than everything at once', (
    tester,
  ) async {
    final service = _FakeReviewsService(pageSize: 2);
    await _pump(tester, service: service);

    expect(find.text('Priya N.'), findsNothing);
    await tester.ensureVisible(find.byKey(const ValueKey('reviews-load-more')));
    await tester.tap(find.byKey(const ValueKey('reviews-load-more')));
    await tester.pumpAndSettle();
    expect(find.text('Priya N.'), findsOneWidget);
  });

  testWidgets('renders in Kurdish and Arabic with RTL', (tester) async {
    for (final locale in const [Locale('ku'), Locale('ar')]) {
      await _pump(tester, service: _FakeReviewsService(), locale: locale);
      expect(find.byType(NatureReviewsScreen), findsOneWidget);
      expect(
        Directionality.of(tester.element(find.byType(NatureReviewsScreen))),
        TextDirection.rtl,
      );
      // Localized, not the English fallback.
      expect(find.text('Reviews & Ratings'), findsNothing);
      expect(find.text('All Reviews'), findsNothing);
    }
  });

  testWidgets('the background follows the design system in both themes', (
    tester,
  ) async {
    for (final mode in const [ThemeMode.light, ThemeMode.dark]) {
      await _pump(tester, service: _FakeReviewsService(), themeMode: mode);
      final background = tester.widget<PageBackground>(
        find.byType(PageBackground),
      );
      // The selected place's own photo, at the shared σ=2 and 45% gradient —
      // never a per-screen override (DESIGN_SYSTEM.md 4.3/4.4).
      expect(background.imageAsset, 'assets/images/featured-rawanduz.png');
      expect(background.blurSigma, isNull);
      expect(background.gradientOpacity, isNull);
    }
  });

  testWidgets('every tappable control meets the 48dp minimum', (tester) async {
    await _pump(tester, service: _FakeReviewsService());

    for (final key in const [
      ValueKey('reviews-sort-button'),
      ValueKey('review-helpful-seed-elena'),
    ]) {
      final size = tester.getSize(find.byKey(key));
      expect(size.height, greaterThanOrEqualTo(48), reason: '$key height');
      expect(size.width, greaterThanOrEqualTo(48), reason: '$key width');
    }
  });
}
