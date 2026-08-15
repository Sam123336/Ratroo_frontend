import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../widgets/app_shell.dart';

import '../providers/api_providers.dart';
import '../services/chat_store.dart';
import '../services/saved_answers_service.dart';
import '../widgets/linkified_text.dart';
import '../core/app_icons.dart';

class _Message {
  final String text;
  final bool fromUser;

  /// The question this answers, kept so a saved reply carries what was asked.
  /// An answer alone is unreadable a week later.
  final String? question;

  /// Which backend tools produced this answer. Empty means the model answered
  /// without consulting the network — worth surfacing, since only tool-backed
  /// replies are grounded in real timetable data.
  final List<String> toolCalls;

  const _Message(
    this.text, {
    required this.fromUser,
    this.toolCalls = const [],
    this.question,
  });

  /// Stable across rebuilds *and* restores. Keyed on the answer alone: a
  /// restored message carries no question field, so folding the question in
  /// gave the same answer two different ids and a saved reply came back from
  /// history looking unsaved.
  String get savedId => text.hashCode.toString();
}

/// Ask about journeys in plain language, in English or Bengali.
class AssistantScreen extends ConsumerStatefulWidget {
  const AssistantScreen({super.key});

  @override
  ConsumerState<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends ConsumerState<AssistantScreen> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final List<_Message> _messages = [];
  bool _busy = false;

  /// The conversation being written to. Created on first open and reused, so
  /// leaving the screen and coming back continues the same chat rather than
  /// starting a blank one — which is what happened before, mid-journey, to a
  /// rider who stepped out to check the map.
  late String _conversationId = DateTime.now().microsecondsSinceEpoch
      .toString();

  @override
  void initState() {
    super.initState();
    // Restore the most recent conversation. Riverpod's future may already be
    // resolved, so this is deferred rather than awaited in initState.
    WidgetsBinding.instance.addPostFrameCallback((_) => _restoreLatest());
  }

  Future<void> _restoreLatest() async {
    final conversations = await ref.read(conversationsProvider.future);
    if (!mounted || conversations.isEmpty || _messages.isNotEmpty) return;

    final latest = conversations.first;
    setState(() {
      _conversationId = latest.id;
      _messages
        ..clear()
        ..addAll(latest.messages.map(_fromStored));
    });
    _scrollToEnd();
  }

  _Message _fromStored(ChatMessage message) => _Message(
    message.text,
    fromUser: message.fromUser,
    toolCalls: message.toolCalls,
  );

  /// Writes the conversation after every turn.
  ///
  /// Saved on each message rather than on dispose: the screen can be killed by
  /// the OS at any point, and a history that only persists on a clean exit is
  /// a history that loses exactly the conversations worth keeping.
  Future<void> _persist() async {
    await ref
        .read(conversationsProvider.notifier)
        .save(
          Conversation(
            id: _conversationId,
            updatedAt: DateTime.now(),
            messages: [
              for (final message in _messages)
                ChatMessage(
                  text: message.text,
                  fromUser: message.fromUser,
                  toolCalls: message.toolCalls,
                  at: DateTime.now(),
                ),
            ],
          ),
        );
  }

  void _startNewChat() {
    setState(() {
      _conversationId = DateTime.now().microsecondsSinceEpoch.toString();
      _messages.clear();
      _controller.clear();
    });
  }

  Future<void> _openConversation(Conversation conversation) async {
    setState(() {
      _conversationId = conversation.id;
      _messages
        ..clear()
        ..addAll(conversation.messages.map(_fromStored));
    });
    _scrollToEnd();
  }

