// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

/// What the two forms and the detail view actually put on screen.
library;

import 'package:campus_koethen/core/locale/locale_mode.dart';
import 'package:campus_koethen/features/requests/application/requests_providers.dart';
import 'package:campus_koethen/features/requests/data/attachment_picker.dart';
import 'package:campus_koethen/features/requests/domain/application_location.dart';
import 'package:campus_koethen/features/requests/domain/case_status.dart';
import 'package:campus_koethen/features/requests/domain/feedback_area.dart';
import 'package:campus_koethen/features/requests/domain/request_drafts.dart';
import 'package:campus_koethen/features/requests/domain/request_gateway.dart';
import 'package:campus_koethen/features/requests/domain/status_gateway.dart';
import 'package:campus_koethen/features/requests/domain/submitted_case.dart';
import 'package:campus_koethen/features/requests/presentation/application_form_screen.dart';
import 'package:campus_koethen/features/requests/presentation/feedback_form_screen.dart';
import 'package:campus_koethen/features/requests/presentation/requests_screen.dart';
import 'package:campus_koethen/features/requests/presentation/submission_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_gremio.dart';
import '../../support/pump_app.dart';

final DateTime _now = DateTime(2026, 8, 6, 12);

const List<ApplicationLocation> _locations = <ApplicationLocation>[
  ApplicationLocation(id: 1, name: 'Standort A'),
  ApplicationLocation(id: 4, name: 'Zentrale'),
];

const List<FeedbackArea> _areas = <FeedbackArea>[
  FeedbackArea(id: 1, name: 'Bibliothek'),
  FeedbackArea(id: 2, name: 'Mensa'),
];

List<Override> _overrides({
  FlakyRequestStore? store,
  ScriptedRequestGateway? gateway,
  ScriptedStatusGateway? status,
  AsyncValue<List<ApplicationLocation>>? locations,
  AsyncValue<List<FeedbackArea>>? areas,
}) => <Override>[
  requestStoreProvider.overrideWithValue(store ?? FlakyRequestStore()),
  requestGatewayProvider.overrideWithValue(
    gateway ?? ScriptedRequestGateway(const SubmissionNotConnected()),
  ),
  statusGatewayProvider.overrideWithValue(
    status ?? ScriptedStatusGateway(const StatusUnavailable('n/a')),
  ),
  attachmentStoreProvider.overrideWithValue(FakeAttachmentStore()),
  requestsEndpointConfiguredProvider.overrideWithValue(true),
  applicationLocationsProvider.overrideWith(
    (Ref ref) async => switch (locations) {
      AsyncData<List<ApplicationLocation>>(
        :final List<ApplicationLocation> value,
      ) =>
        value,
      AsyncError<List<ApplicationLocation>>(:final Object error) => throw error,
      _ => _locations,
    },
  ),
  feedbackAreasProvider.overrideWith(
    (Ref ref) async => switch (areas) {
      AsyncData<List<FeedbackArea>>(:final List<FeedbackArea> value) => value,
      AsyncError<List<FeedbackArea>>(:final Object error) => throw error,
      _ => _areas,
    },
  ),
];

/// The order in which labels appear down the screen.
List<String> _labelOrder(WidgetTester tester, List<String> candidates) {
  final List<(double, String)> found = <(double, String)>[];
  for (final String label in candidates) {
    final Finder finder = find.text(label);
    if (finder.evaluate().isEmpty) continue;
    found.add((tester.getTopLeft(finder.first).dy, label));
  }
  found.sort(((double, String) a, (double, String) b) => a.$1.compareTo(b.$1));
  return found.map(((double, String) e) => e.$2).toList(growable: false);
}

