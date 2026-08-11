import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// An assistant answer the rider chose to keep.
///
/// Stores the reply text as it was given, not a re-query. An answer about the
/// 14:15 from Galsi is a record of what we said at the time; re-asking later
/// could return something different and quietly rewrite history.
class SavedAnswer {
  final String id;
  final String question;
  final String answer;
  final DateTime savedAt;

  /// Whether the reply was built from backend tools rather than the model's own
  /// words. Carried through so a saved answer keeps the provenance the live
  /// bubble showed — an ungrounded answer must not gain authority by being kept.
  final bool fromLiveData;

  const SavedAnswer({
    required this.id,
    required this.question,
    required this.answer,
    required this.savedAt,
    required this.fromLiveData,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'question': question,
    'answer': answer,
    'savedAt': savedAt.toIso8601String(),
    'fromLiveData': fromLiveData,
  };

  factory SavedAnswer.fromJson(Map<String, dynamic> json) => SavedAnswer(
    id: json['id'] as String? ?? '',
    question: json['question'] as String? ?? '',
    answer: json['answer'] as String? ?? '',
    savedAt:
        DateTime.tryParse(json['savedAt'] as String? ?? '') ?? DateTime.now(),
    fromLiveData: json['fromLiveData'] as bool? ?? false,
  );
}

/// Assistant answers kept on the device.
///
/// Device-local rather than server-side: it needs no schema change, works with
/// no signal — which is when a saved answer is worth most, standing at a stop
/// with no data — and keeps a rider's questions off the server. The trade-off
/// is that saves do not follow them to another phone; moving to the backend
/// later can read this same shape.
class SavedAnswersService {
  static const _key = 'ratroo.saved_answers';

  /// Enough to be useful, bounded so the store cannot grow without limit.
  static const maxSaved = 50;

  final FlutterSecureStorage _storage;

  const SavedAnswersService(this._storage);

  Future<List<SavedAnswer>> all() async {
    final raw = await _storage.read(key: _key);
    if (raw == null || raw.isEmpty) return const [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(SavedAnswer.fromJson)
          .toList();
    } on FormatException {
      // A corrupt store must not take the screen down; the rider loses saves,
      // not the app.
      return const [];
    }
  }

  /// Newest first, so the list reads the way a rider expects.
  Future<List<SavedAnswer>> save(SavedAnswer answer) async {
    final existing = await all();
    final next = [
      answer,
      ...existing.where((a) => a.id != answer.id),
    ].take(maxSaved).toList();
    await _write(next);
    return next;
  }

  Future<List<SavedAnswer>> remove(String id) async {
    final next = (await all()).where((a) => a.id != id).toList();
    await _write(next);
    return next;
  }

  Future<void> _write(List<SavedAnswer> answers) => _storage.write(
    key: _key,
    value: jsonEncode(answers.map((a) => a.toJson()).toList()),
  );
}

final savedAnswersServiceProvider = Provider<SavedAnswersService>(
  (ref) => const SavedAnswersService(FlutterSecureStorage()),
);

/// The saved list, shared by the assistant and the home screen so saving in one
/// updates the other without a manual refresh.
final savedAnswersProvider =
    AsyncNotifierProvider<SavedAnswersNotifier, List<SavedAnswer>>(
      SavedAnswersNotifier.new,
    );

class SavedAnswersNotifier extends AsyncNotifier<List<SavedAnswer>> {
  @override
  Future<List<SavedAnswer>> build() =>
      ref.watch(savedAnswersServiceProvider).all();

  Future<void> save(SavedAnswer answer) async {
    final next = await ref.read(savedAnswersServiceProvider).save(answer);
    state = AsyncData(next);
  }

  Future<void> remove(String id) async {
    final next = await ref.read(savedAnswersServiceProvider).remove(id);
    state = AsyncData(next);
  }

  bool contains(String id) =>
      state.valueOrNull?.any((answer) => answer.id == id) ?? false;
}
