import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'type_detail_screen.dart';

/// Renders an EVE description string. CCP wraps cross-references in
/// `<a href=showinfo:typeId>label</a>` tags (no quotes, sometimes with
/// a trailing `//itemID`); we surface those as tappable links that
/// open [TypeDetailScreen]. `<br>` becomes a newline, common HTML
/// entities are decoded, and any leftover tags are stripped.
class HtmlDescription extends StatefulWidget {
  const HtmlDescription({super.key, required this.html, this.style});

  final String html;
  final TextStyle? style;

  @override
  State<HtmlDescription> createState() => _HtmlDescriptionState();
}

class _HtmlDescriptionState extends State<HtmlDescription> {
  final List<TapGestureRecognizer> _recognizers = [];
  late List<InlineSpan> _spans;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _rebuildSpans();
  }

  @override
  void didUpdateWidget(covariant HtmlDescription oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.html != widget.html) _rebuildSpans();
  }

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  void _disposeRecognizers() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  void _rebuildSpans() {
    _disposeRecognizers();
    _spans = _parse(widget.html);
  }

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(children: _spans),
      style: widget.style,
    );
  }

  List<InlineSpan> _parse(String html) {
    final normalized =
        html.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');

    // Matches both `<a href="...">...</a>` and `<a href=...>...</a>`
    // (the unquoted form is what the SDE actually uses).
    final pattern = RegExp(
      r'<a\s+href=(?:"([^"]+)"|([^>\s]+))>([^<]*)</a>',
      caseSensitive: false,
    );

    final spans = <InlineSpan>[];
    var cursor = 0;
    final linkColor = Theme.of(context).colorScheme.primary;

    for (final m in pattern.allMatches(normalized)) {
      if (m.start > cursor) {
        spans.add(TextSpan(text: _clean(normalized.substring(cursor, m.start))));
      }
      final url = m.group(1) ?? m.group(2) ?? '';
      final label = _clean(m.group(3) ?? '');
      final typeId = _parseShowinfo(url);
      if (typeId == null) {
        spans.add(TextSpan(text: label));
      } else {
        final recognizer = TapGestureRecognizer()
          ..onTap = () => _open(typeId);
        _recognizers.add(recognizer);
        spans.add(TextSpan(
          text: label,
          style: TextStyle(
            color: linkColor,
            decoration: TextDecoration.underline,
            decorationColor: linkColor,
          ),
          recognizer: recognizer,
        ));
      }
      cursor = m.end;
    }
    if (cursor < normalized.length) {
      spans.add(TextSpan(text: _clean(normalized.substring(cursor))));
    }
    return spans;
  }

  void _open(int typeId) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TypeDetailScreen(typeId: typeId),
      ),
    );
  }
}

int? _parseShowinfo(String url) {
  final m = RegExp(r'^showinfo:(\d+)').firstMatch(url);
  if (m == null) return null;
  return int.tryParse(m.group(1)!);
}

String _clean(String s) {
  final stripped = s.replaceAll(RegExp(r'<[^>]+>'), '');
  return stripped
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'");
}
