import 'package:flutter_test/flutter_test.dart';
import 'package:ratroo_app/services/saved_answers_service.dart';

SavedAnswer _answer(String id, {bool live = true}) => SavedAnswer(
      id: id,
      question: 'How do I get to Asansol?',
      answer: 'Take the 14:15 from Galsi.',
      savedAt: DateTime(2026, 8, 12, 9),
      fromLiveData: live,
    );

void main() {
  test('round-trips through JSON without losing provenance', () {
    final restored = SavedAnswer.fromJson(_answer('a', live: false).toJson());

    expect(restored.id, 'a');
    expect(restored.question, 'How do I get to Asansol?');
    expect(restored.answer, 'Take the 14:15 from Galsi.');
    expect(restored.savedAt, DateTime(2026, 8, 12, 9));
    // An ungrounded answer must not gain authority by being saved.
    expect(restored.fromLiveData, isFalse);
  });

  test('a missing provenance flag defaults to not-live', () {
    // Old entries written before the flag existed must not claim live data.
    final restored = SavedAnswer.fromJson({
      'id': 'a',
      'question': 'q',
      'answer': 'a',
      'savedAt': '2026-08-12T09:00:00.000',
    });

    expect(restored.fromLiveData, isFalse);
  });

  test('an unparseable date falls back rather than throwing', () {
    // A corrupt store must cost the rider a timestamp, not the screen.
    final restored = SavedAnswer.fromJson({'id': 'a', 'savedAt': 'not a date'});

    expect(restored.savedAt, isA<DateTime>());
    expect(restored.answer, '');
  });
}
