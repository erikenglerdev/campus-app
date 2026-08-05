// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import 'package:campus_koethen/core/content/content_block.dart';
import 'package:campus_koethen/core/locale/locale_mode.dart';
import 'package:campus_koethen/features/news/data/news_models.dart';
import 'package:campus_koethen/features/news/presentation/news_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../../support/news_harness.dart';
import '../../support/pump_app.dart';

ParagraphBlock _p(String text) =>
    ParagraphBlock(<InlineNode>[InlineText(text: text)]);

NewsArticle _article({
  String slug = 'a',
  String title = 'Semesterstart 2026',
  List<ContentBlock>? content,
  List<NewsChannelRef> channels = const <NewsChannelRef>[],
  bool isPinned = false,
  DateTime? publishedAt,
}) => NewsArticle(
  slug: slug,
  title: title,
  teaser: 'Der Teaser, den niemand sehen soll.',
  publishedAt: publishedAt ?? newsTestNow.subtract(const Duration(hours: 2)),
  isPinned: isPinned,
  channels: channels,
  authors: const <NewsAuthor>[NewsAuthor(name: 'Demo-Redaktion', role: 'Demo')],
  content: content ?? <ContentBlock>[_p('Kurzer Text.')],
);

/// Six lines' worth of text, comfortably more than the preview shows.
List<ContentBlock> get _longArticle => <ContentBlock>[
  for (int i = 1; i <= 12; i++) _p('Absatz Nummer $i mit etwas Fließtext.'),
];

