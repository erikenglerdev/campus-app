// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import 'package:campus_koethen/features/calendar/domain/calendar_entry.dart';
import 'package:campus_koethen/features/calendar/domain/week_layout.dart';
import 'package:campus_koethen/features/calendar/presentation/week_grid_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/pump_app.dart';

final DateTime _monday = DateTime(2026, 5, 11);

CalendarEntry _entry({
  required String title,
  required int dayOffset,
  required int fromH,
  int fromM = 0,
  required int toH,
  int toM = 0,
}) {
  final DateTime day = _monday.add(Duration(days: dayOffset));
  return CalendarEntry(
    id: title,
    source: CalendarSource.publicCalendar,
    title: title,
    start: DateTime(day.year, day.month, day.day, fromH, fromM),
    end: DateTime(day.year, day.month, day.day, toH, toM),
  );
}

Future<void> pumpGrid(
  WidgetTester tester,
  List<CalendarEntry> entries, {
  TextScaler textScaler = TextScaler.noScaling,
  int dayCount = 5,
  Size size = const Size(390, 844),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await pumpScreen(
    tester,
    Scaffold(
      body: WeekGridView(
        weekStart: _monday,
        entries: entries,
        today: _monday,
        selected: _monday,
        dayCount: dayCount,
        onSelectDay: (DateTime _) {},
      ),
    ),
    textScaler: textScaler,
  );
  await tester.pumpAndSettle();
}

/// The day headers the grid currently draws, in order.
List<String> _headers(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((Text t) => t.data ?? '')
    .where((String s) => RegExp(r'^\w+\.? \d+$').hasMatch(s))
    .toList(growable: false);

/// The height one line of this text needs at the width it was actually given.
double _neededHeight(WidgetTester tester, String title) {
  final RenderParagraph paragraph = tester.renderObject<RenderParagraph>(
    find.text(title),
  );
  return paragraph.getMinIntrinsicHeight(paragraph.size.width);
}

void main() {
  group('the week the grid draws', () {
    testWidgets('is Monday to Friday by default', (WidgetTester tester) async {
      // Two empty weekend columns cost a fifth of the width of a phone.
      await pumpGrid(tester, <CalendarEntry>[]);

      expect(_headers(tester), hasLength(5));
      expect(_headers(tester).first, contains('11'));
      expect(_headers(tester).last, contains('15'));
    });

    testWidgets('runs to Sunday when the weekend is switched on', (
      WidgetTester tester,
    ) async {
      await pumpGrid(tester, <CalendarEntry>[], dayCount: 7);

      expect(_headers(tester), hasLength(7));
      expect(_headers(tester).last, contains('17'));
    });

    testWidgets('a Saturday entry is not drawn in the work week', (
      WidgetTester tester,
    ) async {
      // Not just hidden columns: an entry outside the drawn days must not land
      // in a neighbouring one.
      await pumpGrid(tester, <CalendarEntry>[
        _entry(title: 'Samstagstermin', dayOffset: 5, fromH: 10, toH: 11),
        _entry(title: 'Freitagstermin', dayOffset: 4, fromH: 10, toH: 11),
      ]);

      expect(find.text('Samstagstermin'), findsNothing);
      expect(find.text('Freitagstermin'), findsOneWidget);
    });

    testWidgets('and is drawn once the weekend is on', (
      WidgetTester tester,
    ) async {
      await pumpGrid(tester, <CalendarEntry>[
        _entry(title: 'Samstagstermin', dayOffset: 5, fromH: 10, toH: 11),
      ], dayCount: 7);

      expect(find.text('Samstagstermin'), findsOneWidget);
    });
  });

  group('the width the week is given', () {
    /// The horizontal extent of the scrollable grid area, and of its content.
    (double viewport, double content) widthsOf(WidgetTester tester) {
      final Finder scroller = find.byWidgetPredicate(
        (Widget widget) =>
            widget is Scrollable && widget.axisDirection == AxisDirection.right,
      );
      expect(scroller, findsOneWidget);
      final ScrollableState state = tester.state<ScrollableState>(scroller);
      final ScrollPosition position = state.position;
      return (
        position.viewportDimension,
        position.viewportDimension + position.maxScrollExtent,
      );
    }

    testWidgets('fits Monday to Friday without scrolling sideways', (
      WidgetTester tester,
    ) async {
      // "The whole teaching week at a glance" is the point of this view. A
      // fixed column width made every phone scroll to reach Friday.
      await pumpGrid(tester, <CalendarEntry>[]);

      final (double viewport, double content) = widthsOf(tester);
      expect(content, lessThanOrEqualTo(viewport + 0.5));
      expect(_headers(tester), hasLength(5));
    });

    testWidgets('still fits on a narrow phone', (WidgetTester tester) async {
      await pumpGrid(tester, <CalendarEntry>[], size: const Size(320, 800));

      final (double viewport, double content) = widthsOf(tester);
      expect(content, lessThanOrEqualTo(viewport + 0.5));
    });

    testWidgets('columns share the width evenly', (WidgetTester tester) async {
      await pumpGrid(tester, <CalendarEntry>[]);

      final List<double> headerWidths = tester
          .renderObjectList<RenderBox>(
            find.ancestor(
              of: find.textContaining('11'),
              matching: find.byType(InkWell),
            ),
          )
          .map((RenderBox box) => box.size.width)
          .toList(growable: false);
      final (double viewport, _) = widthsOf(tester);

      expect(headerWidths, isNotEmpty);
      expect(headerWidths.first, closeTo(viewport / 5, 0.5));
    });

    testWidgets('never squeezes a column below a touch target', (
      WidgetTester tester,
    ) async {
      // Seven columns on a 320 px phone would be narrower than a finger, so
      // that is where the sideways scroll comes back instead of shrinking on.
      await pumpGrid(
        tester,
        <CalendarEntry>[],
        dayCount: 7,
        size: const Size(320, 800),
      );

      final (double viewport, double content) = widthsOf(tester);
      expect(content, greaterThan(viewport));
      expect(content / 7, closeTo(WeekGridView.minColumnWidth, 0.5));
    });
  });

  testWidgets('the hour lines follow the reader text size', (
    WidgetTester tester,
  ) async {
    // The lines and the entries have to agree. Entries are positioned against
    // the scaled hour height; lines drawn at the unscaled constant would sit at
    // half the spacing and a 10:00 lecture would straddle the 12:00 mark.
    await pumpGrid(tester, <CalendarEntry>[
      _entry(title: 'Vorlesung', dayOffset: 0, fromH: 10, toH: 11),
    ], textScaler: const TextScaler.linear(2));

    final List<double> lines =
        tester
            .renderObjectList<RenderBox>(find.byType(Divider))
            .map((RenderBox box) => box.localToGlobal(Offset.zero).dy)
            .toSet()
            .toList(growable: false)
          ..sort();

    expect(lines.length, greaterThan(1));
    expect(
      lines[1] - lines[0],
      closeTo(const TextScaler.linear(2).scale(WeekGridView.hourHeight), 1),
      reason: 'an hour on the grid is as tall as an hour of entries',
    );
  });

  testWidgets('a short entry still shows its title in full', (
    WidgetTester tester,
  ) async {
    // A 15-minute slot is drawn at the 30-minute minimum — barely 28 px tall.
    // Squeezing an icon and a line of text into a column that small cuts the
    // glyphs in half, which is worse than showing no icon at all.
    await pumpGrid(tester, <CalendarEntry>[
      _entry(
        title: 'Kurzbesprechung',
        dayOffset: 2,
        fromH: 17,
        toH: 17,
        toM: 15,
      ),
    ]);

    final RenderBox box = tester.renderObject<RenderBox>(
      find.text('Kurzbesprechung'),
    );
    expect(
      box.size.height,
      greaterThanOrEqualTo(_neededHeight(tester, 'Kurzbesprechung')),
      reason: 'the title is squeezed below the height one line needs',
    );
  });

  testWidgets('a short entry keeps its source icon', (
    WidgetTester tester,
  ) async {
    // Accessibility: the source must never be carried by colour alone, so
    // making room for the title may not simply drop the icon.
    await pumpGrid(tester, <CalendarEntry>[
      _entry(
        title: 'Kurzbesprechung',
        dayOffset: 2,
        fromH: 17,
        toH: 17,
        toM: 15,
      ),
    ]);

    expect(
      find.descendant(of: find.byType(Card), matching: find.byType(Icon)),
      findsOneWidget,
    );
  });

  testWidgets('a long entry shows its title in full too', (
    WidgetTester tester,
  ) async {
    await pumpGrid(tester, <CalendarEntry>[
      _entry(title: 'Vorlesung', dayOffset: 1, fromH: 10, toH: 12),
    ]);

    final RenderBox box = tester.renderObject<RenderBox>(
      find.text('Vorlesung'),
    );
    expect(
      box.size.height,
      greaterThanOrEqualTo(_neededHeight(tester, 'Vorlesung')),
    );
  });

  testWidgets('doubled text does not clip a short entry either', (
    WidgetTester tester,
  ) async {
    await pumpGrid(tester, <CalendarEntry>[
      _entry(title: 'Kurz', dayOffset: 0, fromH: 9, toH: 9, toM: 20),
    ], textScaler: const TextScaler.linear(2));

    final RenderBox box = tester.renderObject<RenderBox>(find.text('Kurz'));
    expect(
      box.size.height,
      greaterThanOrEqualTo(_neededHeight(tester, 'Kurz')),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('the minimum box is tall enough for one line of text', (
    WidgetTester tester,
  ) async {
    // Guards the arithmetic the fix depends on: whatever layout the box uses,
    // the shortest entry must have room for a readable line.
    await pumpGrid(tester, <CalendarEntry>[
      _entry(title: 'Kurz', dayOffset: 0, fromH: 9, toH: 9, toM: 5),
    ]);

    const double minimumBoxHeight =
        WeekLayout.minimumVisibleMinutes * WeekGridView.hourHeight / 60;
    final RenderBox text = tester.renderObject<RenderBox>(find.text('Kurz'));
    expect(text.size.height, lessThanOrEqualTo(minimumBoxHeight));
  });
}
