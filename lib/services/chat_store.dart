import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// One turn in a conversation.
class ChatMessage {
  final String text;
  final bool fromUser;

  /// Which backend tools produced this answer. Empty means the model answered
  /// from its own words — worth keeping, since only tool-backed replies are
  /// grounded in real timetable data, and that distinction must survive being
  /// stored just as it survives on screen.
  final List<String> toolCalls;

  final DateTime at;

  const ChatMessage({
    required this.text,
    required this.fromUser,
    required this.at,
    this.toolCalls = const [],
  });

  bool get fromLiveData => toolCalls.isNotEmpty;

  Map<String, dynamic> toJson() => {
        'text': text,
        'fromUser': fromUser,
        'toolCalls': toolCalls,
        'at': at.toIso8601String(),
      };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        text: json['text'] as String? ?? '',
        fromUser: json['fromUser'] as bool? ?? false,
        toolCalls:
            (json['toolCalls'] as List?)?.whereType<String>().toList() ?? const [],
        at: DateTime.tryParse(json['at'] as String? ?? '') ?? DateTime.now(),
      );
}

/// A conversation the rider had with the assistant.
class Conversation {
  final String id;
  final List<ChatMessage> messages;
  final DateTime updatedAt;

  const Conversation({
    required this.id,
    required this.messages,
    required this.updatedAt,
  });

  /// Named after the first thing the rider asked, which is what they will
  /// recognise it by. Generating a title from the *answer* would name the
  /// conversation after us rather than them.
  String get title {
    for (final message in messages) {
      if (message.fromUser && message.text.trim().isNotEmpty) {
        final text = message.text.trim();
        return text.length <= 60 ? text : '${text.substring(0, 57)}…';
      }
    }
    return 'New chat';
  }

  bool get isEmpty => messages.isEmpty;

  Map<String, dynamic> toJson() => {
        'id': id,
        'messages': messages.map((m) => m.toJson()).toList(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory Conversation.fromJson(Map<String, dynamic> json) => Conversation(
        id: json['id'] as String? ?? '',
        messages: (json['messages'] as List?)
                ?.whereType<Map<String, dynamic>>()
                .map(ChatMessage.fromJson)
                .toList() ??
            const [],
        updatedAt:
            DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? DateTime.now(),
      );
}

/// Conversations kept on the device.
///
/// The assistant used to lose everything the moment the screen closed — a
/// rider who asked about the last bus home, switched to the map to check the
/// stop, and came back found an empty screen and had to ask again.
///
/// Device-local, like saved answers: no schema change, works with no signal,
/// and a rider's questions stay off the server.
class ChatStore {
  static const _key = 'ratroo.conversations';

  /// Bounded so the store cannot grow forever. Old chats fall off the end.
  static const maxConversations = 20;

  final FlutterSecureStorage _storage;

  const ChatStore(this._storage);

  Future<List<Conversation>> all() async {
    final raw = await _storage.read(key: _key);
    if (raw == null || raw.isEmpty) return const [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(Conversation.fromJson)
          .toList();
    } on FormatException {
      // A corrupt store costs the rider their history, not the screen.
      return const [];
    }
  }

  /// Newest first. An empty conversation is never stored — opening the screen
  /// and leaving should not litter the history with blanks.
  Future<List<Conversation>> save(Conversation conversation) async {
    final rest = (await all()).where((c) => c.id != conversation.id);
    final next = conversation.isEmpty
        ? rest.toList()
        : [conversation, ...rest].take(maxConversations).toList();
    await _write(next);
    return next;
  }

  Future<List<Conversation>> remove(String id) async {
    final next = (await all()).where((c) => c.id != id).toList();
    await _write(next);
    return next;
  }

  Future<void> _write(List<Conversation> conversations) => _storage.write(
        key: _key,
        value: jsonEncode(conversations.map((c) => c.toJson()).toList()),
      );
}

final chatStoreProvider =
    Provider<ChatStore>((ref) => const ChatStore(FlutterSecureStorage()));

final conversationsProvider =
    AsyncNotifierProvider<ConversationsNotifier, List<Conversation>>(
  ConversationsNotifier.new,
);

class ConversationsNotifier extends AsyncNotifier<List<Conversation>> {
  @override
  Future<List<Conversation>> build() => ref.watch(chatStoreProvider).all();

  Future<void> save(Conversation conversation) async {
    state = AsyncData(await ref.read(chatStoreProvider).save(conversation));
  }

  Future<void> remove(String id) async {
    state = AsyncData(await ref.read(chatStoreProvider).remove(id));
  }
}
