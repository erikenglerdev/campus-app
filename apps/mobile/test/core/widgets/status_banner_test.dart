// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import 'package:campus_koethen/core/widgets/status_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/pump_app.dart';

const StatusBanner _banner = StatusBanner(
  title: 'Lageplan',
  message: 'Der mitgelieferte Plan passt nicht zur aktuellen Raumliste.',
  tone: StatusTone.warning,
  icon: Icons.map_outlined,
);

Future<double> heightIn(WidgetTester tester, Widget parent) async {
  await pumpScreen(tester, parent);
  await tester.pumpAndSettle();
  return tester.renderObject<RenderBox>(find.byType(StatusBanner)).size.height;
}

void main() {
  testWidgets('hugs its content when the height is bounded', (
    WidgetTester tester,
  ) async {
    // The banner was written for a scrolling list, where the height is
    // unbounded and a `MainAxisSize.max` column happens to hug its children.
    // Put the same widget in a box that HAS a height — a centred empty state,
    // for instance — and it stretched to fill all of it, turning a three-line
    // hint into a full-screen slab that hid everything behind it.
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final double height = await heightIn(
      tester,
      const Scaffold(
        body: SizedBox(height: 700, child: Center(child: _banner)),
      ),
    );

    expect(
      height,
      lessThan(300),
      reason: 'the banner filled the box instead of sizing to its text',
    );
  });

  testWidgets('is the same height bounded as unbounded', (
    WidgetTester tester,
  ) async {
    // The real invariant: how tall the banner is must follow from its content,
    // not from what happens to be around it.
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final double inList = await heightIn(
      tester,
      Scaffold(body: ListView(children: const <Widget>[_banner])),
    );
    final double inBox = await heightIn(
      tester,
      const Scaffold(
        body: SizedBox(height: 700, child: Center(child: _banner)),
      ),
    );

    expect(inBox, inList);
  });

  testWidgets('a title-only banner is shorter than one with a message', (
    WidgetTester tester,
  ) async {
    final double withMessage = await heightIn(
      tester,
      Scaffold(body: ListView(children: const <Widget>[_banner])),
    );
    final double titleOnly = await heightIn(
      tester,
      Scaffold(
        body: ListView(
          children: const <Widget>[StatusBanner(title: 'Lageplan')],
        ),
      ),
    );

    expect(titleOnly, lessThan(withMessage));
  });
}