  static const _suggestions = [
    'How do I get to Digha from here?',
    'ekhan theke bongaon kivabe jabo?',
    'How do I get from Sealdah to Bongaon?',
  ];

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send([String? preset]) async {
    final text = (preset ?? _controller.text).trim();
    if (text.isEmpty || _busy) return;

    setState(() {
      _messages.add(_Message(text, fromUser: true));
      _busy = true;
      _controller.clear();
    });
    _scrollToEnd();

    // Read rather than watch: the question is asked with the position as it is
    // now, and a later fix must not rebuild the conversation.
    final location = await ref.read(userLocationProvider.future);
    final result = await ref
        .read(assistantServiceProvider)
        .ask(text, from: location);
    if (!mounted) return;

    setState(() {
      _busy = false;
      _messages.add(
        result.success && result.data != null
            ? _Message(
                result.data!.answer,
                fromUser: false,
                toolCalls: result.data!.toolCalls,
                question: text,
              )
            : _Message(
                result.error ?? 'Something went wrong.',
                fromUser: false,
                question: text,
              ),
      );
    });
    _scrollToEnd();
    await _persist();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ask Ratroo'),
        actions: [
          IconButton(
            icon: const Icon(AppIcons.time),
            tooltip: 'Past chats',
            onPressed: _showHistory,
          ),
          IconButton(
            icon: const Icon(AppIcons.add),
            tooltip: 'New chat',
            // Disabled on an empty chat: starting a new one from a blank
            // screen does nothing and looks broken.
            onPressed: _messages.isEmpty ? null : _startNewChat,
          ),
        ],
      ),
      body: SafeArea(
        // bottom: false — the floating bar is cleared by AppShell.contentInset at
        // the end of the scroll, not here. Under `extendBody: true` Flutter
        // already adds the bar's height to this body's MediaQuery, so a
        // bottom-safe SafeArea reserves it a second time and leaves a gap the
        // size of the bar below the content.
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: _messages.isEmpty
                  ? _buildIntro(theme)
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.all(RatrooTheme.space4),
                      itemCount: _messages.length + (_busy ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index >= _messages.length) {
                          return _buildThinking(theme);
                        }
                        return _buildBubble(
                          theme,
                          _messages[index],
                          _questionBefore(index),
                        );
                      },
                    ),
            ),
            _buildComposer(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildIntro(ThemeData theme) {
    return ListView(
      padding: const EdgeInsets.all(RatrooTheme.space6),
      children: [
        const SizedBox(height: RatrooTheme.space8),
        Icon(AppIcons.assistant, size: 48, color: theme.colorScheme.primary),
        const SizedBox(height: RatrooTheme.space4),
        Text(
          'Ask about any journey',
          style: theme.textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: RatrooTheme.space2),
        Text(
          'In English or Bengali. Name just a destination and it plans from '
          'where you are. Answers come from real routes and timetables — if a '
          'route does not exist, it will say so rather than guess.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: RatrooTheme.space8),
        ..._suggestions.map(
          (s) => Padding(
            padding: const EdgeInsets.only(bottom: RatrooTheme.space3),
            child: OutlinedButton(
              onPressed: () => _send(s),
              child: Text(s, textAlign: TextAlign.center),
            ),
          ),
        ),
      ],
    );
  }

  /// The rider's last question before [index]. Read from the conversation
  /// rather than stored on the message, so it survives a restore.
  String _questionBefore(int index) {
    for (var i = index - 1; i >= 0; i--) {
      if (_messages[i].fromUser) return _messages[i].text;
    }
    return '';
  }

  Widget _buildBubble(ThemeData theme, _Message message, String question) {
    final isUser = message.fromUser;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: RatrooTheme.space3),
        padding: const EdgeInsets.all(RatrooTheme.space4),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.82,
        ),
        decoration: BoxDecoration(
          color: isUser ? theme.colorScheme.primary : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(RatrooTheme.radiusLg),
          border: isUser
              ? null
              : Border.all(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
                ),
          boxShadow: isUser ? null : RatrooTheme.cardShadow(theme.brightness),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // The assistant's replies carry a link per service; a plain Text
            // left them as dead characters.
            LinkifiedText(
              message.text,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: isUser ? Colors.white : theme.colorScheme.onSurface,
              ),
            ),
            if (!isUser) ...[
              const SizedBox(height: RatrooTheme.space2),
              Row(
                children: [
                  // Shows the answer was built from live route data, not
                  // invented.
                  if (message.toolCalls.isNotEmpty) ...[
                    const Icon(
                      AppIcons.verified,
                      size: 13,
                      color: RatrooTheme.confidenceHighText,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'From live route data',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: RatrooTheme.confidenceHighText,
                      ),
                    ),
                  ],
                  const Spacer(),
                  _BubbleAction(
                    icon: AppIcons.copy,
                    label: 'Copy',
                    onTap: () async {
                      // Captured before the await: reaching for the messenger
                      // afterwards uses a context that may be gone.
                      final messenger = ScaffoldMessenger.of(context);
                      await Clipboard.setData(
                        ClipboardData(text: message.text),
                      );
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text('Copied'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: RatrooTheme.space2),
                  _SaveButton(message: message, question: question),
                ],
              ),
            ],
          ],
        ),
      ),
    ).animate().fadeIn(duration: 200.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildThinking(ThemeData theme) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: RatrooTheme.space3),
        padding: const EdgeInsets.all(RatrooTheme.space4),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(RatrooTheme.radiusLg),
          border: Border.all(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: RatrooTheme.space3),
            Text('Checking routes…', style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }

  /// The composer floats above the navigation bar rather than docking to the
  /// bottom edge.
  ///
  /// It used to be a full-bleed panel with a top hairline, which was right
  /// when it sat on the bottom edge. Once the bar started floating over the
  /// content, clearing it meant 100px of bottom padding — and the panel's own
  /// surface colour filled all of it, so the screen ended in a tall empty
  /// slab with the input stranded at its top. A floating pill clears the bar
  /// the same way and matches the language of the thing it sits above.
  Widget _buildComposer(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.fromLTRB(
        RatrooTheme.space4,
        RatrooTheme.space2,
        RatrooTheme.space4,
        AppShell.contentInset,
      ),
      padding: const EdgeInsets.all(RatrooTheme.space2),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(RatrooTheme.radiusXl),
        border: Border.all(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
        ),
        boxShadow: RatrooTheme.cardShadow(theme.brightness),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              enabled: !_busy,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _send(),
              decoration: const InputDecoration(
                hintText: 'Where do you want to go?',
              ),
            ),
          ),
          const SizedBox(width: RatrooTheme.space2),
          IconButton.filled(
            onPressed: _busy ? null : () => _send(),
            icon: const Icon(AppIcons.up),
            tooltip: 'Ask',
          ),
        ],
      ),
    );
  }
}

