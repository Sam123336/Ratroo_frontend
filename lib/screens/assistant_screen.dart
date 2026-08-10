import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme.dart';
import '../providers/api_providers.dart';
import '../widgets/linkified_text.dart';
import '../core/app_icons.dart';

class _Message {
  final String text;
  final bool fromUser;

  /// Which backend tools produced this answer. Empty means the model answered
  /// without consulting the network — worth surfacing, since only tool-backed
  /// replies are grounded in real timetable data.
  final List<String> toolCalls;

  const _Message(this.text, {required this.fromUser, this.toolCalls = const []});
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
    final result = await ref.read(assistantServiceProvider).ask(text, from: location);
    if (!mounted) return;

    setState(() {
      _busy = false;
      _messages.add(result.success && result.data != null
          ? _Message(result.data!.answer, fromUser: false, toolCalls: result.data!.toolCalls)
          : _Message(result.error ?? 'Something went wrong.', fromUser: false));
    });
    _scrollToEnd();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Ask Ratroo')),
      body: SafeArea(
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
                        if (index >= _messages.length) return _buildThinking(theme);
                        return _buildBubble(theme, _messages[index]);
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
        Text('Ask about any journey', style: theme.textTheme.headlineSmall, textAlign: TextAlign.center),
        const SizedBox(height: RatrooTheme.space2),
        Text(
          'In English or Bengali. Name just a destination and it plans from '
          'where you are. Answers come from real routes and timetables — if a '
          'route does not exist, it will say so rather than guess.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: RatrooTheme.space8),
        ..._suggestions.map((s) => Padding(
              padding: const EdgeInsets.only(bottom: RatrooTheme.space3),
              child: OutlinedButton(
                onPressed: () => _send(s),
                child: Text(s, textAlign: TextAlign.center),
              ),
            )),
      ],
    );
  }

  Widget _buildBubble(ThemeData theme, _Message message) {
    final isUser = message.fromUser;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: RatrooTheme.space3),
        padding: const EdgeInsets.all(RatrooTheme.space4),
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.82),
        decoration: BoxDecoration(
          color: isUser ? theme.colorScheme.primary : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(RatrooTheme.radiusLg),
          border: isUser ? null : Border.all(color: theme.colorScheme.onSurface.withValues(alpha: 0.08)),
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
            // Shows the answer was built from live route data, not invented.
            if (!isUser && message.toolCalls.isNotEmpty) ...[
              const SizedBox(height: RatrooTheme.space2),
              Row(
                children: [
                  const Icon(AppIcons.verified, size: 13, color: RatrooTheme.confidenceHighText),
                  const SizedBox(width: 4),
                  Text(
                    'From live route data',
                    style: theme.textTheme.labelSmall?.copyWith(color: RatrooTheme.confidenceHighText),
                  ),
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
          border: Border.all(color: theme.colorScheme.onSurface.withValues(alpha: 0.08)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
            const SizedBox(width: RatrooTheme.space3),
            Text('Checking routes…', style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }

  Widget _buildComposer(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
          RatrooTheme.space4, RatrooTheme.space2, RatrooTheme.space4, RatrooTheme.space4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(top: BorderSide(color: theme.colorScheme.onSurface.withValues(alpha: 0.08))),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              enabled: !_busy,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _send(),
              decoration: const InputDecoration(hintText: 'Where do you want to go?'),
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
