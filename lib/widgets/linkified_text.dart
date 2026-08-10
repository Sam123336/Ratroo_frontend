import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/theme.dart';

/// Text with bare URLs turned into tappable links.
///
/// The assistant answers with an operator's page per service — "…(WBBUS)
/// https://wbbus.in/bus/aniket-…". In a plain Text widget those were dead
/// characters, so the one useful action in the reply could not be taken.
class LinkifiedText extends StatefulWidget {
  final String text;
  final TextStyle? style;

  const LinkifiedText(this.text, {super.key, this.style});

  @override
  State<LinkifiedText> createState() => _LinkifiedTextState();
}

class _LinkifiedTextState extends State<LinkifiedText> {
  /// Recognisers hold gesture state and must be released with the widget.
  final List<TapGestureRecognizer> _recognisers = [];

  /// Stops at whitespace, and trims trailing punctuation so a URL ending a
  /// sentence does not carry the full stop into the address.
  static final _url = RegExp(r'https?://[^\s<>"]+[^\s<>",.;:!?)\]]');

  @override
  void dispose() {
    for (final recogniser in _recognisers) {
      recogniser.dispose();
    }
    super.dispose();
  }

  Future<void> _open(String url) async {
    final messenger = ScaffoldMessenger.of(context);
    final uri = Uri.tryParse(url);
    if (uri == null || !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      messenger.showSnackBar(SnackBar(content: Text('Could not open $url')));
    }
  }

  @override
  Widget build(BuildContext context) {
    for (final recogniser in _recognisers) {
      recogniser.dispose();
    }
    _recognisers.clear();

    final base = widget.style ?? Theme.of(context).textTheme.bodyLarge;
    final spans = <InlineSpan>[];
    var index = 0;

    for (final match in _url.allMatches(widget.text)) {
      if (match.start > index) {
        spans.add(TextSpan(text: widget.text.substring(index, match.start)));
      }

      final url = match.group(0)!;
      final recogniser = TapGestureRecognizer()..onTap = () => _open(url);
      _recognisers.add(recogniser);

      spans.add(TextSpan(
        // The address itself is noise in a chat bubble; what matters is that
        // there is something to tap and where it goes.
        text: _label(url),
        style: base?.copyWith(
          color: RatrooTheme.primaryColor,
          decoration: TextDecoration.underline,
          decorationColor: RatrooTheme.primaryColor.withValues(alpha: 0.4),
        ),
        recognizer: recogniser,
      ));

      index = match.end;
    }

    if (index < widget.text.length) {
      spans.add(TextSpan(text: widget.text.substring(index)));
    }

    return SelectableText.rich(TextSpan(style: base, children: spans));
  }

  /// "wbbus.in — timetable" rather than a 70-character slug.
  static String _label(String url) {
    final host = Uri.tryParse(url)?.host.replaceFirst('www.', '');
    return host == null || host.isEmpty ? url : 'open on $host';
  }
}
