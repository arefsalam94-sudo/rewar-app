import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kurdistan_paradise_travel_guide/models/help_faq.dart';
import 'package:kurdistan_paradise_travel_guide/models/help_topic.dart';
import 'package:kurdistan_paradise_travel_guide/services/help_topics_service.dart';

/// A `content` map in the DATA_MODEL.md shape.
Map<String, dynamic> doc(Map<String, Object?> content) => {
  'order': 1,
  'active': true,
  'content': content,
};

Map<String, Object?> qa(String q, String a) => {'question': q, 'answer': a};

void main() {
  group('parseQuestions — locale selection', () {
    test('reads the requested locale when present', () {
      final entries = HelpTopicsService.parseQuestions(
        doc({
          'en': {
            'questions': [qa('English?', 'Yes.')],
          },
          'ku': {
            'questions': [qa('Kurdish?', 'Belê.')],
          },
        }),
        'ku',
      );

      expect(entries, hasLength(1));
      expect(entries!.single.question, 'Kurdish?');
    });

    test('falls back to English when the locale is missing', () {
      // The documented rule, same as legal_documents: a missing locale falls
      // back to en rather than showing an empty topic.
      final entries = HelpTopicsService.parseQuestions(
        doc({
          'en': {
            'questions': [qa('English?', 'Yes.')],
          },
        }),
        'ar',
      );

      expect(entries!.single.question, 'English?');
    });

    test('falls back to English for a locale the app does not support', () {
      final entries = HelpTopicsService.parseQuestions(
        doc({
          'en': {
            'questions': [qa('English?', 'Yes.')],
          },
        }),
        'fr',
      );

      expect(entries!.single.answer, 'Yes.');
    });
  });

  group('parseQuestions — empty vs unusable', () {
    test('an empty questions array is preserved, not treated as missing', () {
      // contact_support is seeded exactly this way on purpose. Returning null
      // here would swap in the bundled copy and break its "Coming soon" state.
      final entries = HelpTopicsService.parseQuestions(
        doc({
          'en': {'questions': <Object?>[]},
        }),
        'en',
      );

      expect(entries, isNotNull);
      expect(entries, isEmpty);
    });

    test('returns null when there is no content map at all', () {
      expect(
        HelpTopicsService.parseQuestions({'order': 1, 'active': true}, 'en'),
        isNull,
      );
    });

    test('returns null when content is not a map', () {
      expect(
        HelpTopicsService.parseQuestions({'content': 'nope'}, 'en'),
        isNull,
      );
    });

    test('returns null when no usable locale block exists', () {
      expect(
        HelpTopicsService.parseQuestions(
          doc({
            'ku': {
              'questions': [qa('K?', 'B.')],
            },
          }),
          'ar',
        ),
        isNull,
        reason: 'no ar and no en means nothing to show — fall back to bundled',
      );
    });

    test('returns null when questions is not a list', () {
      expect(
        HelpTopicsService.parseQuestions(
          doc({
            'en': {'questions': 'nope'},
          }),
          'en',
        ),
        isNull,
      );
    });
  });

  group('parseQuestions — malformed entries are skipped, not fatal', () {
    test('drops entries with a missing or non-string field', () {
      final entries = HelpTopicsService.parseQuestions(
        doc({
          'en': {
            'questions': [
              qa('Good?', 'Yes.'),
              {'question': 'No answer'},
              {'answer': 'No question'},
              {'question': 42, 'answer': 'Wrong type'},
              'not a map',
              qa('Also good?', 'Also yes.'),
            ],
          },
        }),
        'en',
      );

      // One bad row from the admin panel must not blank the whole topic.
      expect(entries, hasLength(2));
      expect(entries!.map((e) => e.question), ['Good?', 'Also good?']);
    });

    test('drops entries that are blank or whitespace only', () {
      final entries = HelpTopicsService.parseQuestions(
        doc({
          'en': {
            'questions': [
              qa('', 'Answer with no question'),
              qa('Question with no answer', '   '),
              qa('Real?', 'Real.'),
            ],
          },
        }),
        'en',
      );

      expect(entries, hasLength(1));
      expect(entries!.single.question, 'Real?');
    });
  });

  group('bundled fallback', () {
    test('is used when Firebase is unavailable', () async {
      // FirebaseBootstrap is never initialised under flutter test, so this
      // exercises the real fallback path end to end through the public API.
      final service = HelpTopicsService();
      final content = await service.fetchTopic(HelpTopic.account, 'en');

      expect(content.fromFirestore, isFalse);
      expect(content.questions, isNotEmpty);
      expect(content.questions, bundledHelpFaqsFor(HelpTopic.account));
    });

    test('preserves the empty contact topic', () async {
      final service = HelpTopicsService();
      final content = await service.fetchTopic(HelpTopic.contact, 'en');

      expect(content.questions, isEmpty);
    });

    test('covers every topic in the enum', () async {
      final service = HelpTopicsService();
      for (final topic in HelpTopic.values) {
        final content = await service.fetchTopic(topic, 'en');
        expect(
          content.questions,
          bundledHelpFaqsFor(topic),
          reason: '${topic.docId} lost its bundled fallback',
        );
      }
    });

    test('a repeated fetch is served from cache', () async {
      final service = HelpTopicsService();
      final first = await service.fetchTopic(HelpTopic.flights, 'en');
      final second = await service.fetchTopic(HelpTopic.flights, 'en');

      expect(identical(first, second), isTrue);

      service.clearCache();
      final third = await service.fetchTopic(HelpTopic.flights, 'en');
      expect(identical(first, third), isFalse);
    });
  });

  group('the seeded documents parse back to the bundled content', () {
    // tool/help_topics_seed.json is what tool/seed_help_topics.js wrote to
    // Firestore. Running it back through the app's own parser is what proves
    // the seed shape and the reader agree — a mismatch here would show up in
    // production as a silently empty help topic.
    late final Map<String, dynamic> seeded;

    setUpAll(() {
      final file = File('tool/help_topics_seed.json');
      expect(
        file.existsSync(),
        isTrue,
        reason: 'run: dart run tool/export_help_topics.dart',
      );
      seeded = (jsonDecode(file.readAsStringSync()) as Map<String, dynamic>)
        ..removeWhere((key, _) => key.startsWith('_'));
    });

    test('every HelpTopic id is present exactly once', () {
      expect(
        seeded.keys.toSet(),
        HelpTopic.values.map((t) => t.docId).toSet(),
      );
    });

    test('each seeded document parses to its bundled questions', () {
      for (final topic in HelpTopic.values) {
        final parsed = HelpTopicsService.parseQuestions(
          Map<String, dynamic>.from(seeded[topic.docId] as Map),
          'en',
        );
        final bundled = bundledHelpFaqsFor(topic);

        expect(parsed, isNotNull, reason: '${topic.docId} did not parse');
        expect(
          parsed!.map((e) => e.question).toList(),
          bundled.map((e) => e.question).toList(),
          reason: '${topic.docId} questions drifted from the bundled copy',
        );
        expect(
          parsed.map((e) => e.answer).toList(),
          bundled.map((e) => e.answer).toList(),
          reason: '${topic.docId} answers drifted from the bundled copy',
        );
      }
    });

    test('orders are 1..10 with no duplicates', () {
      final orders = seeded.values
          .map((t) => (t as Map)['order'] as int)
          .toList()
        ..sort();
      expect(orders, List<int>.generate(HelpTopic.values.length, (i) => i + 1));
    });

    test('every seeded topic is active and has an en block', () {
      for (final entry in seeded.entries) {
        final topic = entry.value as Map;
        expect(topic['active'], isTrue, reason: entry.key);
        expect((topic['content'] as Map)['en'], isNotNull, reason: entry.key);
      }
    });
  });

  test('the collection name matches DATA_MODEL.md', () {
    expect(HelpTopicsService.collection, 'help_topics');
    expect(HelpTopicsService.fallbackLocale, 'en');
    expect(HelpTopicsService.supportedLocales, ['en', 'ku', 'ar']);
  });
}
