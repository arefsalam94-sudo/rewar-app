import 'package:flutter_test/flutter_test.dart';
import 'package:kurdistan_paradise_travel_guide/models/nature_detail.dart';
import 'package:kurdistan_paradise_travel_guide/services/hotel_reviews_service.dart';

/// The seeded preview hotel: three reviews, 5 / 4 / 4.5 stars.
const _divan = 'preview-divan-erbil';

void main() {
  test('the aggregate is derived from the reviews, never hand-set', () {
    final aggregate = PreviewHotelReviewService.aggregateFor(_divan);
    expect(aggregate.count, 3);
    // (10 + 8 + 9) / 3 on the 0-10 scale.
    expect(aggregate.score, closeTo(9.0, 0.001));
    expect(aggregate.breakdown.total, 3);
  });

  test('a hotel with no reviews reports no score rather than zero', () {
    final aggregate = PreviewHotelReviewService.aggregateFor('nothing-here');
    expect(aggregate.count, 0);
    expect(aggregate.score, isNull);
    expect(aggregate.breakdown.isEmpty, isTrue);
  });

  test('the detail card gets the two newest reviews', () async {
    final service = PreviewHotelReviewService();
    final reviews = await service.fetchTopReviews(_divan);
    expect(reviews.length, 2);
    expect(reviews.first.createdAt!.isAfter(reviews.last.createdAt!), isTrue);
  });

  test('sorting is applied to the whole list, not to one page', () async {
    final service = PreviewHotelReviewService();
    final highest = await service.fetchReviewPage(
      spotId: _divan,
      sort: ReviewSort.highestRated,
    );
    final lowest = await service.fetchReviewPage(
      spotId: _divan,
      sort: ReviewSort.lowestRated,
    );
    expect(highest.reviews.first.rating, 5);
    expect(lowest.reviews.first.rating, 4);
    expect(highest.hasMore, isFalse);
  });

  test('posting twice edits the same review instead of stacking one', () async {
    final service = PreviewHotelReviewService();
    const hotel = 'test-hotel-edit';

    await service.submitReview(
      spotId: hotel,
      rating: 4,
      comment: 'First',
      userName: 'Viewer',
    );
    await service.submitReview(
      spotId: hotel,
      rating: 5,
      comment: 'Second',
      userName: 'Viewer',
    );

    final page = await service.fetchReviewPage(spotId: hotel);
    expect(page.reviews.length, 1);
    expect(page.reviews.single.comment, 'Second');
    expect((await service.fetchViewerReview(hotel))?.rating, 5);
  });

  test('a helpful vote is recorded once and can be taken back', () async {
    final service = PreviewHotelReviewService();
    const hotel = 'test-hotel-votes';
    await service.submitReview(
      spotId: hotel,
      rating: 4,
      comment: 'Vote on me',
      userName: 'Viewer',
    );
    final id = (await service.fetchViewerReview(hotel))!.id;

    await service.setHelpful(spotId: hotel, reviewId: id, helpful: true);
    expect(await service.fetchViewerVotes(hotel, <String>[id]), <String>{id});

    await service.setHelpful(spotId: hotel, reviewId: id, helpful: false);
    expect(await service.fetchViewerVotes(hotel, <String>[id]), isEmpty);
    final page = await service.fetchReviewPage(spotId: hotel);
    // Never negative, whatever order the votes arrive in.
    expect(page.reviews.single.helpfulCount, 0);
  });
}
