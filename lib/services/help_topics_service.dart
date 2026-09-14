import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/help_faq.dart';
import '../models/help_topic.dart';
import 'firebase_bootstrap.dart';

/// The resolved content for one Help & Support row.
class HelpTopicContent {
  const HelpTopicContent({
    required this.questions,
    required this.fromFirestore,
  });

  final List<HelpFaqEntry> questions;

  /// True when this came from `help_topics`, false when it is the bundled
  /// fallback. Exposed for tests and diagnostics — the screen draws both the
  /// same way, because a user should never be shown plumbing.
  final bool fromFirestore;
}

/// Loads Help & Support Q&A from `help_topics` (DATA_MODEL.md), falling back
/// to the bundled English copy in [bundledHelpFaqs].
///
/// Public read, admin-only write (`firestore.rules`) — someone who cannot sign
/// in is exactly the person who needs the help centre.
///
/// ## Why this falls back instead of throwing
///
/// [LegalDocumentService] deliberately throws rather than showing bundled
/// text, because consent must be recorded against the *current* wording. Help
/// content carries no such obligation: a slightly stale answer is far better
/// than an error page in front of someone already stuck. So every failure
/// path here — Firebase absent, document missing, network down, malformed
/// data — lands on the bundled copy.
class HelpTopicsService {
  HelpTopicsService({FirebaseFirestore? firestore})
    : _firestoreOverride = firestore;

  final FirebaseFirestore? _firestoreOverride;

  FirebaseFirestore get _firestore =>
      _firestoreOverride ?? FirebaseFirestore.instance;

  static const String collection = 'help_topics';

  /// Locales the schema supports. A locale outside this set, or one with no
  /// content, falls back to English — the same rule as `legal_documents`.
  static const List<String> supportedLocales = ['en', 'ku', 'ar'];
  static const String fallbackLocale = 'en';

  /// Resolved topics, so expanding the same row twice costs one read rather
  /// than two. Firestore bills per document read and this collection changes
  /// rarely; a process-lifetime cache is the right trade.
  final Map<String, HelpTopicContent> _cache = {};

  @visibleForTesting
  void clearCache() => _cache.clear();

  /// Fetches the Q&A for [topic] in [languageCode].
  Future<HelpTopicContent> fetchTopic(
    HelpTopic topic,
    String languageCode,
  ) async {
    final key = '${topic.docId}:$languageCode';
    final cached = _cache[key];
    if (cached != null) return cached;

    final resolved = await _load(topic, languageCode);
    _cache[key] = resolved;
    return resolved;
  }

  Future<HelpTopicContent> _load(HelpTopic topic, String languageCode) async {
    if (!FirebaseBootstrap.isReady) {
      return _bundled(topic);
    }

    try {
      final snapshot = await _firestore
          .collection(collection)
          .doc(topic.docId)
          .get();

      if (!snapshot.exists) {
        debugPrint(
          '$collection/${topic.docId} is not seeded — using bundled content.',
        );
        return _bundled(topic);
      }

      final data = snapshot.data();
      if (data == null) return _bundled(topic);

      // `active: false` hides a topic without deleting it (DATA_MODEL.md).
      // The row itself still draws, because the row list comes from the
      // HelpTopic enum rather than from Firestore — so the honest rendering
      // of a disabled topic is the empty state the tenth row already uses,
      // not the bundled answers an admin has just chosen to retire.
      if (data['active'] == false) {
        return const HelpTopicContent(questions: [], fromFirestore: true);
      }

      final questions = parseQuestions(data, languageCode);
      if (questions == null) return _bundled(topic);

      return HelpTopicContent(questions: questions, fromFirestore: true);
    } catch (error) {
      // Offline, permission denied, malformed — all the same to the reader.
      debugPrint('Could not load $collection/${topic.docId}: $error');
      return _bundled(topic);
    }
  }

  /// Reads `content.{locale}.questions`, falling back to English.
  ///
  /// Returns null when the document carries no usable content at all, so the
  /// caller can fall back to the bundled copy. Returns an EMPTY list when the
  /// document legitimately has no questions — `contact_support` is seeded that
  /// way on purpose, and must not be replaced by a fallback.
  @visibleForTesting
  static List<HelpFaqEntry>? parseQuestions(
    Map<String, dynamic> data,
    String languageCode,
  ) {
    final content = data['content'];
    if (content is! Map) return null;

    final raw =
        _localeBlock(content, languageCode) ??
        _localeBlock(content, fallbackLocale);
    if (raw == null) return null;

    final questions = raw['questions'];
    if (questions is! List) return null;

    final entries = <HelpFaqEntry>[];
    for (final item in questions) {
      if (item is! Map) continue;
      final question = item['question'];
      final answer = item['answer'];
      if (question is! String || answer is! String) continue;
      if (question.trim().isEmpty || answer.trim().isEmpty) continue;
      entries.add(HelpFaqEntry(question: question, answer: answer));
    }
    return entries;
  }

  static Map<Object?, Object?>? _localeBlock(
    Map<Object?, Object?> content,
    String l,
  ) {
    final block = content[l];
    return block is Map ? block : null;
  }

  HelpTopicContent _bundled(HelpTopic topic) => HelpTopicContent(
    questions: bundledHelpFaqsFor(topic),
    fromFirestore: false,
  );
}
