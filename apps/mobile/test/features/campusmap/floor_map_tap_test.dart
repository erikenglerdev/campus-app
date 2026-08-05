// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

/// Tapping a room on the plan must select that room — before and after the
/// reader has zoomed and dragged.
///
/// The hit test itself is a pure function with its own tests; what these tests
/// guard is the part that cannot be checked in isolation: that a screen
/// coordinate arrives in the geometry's coordinate system at all, whatever the
/// current pan and zoom are.
library;

import 'package:campus_koethen/core/locale/locale_mode.dart';
import 'package:campus_koethen/features/campusmap/domain/map_catalog.dart';
import 'package:campus_koethen/features/campusmap/presentation/floor_map_view.dart';
import 'package:campus_koethen/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const MapFloor _floor = MapFloor(
  floorKey: 'demo-north-level2',
  buildingKey: 'demo-north',
  level: 2,
  name: LocalisedName(de: '2. Obergeschoss', en: 'Second floor'),
  svgAsset: 'assets/maps/demo-north/level2.svg',
  viewBox: Rect.fromLTWH(0, 0, 1000, 1000),
  sortOrder: 10,
);

MapRoomGeometry _room(String key, Rect bounds) => MapRoomGeometry(
  roomKey: key,
  buildingKey: 'demo-north',
  floorKey: 'demo-north-level2',
  svgElementId: key,
  focus: bounds.center,
  bounds: bounds,
);

/// Top-left quarter and bottom-right quarter, with plenty of floor between.
final MapRoomGeometry _a = _room('a', const Rect.fromLTWH(0, 0, 300, 300));
final MapRoomGeometry _b = _room('b', const Rect.fromLTWH(700, 700, 300, 300));

const Size _viewport = Size(500, 500);

Future<List<String>> _pump(
  WidgetTester tester, {
  MapRoomGeometry? selected,
}) async {
  tester.view.physicalSize = const Size(700, 700);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  final List<String> tapped = <String>[];
  await tester.pumpWidget(
    MaterialApp(
      locale: AppLocales.german,
      supportedLocales: AppLocales.supported,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: _viewport.width,
            height: _viewport.height,
            child: FloorMapView(
              floor: _floor,
              rooms: <MapRoomGeometry>[_a, _b],
              selected: selected,
              onRoomTap: tapped.add,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return tapped;
}

/// The centre of the plan area, in screen coordinates.
Offset _planCentre(WidgetTester tester) =>
    tester.getCenter(find.byType(FloorMapView));

void main() {
  testWidgets('a tap on a room reports that room', (WidgetTester tester) async {
    final List<String> tapped = await _pump(tester);
    final Offset centre = _planCentre(tester);

    // The plan is 1000x1000 in a 500x500 box: one plan unit is half a pixel,
    // and the centre of the view is plan (500, 500). Room "a" fills the
    // top-left quarter.
    await tester.tapAt(centre - const Offset(150, 150));
    await tester.pumpAndSettle();

    expect(tapped, <String>['a']);
  });

  testWidgets('a tap on empty floor does nothing at all', (
    WidgetTester tester,
  ) async {
    final List<String> tapped = await _pump(tester);

    // Dead centre: between the two rooms and far from both.
    await tester.tapAt(_planCentre(tester));
    await tester.pumpAndSettle();

    expect(tapped, isEmpty);
  });

  testWidgets('the other room is the other room', (WidgetTester tester) async {
    final List<String> tapped = await _pump(tester);

    await tester.tapAt(_planCentre(tester) + const Offset(150, 150));
    await tester.pumpAndSettle();

    expect(tapped, <String>['b']);
  });

  testWidgets('it still works after zooming and dragging', (
    WidgetTester tester,
  ) async {
    // The real risk: a hand-rolled coordinate transform that is only correct at
    // scale 1. Selecting a room zooms and pans the plan, so this is the state
    // the map is in most of the time.
    final List<String> tapped = await _pump(tester, selected: _a);
    expect(
      tester
          .state<FloorMapViewState>(find.byType(FloorMapView))
          .currentTransform,
      isNot(Matrix4.identity()),
      reason: 'the selection must actually have moved the plan',
    );

    // Room "a" is now centred in the viewport, so its own centre is what a tap
    // in the middle of the view hits.
    await tester.tapAt(_planCentre(tester));
    await tester.pumpAndSettle();

    expect(tapped, <String>['a']);
  });

  testWidgets('the plan can still be dragged', (WidgetTester tester) async {
    // A tap detector that swallowed drags would trade one gesture for another.
    final List<String> tapped = await _pump(tester, selected: _a);
    final FloorMapViewState state = tester.state<FloorMapViewState>(
      find.byType(FloorMapView),
    );
    final Matrix4 before = state.currentTransform.clone();

    await tester.drag(find.byType(FloorMapView), const Offset(-80, -40));
    await tester.pumpAndSettle();

    expect(state.currentTransform, isNot(before));
    expect(tapped, isEmpty, reason: 'a drag is not a tap');
  });

  testWidgets('a room outside the given list never answers', (
    WidgetTester tester,
  ) async {
    // The screen passes only the visible floor; this is the guard that the
    // widget does not go looking for more.
    final List<String> tapped = <String>[];
    tester.view.physicalSize = const Size(700, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        locale: AppLocales.german,
        supportedLocales: AppLocales.supported,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: _viewport.width,
              height: _viewport.height,
              child: FloorMapView(
                floor: _floor,
                rooms: const <MapRoomGeometry>[],
                selected: null,
                onRoomTap: tapped.add,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tapAt(_planCentre(tester) - const Offset(150, 150));
    await tester.pumpAndSettle();

    expect(tapped, isEmpty);
  });
}
