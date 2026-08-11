import 'package:flutter_test/flutter_test.dart';
import 'package:ratroo_app/services/chat_store.dart';

ChatMessage _msg(String text, {bool user = false, List<String> tools = const []}) =>
    ChatMessage(
      text: text,
      fromUser: user,
      toolCalls: tools,
      at: DateTime(2026, 8, 12, 10),
    );

void main() {
  group('Conversation', () {
    test('is titled by what the rider asked, not what we answered', () {
      final chat = Conversation(
        id: '1',
        updatedAt: DateTime(2026, 8, 12),
        messages: [
          _msg('How do I get to Digha?', user: true),
          _msg('Take the 14:15 from Esplanade.'),
        ],
      );

      expect(chat.title, 'How do I get to Digha?');
    });

    test('a long question is truncated rather than wrapping a list row', () {
      final chat = Conversation(
        id: '1',
        updatedAt: DateTime(2026, 8, 12),
        messages: [_msg('a' * 200, user: true)],
      );

      expect(chat.title.length, lessThanOrEqualTo(60));
      expect(chat.title.endsWith('…'), isTrue);
    });

    test('a chat with no question of its own still names itself', () {
      final chat = Conversation(
        id: '1',
        updatedAt: DateTime(2026, 8, 12),
        messages: [_msg('Something went wrong.')],
      );

      expect(chat.title, 'New chat');
    });

    test('round-trips through JSON keeping provenance per message', () {
      final chat = Conversation(
        id: 'abc',
        updatedAt: DateTime(2026, 8, 12, 10, 30),
        messages: [
          _msg('Where to?', user: true),
          _msg('The 14:15.', tools: ['plan_journey']),
          _msg('I think so.'),
        ],
      );

      final restored = Conversation.fromJson(chat.toJson());

      expect(restored.id, 'abc');
      expect(restored.messages.length, 3);
      expect(restored.updatedAt, DateTime(2026, 8, 12, 10, 30));
      // Only the tool-backed reply may claim live data — that distinction has
      // to survive storage exactly as it survives on screen.
      expect(restored.messages[1].fromLiveData, isTrue);
      expect(restored.messages[2].fromLiveData, isFalse);
    });

    test('a message with no recorded tools never claims live data', () {
      final restored = ChatMessage.fromJson({'text': 'hi', 'fromUser': false});

      expect(restored.fromLiveData, isFalse);
    });
  });
}
