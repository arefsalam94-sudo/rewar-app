import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurdistan_paradise_travel_guide/l10n/app_localizations.dart';
import 'package:kurdistan_paradise_travel_guide/models/favorite_item.dart';
import 'package:kurdistan_paradise_travel_guide/screens/favorites_category_screen.dart';
import 'package:kurdistan_paradise_travel_guide/screens/favorites_screen.dart';
import 'package:kurdistan_paradise_travel_guide/services/favorites_service.dart';
import 'package:kurdistan_paradise_travel_guide/theme/app_theme.dart';
import 'package:kurdistan_paradise_travel_guide/widgets/sign_in_required.dart';

void main() {
  group('Favorites screen', () {
    testWidgets('lists both sections with their counts', (tester) async {
      await _pump(
        tester,
        service: _FakeFavoritesService(
          items: [
            _stay('divan', 'Divan Erbil', 'Erbil, Iraq'),
            _stay('ramada', 'Ramada Sulaimani', 'Sulaimani, Iraq'),
            _nature('bekhal', 'Bekhal Waterfall', 'Rawanduz, Kurdistan'),
          ],
        ),
      );

      expect(find.text('Favorites'), findsOneWidget);
      expect(find.text('3 Favorites'), findsOneWidget);

      expect(find.text('Where to Stay'), findsOneWidget);
      expect(find.text('Explore Nature'), findsOneWidget);
      // Two stays, one nature spot — counted per section, not overall.
      expect(find.text('2 options'), findsOneWidget);
      expect(find.text('1 option'), findsOneWidget);

      expect(find.text('Divan Erbil'), findsOneWidget);
      expect(find.text('Bekhal Waterfall'), findsOneWidget);
      expect(find.text('Rawanduz, Kurdistan'), findsOneWidget);
    });

    testWidgets('a section previews four rows and hides the rest behind '
        'View all', (tester) async {
      await _pump(
        tester,
        service: _FakeFavoritesService(
          items: [
            for (var i = 0; i < 6; i++) _nature('spot-$i', 'Spot $i', 'Erbil'),
          ],
        ),
      );

      for (var i = 0; i < FavoritesService.sectionPreviewCount; i++) {
        expect(find.text('Spot $i'), findsOneWidget);
      }
      // The fifth and sixth are not drawn on the section card.
      expect(find.text('Spot 4'), findsNothing);
      expect(find.text('Spot 5'), findsNothing);

      expect(find.text('6 options'), findsOneWidget);
      expect(find.text('View all'), findsOneWidget);
    });

    testWidgets('View all is not offered when the preview already shows '
        'everything', (tester) async {
      await _pump(
        tester,
        service: _FakeFavoritesService(
          items: [
            _nature('a', 'Alpha', 'Erbil'),
            _nature('b', 'Beta', 'Erbil'),
          ],
        ),
      );

      // A "View all" that opens the same two rows is a dead end.
      expect(find.text('View all'), findsNothing);
    });

    testWidgets('View all opens the full list for that category', (
      tester,
    ) async {
      await _pump(
        tester,
        service: _FakeFavoritesService(
          items: [
            for (var i = 0; i < 6; i++) _nature('spot-$i', 'Spot $i', 'Erbil'),
          ],
        ),
      );

      // Six rows push the section's footer below the fold on a test-sized
      // viewport, so scroll it into view before tapping it.
      await tester.ensureVisible(find.text('View all'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('View all'));
      await tester.pumpAndSettle();

      expect(find.byType(FavoritesCategoryScreen), findsOneWidget);
      // The whole category, not just the preview — its list is lazy, so the
      // last row is reached by scrolling rather than asserted in place.
      expect(find.text('6 options'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Spot 5'), 200);
      expect(find.text('Spot 5'), findsOneWidget);
    });

    testWidgets('tapping a filled heart removes the row and offers Undo', (
      tester,
    ) async {
      final service = _FakeFavoritesService(
        items: [
          _nature('bekhal', 'Bekhal Waterfall', 'Rawanduz'),
          _nature('gali', 'Gali Ali Bag', 'Rawanduz'),
        ],
      );
      await _pump(tester, service: service);

      expect(find.text('Bekhal Waterfall'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.favorite_rounded).first);
      await tester.pumpAndSettle();

      expect(service.removed, ['bekhal']);
      // Gone from the list straight away, not after the write returns.
      expect(find.text('Bekhal Waterfall'), findsNothing);
      expect(find.text('Removed from your favourites'), findsOneWidget);
      expect(find.text('Undo'), findsOneWidget);
    });

    testWidgets('Undo puts the row back', (tester) async {
      final service = _FakeFavoritesService(
        items: [_nature('bekhal', 'Bekhal Waterfall', 'Rawanduz')],
      );
      await _pump(tester, service: service);

      await tester.tap(find.byIcon(Icons.favorite_rounded).first);
      await tester.pumpAndSettle();
      expect(find.text('Bekhal Waterfall'), findsNothing);

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();

      expect(service.restored, ['bekhal']);
      expect(find.text('Bekhal Waterfall'), findsOneWidget);
    });

    testWidgets('a guest is asked to sign in rather than shown an empty list', (
      tester,
    ) async {
      await _pump(
        tester,
        isGuest: true,
        service: _FakeFavoritesService(items: const []),
      );

      expect(find.byType(SignInRequired), findsOneWidget);
      expect(find.text('Sign in to see your favourites'), findsOneWidget);
      // The count line is hidden — "0 Favorites" beside a sign-in prompt would
      // read as "you have saved nothing".
      expect(find.textContaining('Favorites'), findsOneWidget);
    });

    testWidgets('an empty list explains how to fill it', (tester) async {
      await _pump(tester, service: _FakeFavoritesService(items: const []));

      expect(find.text('Nothing saved yet'), findsOneWidget);
      expect(find.text('0 Favorites'), findsOneWidget);
      // The footer is always drawn, as in the reference.
      expect(find.text('Keep exploring'), findsOneWidget);
    });

    testWidgets('the Keep exploring footer is drawn below a filled list too', (
      tester,
    ) async {
      await _pump(
        tester,
        service: _FakeFavoritesService(
          items: [_stay('divan', 'Divan Erbil', 'Erbil')],
        ),
      );

      expect(find.text('Keep exploring'), findsOneWidget);
      expect(find.text('Your next adventure is waiting.'), findsOneWidget);
    });

    testWidgets('a failed read shows the error state and can be retried', (
      tester,
    ) async {
      final service = _FakeFavoritesService(items: const [], failFirst: true);
      await _pump(tester, service: service);

      expect(find.text("Couldn't load your favourites"), findsOneWidget);

      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(find.text("Couldn't load your favourites"), findsNothing);
      expect(find.text('Nothing saved yet'), findsOneWidget);
    });

    testWidgets('a legacy row of a removed type is skipped, not fatal', (
      tester,
    ) async {
      // `car`, `tour` and `flight` favourites can still exist from before the
      // heart was consolidated. The screen has no section for them.
      final parsed = FavoriteItem.fromMap('uid_tour_x', {
        'itemType': 'tour',
        'itemId': 'x',
        'title': {'en': 'An old saved tour'},
      });
      expect(parsed, isNull);

      await _pump(
        tester,
        service: _FakeFavoritesService(
          items: [_nature('bekhal', 'Bekhal Waterfall', 'Rawanduz')],
        ),
      );
      expect(find.text('Bekhal Waterfall'), findsOneWidget);
    });

    testWidgets('renders in dark mode', (tester) async {
      await _pump(
        tester,
        dark: true,
        service: _FakeFavoritesService(
          items: [_stay('divan', 'Divan Erbil', 'Erbil')],
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Divan Erbil'), findsOneWidget);
    });

    testWidgets('renders in Arabic', (tester) async {
      await _pump(
        tester,
        locale: const Locale('ar'),
        service: _FakeFavoritesService(
          items: [_nature('bekhal', 'شلال بيخال', 'راوندوز')],
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('المفضّلة'), findsOneWidget);
      // The snapshot's Arabic entry, not the English fallback.
      expect(find.text('شلال بيخال'), findsOneWidget);
    });
  });

  group('FavoriteSnapshot', () {
    test('omits an empty place line rather than writing an empty map', () {
      // The rules reject an empty locale map, so sending `{}` would have the
      // whole save denied instead of the row simply drawing without the line.
      const snapshot = FavoriteSnapshot(
        titles: {'en': 'Somewhere'},
        locationLabels: {},
      );

      expect(snapshot.toMap().containsKey('locationLabel'), isFalse);
      expect(snapshot.toMap()['title'], {'en': 'Somewhere'});
    });

    test('an asset path and a URL are told apart by the row', () {
      expect(
        _nature('a', 'A', 'B', image: 'assets/images/x.webp').imageIsAsset,
        isTrue,
      );
      expect(
        _nature('a', 'A', 'B', image: 'https://example.com/x.jpg').imageIsAsset,
        isFalse,
      );
    });
  });
}

// --- Helpers -----------------------------------------------------------------

FavoriteItem _stay(String id, String title, String location) => FavoriteItem(
  id: 'uid_hotel_$id',
  category: FavoriteCategory.stay,
  itemId: id,
  titles: {'en': title},
  locationLabels: {'en': location},
);

FavoriteItem _nature(
  String id,
  String title,
  String location, {
  String? image,
}) => FavoriteItem(
  id: 'uid_nature_spot_$id',
  category: FavoriteCategory.nature,
  itemId: id,
  titles: {'en': title, 'ar': title},
  locationLabels: {'en': location, 'ar': location},
  imageRef: image,
);

Future<void> _pump(
  WidgetTester tester, {
  required _FakeFavoritesService service,
  bool isGuest = false,
  bool dark = false,
  Locale locale = const Locale('en'),
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      theme: AppTheme.lightForLocale(locale),
      darkTheme: AppTheme.darkForLocale(locale),
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      home: FavoritesScreen(isGuest: isGuest, service: service),
    ),
  );
  await tester.pumpAndSettle();
}

class _FakeFavoritesService extends FavoritesService {
  _FakeFavoritesService({
    required List<FavoriteItem> items,
    this.failFirst = false,
  }) : _items = List<FavoriteItem>.of(items);

  List<FavoriteItem> _items;
  bool failFirst;

  final List<String> removed = [];
  final List<String> restored = [];

  @override
  bool get hasViewer => true;

  @override
  Future<List<FavoriteItem>> fetchFavorites() async {
    if (failFirst) {
      failFirst = false;
      throw StateError('permission-denied');
    }
    return List<FavoriteItem>.of(_items);
  }

  @override
  Future<void> remove(FavoriteItem item) async {
    removed.add(item.itemId);
    _items = _items.where((other) => other.id != item.id).toList();
  }

  @override
  Future<void> restore(FavoriteItem item) async {
    restored.add(item.itemId);
    _items = [item, ..._items];
  }
}