/// Keeps an answer for later.
///
/// Saved on the device rather than re-asked: an answer about the 14:15 from
/// Galsi is a record of what we said at the time, and re-querying could quietly
/// return something different.
/// A small text action under an answer. Deliberately quiet: these sit under
/// every reply, and a row of loud buttons competes with the answer itself.
class _BubbleAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;

  const _BubbleAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tint = active
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurface.withValues(alpha: 0.45);

    return InkWell(
      borderRadius: BorderRadius.circular(RatrooTheme.radiusPill),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: RatrooTheme.space2,
          vertical: RatrooTheme.space1,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: tint),
            const SizedBox(width: 4),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(color: tint),
            ),
          ],
        ),
      ),
    );
  }
}

class _SaveButton extends ConsumerWidget {
  final _Message message;
  final String question;

  const _SaveButton({required this.message, required this.question});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saved = ref.watch(savedAnswersProvider).valueOrNull ?? const [];
    final isSaved = saved.any((answer) => answer.id == message.savedId);

    return _BubbleAction(
      icon: isSaved ? AppIcons.bookmarkSelected : AppIcons.bookmark,
      label: isSaved ? 'Saved' : 'Save',
      active: isSaved,
      onTap: () async {
        final messenger = ScaffoldMessenger.of(context);
        final notifier = ref.read(savedAnswersProvider.notifier);
        if (isSaved) {
          await notifier.remove(message.savedId);
        } else {
          await notifier.save(
            SavedAnswer(
              id: message.savedId,
              question: question,
              answer: message.text,
              savedAt: DateTime.now(),
              // Carried through so a saved answer keeps the provenance the
              // live bubble showed.
              fromLiveData: message.toolCalls.isNotEmpty,
            ),
          );
        }
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              isSaved ? 'Removed from your journeys' : 'Saved to your journeys',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
    );
  }
}

extension _History on _AssistantScreenState {
  /// Past conversations, newest first.
  ///
  /// A sheet rather than a separate screen: picking an old chat is a detour
  /// from the one in front of you, not a place to navigate to.
  void _showHistory() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => Consumer(
        builder: (context, ref, _) {
          final theme = Theme.of(context);
          final conversations =
              ref.watch(conversationsProvider).valueOrNull ??
              const <Conversation>[];

          // Gesture bar / navigation bar height. Without it the last row sits
          // under the system chrome and reads as a clipped, broken sheet.
          final systemInset = MediaQuery.viewPaddingOf(context).bottom;

          if (conversations.isEmpty) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                RatrooTheme.space8,
                RatrooTheme.space8,
                RatrooTheme.space8,
                RatrooTheme.space8 + systemInset,
              ),
              child: Text(
                'No past chats yet.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
            );
          }

          return ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.7,
            ),
            child: ListView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.only(
                bottom: RatrooTheme.space6 + systemInset,
              ),
              itemCount: conversations.length,
              itemBuilder: (context, index) {
                final conversation = conversations[index];
                final isCurrent = conversation.id == _conversationId;

                return ListTile(
                  leading: Icon(
                    AppIcons.assistant,
                    color: isCurrent
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                  title: Text(
                    conversation.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '${conversation.messages.length} messages · '
                    '${timeAgo(conversation.updatedAt)}',
                  ),
                  trailing: IconButton(
                    icon: const Icon(AppIcons.close, size: 18),
                    tooltip: 'Delete',
                    onPressed: () => ref
                        .read(conversationsProvider.notifier)
                        .remove(conversation.id),
                  ),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _openConversation(conversation);
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}
