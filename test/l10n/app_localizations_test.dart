import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurdistan_paradise_travel_guide/l10n/app_localizations.dart';

void main() {
  const kurdish = AppLocalizations(Locale('ku'));

  test('Kurdish month names follow the approved Sorani terminology', () {
    expect(
      List<String>.generate(12, (index) => kurdish.monthName(index + 1)),
      const <String>[
        'کانوونی دووەم',
        'شوبات',
        'ئازار',
        'نیسان',
        'ئایار',
        'حوزەیران',
        'تەمموز',
        'ئاب',
        'ئەیلوول',
        'تشرینی یەکەم',
        'تشرینی دووەم',
        'کانوونی یەکەم',
      ],
    );
  });

  test(
    'Kurdish day and month counts use the approved singular/plural terms',
    () {
      expect(kurdish.carRentalDays(1), '١ ڕۆژی کرێ');
      expect(kurdish.carRentalDays(3), 'کرێی 3 ڕۆژان');
      expect(kurdish.tourDuration(1), 'گەشتی 1 ڕۆژ');
      expect(kurdish.tourDuration(3), 'گەشتی 3 ڕۆژان');

      final now = DateTime(2026, 9, 1);
      expect(
        kurdish.reviewAge(now.subtract(const Duration(days: 3)), now: now),
        'لەمەوبەر 3 ڕۆژان',
      );
      expect(
        kurdish.reviewAge(now.subtract(const Duration(days: 61)), now: now),
        'لەمەوبەر 2 مانگەکان',
      );
    },
  );

  testWidgets('Kurdish Material calendars use Sorani weekdays and months', (
    tester,
  ) async {
    late MaterialLocalizations material;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ku'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Builder(
          builder: (context) {
            material = MaterialLocalizations.of(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(material.firstDayOfWeekIndex, 6); // Saturday.
    expect(material.formatMonthYear(DateTime(2026, 7)), contains('تەمموز'));
    expect(material.formatFullDate(DateTime(2026, 8, 29)), contains('شەممە'));
    expect(
      material.formatFullDate(DateTime(2026, 8, 30)),
      contains('یەکشەممە'),
    );
    expect(
      material.formatFullDate(DateTime(2026, 8, 31)),
      contains('دووشەممە'),
    );
    expect(material.formatFullDate(DateTime(2026, 9, 1)), contains('سێشەممە'));
    expect(
      material.formatFullDate(DateTime(2026, 9, 2)),
      contains('چوارشەممە'),
    );
    expect(
      material.formatFullDate(DateTime(2026, 9, 3)),
      contains('پێنجشەممە'),
    );
    expect(material.formatFullDate(DateTime(2026, 9, 4)), contains('هەینی'));
  });
}