Future<void> _pumpCard(
  WidgetTester tester,
  NewsArticle article, {
  bool isUnread = false,
  Locale locale = AppLocales.german,
}) async {
  tester.view.physicalSize = const Size(390, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await pumpScreen(
    tester,
    Scaffold(
      body: ListView(
        children: <Widget>[NewsCard(article: article, isUnread: isUnread)],
      ),
    ),
    locale: locale,
    overrides: <Override>[frozenNewsClock()],
  );
  await tester.pump();
}

/// Every semantics label under the card, optionally only the buttons.
List<String> _semanticsLabels(WidgetTester tester, {bool isButton = false}) {
  final List<String> labels = <String>[];
  void visit(SemanticsNode node) {
    if (!isButton || node.flagsCollection.isButton) {
      if (node.label.isNotEmpty) labels.add(node.label);
    }
    node.visitChildren((SemanticsNode child) {
      visit(child);
      return true;
    });
  }

  visit(tester.getSemantics(find.byType(NewsCard)));
  return labels;
}

void main() {
  testWidgets('shows the title, the handles and the article', (
    WidgetTester tester,
  ) async {
    await _pumpCard(
      tester,
      _article(
        channels: const <NewsChannelRef>[
          NewsChannelRef(slug: 'fb5-news', name: 'FB5-News'),
          NewsChannelRef(slug: 'fsr-ins', name: 'FSR INS'),
        ],
        content: <ContentBlock>[_p('Der Artikeltext.')],
      ),
    );

    expect(find.text('Semesterstart 2026'), findsOneWidget);
    expect(find.text('@fb5-news @fsrins'), findsOneWidget);
    expect(find.text('Der Artikeltext.'), findsOneWidget);
  });

  testWidgets('never shows the teaser or the author', (
    WidgetTester tester,
  ) async {
    // Both still exist in the API for compatibility. The feed shows the
    // article itself, and a teaser standing in for it would look like the text
    // while being something else.
    await _pumpCard(tester, _article());

    expect(find.textContaining('Teaser'), findsNothing);
    expect(find.textContaining('Demo-Redaktion'), findsNothing);
  });

  testWidgets('the card is not a button and offers no other tap target', (
    WidgetTester tester,
  ) async {
    // There is nowhere to navigate to, so nothing may announce itself as
    // tappable. An article short enough to need no expand button therefore has
    // no control at all.
    await _pumpCard(tester, _article(content: <ContentBlock>[_p('Kurz.')]));

    expect(_semanticsLabels(tester, isButton: true), isEmpty);
    expect(find.byType(InkWell), findsNothing);
  });

  testWidgets('only the real action is a button', (WidgetTester tester) async {
    await _pumpCard(tester, _article(content: _longArticle));

    expect(_semanticsLabels(tester, isButton: true), <String>['Mehr anzeigen']);
  });

  group('expanding', () {
    testWidgets('a short article offers nothing to expand', (
      WidgetTester tester,
    ) async {
      await _pumpCard(tester, _article(content: <ContentBlock>[_p('Kurz.')]));

      expect(find.text('Mehr anzeigen'), findsNothing);
    });

    testWidgets('a long article shows six lines and then the whole text', (
      WidgetTester tester,
    ) async {
      await _pumpCard(tester, _article(content: _longArticle));

      final Text preview = tester.widget<Text>(
        find.textContaining('Absatz Nummer 1'),
      );
      expect(preview.maxLines, 6);
      expect(preview.overflow, TextOverflow.ellipsis);
      // The twelfth paragraph is in the preview STRING but clipped; it becomes
      // a block of its own only once expanded.
      expect(find.text('Absatz Nummer 12 mit etwas Fließtext.'), findsNothing);

      await tester.tap(find.text('Mehr anzeigen'));
      await tester.pumpAndSettle();

      expect(
        find.text('Absatz Nummer 12 mit etwas Fließtext.'),
        findsOneWidget,
      );
      expect(find.text('Weniger anzeigen'), findsOneWidget);
      expect(find.text('Mehr anzeigen'), findsNothing);
    });

    testWidgets('an article that is only an image can still be opened', (
      WidgetTester tester,
    ) async {
      // Nothing to truncate, so the text alone would never offer a way in.
      await _pumpCard(
        tester,
        _article(
          content: const <ContentBlock>[
            ImageBlock(url: 'https://cdn.example.org/plakat.png'),
          ],
        ),
      );

      expect(find.text('Mehr anzeigen'), findsOneWidget);
    });

    testWidgets('the source link is reachable in the expanded article', (
      WidgetTester tester,
    ) async {
      // The editorial rule is to summarise with a link, so the way back to the
      // original has to survive the loss of the detail page.
      await _pumpCard(
        tester,
        NewsArticle(
          slug: 'a',
          title: 'Mit Quelle',
          isPinned: false,
          publishedAt: newsTestNow,
          sourceName: 'Beispielquelle',
          sourceUrl: 'https://example.org/artikel',
          content: _longArticle,
        ),
      );

      expect(find.text('Quelle öffnen'), findsNothing);

      await tester.tap(find.text('Mehr anzeigen'));
      await tester.pumpAndSettle();

      expect(find.text('Quelle: Beispielquelle'), findsOneWidget);
      expect(find.text('Quelle öffnen'), findsOneWidget);
    });

    testWidgets('an article without content says so', (
      WidgetTester tester,
    ) async {
      await _pumpCard(tester, _article(content: const <ContentBlock>[]));

      expect(
        find.text('Für diesen Beitrag liegt kein Text vor.'),
        findsOneWidget,
      );
      expect(find.text('Mehr anzeigen'), findsNothing);
    });
  });

  testWidgets('shows the age relative to now', (WidgetTester tester) async {
    await _pumpCard(
      tester,
      _article(publishedAt: newsTestNow.subtract(const Duration(hours: 3))),
    );

    expect(find.text('vor 3 h'), findsOneWidget);
  });

  testWidgets('invents no timestamp when the article has none', (
    WidgetTester tester,
  ) async {
    await _pumpCard(
      tester,
      NewsArticle(
        slug: 'a',
        title: 'Ohne Datum',
        isPinned: false,
        content: <ContentBlock>[_p('Text.')],
      ),
    );

    expect(find.textContaining('vor'), findsNothing);
  });

  testWidgets('states unread in words and pinned with a label', (
    WidgetTester tester,
  ) async {
    await _pumpCard(tester, _article(isPinned: true), isUnread: true);

    expect(find.text('Neu'), findsOneWidget);
    expect(find.text('Angepinnt'), findsOneWidget);
    expect(_semanticsLabels(tester).join('\n'), contains('Ungelesen'));
  });

  testWidgets('renders in English', (WidgetTester tester) async {
    await _pumpCard(
      tester,
      _article(content: _longArticle),
      locale: AppLocales.english,
    );

    expect(find.text('Show more'), findsOneWidget);
  });

  testWidgets('survives a narrow phone with doubled text', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await pumpScreen(
      tester,
      Scaffold(
        body: ListView(
          children: <Widget>[
            NewsCard(
              article: _article(
                title: 'Eine ziemlich lange Überschrift für den Umbruchtest',
                content: _longArticle,
                isPinned: true,
                channels: const <NewsChannelRef>[
                  NewsChannelRef(slug: 'campus-news', name: 'Campus News'),
                ],
              ),
              isUnread: true,
            ),
          ],
        ),
      ),
      textScaler: const TextScaler.linear(2),
      overrides: <Override>[frozenNewsClock()],
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}
