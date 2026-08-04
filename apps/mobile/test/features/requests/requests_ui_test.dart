// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import 'package:campus_koethen/core/locale/locale_mode.dart';
import 'package:campus_koethen/features/requests/application/requests_controller.dart';
import 'package:campus_koethen/features/requests/domain/request_models.dart';
import 'package:campus_koethen/features/requests/domain/request_store.dart';
import 'package:campus_koethen/features/requests/presentation/request_draft_screen.dart';
import 'package:campus_koethen/features/requests/presentation/requests_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../../support/pump_app.dart';

Future<ProviderContainer> pumpRequests(
  WidgetTester tester,
  Widget screen, {
  RequestStore? store,
  Locale locale = AppLocales.german,
  TextScaler textScaler = TextScaler.noScaling,
  Size surface = const Size(390, 3600),
  List<Override> extraOverrides = const <Override>[],
}) async {
  tester.view.physicalSize = surface;
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  final ProviderContainer container = await pumpScreen(
    tester,
    screen,
    locale: locale,
    textScaler: textScaler,
    overrides: <Override>[
      requestStoreProvider.overrideWithValue(store ?? InMemoryRequestStore()),
      ...extraOverrides,
    ],
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  group('endpoint notice', _endpointNoticeTests);

  group('overview', () {
    testWidgets('says up front that nothing can be submitted yet', (
      WidgetTester tester,
    ) async {
      // A form that looks like it files an application, and does not, is worse
      // than no form at all — so this is stated before anything can be typed.
      await pumpRequests(tester, const RequestsScreen());

      expect(find.text('Übermittlung noch nicht angebunden'), findsOneWidget);
      expect(
        find.textContaining('keine vereinbarte Empfangsstelle'),
        findsOneWidget,
      );
    });

    testWidgets('offers both kinds', (WidgetTester tester) async {
      await pumpRequests(tester, const RequestsScreen());
      expect(find.text('Finanzantrag'), findsOneWidget);
      expect(find.text('Feedback'), findsOneWidget);
    });

    testWidgets('an empty list says so', (WidgetTester tester) async {
      await pumpRequests(tester, const RequestsScreen());
      expect(find.text('Noch keine Entwürfe.'), findsWidgets);
    });

    testWidgets('stored drafts are listed newest first', (
      WidgetTester tester,
    ) async {
      final InMemoryRequestStore store = InMemoryRequestStore();
      await store.writeDrafts(<RequestDraft>[
        RequestDraft(
          id: 'old',
          kind: RequestKind.feedback,
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
          idempotencyKey: 'test-key-0000000000',
          title: 'Älterer Entwurf',
          description: 'x',
        ),
        RequestDraft(
          id: 'new',
          kind: RequestKind.financeApplication,
          createdAt: DateTime(2026, 5, 1),
          updatedAt: DateTime(2026, 5, 1),
          idempotencyKey: 'test-key-0000000000',
          title: 'Neuerer Entwurf',
          description: 'y',
        ),
      ]);

      await pumpRequests(tester, const RequestsScreen(), store: store);

      final double newer = tester.getTopLeft(find.text('Neuerer Entwurf')).dy;
      final double older = tester.getTopLeft(find.text('Älterer Entwurf')).dy;
      expect(newer, lessThan(older));
    });
  });

  group('draft editor', () {
    testWidgets('a finance application asks for amount and purpose', (
      WidgetTester tester,
    ) async {
      await pumpRequests(
        tester,
        const RequestDraftScreen(
          draftId: 'new',
          kind: RequestKind.financeApplication,
        ),
      );

      expect(find.text('Beantragter Betrag'), findsOneWidget);
      expect(find.text('Verwendungszweck'), findsOneWidget);
    });

    testWidgets('feedback asks for neither', (WidgetTester tester) async {
      await pumpRequests(
        tester,
        const RequestDraftScreen(draftId: 'new', kind: RequestKind.feedback),
      );

      expect(find.text('Beantragter Betrag'), findsNothing);
      expect(find.text('Verwendungszweck'), findsNothing);
      expect(find.text('Beschreibung'), findsOneWidget);
    });

    testWidgets(
      'saving does not validate — a half-written draft is the point',
      (WidgetTester tester) async {
        final InMemoryRequestStore store = InMemoryRequestStore();
        await pumpRequests(
          tester,
          const RequestDraftScreen(draftId: 'new', kind: RequestKind.feedback),
          store: store,
        );

        await tester.enterText(
          find.byType(TextFormField).first,
          'Nur ein Titel',
        );
        await tester.tap(find.text('Entwurf speichern'));
        await tester.pumpAndSettle();

        expect(find.text('Entwurf gespeichert.'), findsOneWidget);
        expect(find.text('Bitte eine Beschreibung angeben.'), findsNothing);
        final List<RequestDraft> saved = await store.readDrafts();
        expect(saved, hasLength(1));
        expect(saved.single.title, 'Nur ein Titel');
      },
    );

    testWidgets('submitting an incomplete draft shows the field errors', (
      WidgetTester tester,
    ) async {
      await pumpRequests(
        tester,
        const RequestDraftScreen(
          draftId: 'new',
          kind: RequestKind.financeApplication,
        ),
      );

      await tester.tap(find.text('Einreichen'));
      await tester.pumpAndSettle();

      expect(find.text('Bitte einen Titel angeben.'), findsOneWidget);
      expect(find.text('Bitte eine Kategorie wählen.'), findsOneWidget);
      expect(find.text('Bitte einen Betrag angeben.'), findsOneWidget);
      expect(find.text('Bitte den Verwendungszweck angeben.'), findsOneWidget);
      expect(find.text('Bitte eine Beschreibung angeben.'), findsOneWidget);
    });

    testWidgets('a complete draft is told that submission is not connected', (
      WidgetTester tester,
    ) async {
      // The decisive assertion of this whole feature: never a confirmation.
      final InMemoryRequestStore store = InMemoryRequestStore();
      await store.writeDrafts(<RequestDraft>[
        RequestDraft(
          id: 'complete',
          kind: RequestKind.feedback,
          createdAt: DateTime(2026, 5, 1),
          updatedAt: DateTime(2026, 5, 1),
          idempotencyKey: 'test-key-0000000000',
          title: 'Vollständig',
          category: 'general',
          description: 'Eine ausreichend lange Beschreibung.',
        ),
      ]);

      await pumpRequests(
        tester,
        const RequestDraftScreen(
          draftId: 'complete',
          kind: RequestKind.feedback,
        ),
        store: store,
      );

      await tester.tap(find.text('Einreichen'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Für diese Fassung ist keine Empfangsstelle hinterlegt. '
          'Es wurde nichts übermittelt.',
        ),
        findsOneWidget,
      );
      // No wording that could read as a confirmation.
      expect(find.textContaining('eingereicht'), findsNothing);
      expect(find.textContaining('erfolgreich'), findsNothing);
    });

    testWidgets('an invalid amount is reported rather than rounded', (
      WidgetTester tester,
    ) async {
      await pumpRequests(
        tester,
        const RequestDraftScreen(
          draftId: 'new',
          kind: RequestKind.financeApplication,
        ),
      );

      final Finder amount = find.ancestor(
        of: find.text('Beantragter Betrag'),
        matching: find.byType(TextFormField),
      );
      await tester.enterText(amount, '12,345');
      await tester.tap(find.text('Einreichen'));
      await tester.pumpAndSettle();

      expect(
        find.text('Bitte einen Betrag wie 120,50 angeben.'),
        findsOneWidget,
      );
    });
  });

  group('deleting', () {
    testWidgets('a draft can be deleted after confirming', (
      WidgetTester tester,
    ) async {
      final InMemoryRequestStore store = InMemoryRequestStore();
      await store.writeDrafts(<RequestDraft>[
        RequestDraft(
          id: 'x',
          kind: RequestKind.feedback,
          createdAt: DateTime(2026, 5, 1),
          updatedAt: DateTime(2026, 5, 1),
          idempotencyKey: 'test-key-0000000000',
          title: 'Wegwerfentwurf',
          description: 'x',
        ),
      ]);

      await pumpRequests(tester, const RequestsScreen(), store: store);
      expect(find.text('Wegwerfentwurf'), findsOneWidget);

      await tester.tap(find.byTooltip('Entwurf löschen'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Entwurf löschen'));
      await tester.pumpAndSettle();

      expect(find.text('Wegwerfentwurf'), findsNothing);
      expect(await store.readDrafts(), isEmpty);
    });
  });

  testWidgets('renders in English', (WidgetTester tester) async {
    await pumpRequests(
      tester,
      const RequestsScreen(),
      locale: AppLocales.english,
    );
    expect(find.text('Submission not connected yet'), findsOneWidget);
    expect(find.text('Finance application'), findsOneWidget);
  });

  testWidgets('the editor survives a narrow phone with doubled text', (
    WidgetTester tester,
  ) async {
    await pumpRequests(
      tester,
      const RequestDraftScreen(
        draftId: 'new',
        kind: RequestKind.financeApplication,
      ),
      textScaler: const TextScaler.linear(2),
      surface: const Size(320, 3000),
    );

    expect(tester.takeException(), isNull);
  });
}

void _endpointNoticeTests() {
  testWidgets('the "not connected" notice disappears once it is untrue', (
    WidgetTester tester,
  ) async {
    // The notice is a factual claim about this build. A build that can submit
    // must not keep making it.
    await pumpRequests(
      tester,
      const RequestsScreen(),
      extraOverrides: <Override>[
        requestsEndpointConfiguredProvider.overrideWithValue(true),
      ],
    );

    expect(find.text('Übermittlung noch nicht angebunden'), findsNothing);
    expect(find.text('Finanzantrag'), findsOneWidget);
  });

  testWidgets('and is shown while it is true', (WidgetTester tester) async {
    await pumpRequests(
      tester,
      const RequestsScreen(),
      extraOverrides: <Override>[
        requestsEndpointConfiguredProvider.overrideWithValue(false),
      ],
    );

    expect(find.text('Übermittlung noch nicht angebunden'), findsOneWidget);
  });
}
