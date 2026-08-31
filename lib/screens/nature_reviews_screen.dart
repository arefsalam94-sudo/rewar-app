import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/nature_detail.dart';
import '../models/nature_spot.dart';
import '../services/nature_spots_service.dart';
import '../services/user_profile_service.dart';
import '../theme/app_colors.dart';
import '../widgets/glass_back_button.dart';
import '../widgets/glass_panel.dart';
import '../widgets/page_background.dart';
import '../widgets/primary_button.dart';
import '../widgets/recessed_liquid_glass_field.dart';
import '../widgets/sign_in_required.dart';
import 'customize_filters_screen.dart' show exploreNatureBackgroundAsset;

/// Reviews & Ratings for one nature place.
///
/// Opened from the detail screen's review card. Reads
/// `nature_spots/{spotId}/reviews` a page at a time, and writes exactly one
/// document — the viewer's own review, keyed by their uid.
///
/// Every number at the top of this page (`reviewScore`, `ratingCount`,
/// `ratingBreakdown`) is **server-owned**: it lives on the admin-only-write
/// `nature_spots` document and is derived by the `syncNatureReviewAggregates`
/// Cloud Function. The screen never computes an average from the page it
/// downloaded — bars describing ten reviews beside a label reading
/// "128 reviews" would be worse than no bars at all.
class NatureReviewsScreen extends StatefulWidget {
  const NatureReviewsScreen({
    super.key,
    required this.spot,
    this.natureSpotsService,
    this.userProfileService,
    this.isTourReview = false,
    this.backgroundFallbackAsset = exploreNatureBackgroundAsset,
    this.useSubjectPhotoForBackground = true,
  });

  final NatureSpot spot;
  final NatureSpotsService? natureSpotsService;
  final UserProfileService? userProfileService;
  final bool isTourReview;
  final String backgroundFallbackAsset;
  final bool useSubjectPhotoForBackground;

  @override
  State<NatureReviewsScreen> createState() => _NatureReviewsScreenState();
}

class _NatureReviewsScreenState extends State<NatureReviewsScreen> {
  late final NatureSpotsService _service =
      widget.natureSpotsService ?? NatureSpotsService();
  late final UserProfileService _profileService =
      widget.userProfileService ?? UserProfileService();

  /// The spot as last read. Replaced after a post, because the aggregates are
  /// written by a Cloud Function and only exist once the trigger has run.
  late NatureSpot _spot = widget.spot;

  final TextEditingController _comment = TextEditingController();
  final ScrollController _scroll = ScrollController();

  List<NatureReview> _reviews = const <NatureReview>[];
  ReviewSort _sort = ReviewSort.mostRecent;
  Object? _cursor;
  bool _hasMore = false;
  bool _loading = true;
  bool _loadingMore = false;
  bool _submitting = false;
  Object? _error;

  /// 0 means "not chosen yet" — the reference shows an empty row and 0 / 10
  /// before the user picks, and a zero-star review is not a thing we accept.
  double _draftRating = 0;
  String? _draftError;

  /// The viewer's existing review, when they have already written one. Its
  /// presence flips the composer into edit mode, because the document id is
  /// their uid and posting again replaces rather than duplicates.
  NatureReview? _ownReview;
  UserProfile? _profile;

