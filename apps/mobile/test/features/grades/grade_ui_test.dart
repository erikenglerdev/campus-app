// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import 'package:campus_koethen/features/grades/application/grades_providers.dart';
import 'package:campus_koethen/features/grades/domain/grade_credentials.dart';
import 'package:campus_koethen/features/grades/presentation/grades_screen.dart';
import 'package:campus_koethen/features/more/presentation/more_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_grades.dart';
import '../../support/pump_app.dart';

const GradeCredentials _creds = GradeCredentials(
  username: 'testuser',
  password: 'test-pw',
);
final DateTime _t0 = DateTime.utc(2026, 7, 26, 12);

List<Override> _grades({
  required FakeGradesGateway gateway,
  required InMemoryGradeCredentialStore store,
  required InMemoryGradeCacheStore cache,
  MutableClock? clock,
}) {
  return <Override>[
    gradesGatewayProvider.overrideWithValue(gateway),
    gradeCredentialStoreProvider.overrideWithValue(store),
    gradeCacheStoreProvider.overrideWithValue(cache),
    gradeClockProvider.overrideWithValue(clock ?? MutableClock(_t0)),
  ];
}

void _tall(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('More lists the grades entry', (WidgetTester tester) async {
    await pumpScreen(tester, const MoreScreen());
    await tester.pumpAndSettle();
    expect(find.text('Noten'), findsOneWidget);
  });

  testWidgets('gate shows the setup screen when signed out', (
    WidgetTester tester,
  ) async {
    _tall(tester);
    await pumpScreen(
      tester,
      const GradesScreen(),
      overrides: _grades(
        gateway: FakeGradesGateway(),
        store: InMemoryGradeCredentialStore(),
        cache: InMemoryGradeCacheStore(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Anmelden und Noten laden'), findsOneWidget);
    expect(find.text('Benutzername'), findsOneWidget);
  });

  testWidgets('setup requires consent before contacting the portal', (
    WidgetTester tester,
  ) async {
    _tall(tester);
    final gateway = FakeGradesGateway(report: sampleReport());
    await pumpScreen(
      tester,
      const GradesScreen(),
      overrides: _grades(
        gateway: gateway,
        store: InMemoryGradeCredentialStore(),
        cache: InMemoryGradeCacheStore(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), 'testuser');
    await tester.enterText(find.byType(TextFormField).at(1), 'test-pw');
    await tester.tap(find.text('Anmelden und Noten laden'));
    await tester.pumpAndSettle();

    expect(
      find.text('Bitte stimme der lokalen Speicherung zu.'),
      findsOneWidget,
    );
    expect(gateway.fetchCalls, 0);
  });

  testWidgets('setup signs in and reveals the overview', (
    WidgetTester tester,
  ) async {
    _tall(tester);
    final gateway = FakeGradesGateway(report: sampleReport('Grundlagen'));
    final store = InMemoryGradeCredentialStore();
    final cache = InMemoryGradeCacheStore();
    await pumpScreen(
      tester,
      const GradesScreen(),
      overrides: _grades(gateway: gateway, store: store, cache: cache),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), 'testuser');
    await tester.enterText(find.byType(TextFormField).at(1), 'test-pw');
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Anmelden und Noten laden'));
    await tester.pumpAndSettle();

    expect(gateway.fetchCalls, 1);
    expect(store.writes, 1);
    expect(find.text('Grundlagen'), findsOneWidget);
    expect(find.textContaining('Zuletzt aktualisiert'), findsOneWidget);
  });

  testWidgets('overview shows the cached grades without an auto sync', (
    WidgetTester tester,
  ) async {
    final gateway = FakeGradesGateway();
    final store = InMemoryGradeCredentialStore()..write(_creds);
    final cache = InMemoryGradeCacheStore();
    await cache.writeReport(sampleReport('Grundlagen'));
    await cache.writeLastSuccessfulSync(_t0);
    await cache.writeLastAttemptedSync(_t0); // within 24h → no auto sync

    await pumpScreen(
      tester,
      const GradesScreen(),
      overrides: _grades(gateway: gateway, store: store, cache: cache),
    );
    await tester.pumpAndSettle();

    expect(find.text('Grundlagen'), findsOneWidget);
    expect(gateway.fetchCalls, 0, reason: 'the 24h gate blocks the auto sync');
  });

  testWidgets('delete asks for confirmation and returns to setup', (
    WidgetTester tester,
  ) async {
    _tall(tester);
    final store = InMemoryGradeCredentialStore()..write(_creds);
    final cache = InMemoryGradeCacheStore();
    await cache.writeReport(sampleReport());
    await cache.writeLastSuccessfulSync(_t0);
    await cache.writeLastAttemptedSync(_t0);

    await pumpScreen(
      tester,
      const GradesScreen(),
      overrides: _grades(
        gateway: FakeGradesGateway(),
        store: store,
        cache: cache,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Zugangsdaten und lokale Noten löschen'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Löschen'));
    await tester.pumpAndSettle();

    expect(store.clears, greaterThanOrEqualTo(1));
    expect(cache.clears, greaterThanOrEqualTo(1));
    expect(find.text('Anmelden und Noten laden'), findsOneWidget);
  });
}
