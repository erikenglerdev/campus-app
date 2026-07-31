// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

/// Selecting a room must bring THAT room into view.
///
/// The plan is laid out inside a `Center`, so it is offset within the viewport
/// whenever it does not fill it completely. Focusing in plain plan coordinates
/// therefore lands next to the intended room — which is exactly what the first
/// real run in a browser showed: picking B.222 scrolled to B.216.
library;

import 'package:campus_koethen/features/campusmap/domain/map_catalog.dart';
import 'package:campus_koethen/core/locale/locale_mode.dart';
import 'package:campus_koethen/features/campusmap/presentation/floor_map_view.dart';
import 'package:campus_koethen/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const MapFloor _floor = MapFloor(
  floorKey: 'demo-north-level2',
  buildingKey: 'demo-north',
  level: 2,
  svgAsset: 'assets/maps/demo-north/level2.svg',
  viewBox: Rect.fromLTWH(0, 0, 1900, 1080),
  sortOrder: 10,
);

MapRoomGeometry _room({required Offset focus, required Rect bounds}) =>
    MapRoomGeometry(
      roomKey: 'demo-north-level2-b222',
      buildingKey: 'demo-north',
      floorKey: 'demo-north-level2',
      svgElementId: 'room-demo-north-level2-b222',
      focus: focus,
      bounds: bounds,
    );

Future<GlobalKey<FloorMapViewState>> pumpMap(
  WidgetTester tester, {
  MapRoomGeometry? selected,
  Size viewport = const Size(1200, 400),
}) async {
  // The default 800x600 test surface would silently shrink the requested
  // viewport and make the expectations below measure something else.
  tester.view.physicalSize = Size(viewport.width + 200, viewport.height + 200);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  final GlobalKey<FloorMapViewState> key = GlobalKey<FloorMapViewState>();
  await tester.pumpWidget(
    MaterialApp(
      locale: AppLocales.german,
      supportedLocales: AppLocales.supported,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: viewport.width,
            height: viewport.height,
            child: FloorMapView(key: key, floor: _floor, selected: selected),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return key;
}

/// Where a point of the PLAN ends up inside the viewport.
Offset planPointInViewport(
  FloorMapViewState state,
  Offset planPoint,
  Size viewport,
) {
  final double planScale = state.planScale;
  final Size planSize = Size(
    _floor.viewBox.width * planScale,
    _floor.viewBox.height * planScale,
  );
  // The plan sits centred inside the viewport before the transform applies.
  final Offset origin = Offset(
    (viewport.width - planSize.width) / 2,
    (viewport.height - planSize.height) / 2,
  );
  final Offset inChild = origin + planPoint * planScale;
  return MatrixUtils.transformPoint(state.currentTransform, inChild);
}

void main() {
  testWidgets('without a selection the plan is shown untransformed', (
    WidgetTester tester,
  ) async {
    final GlobalKey<FloorMapViewState> key = await pumpMap(tester);
    expect(key.currentState!.currentTransform, Matrix4.identity());
  });

  testWidgets('a selected room lands in the middle of the viewport', (
    WidgetTester tester,
  ) async {
    const Size viewport = Size(1200, 400);
    // A room low and left of centre — the case the browser run got wrong.
    final MapRoomGeometry room = _room(
      focus: const Offset(775, 570),
      bounds: const Rect.fromLTWH(725, 480, 100, 180),
    );

    final GlobalKey<FloorMapViewState> key = await pumpMap(
      tester,
      selected: room,
      viewport: viewport,
    );

    final Offset landed = planPointInViewport(
      key.currentState!,
      room.focus,
      viewport,
    );

    expect(
      landed.dx,
      closeTo(viewport.width / 2, 1.0),
      reason: 'the focused room must be centred horizontally',
    );
    expect(
      landed.dy,
      closeTo(viewport.height / 2, 1.0),
      reason: 'the focused room must be centred vertically',
    );
  });

  testWidgets('a room at the far right is centred just as precisely', (
    WidgetTester tester,
  ) async {
    const Size viewport = Size(1200, 400);
    final MapRoomGeometry room = _room(
      focus: const Offset(1750, 300),
      bounds: const Rect.fromLTWH(1700, 200, 100, 200),
    );

    final GlobalKey<FloorMapViewState> key = await pumpMap(
      tester,
      selected: room,
      viewport: viewport,
    );

    final Offset landed = planPointInViewport(
      key.currentState!,
      room.focus,
      viewport,
    );
    expect(landed.dx, closeTo(viewport.width / 2, 1.0));
    expect(landed.dy, closeTo(viewport.height / 2, 1.0));
  });

  testWidgets('resetting returns to the untransformed overview', (
    WidgetTester tester,
  ) async {
    final GlobalKey<FloorMapViewState> key = await pumpMap(
      tester,
      selected: _room(
        focus: const Offset(775, 570),
        bounds: const Rect.fromLTWH(725, 480, 100, 180),
      ),
    );
    expect(key.currentState!.currentTransform, isNot(Matrix4.identity()));

    key.currentState!.resetView();
    await tester.pumpAndSettle();
    expect(key.currentState!.currentTransform, Matrix4.identity());
  });
}