  /// The hero photo's rounded bottom, matching the reference's card-shaped
  /// image. Same 28px card radius as every other surface in the app.
  static const double _heroRadius = 28;
  static const double _heroHeight = 300;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _comment.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await _service.fetchReviewPage(
        spotId: _spot.id,
        sort: _sort,
      );
      final reviews = await _withViewerVotes(page.reviews);
      final own = await _service.fetchViewerReview(_spot.id);
      final profile = _profile ?? await _profileService.fetchProfile();
      if (!mounted) return;
      setState(() {
        _reviews = reviews;
        _cursor = page.cursor;
        _hasMore = page.hasMore;
        _ownReview = own;
        _profile = profile;
        if (own != null && _draftRating == 0) {
          _draftRating = own.rating;
          _comment.text = own.comment;
        }
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final page = await _service.fetchReviewPage(
        spotId: _spot.id,
        sort: _sort,
        startAfter: _cursor,
      );
      final reviews = await _withViewerVotes(page.reviews);
      if (!mounted) return;
      setState(() {
        _reviews = [..._reviews, ...reviews];
        _cursor = page.cursor;
        _hasMore = page.hasMore;
        _loadingMore = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
      _snack(AppLocalizations.of(context).reviewsLoadFailed);
    }
  }

  /// Attaches the viewer's own helpful votes to a freshly-read page.
  ///
  /// A failure here is swallowed on purpose: not knowing which hearts to fill
  /// is a cosmetic problem, and letting it fail the whole page would mean one
  /// unreadable vote hides 128 readable reviews.
  Future<List<NatureReview>> _withViewerVotes(
    List<NatureReview> reviews,
  ) async {
    if (reviews.isEmpty || !_service.isSignedIn) return reviews;
    try {
      final voted = await _service.fetchViewerVotes(
        _spot.id,
        reviews.map((review) => review.id),
      );
      return reviews
          .map(
            (review) =>
                review.copyWith(viewerFoundHelpful: voted.contains(review.id)),
          )
          .toList(growable: false);
    } catch (_) {
      return reviews;
    }
  }

  Future<void> _changeSort(ReviewSort sort) async {
    if (sort == _sort) return;
    setState(() {
      _sort = sort;
      _cursor = null;
    });
    await _load();
  }

  Future<void> _toggleHelpful(NatureReview review) async {
    final l10n = AppLocalizations.of(context);
    if (!_service.isSignedIn) {
      _showSignInSheet(l10n.helpfulSignInBody);
      return;
    }
    final wanted = !review.viewerFoundHelpful;
    final index = _reviews.indexWhere((item) => item.id == review.id);
    if (index < 0) return;

    // Optimistic: the heart fills on the tap, not a round trip later. Reverted
    // below if the write fails, so the UI never keeps a vote the server
    // rejected.
    setState(() {
      _reviews = [..._reviews]
        ..[index] = review.copyWith(
          viewerFoundHelpful: wanted,
          helpfulCount: (review.helpfulCount + (wanted ? 1 : -1)).clamp(
            0,
            1 << 30,
          ),
        );
    });

    try {
      await _service.setHelpful(
        spotId: _spot.id,
        reviewId: review.id,
        helpful: wanted,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        final current = _reviews.indexWhere((item) => item.id == review.id);
        if (current >= 0) _reviews = [..._reviews]..[current] = review;
      });
      _snack(l10n.helpfulFailed);
    }
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    if (!_service.isSignedIn) {
      _showSignInSheet(
        widget.isTourReview ? l10n.tourReviewSignInBody : l10n.reviewSignInBody,
      );
      return;
    }
    final text = _comment.text.trim();
    if (_draftRating <= 0) {
      setState(() => _draftError = l10n.reviewRatingRequired);
      return;
    }
    if (text.length < NatureSpotsService.minCommentLength) {
      setState(() => _draftError = l10n.reviewCommentTooShort);
      return;
    }
    if (text.length > NatureSpotsService.maxCommentLength) {
      setState(() => _draftError = l10n.reviewCommentTooLong);
      return;
    }

    final editing = _ownReview != null;
    setState(() {
      _draftError = null;
      _submitting = true;
    });
    try {
      await _service.submitReview(
        spotId: _spot.id,
        rating: _draftRating,
        comment: text,
        userName: _authorName(l10n),
        avatarUrl: _profile?.profileImageUrl,
      );
      // Re-read the spot as well as the list: the average, the count and the
      // bars are all written by the Cloud Function, so they only change once
      // the trigger has run.
      final refreshed = await _service.fetchSpot(_spot.id);
      if (!mounted) return;
      if (refreshed != null) setState(() => _spot = refreshed);
      await _load();
      if (!mounted) return;
      setState(() => _submitting = false);
      _snack(editing ? l10n.reviewUpdated : l10n.reviewPosted);
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _snack(l10n.reviewPostFailed);
    }
  }

  /// The name printed on the review. Denormalized onto the document on
  /// purpose — a review must keep showing who wrote it even if that account is
  /// later renamed or deleted, the same rule `bookings.display` follows.
  String _authorName(AppLocalizations l10n) {
    final name = _profile?.name.trim();
    if (name != null && name.isNotEmpty) return name;
    return l10n.guestUser;
  }

  void _showSignInSheet(String body) {
    final l10n = AppLocalizations.of(context);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          SignInRequiredSheet(title: l10n.reviewSignInTitle, body: body),
    );
  }

