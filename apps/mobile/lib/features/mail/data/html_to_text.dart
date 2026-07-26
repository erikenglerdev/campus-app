// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

/// Reduces an HTML mail body to safe plain text.
///
/// This is intentionally lossy: the MVP renders TEXT only. No HTML is shown, no
/// WebView is used, and — because the output is plain text — no remote image is
/// ever fetched. Scripts, styles and tags are removed rather than interpreted.
String htmlToPlainText(String? html) {
  if (html == null || html.trim().isEmpty) return '';
  String text = html;
  // Drop script/style blocks entirely, including their content.
  text = text.replaceAll(
    RegExp(
      r'<(script|style)[^>]*>.*?</\1>',
      dotAll: true,
      caseSensitive: false,
    ),
    ' ',
  );
  // Turn common block/line breaks into newlines before stripping tags.
  text = text.replaceAll(RegExp(r'<\s*br\s*/?>', caseSensitive: false), '\n');
  text = text.replaceAll(
    RegExp(r'</\s*(p|div|tr|li|h[1-6])\s*>', caseSensitive: false),
    '\n',
  );
  // Remove all remaining tags.
  text = text.replaceAll(RegExp(r'<[^>]+>'), '');
  // Decode the handful of entities worth handling.
  text = text
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'");
  // Collapse excessive blank lines and trailing whitespace.
  text = text.replaceAll(RegExp(r'[ \t]+\n'), '\n');
  text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');
  return text.trim();
}
