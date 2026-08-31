import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kurdistan_paradise_travel_guide/l10n/app_localizations.dart';
import 'package:kurdistan_paradise_travel_guide/models/nature_detail.dart';
import 'package:kurdistan_paradise_travel_guide/models/tour.dart';
import 'package:kurdistan_paradise_travel_guide/screens/tour_assets.dart';
import 'package:kurdistan_paradise_travel_guide/screens/tour_reviews_screen.dart';
import 'package:kurdistan_paradise_travel_guide/services/tours_service.dart';
import 'package:kurdistan_paradise_travel_guide/services/user_profile_service.dart';
import 'package:kurdistan_paradise_travel_guide/theme/app_theme.dart';
import 'package:kurdistan_paradise_travel_guide/widgets/page_background.dart';

void main() {
  const tour = Tour(
    id: 'tour-review-test',
    names: {'en': 'Gali Alibag Tour'},
    locationLabels: {'en': 'Rawanduz, Erbil'},
  );

  testWidgets('uses tour copy, tour data, and the tour background', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightForLocale(const Locale('en')),
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: TourReviewsScreen(
          tour: tour,
          toursService: _EmptyTourReviewsService(),
          userProfileService: _EmptyProfileService(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Gali Alibag Tour'), findsOneWidget);
    expect(find.text('Rawanduz, Erbil'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -900));
    await tester.pump();
    expect(
      find.text(
        'Tour reviews are tied to your account, so travellers can trust who joined.',
      ),
      findsOneWidget,
    );
    final background = tester.widget<PageBackground>(
      find.byType(PageBackground),
    );
    expect(background.imageAsset, exploreToursBackgroundAsset);
  });
}

class _EmptyTourReviewsService extends ToursService {
  @override
  String? get currentUid => null;

  @override
  Future<NatureReviewPage> fetchReviewPage({
    required String tourId,
    ReviewSort sort = ReviewSort.mostRecent,
    Object? startAfter,
  }) async => NatureReviewPage.empty;

  @override
  Future<NatureReview?> fetchViewerReview(String tourId) async => null;
}

class _EmptyProfileService extends UserProfileService {
  @override
  Future<UserProfile?> fetchProfile() async => null;
}