void main() {
  group('the finance application form', () {
    testWidgets('asks for the fields in the documented order', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(430, 2600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);

      await pumpScreen(
        tester,
        const ApplicationFormScreen(),
        overrides: _overrides(),
      );
      await tester.pumpAndSettle();

      expect(
        _labelOrder(tester, <String>[
          'Standort',
          'Antragsgegenstand',
          'Antragsteller',
          'Finanzantrag',
          'Studierendenausweis',
          'Anlage A',
          'Anlage B',
        ]),
        <String>[
          'Standort',
          'Antragsgegenstand',
          'Antragsteller',
          'Finanzantrag',
          'Studierendenausweis',
          'Anlage A',
          'Anlage B',
        ],
      );
    });

    testWidgets('shows none of the invented placeholder fields', (
      WidgetTester tester,
    ) async {
      await pumpScreen(
        tester,
        const ApplicationFormScreen(),
        overrides: _overrides(),
      );
      await tester.pumpAndSettle();

      for (final String gone in <String>[
        'Betrag',
        'Verwendungszweck',
        'Kategorie',
        'Beschreibung',
        'E-Mail',
      ]) {
        expect(find.textContaining(gone), findsNothing, reason: gone);
      }
    });

    testWidgets('enforces the 200-character limit in the field itself', (
      WidgetTester tester,
    ) async {
      await pumpScreen(
        tester,
        const ApplicationFormScreen(),
        overrides: _overrides(),
      );
      await tester.pumpAndSettle();

      final Iterable<TextField> fields = tester.widgetList<TextField>(
        find.byType(TextField),
      );
      expect(fields, hasLength(2));
      for (final TextField field in fields) {
        expect(field.maxLength, 200);
      }
    });

    testWidgets('says the card is processed internally only', (
      WidgetTester tester,
    ) async {
      await pumpScreen(
        tester,
        const ApplicationFormScreen(),
        overrides: _overrides(),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('nur intern verarbeitet'), findsOneWidget);
    });

    testWidgets('offers a retry when the locations cannot be loaded', (
      WidgetTester tester,
    ) async {
      await pumpScreen(
        tester,
        const ApplicationFormScreen(),
        overrides: _overrides(
          locations: AsyncError<List<ApplicationLocation>>(
            Exception('offline'),
            StackTrace.empty,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Die Standorte konnten nicht geladen werden.'),
        findsOneWidget,
      );
      expect(find.text('Erneut laden'), findsOneWidget);
    });

    testWidgets('says so when no location is available at all', (
      WidgetTester tester,
    ) async {
      await pumpScreen(
        tester,
        const ApplicationFormScreen(),
        overrides: _overrides(
          locations: const AsyncData<List<ApplicationLocation>>(
            <ApplicationLocation>[],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Zurzeit steht kein Standort zur Auswahl.'),
        findsOneWidget,
      );
    });

    testWidgets('a failed submission keeps everything the user typed', (
      WidgetTester tester,
    ) async {
      final FlakyRequestStore store = FlakyRequestStore();
      await pumpScreen(
        tester,
        const ApplicationFormScreen(),
        overrides: _overrides(
          store: store,
          gateway: ScriptedRequestGateway(
            const SubmissionRateLimited(retryAfter: Duration(seconds: 30)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'Grillabend');
      await tester.enterText(find.byType(TextField).last, 'Testperson');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Antrag einreichen'));
      await tester.pumpAndSettle();

      // Still on screen, still filled in.
      expect(find.text('Grillabend'), findsOneWidget);
      expect(find.text('Testperson'), findsOneWidget);
      expect(
        (store.drafts.single as FinanceApplicationDraft).title,
        'Grillabend',
      );
    });
  });

  group('the feedback form', () {
    testWidgets('asks for area, optional name and text, in that order', (
      WidgetTester tester,
    ) async {
      await pumpScreen(
        tester,
        const FeedbackFormScreen(),
        overrides: _overrides(),
      );
      await tester.pumpAndSettle();

      expect(
        _labelOrder(tester, <String>[
          'Bereich',
          'Dein Name (optional)',
          'Dein Feedback',
        ]),
        <String>['Bereich', 'Dein Name (optional)', 'Dein Feedback'],
      );
      expect(
        find.textContaining('erscheint dein Feedback als'),
        findsOneWidget,
      );
      expect(find.text('Bis zu 10.000 Zeichen.'), findsOneWidget);
    });

    testWidgets('caps the name at 200 and the text at 10000', (
      WidgetTester tester,
    ) async {
      await pumpScreen(
        tester,
        const FeedbackFormScreen(),
        overrides: _overrides(),
      );
      await tester.pumpAndSettle();

      final List<TextField> fields = tester
          .widgetList<TextField>(find.byType(TextField))
          .toList();
      expect(fields.first.maxLength, 200);
      expect(fields.last.maxLength, 10000);
      expect(fields.last.minLines, 7);
    });

    testWidgets('offers a retry when the areas cannot be loaded', (
      WidgetTester tester,
    ) async {
      await pumpScreen(
        tester,
        const FeedbackFormScreen(),
        overrides: _overrides(
          areas: AsyncError<List<FeedbackArea>>(
            Exception('offline'),
            StackTrace.empty,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Die Bereiche konnten nicht geladen werden.'),
        findsOneWidget,
      );
    });

    testWidgets('a rejected submission keeps the text', (
      WidgetTester tester,
    ) async {
      await pumpScreen(
        tester,
        const FeedbackFormScreen(),
        overrides: _overrides(
          gateway: ScriptedRequestGateway(
            const SubmissionOutcomeUnknown('transport'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).last, 'Mein Hinweis');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Feedback absenden'));
      await tester.pumpAndSettle();

      expect(find.text('Mein Hinweis'), findsOneWidget);
    });
  });

  group('the main screen', () {
    testWidgets('offers both actions and both lists', (
      WidgetTester tester,
    ) async {
      await pumpScreen(tester, const RequestsScreen(), overrides: _overrides());
      await tester.pumpAndSettle();

      expect(find.text('Finanzantrag stellen'), findsOneWidget);
      expect(find.text('Feedback geben'), findsOneWidget);
      expect(find.text('Meine Einreichungen'), findsOneWidget);
      expect(find.text('Entwürfe'), findsOneWidget);
      expect(find.text('Noch nichts eingereicht.'), findsOneWidget);
    });

    testWidgets('can be pulled to refresh', (WidgetTester tester) async {
      await pumpScreen(tester, const RequestsScreen(), overrides: _overrides());
      await tester.pumpAndSettle();

      expect(find.byType(RefreshIndicator), findsOneWidget);
    });

    testWidgets('lists a submitted case with its number and status', (
      WidgetTester tester,
    ) async {
      final FlakyRequestStore store = FlakyRequestStore()
        ..cases = <SubmittedCase>[
          SubmittedCase(
            id: 'case-1',
            kind: RequestKind.financeApplication,
            submittedAt: _now,
            statusUrl: kFakeStatusUrl,
            receiptPdfUrl: kFakeReceiptUrl,
            number: 'A_0042_2026',
            localTitle: 'Grillabend am FB5',
          ),
        ];

      await pumpScreen(
        tester,
        const RequestsScreen(),
        overrides: _overrides(
          store: store,
          status: ScriptedStatusGateway(
            StatusLoaded(CaseStatus.fromJson(applicationStatusBody())!),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Grillabend am FB5'), findsOneWidget);
      expect(find.textContaining('A_0042_2026'), findsOneWidget);
      expect(find.textContaining('In Bearbeitung'), findsOneWidget);
    });
  });

  group('the detail view', () {
    Future<void> pumpDetail(
      WidgetTester tester, {
      required Map<String, dynamic> body,
      RequestKind kind = RequestKind.financeApplication,
      Locale locale = AppLocales.german,
    }) async {
      tester.view.physicalSize = const Size(430, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);

      final FlakyRequestStore store = FlakyRequestStore()
        ..cases = <SubmittedCase>[
          SubmittedCase(
            id: 'case-1',
            kind: kind,
            submittedAt: _now,
            statusUrl: kFakeStatusUrl,
            receiptPdfUrl: kFakeReceiptUrl,
            number: 'A_0042_2026',
            localTitle: 'Grillabend am FB5',
          ),
        ];

      await pumpScreen(
        tester,
        const SubmissionDetailScreen(submissionId: 'case-1'),
        locale: locale,
        overrides: _overrides(
          store: store,
          status: ScriptedStatusGateway(
            StatusLoaded(CaseStatus.fromJson(body)!),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('shows every field of an application status', (
      WidgetTester tester,
    ) async {
      await pumpDetail(
        tester,
        body: applicationStatusBody(
          publicNote: 'Bitte reiche noch eine Quittung nach.',
          archived: true,
          resubmittedAt: '2026-08-06T09:00:00.000Z',
          submitMode: 'receipt',
          canUpload: true,
          documents: <Map<String, dynamic>>[
            <String, dynamic>{
              'kind': 'finance_request',
              'label': 'Finanzantrag',
              'filename': 'Finanzantrag.pdf',
              'mimeType': 'application/pdf',
              'downloadUrl': '$kFakeBaseUrl/api/status/testtoken/attachment/12',
            },
          ],
        ),
      );

      expect(find.text('Grillabend am FB5'), findsOneWidget);
      expect(find.textContaining('A_0042_2026'), findsOneWidget);
      expect(find.text('In Bearbeitung'), findsOneWidget);
      expect(find.text('Abgeschlossen'), findsWidgets);
      expect(find.text('Testperson'), findsOneWidget);
      expect(find.textContaining('Eingereicht:'), findsOneWidget);
      expect(find.textContaining('Zuletzt geändert:'), findsOneWidget);
      expect(find.textContaining('Nachgereicht:'), findsOneWidget);
      expect(find.text('Hinweis des Gremiums'), findsOneWidget);
      expect(
        find.text('Finanzantrag'),
        findsNWidgets(2),
        reason: 'the screen title and the document share the word',
      );
      expect(find.text('Eingangsbestätigung (PDF)'), findsOneWidget);
      expect(find.text('Quittung kann eingereicht werden'), findsOneWidget);
      // The boundary is stated rather than faked.
      expect(find.textContaining('Weboberfläche'), findsOneWidget);
    });

    testWidgets('shows the full feedback text', (WidgetTester tester) async {
      await pumpDetail(
        tester,
        kind: RequestKind.feedback,
        body: feedbackStatusBody(
          text: 'Ein sehr langer Hinweis, der vollständig sichtbar sein muss.',
          submitterName: 'Max Mustermann',
        ),
      );

      expect(find.text('Bibliothek'), findsOneWidget);
      expect(find.text('Max Mustermann'), findsOneWidget);
      expect(
        find.text(
          'Ein sehr langer Hinweis, der vollständig sichtbar sein muss.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('never shows the student card or the secret link', (
      WidgetTester tester,
    ) async {
      await pumpDetail(tester, body: applicationStatusBody());

      expect(find.textContaining('Studierendenausweis'), findsNothing);
      expect(find.textContaining('testtoken'), findsNothing);
      expect(find.textContaining(kFakeStatusUrl), findsNothing);
      // It says the link exists and stays put, without printing it.
      expect(find.textContaining('einzige Zugang'), findsOneWidget);
    });

    testWidgets('says "Status nicht angegeben" for a null column name', (
      WidgetTester tester,
    ) async {
      await pumpDetail(tester, body: applicationStatusBody(name: null));

      expect(find.text('Status nicht angegeben'), findsOneWidget);
    });

    testWidgets('states plainly when no resubmission is offered', (
      WidgetTester tester,
    ) async {
      await pumpDetail(tester, body: applicationStatusBody());

      expect(
        find.text('Zurzeit ist keine Nachreichung vorgesehen.'),
        findsOneWidget,
      );
    });

    testWidgets('renders in English too', (WidgetTester tester) async {
      await pumpDetail(
        tester,
        body: applicationStatusBody(),
        locale: AppLocales.english,
      );

      expect(find.text('Documents'), findsOneWidget);
      expect(find.text('Receipt (PDF)'), findsOneWidget);
      expect(find.text('Available actions'), findsOneWidget);
    });

    testWidgets('survives a small screen with doubled text', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(320, 4000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);

      final FlakyRequestStore store = FlakyRequestStore()
        ..cases = <SubmittedCase>[
          SubmittedCase(
            id: 'case-1',
            kind: RequestKind.financeApplication,
            submittedAt: _now,
            statusUrl: kFakeStatusUrl,
            receiptPdfUrl: kFakeReceiptUrl,
            localTitle: 'Ein langer Antragsgegenstand für den Umbruchtest',
          ),
        ];

      await pumpScreen(
        tester,
        const SubmissionDetailScreen(submissionId: 'case-1'),
        textScaler: const TextScaler.linear(2),
        overrides: _overrides(
          store: store,
          status: ScriptedStatusGateway(
            StatusLoaded(CaseStatus.fromJson(applicationStatusBody())!),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('offers a retry when the status cannot be read', (
      WidgetTester tester,
    ) async {
      final FlakyRequestStore store = FlakyRequestStore()
        ..cases = <SubmittedCase>[
          SubmittedCase(
            id: 'case-1',
            kind: RequestKind.feedback,
            submittedAt: _now,
            statusUrl: kFakeStatusUrl,
            receiptPdfUrl: kFakeReceiptUrl,
          ),
        ];

      await pumpScreen(
        tester,
        const SubmissionDetailScreen(submissionId: 'case-1'),
        overrides: _overrides(
          store: store,
          status: ScriptedStatusGateway(const StatusUnavailable('transport')),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Der Status konnte nicht geladen werden.'),
        findsOneWidget,
      );
      expect(find.text('Erneut laden'), findsOneWidget);
    });

    testWidgets('a 404 does not remove the local record', (
      WidgetTester tester,
    ) async {
      final FlakyRequestStore store = FlakyRequestStore()
        ..cases = <SubmittedCase>[
          SubmittedCase(
            id: 'case-1',
            kind: RequestKind.feedback,
            submittedAt: _now,
            statusUrl: kFakeStatusUrl,
            receiptPdfUrl: kFakeReceiptUrl,
          ),
        ];

      await pumpScreen(
        tester,
        const SubmissionDetailScreen(submissionId: 'case-1'),
        overrides: _overrides(
          store: store,
          status: ScriptedStatusGateway(const StatusNotFound()),
        ),
      );
      await tester.pumpAndSettle();

      expect(store.cases, hasLength(1));
      expect(
        find.textContaining('bleibt auf dem Gerät erhalten'),
        findsOneWidget,
      );
    });
  });
}