  void _snack(String message) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final language = Localizations.localeOf(context).languageCode;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    final photos = _spot.photos;
    final background =
        widget.useSubjectPhotoForBackground &&
            _spot.photosAreAssets &&
            photos.isNotEmpty
        ? photos.first
        : widget.backgroundFallbackAsset;
    return Scaffold(
      backgroundColor: Colors.transparent,
      // The page background follows DESIGN_SYSTEM.md 4 exactly: the selected
      // place's own photograph, blurred at the shared σ=2, under the theme
      // gradient at 45% — the same treatment the detail screen it opens from
      // uses, so the two read as one flow.
      body: PageBackground(
        imageAsset: background,
        child: SafeArea(
          bottom: false,
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              controller: _scroll,
              padding: EdgeInsets.only(bottom: bottomInset + 28),
              children: [
                _hero(l10n, language),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: _AverageCard(spot: _spot),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          l10n.allReviews,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: AppColors.heading(context),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      _SortControl(current: _sort, onChanged: _changeSort),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _reviewList(l10n),
                ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _composer(l10n),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _hero(AppLocalizations l10n, String language) {
    final photos = _spot.photos;
    return SizedBox(
      height: _heroHeight,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(_heroRadius),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (photos.isEmpty)
                  const _PhotoFallback()
                else
                  _SpotPhoto(
                    source: photos.first,
                    asset: _spot.photosAreAssets,
                  ),
                // Scrim under the title block only. Text drawn straight onto a
                // photograph fails contrast on a bright frame; DESIGN_SYSTEM
                // 19 asks for a local scrim rather than darkening the type.
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [Color(0xB3000000), Color(0x00000000)],
                      stops: [0, 0.55],
                    ),
                  ),
                ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x59000000), Color(0x00000000)],
                      stops: [0, 0.4],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Back button and the page title share one row, as asked. The button
          // stays physically top-left in every language (DESIGN_SYSTEM 11.3),
          // and the title follows it on the same line rather than sitting over
          // the photo further down.
          PositionedDirectional(
            top: 8,
            start: 16,
            end: 16,
            child: Row(
              children: [
                GlassBackButton(onTap: () => Navigator.of(context).maybePop()),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.reviewsAndRatings,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 24,
                      height: 30 / 24,
                      fontWeight: FontWeight.w700,
                      // On the photo, not on glass — white is the semantic
                      // on-photo token in both themes (AppColors docs).
                      color: AppColors.onPhotoBackground,
                    ),
                  ),
                ),
              ],
            ),
          ),
          PositionedDirectional(
            start: 20,
            end: 20,
            bottom: 22,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _spot.name(language),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 28,
                    height: 36 / 28,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onPhotoBackground,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_rounded,
                      size: 18,
                      color: AppColors.onPhotoBackground,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        _spot.locationLabel(language),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          color: AppColors.onPhotoBackground,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _reviewList(AppLocalizations l10n) {
    if (_loading) {
      return GlassPanel(
        borderRadius: 28,
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Center(
          child: CircularProgressIndicator(color: AppColors.accent(context)),
        ),
      );
    }
    if (_error != null) {
      return GlassPanel(
        borderRadius: 28,
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Text(
              l10n.reviewsLoadFailed,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.heading(context)),
            ),
            const SizedBox(height: 12),
            TextButton(onPressed: _load, child: Text(l10n.tryAgain)),
          ],
        ),
      );
    }
    if (_reviews.isEmpty) {
      return GlassPanel(
        borderRadius: 28,
        padding: const EdgeInsets.all(28),
        child: Center(
          child: Text(
            widget.isTourReview ? l10n.tourNoReviewsYet : l10n.noReviewsYet,
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.secondaryText(context)),
          ),
        ),
      );
    }

    return GlassPanel(
      borderRadius: 28,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Column(
        children: [
          for (var index = 0; index < _reviews.length; index++) ...[
            _ReviewTile(
              review: _reviews[index],
              isOwn: _reviews[index].id == _service.currentUid,
              onHelpful: () => _toggleHelpful(_reviews[index]),
            ),
            if (index != _reviews.length - 1)
              Divider(
                height: 1,
                color: AppColors.secondaryText(context).withValues(alpha: 0.22),
              ),
          ],
          if (_hasMore) ...[
            Divider(
              height: 1,
              color: AppColors.secondaryText(context).withValues(alpha: 0.22),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: _loadingMore
                  ? Padding(
                      padding: const EdgeInsets.all(10),
                      child: SizedBox.square(
                        dimension: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: AppColors.accent(context),
                        ),
                      ),
                    )
                  : TextButton(
                      key: const ValueKey('reviews-load-more'),
                      onPressed: _loadMore,
                      child: Text(l10n.loadMoreReviews),
                    ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _composer(AppLocalizations l10n) {
    // A guest is told why, and given a route in — never shown a composer that
    // fails on submit, and never given a local draft that has nowhere to go
    // (`SECURITY.md` 6.1f: no anonymous mirror of signed-in data).
    if (!_service.isSignedIn) {
      return GlassPanel(
        borderRadius: 28,
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.addYourReview,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.heading(context),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(
                  Icons.lock_outline_rounded,
                  color: AppColors.accent(context),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.isTourReview
                        ? l10n.tourReviewSignInBody
                        : l10n.reviewSignInBody,
                    style: TextStyle(color: AppColors.secondaryText(context)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            PrimaryButton(
              label: l10n.logIn,
              onTap: () =>
                  Navigator.of(context).push(SignInRequired.loginRoute()),
            ),
          ],
        ),
      );
    }

    final editing = _ownReview != null;
    return GlassPanel(
      borderRadius: 28,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            editing ? l10n.editYourReview : l10n.addYourReview,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.heading(context),
            ),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final label = Text(
                l10n.yourRating,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  color: AppColors.secondaryText(context),
                ),
              );
              final input = _StarRatingInput(
                value: _draftRating,
                onChanged: (value) => setState(() {
                  _draftRating = value;
                  _draftError = null;
                }),
              );
              final score = _ScoreOutOfTen(score: _draftRating * 2);
              // Label · stars · score on one line when it fits, which is the
              // reference layout; stacked below ~330dp of card, where the row
              // would otherwise squeeze the stars under their tap target.
              // The star row has a fixed width — the tap maths depends on it —
              // so the two text ends are what flex. Below the width where the
              // label would be reduced to an ellipsis, the row stacks instead.
              if (constraints.maxWidth < _StarRatingInput.rowWidth + 150) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(child: label),
                        score,
                      ],
                    ),
                    const SizedBox(height: 6),
                    input,
                  ],
                );
              }
              return Row(
                children: [
                  Flexible(child: label),
                  const SizedBox(width: 10),
                  input,
                  const SizedBox(width: 10),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: AlignmentDirectional.centerEnd,
                      child: score,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          RecessedLiquidGlassField(
            key: const ValueKey('review-comment-field'),
            controller: _comment,
            hint: l10n.reviewCommentHint,
            minLines: 2,
            maxLines: 5,
            maxLength: NatureSpotsService.maxCommentLength,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) {
              if (_draftError != null) setState(() => _draftError = null);
            },
          ),
          if (_draftError != null) ...[
            const SizedBox(height: 8),
            Text(
              _draftError!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 16),
          PrimaryButton(
            label: editing ? l10n.updateReview : l10n.postReview,
            onTap: _submitting ? null : _submit,
          ),
        ],
      ),
    );
  }
}

