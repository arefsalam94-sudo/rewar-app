import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kurdistan_paradise_travel_guide/l10n/app_localizations.dart';
import 'package:kurdistan_paradise_travel_guide/screens/new_card_screen.dart';
import 'package:kurdistan_paradise_travel_guide/theme/app_theme.dart';

void main() {
  testWidgets('shows the complete localized card form', (tester) async {
    await _pump(tester);

    for (final text in const [
      'New Card',
      'Add a card for faster checkout on future bookings.',
      'Card Details',
      'Cardholder Name',
      'Card Number',
      'Expiry Date',
      'CVV',
      'Country',
      'ZIP Code',
      'Save this card for future bookings',
    ]) {
      expect(
        find.text(text),
        text == 'Cardholder Name' ? findsNWidgets(2) : findsOneWidget,
        reason: text,
      );
    }

    // The form lives in a lazy ListView, so the submit button at its foot is
    // only built once it is scrolled into view.
    await tester.scrollUntilVisible(
      find.text('Add Card'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Add Card'), findsOneWidget);
  });

  testWidgets('updates the card preview while typing', (tester) async {
    await _pump(tester);

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Sara Ahmad');
    await tester.enterText(fields.at(1), '1234567890123456');
    await tester.pump();

    expect(find.text('SARA AHMAD'), findsOneWidget);
    expect(find.text('1234 5678 9012 3456'), findsNWidgets(2));
  });

  testWidgets('renders Arabic and Kurdish in RTL', (tester) async {
    for (final locale in const [Locale('ar'), Locale('ku')]) {
      await _pump(tester, locale: locale);
      expect(
        Directionality.of(tester.element(find.byType(NewCardScreen))),
        TextDirection.rtl,
      );
      final l10n = AppLocalizations(locale);
      expect(find.text(l10n.newCard), findsOneWidget);
      expect(find.text(l10n.cardDetails), findsOneWidget);
    }
  });
}

Future<void> _pump(
  WidgetTester tester, {
  Locale locale = const Locale('en'),
}) async {
  tester.view.physicalSize = const Size(393, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      theme: AppTheme.lightForLocale(locale),
      home: const NewCardScreen(),
    ),
  );
  await tester.pumpAndSettle();
}
