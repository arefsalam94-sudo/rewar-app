import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kurdistan_paradise_travel_guide/l10n/app_localizations.dart';
import 'package:kurdistan_paradise_travel_guide/screens/billing_payment_screen.dart';
import 'package:kurdistan_paradise_travel_guide/screens/new_card_screen.dart';
import 'package:kurdistan_paradise_travel_guide/theme/app_colors.dart';
import 'package:kurdistan_paradise_travel_guide/theme/app_theme.dart';
import 'package:kurdistan_paradise_travel_guide/widgets/glass_back_button.dart';
import 'package:kurdistan_paradise_travel_guide/widgets/glass_panel.dart';

void main() {
  group('BillingPaymentScreen — empty state', () {
    testWidgets('draws the supplied copy and unbordered security hints', (
      tester,
    ) async {
      await _pump(tester);

      for (final text in const [
        'Billing & Payments',
        'Current Payment Method',
        'Add a payment method',
        'Save your debit or credit card to pay for hotels, flights, car rentals, and tours.',
        'Your payment information is securely encrypted.',
        'Add Card',
        'Debit or Credit Card',
        'Secure checkout',
      ]) {
        expect(find.text(text), findsOneWidget, reason: text);
      }

      // One panel is the circular back button and one is the payment card.
      // The two bottom hints are plain icon/text rows, not stroked pills.
      expect(find.byType(GlassPanel), findsNWidgets(2));
    });

    testWidgets('puts the title below the physical-left back button', (
      tester,
    ) async {
      await _pump(tester);

      expect(
        tester.getTopLeft(find.text('Billing & Payments')).dy,
        greaterThan(tester.getBottomLeft(find.byType(GlassBackButton)).dy),
      );
      expect(
        tester.getTopLeft(find.byType(GlassBackButton)).dx,
        lessThan(tester.getCenter(find.text('Billing & Payments')).dx),
      );
    });

    testWidgets('uses the required blurred photo and sheen card', (
      tester,
    ) async {
      await _pump(tester);

      final image = tester.widget<Image>(find.byType(Image).first);
      expect(
        (image.image as AssetImage).assetName,
        BillingPaymentScreen.backgroundAsset,
      );
      expect(find.byType(ImageFiltered), findsOneWidget);

      final card = tester
          .widgetList<GlassPanel>(find.byType(GlassPanel))
          .singleWhere((panel) => panel.borderRadius == 28);
      expect(card.depth, GlassDepth.base);
    });

    testWidgets('Add Card calls the hosted-flow hook when supplied', (
      tester,
    ) async {
      var calls = 0;
      await _pump(tester, onAddCard: () => calls++);

      await tester.ensureVisible(find.text('Add Card'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add Card'));
      expect(calls, 1);
    });

    testWidgets('Add Card opens the new-card form without a provider hook', (
      tester,
    ) async {
      await _pump(tester);

      await tester.ensureVisible(find.text('Add Card'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add Card'));
      await tester.pumpAndSettle();
      expect(find.byType(NewCardScreen), findsOneWidget);
      expect(find.text('New Card'), findsOneWidget);
    });

    testWidgets('the back button pops the route', (tester) async {
      await _pump(tester, withHost: true);

      expect(find.byType(BillingPaymentScreen), findsOneWidget);
      await tester.tap(find.byType(GlassBackButton));
      await tester.pumpAndSettle();
      expect(find.byType(BillingPaymentScreen), findsNothing);
    });

    testWidgets('uses the correct dark-mode action and text colours', (
      tester,
    ) async {
      await _pump(tester, dark: true);

      expect(
        tester.widget<Text>(find.text('Billing & Payments')).style!.color,
        Colors.white,
      );
      final button = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Add Card'),
      );
      expect(
        button.style!.backgroundColor!.resolve({}),
        AppColors.luminousMint,
      );
    });

    testWidgets('renders Kurdish and Arabic copy in RTL', (tester) async {
      for (final locale in const [Locale('ku'), Locale('ar')]) {
        await _pump(tester, locale: locale);
        expect(
          Directionality.of(tester.element(find.byType(BillingPaymentScreen))),
          TextDirection.rtl,
        );
        final l10n = AppLocalizations(locale);
        expect(find.text(l10n.currentPaymentMethod), findsOneWidget);
        expect(find.text(l10n.addCard), findsOneWidget);
        expect(find.text(l10n.secureCheckout), findsOneWidget);
      }
    });

    testWidgets('fits a narrow phone and 2x text without overflow', (
      tester,
    ) async {
      await _pump(tester, textScale: 2, size: const Size(320, 900));
      expect(tester.takeException(), isNull);
    });

    testWidgets('draws the saved cards and payment history', (tester) async {
      await _pump(tester, hasSavedMethods: true);

      expect(find.byKey(const Key('saved-payment-methods')), findsOneWidget);
      // The carousel snaps one card per page, so only the visible card is
      // built — the second is reached by swiping, as a user would.
      expect(find.text('Kurdistan International Bank'), findsOneWidget);
      expect(find.text('First Iraqi Bank'), findsNothing);
      await _swipeCarousel(tester);
      expect(find.text('First Iraqi Bank'), findsOneWidget);

      expect(find.text('Payment History'), findsOneWidget);
      expect(find.text('Paid'), findsNWidgets(3));
      expect(find.text('Pending'), findsOneWidget);
      expect(find.text('View Receipt'), findsNWidgets(4));
    });

    testWidgets('the first saved card carries the Default badge', (
      tester,
    ) async {
      await _pump(tester, hasSavedMethods: true);
      expect(find.text('Default'), findsOneWidget);
      await _swipeCarousel(tester);
      expect(find.text('Default'), findsNothing);
    });
  });

  // --- Add / Change / Delete ------------------------------------------------

  group('BillingPaymentScreen — saved card actions', () {
    testWidgets('a second added card is appended, not substituted', (
      tester,
    ) async {
      await _pump(tester, hasSavedMethods: true);

      // Twice per card: once on the mini bank card, once in the info column.
      await _addCardViaForm(tester, number: '4111 1111 1111 1111');
      expect(find.text('•••• 1111'), findsNWidgets(2));

      await _addCardViaForm(tester, number: '5555 5555 5555 4444');
      // The regression this covers: the screen used to hold one
      // `NewCardSummary?`, so the second add erased the first.
      expect(find.text('•••• 4444'), findsNWidgets(2));
      await _swipeCarousel(tester);
      expect(find.text('•••• 1111'), findsNWidgets(2));
    });

    testWidgets('Change moves the Default badge to the chosen card', (
      tester,
    ) async {
      await _pump(tester, hasSavedMethods: true);

      await tester.tap(find.text('Change'));
      await tester.pumpAndSettle();
      expect(find.text('Set default card'), findsOneWidget);

      await tester.tap(find.text('First Iraqi Bank').last);
      await tester.pumpAndSettle();

      // The badge left the first card and followed the selection.
      expect(find.text('Default'), findsNothing);
      await _swipeCarousel(tester);
      expect(find.text('Default'), findsOneWidget);
    });

    testWidgets('Change is disabled while only one card is saved', (
      tester,
    ) async {
      await _pump(tester, hasSavedMethods: true);
      await _deleteVisibleCard(tester);

      await tester.tap(find.text('Change'));
      await tester.pumpAndSettle();
      expect(find.text('Set default card'), findsNothing);
    });

    testWidgets('Delete confirms first, then removes the visible card', (
      tester,
    ) async {
      await _pump(tester, hasSavedMethods: true);

      // Cancelling must leave the card in place.
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(find.text('Delete this card?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Kurdistan International Bank'), findsOneWidget);

      await _deleteVisibleCard(tester);
      // The survivor takes over both the carousel and the Default badge.
      expect(find.text('Kurdistan International Bank'), findsNothing);
      expect(find.text('First Iraqi Bank'), findsOneWidget);
      expect(find.text('Default'), findsOneWidget);
    });

    testWidgets('deleting the last card falls back to the empty state', (
      tester,
    ) async {
      await _pump(tester, hasSavedMethods: true);
      await _deleteVisibleCard(tester);
      await _deleteVisibleCard(tester);

      expect(find.byKey(const Key('saved-payment-methods')), findsNothing);
      expect(find.text('Add a payment method'), findsOneWidget);
    });

    testWidgets('a guest sees the sign-in gate instead of any card', (
      tester,
    ) async {
      await _pump(tester, hasSavedMethods: true, isGuest: true);

      expect(find.text('Sign in to manage payment'), findsOneWidget);
      expect(find.text('Log In'), findsOneWidget);
      // Still the billing screen, so the title and back button remain.
      expect(find.text('Billing & Payments'), findsOneWidget);
      // But nothing account-specific is drawn.
      expect(find.byKey(const Key('saved-payment-methods')), findsNothing);
      expect(find.text('Payment History'), findsNothing);
      expect(find.text('Add Card'), findsNothing);
    });
  });
}

/// Swipes the saved-card carousel on by one page.
Future<void> _swipeCarousel(WidgetTester tester) async {
  await tester.drag(
    find.byKey(const Key('saved-payment-methods')),
    const Offset(-400, 0),
  );
  await tester.pumpAndSettle();
}

/// Deletes whichever card the carousel is showing, confirming the dialog.
Future<void> _deleteVisibleCard(WidgetTester tester) async {
  await tester.tap(find.text('Delete'));
  await tester.pumpAndSettle();
  // Both the action row and the dialog button read "Delete"; the dialog's is
  // the one added last.
  await tester.tap(find.text('Delete').last);
  await tester.pumpAndSettle();
}

/// Runs the real New Card form end to end and returns to Billing.
Future<void> _addCardViaForm(
  WidgetTester tester, {
  required String number,
}) async {
  await tester.tap(find.text('Add'));
  await tester.pumpAndSettle();

  await tester.enterText(find.byType(TextFormField).at(0), 'Aria Salam');
  await tester.enterText(find.byType(TextFormField).at(1), number);
  await tester.enterText(find.byType(TextFormField).at(2), '11/30');
  await tester.enterText(find.byType(TextFormField).at(3), '123');
  await tester.pumpAndSettle();

  await tester.tap(find.byType(DropdownButtonFormField<String>));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Iraq').last);
  await tester.pumpAndSettle();

  // The submit button sits below the fold on a phone-sized viewport, and the
  // form's ListView is lazy, so it has to be scrolled into existence first.
  await tester.scrollUntilVisible(
    find.text('Add Card'),
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Add Card'));
  await tester.pumpAndSettle();
}

Future<void> _pump(
  WidgetTester tester, {
  Locale locale = const Locale('en'),
  bool dark = false,
  double textScale = 1,
  bool withHost = false,
  VoidCallback? onAddCard,
  bool hasSavedMethods = false,
  bool isGuest = false,
  Size size = const Size(393, 1000),
}) async {
  tester.view.physicalSize = size;
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
      builder: (context, child) => MediaQuery.withClampedTextScaling(
        minScaleFactor: textScale,
        maxScaleFactor: textScale,
        child: child!,
      ),
      home: withHost
          ? _PushHost(onAddCard: onAddCard)
          : BillingPaymentScreen(
              onAddCard: onAddCard,
              hasSavedMethods: hasSavedMethods,
              isGuest: isGuest,
            ),
    ),
  );
  await tester.pumpAndSettle();
}

class _PushHost extends StatefulWidget {
  const _PushHost({this.onAddCard});

  final VoidCallback? onAddCard;

  @override
  State<_PushHost> createState() => _PushHostState();
}

class _PushHostState extends State<_PushHost> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => BillingPaymentScreen(onAddCard: widget.onAddCard),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) => const Scaffold();
}