/// The average score, its stars, the real review count, and the 5→1 bars.
class _AverageCard extends StatelessWidget {
  const _AverageCard({required this.spot});

  final NatureSpot spot;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final score = spot.reviewScore;

    final summary = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          l10n.averageRating,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.heading(context),
          ),
        ),
        const SizedBox(height: 6),
        if (score == null)
          Text(
            l10n.noRatingsYet,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.secondaryText(context),
            ),
          )
        else ...[
          // 44pt digits do not fit the summary column on a narrow phone, and
          // the score is the one number on this page that must never be
          // clipped — so it scales down rather than overflowing.
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: _ScoreOutOfTen(score: score, large: true),
          ),
          const SizedBox(height: 6),
          _StarRow(
            value: NatureSpot.halfStarsForScore(score),
            size: 22,
            color: AppColors.accent(context),
          ),
        ],
        const SizedBox(height: 6),
        Text(
          // The real number, from the server-owned `ratingCount` — never the
          // length of the page that happens to be downloaded.
          l10n.reviewCountLabel(spot.ratingCount),
          style: TextStyle(
            fontSize: 14,
            color: AppColors.secondaryText(context),
          ),
        ),
      ],
    );

    return GlassPanel(
      borderRadius: 28,
      padding: const EdgeInsets.all(18),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final bars = _RatingBars(breakdown: spot.ratingBreakdown);
          // Side by side as drawn; stacked on a narrow card, where the bars
          // would otherwise be too short to read a percentage from.
          if (constraints.maxWidth < 320) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [summary, const SizedBox(height: 16), bars],
            );
          }
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 4, child: summary),
                const SizedBox(width: 12),
                VerticalDivider(
                  width: 1,
                  color: AppColors.secondaryText(
                    context,
                  ).withValues(alpha: 0.28),
                ),
                const SizedBox(width: 12),
                Expanded(flex: 6, child: Center(child: bars)),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// The 5★→1★ distribution bars.
