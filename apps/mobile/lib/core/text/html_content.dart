// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import 'package:html/dom.dart';
import 'package:html/parser.dart' as html;

/// Reduces untrusted HTML (e.g. Moodle course/module descriptions and forum
/// posts) to safe plain text.
///
/// A real DOM parse (not regex) that removes `<script>`/`<style>` entirely and
/// keeps only the text — the safest possible rendered subset. No script ever
/// runs, and no markup reaches the UI. HTML entities are decoded, whitespace is
/// collapsed and paragraph breaks are preserved.
String htmlToSafeText(String? source) {
  if (source == null || source.trim().isEmpty) return '';
  final DocumentFragment fragment = html.parseFragment(source);
  for (final Element node in fragment.querySelectorAll('script, style')) {
    node.remove();
  }
  // Turn block boundaries into newlines before flattening to text.
  for (final Element node in fragment.querySelectorAll(
    'br, p, div, li, tr, h1, h2, h3, h4',
  )) {
    node.append(Text('\n'));
  }
  final String text = fragment.text ?? '';
  return text
      .replaceAll(' ', ' ')
      .replaceAll(RegExp(r'[ \t]+'), ' ')
      .replaceAll(RegExp(r' *\n *'), '\n')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();
}