class _RatingBars extends StatelessWidget {
  const _RatingBars({required this.breakdown});

  final RatingBreakdown breakdown;

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.accent(context);
    final track = AppColors.secondaryText(context).withValues(alpha: 0.24);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var star = 5; star >= 1; star--) ...[
          Semantics(
            // One label per bar: a screen reader would otherwise read five
            // bare percentages with nothing to attach them to.
            label: '$star ★ ${(breakdown.fractionFor(star) * 100).round()}%',
            excludeSemantics: true,
            child: Row(
              // A star count, a bar and a percentage are a measurement
              // sequence, which DESIGN_SYSTEM 20 keeps left-to-right in every
              // language — the same rule the rating badges already follow.
              textDirection: TextDirection.ltr,
              children: [
                Text(
                  '$star',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.heading(context),
                  ),
                ),
                const SizedBox(width: 3),
                Icon(Icons.star_rounded, size: 14, color: accent),
                const SizedBox(width: 8),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: breakdown.fractionFor(star),
                      minHeight: 7,
                      backgroundColor: track,
                      valueColor: AlwaysStoppedAnimation<Color>(accent),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 38,
                  child: Text(
                    '${(breakdown.fractionFor(star) * 100).round()}%',
                    textAlign: TextAlign.end,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.secondaryText(context),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (star != 1) const SizedBox(height: 8),
        ],
      ],
    );
  }
}

/// One review row: avatar, name and age, stars and score, comment, heart.
class _ReviewTile extends StatelessWidget {
  const _ReviewTile({
    required this.review,
    required this.isOwn,
    required this.onHelpful,
  });

  final NatureReview review;
  final bool isOwn;
  final VoidCallback onHelpful;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final createdAt = review.createdAt;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: AppColors.accent(context).withValues(alpha: 0.16),
            foregroundImage: (review.avatarUrl?.isNotEmpty ?? false)
                ? NetworkImage(review.avatarUrl!)
                : null,
            child: (review.avatarUrl?.isNotEmpty ?? false)
                ? null
                : Icon(Icons.person_outline, color: AppColors.accent(context)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Flexible(
                      child: Text(
                        review.userName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.heading(context),
                        ),
                      ),
                    ),
                    if (createdAt != null) ...[
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          '· ${l10n.reviewAge(createdAt)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.secondaryText(context),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (isOwn) ...[
                  const SizedBox(height: 2),
                  Text(
                    l10n.yourReviewLabel,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.accent(context),
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Row(
                  children: [
                    _StarRow(
                      value: review.rating,
                      size: 17,
                      color: AppColors.accent(context),
                    ),
                    const SizedBox(width: 8),
                    _ScoreOutOfTen(score: review.scoreOutOfTen, compact: true),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  review.comment,
                  style: TextStyle(
                    fontSize: 14,
                    height: 20 / 14,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white
                        : Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _HelpfulButton(review: review, onTap: onHelpful),
        ],
      ),
    );
  }
}

/// The heart and its count.
class _HelpfulButton extends StatelessWidget {
  const _HelpfulButton({required this.review, required this.onTap});

  final NatureReview review;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final accent = AppColors.accent(context);

    return Semantics(
      button: true,
      label: review.viewerFoundHelpful
          ? l10n.helpfulVoteRemove
          : l10n.helpfulVote,
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: ValueKey('review-helpful-${review.id}'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            // 48dp minimum tap target (DESIGN_SYSTEM 19) even though the icon
            // and its number are smaller than that.
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    review.viewerFoundHelpful
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    size: 22,
                    color: accent,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${review.helpfulCount}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.secondaryText(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The "Most Recent ⌄" control beside the All Reviews heading.
class _SortControl extends StatelessWidget {
  const _SortControl({required this.current, required this.onChanged});

  final ReviewSort current;
  final ValueChanged<ReviewSort> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      button: true,
      label: '${l10n.sortReviewsBy}: ${l10n.reviewSortLabel(current)}',
      excludeSemantics: true,
      child: GlassPanel(
        borderRadius: 999,
        padding: EdgeInsets.zero,
        child: PopupMenuButton<ReviewSort>(
          key: const ValueKey('reviews-sort-button'),
          initialValue: current,
          onSelected: onChanged,
          tooltip: l10n.sortReviewsBy,
          position: PopupMenuPosition.under,
          // The popup is a floating surface, so it inherits the glass system's
          // colours rather than Material's default opaque sheet
          // (DESIGN_SYSTEM 15).
          color: Theme.of(context).brightness == Brightness.dark
              ? AppColors.darkGlassBottom
              : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          itemBuilder: (context) => [
            for (final sort in ReviewSort.values)
              PopupMenuItem<ReviewSort>(
                value: sort,
                child: Text(
                  l10n.reviewSortLabel(sort),
                  style: TextStyle(
                    fontWeight: sort == current
                        ? FontWeight.w700
                        : FontWeight.w400,
                    color: AppColors.heading(context),
                  ),
                ),
              ),
          ],
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      l10n.reviewSortLabel(current),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.heading(context),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: AppColors.heading(context),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A read-only 5-star row that can show halves.
class _StarRow extends StatelessWidget {
  const _StarRow({
    required this.value,
    required this.size,
    required this.color,
  });

  /// 0.0–5.0, in half steps.
  final double value;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    // Star progress stays left-to-right in every language (DESIGN_SYSTEM 20).
    textDirection: TextDirection.ltr,
    children: [
      for (var index = 0; index < 5; index++)
        Icon(_iconFor(index), size: size, color: color),
    ],
  );

  IconData _iconFor(int index) {
    final filled = value - index;
    if (filled >= 1) return Icons.star_rounded;
    if (filled >= 0.5) return Icons.star_half_rounded;
    return Icons.star_outline_rounded;
  }
}

/// The tappable 5-star row in the composer, in half-star steps.
///
/// > **Known accessibility trade-off.** `DESIGN_SYSTEM.md` 19 requires a
/// > 48×48dp hit area per control, and half a star cannot be 48dp wide without
/// > the row running off a phone. Two mitigations, rather than dropping halves
/// > (which would make the design's 7.0 and 9.0 scores unreachable):
/// > the row is 56dp tall and also accepts a horizontal **drag**, so the value
/// > can be landed without hitting a 24dp target; and it exposes slider
/// > semantics with increase/decrease actions, so assistive technology adjusts
/// > it in half steps without touching the geometry at all.
class _StarRatingInput extends StatelessWidget {
  const _StarRatingInput({required this.value, required this.onChanged});

  final double value;
  final ValueChanged<double> onChanged;

  static const double _starSize = 34;
  static const double _slotWidth = 40;
  static const double _rowHeight = 56;

  /// The row's fixed width. Fixed because the tap/drag maths converts a
  /// horizontal offset into a half-star, which only works against a known
  /// slot width — so the surrounding layout flexes around it, not through it.
  static const double rowWidth = _slotWidth * 5;

  void _updateFromOffset(double dx) {
    // Which half-star the pointer is over. Clamped to 0.5 at the bottom: there
    // is no zero-star review, and the rules reject one.
    final raw = (dx / _slotWidth) * 2;
    final halves = raw.ceil().clamp(1, 10);
    onChanged(halves / 2);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final accent = AppColors.accent(context);

    // Flutter requires `increasedValue`/`decreasedValue` alongside `value`
    // whenever the matching action is offered — an assertion, not a lint,
    // because a screen reader announcing a change without saying what it
    // changed to is useless.
    String outOfTen(double stars) =>
        '${(stars.clamp(0.5, 5.0) * 2).toStringAsFixed(1)} / 10';

    return Semantics(
      slider: true,
      label: l10n.yourRating,
      value: outOfTen(value),
      increasedValue: outOfTen(value + 0.5),
      decreasedValue: outOfTen(value - 0.5),
      onIncrease: value >= 5 ? null : () => onChanged(value + 0.5),
      onDecrease: value <= 0.5 ? null : () => onChanged(value - 0.5),
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (details) => _updateFromOffset(details.localPosition.dx),
        onHorizontalDragUpdate: (details) =>
            _updateFromOffset(details.localPosition.dx),
        child: SizedBox(
          height: _rowHeight,
          width: rowWidth,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            // The gesture maths above measures from the left edge, so the row
            // must not mirror in Arabic or Kurdish — and stars stay LTR
            // anyway (DESIGN_SYSTEM 20).
            textDirection: TextDirection.ltr,
            children: [
              for (var index = 0; index < 5; index++)
                SizedBox(
                  width: _slotWidth,
                  child: Icon(
                    _iconFor(index),
                    key: ValueKey('review-star-$index'),
                    size: _starSize,
                    color: accent,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconFor(int index) {
    final filled = value - index;
    if (filled >= 1) return Icons.star_rounded;
    if (filled >= 0.5) return Icons.star_half_rounded;
    return Icons.star_outline_rounded;
  }
}

/// "8.6 / 10" — the number large, the suffix quiet, as the reference draws it.
class _ScoreOutOfTen extends StatelessWidget {
  const _ScoreOutOfTen({
    required this.score,
    this.large = false,
    this.compact = false,
  });

  final double score;
  final bool large;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      // A score is a measurement, not a sentence — LTR in every language.
      textDirection: TextDirection.ltr,
      children: [
        Text(
          score.toStringAsFixed(1),
          style: TextStyle(
            fontSize: large ? 44 : (compact ? 14 : 18),
            height: 1.05,
            fontWeight: FontWeight.w700,
            color: AppColors.heading(context),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          l10n.outOfTen,
          style: TextStyle(
            fontSize: large ? 18 : (compact ? 12 : 14),
            fontWeight: FontWeight.w600,
            color: AppColors.secondaryText(context),
          ),
        ),
      ],
    );
  }
}

class _SpotPhoto extends StatelessWidget {
  const _SpotPhoto({required this.source, required this.asset});
  final String source;
  final bool asset;

  @override
  Widget build(BuildContext context) {
    if (source.isEmpty) return const _PhotoFallback();
    return asset
        ? Image.asset(
            source,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const _PhotoFallback(),
          )
        : Image.network(
            source,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const _PhotoFallback(),
          );
  }
}

class _PhotoFallback extends StatelessWidget {
  const _PhotoFallback();

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: AppColors.accent(context).withValues(alpha: 0.18),
    child: Center(
      child: Icon(
        Icons.landscape_outlined,
        size: 54,
        color: AppColors.accent(context),
      ),
    ),
  );
}
