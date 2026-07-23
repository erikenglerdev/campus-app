// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Sommer

import 'dart:typed_data';

import 'package:campus_koethen/features/mail/application/mail_providers.dart';
import 'package:campus_koethen/features/mail/data/mail_cache.dart';
import 'package:campus_koethen/features/mail/domain/mail_cache_store.dart';
import 'package:campus_koethen/features/mail/domain/mail_credentials.dart';
import 'package:campus_koethen/features/mail/domain/mail_folder.dart';
import 'package:campus_koethen/features/mail/domain/mail_message.dart';
import 'package:campus_koethen/features/mail/presentation/compose_draft.dart';
import 'package:campus_koethen/features/mail/presentation/mail_compose_screen.dart';
import 'package:campus_koethen/features/mail/presentation/mail_message_screen.dart';
import 'package:campus_koethen/features/mail/presentation/mail_screen.dart';
import 'package:campus_koethen/features/mail/presentation/mail_search_screen.dart';
import 'package:campus_koethen/features/more/presentation/more_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_mail.dart';
import '../../support/pump_app.dart';

const MailCredentials _creds = MailCredentials(
  emailAddress: 'stud@hs-anhalt.de',
  password: 'pw',
);

List<Override> _mail(
  FakeMailGateway gateway,
  InMemoryMailCredentialStore store, {
  MailCacheStore? cache,
}) {
  return <Override>[
    mailGatewayProvider.overrideWithValue(gateway),
    mailCredentialStoreProvider.overrideWithValue(store),
    if (cache != null) mailCacheStoreProvider.overrideWithValue(cache),
  ];
}

/// The sign-in form is a tall, scrolling [ListView]. A tall surface keeps every
/// field and button laid out and hittable, so tests need no manual scrolling.
void _tallSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

/// A valid 1×1 transparent PNG, so Image.memory decodes without error.
const List<int> _pngBytes = <int>[
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x06,
  0x00,
  0x00,
  0x00,
  0x1F,
  0x15,
  0xC4,
  0x89,
  0x00,
  0x00,
  0x00,
  0x0A,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0x9C,
  0x63,
  0x00,
  0x01,
  0x00,
  0x00,
  0x05,
  0x00,
  0x01,
  0x0D,
  0x0A,
  0x2D,
  0xB4,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4E,
  0x44,
  0xAE,
  0x42,
  0x60,
  0x82,
];

MailMessageHeader _header({String id = '1'}) => MailMessageHeader(
  id: id,
  subject: 'Hallo Welt',
  from: const MailAddress(email: 'alice@hs-anhalt.de', name: 'Alice'),
  date: DateTime.utc(2026, 7, 20, 9, 30),
  isSeen: false,
  hasAttachments: false,
);

void main() {
  group('MoreScreen', () {
    testWidgets('lists the mail and settings entries', (
      WidgetTester tester,
    ) async {
      await pumpScreen(tester, const MoreScreen());
      await tester.pumpAndSettle();

      expect(find.text('Studentische E-Mail'), findsOneWidget);
      expect(find.text('Einstellungen'), findsOneWidget);
    });
  });

  group('mail gate', () {
    testWidgets('shows the sign-in screen when signed out', (
      WidgetTester tester,
    ) async {
      _tallSurface(tester);
      await pumpScreen(
        tester,
        const MailScreen(),
        overrides: _mail(FakeMailGateway(), InMemoryMailCredentialStore()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Verbindung prüfen und anmelden'), findsOneWidget);
      expect(find.text('E-Mail-Adresse'), findsOneWidget);
    });

    testWidgets('shows the cached inbox when an account is stored', (
      WidgetTester tester,
    ) async {
      final store = InMemoryMailCredentialStore()..write(_creds);
      // The INBOX is served from the offline cache — pre-populate it.
      final MemoryMailCache cache = MemoryMailCache();
      await cache.saveHeaders(<MailMessageHeader>[_header()]);
      await pumpScreen(
        tester,
        const MailScreen(),
        overrides: _mail(FakeMailGateway(), store, cache: cache),
      );
      await tester.pumpAndSettle();

      expect(find.text('Posteingang'), findsOneWidget);
      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('Hallo Welt'), findsOneWidget);
    });
  });

  group('sign in flow', () {
    testWidgets('rejects an invalid address without calling the server', (
      WidgetTester tester,
    ) async {
      _tallSurface(tester);
      final gateway = FakeMailGateway();
      await pumpScreen(
        tester,
        const MailScreen(),
        overrides: _mail(gateway, InMemoryMailCredentialStore()),
      );
      await tester.pumpAndSettle();

      // Field order: Name, Email, Password.
      await tester.enterText(find.byType(TextFormField).at(1), 'not-an-email');
      await tester.tap(find.text('Verbindung prüfen und anmelden'));
      await tester.pumpAndSettle();

      expect(
        find.text('Bitte gib eine gültige E-Mail-Adresse ein.'),
        findsOneWidget,
      );
      expect(gateway.verifyCalls, 0);
    });

    testWidgets('signs in and reveals the inbox', (WidgetTester tester) async {
      _tallSurface(tester);
      final store = InMemoryMailCredentialStore();
      final gateway = FakeMailGateway(inbox: <MailMessageHeader>[_header()]);
      await pumpScreen(
        tester,
        const MailScreen(),
        overrides: _mail(gateway, store),
      );
      await tester.pumpAndSettle();

      // Field order: Name, Email, Password.
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'Max Mustermensch',
      );
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'stud@hs-anhalt.de',
      );
      await tester.enterText(find.byType(TextFormField).at(2), 'pw');
      await tester.tap(find.text('Verbindung prüfen und anmelden'));
      await tester.pumpAndSettle();

      expect(gateway.verifyCalls, 1);
      expect(store.writes, 1);
      expect(store.lastWritten?.displayName, 'Max Mustermensch');
      // The gate switched to the inbox (its app-bar title is the folder name).
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text('Posteingang'),
        ),
        findsOneWidget,
      );
    });
  });

  group('inbox actions', () {
    testWidgets('removing the account returns to the sign-in screen', (
      WidgetTester tester,
    ) async {
      _tallSurface(tester);
      final store = InMemoryMailCredentialStore()..write(_creds);
      await pumpScreen(
        tester,
        const MailScreen(),
        overrides: _mail(
          FakeMailGateway(inbox: <MailMessageHeader>[_header()]),
          store,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Account entfernen'));
      await tester.pumpAndSettle();
      // Confirm in the dialog.
      await tester.tap(find.text('Entfernen'));
      await tester.pumpAndSettle();

      expect(store.clears, greaterThanOrEqualTo(1));
      expect(find.text('Verbindung prüfen und anmelden'), findsOneWidget);
    });
  });

  group('message detail', () {
    testWidgets('renders the plain-text body and marks it seen', (
      WidgetTester tester,
    ) async {
      final store = InMemoryMailCredentialStore()..write(_creds);
      final gateway = FakeMailGateway(
        detail: MailMessageDetail(
          id: '1',
          subject: 'Betreff',
          from: const MailAddress(email: 'alice@hs-anhalt.de', name: 'Alice'),
          to: const <MailAddress>[MailAddress(email: 'stud@hs-anhalt.de')],
          date: null,
          body: 'Dies ist der Nachrichtentext.',
          attachments: <MailAttachment>[
            MailAttachment(
              filename: 'bericht.pdf',
              mediaType: 'application/pdf',
              sizeBytes: 2048,
            ),
            MailAttachment(
              filename: 'bild.png',
              mediaType: 'image/png',
              bytes: Uint8List.fromList(_pngBytes),
            ),
          ],
        ),
      );
      await pumpScreen(
        tester,
        const MailMessageScreen(id: '1'),
        overrides: _mail(gateway, store),
      );
      await tester.pumpAndSettle();

      expect(find.text('Betreff'), findsOneWidget);
      expect(find.text('Dies ist der Nachrichtentext.'), findsOneWidget);
      expect(gateway.markedSeen, contains('1'));
      // Attachments are listed; the image previews inline because Alice's
      // address is @hs-anhalt.de (a trusted sender).
      expect(find.text('Anhänge'), findsOneWidget);
      expect(find.text('bericht.pdf'), findsOneWidget);
      expect(find.text('bild.png'), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets(
      'holds back images from untrusted senders behind "Bild laden"',
      (WidgetTester tester) async {
        final store = InMemoryMailCredentialStore()..write(_creds);
        final gateway = FakeMailGateway(
          detail: MailMessageDetail(
            id: '1',
            subject: 'Werbung',
            from: const MailAddress(email: 'promo@example.com'),
            to: const <MailAddress>[MailAddress(email: 'stud@hs-anhalt.de')],
            date: null,
            body: 'Body',
            attachments: <MailAttachment>[
              MailAttachment(
                filename: 'bild.png',
                mediaType: 'image/png',
                bytes: Uint8List.fromList(_pngBytes),
              ),
            ],
          ),
        );
        await pumpScreen(
          tester,
          const MailMessageScreen(id: '1'),
          overrides: _mail(gateway, store),
        );
        await tester.pumpAndSettle();

        // The image is not shown yet — only the "load image" button.
        expect(find.text('Bild laden'), findsOneWidget);
        expect(find.byType(Image), findsNothing);

        await tester.tap(find.text('Bild laden'));
        await tester.pumpAndSettle();

        expect(find.byType(Image), findsOneWidget);
      },
    );
  });

  group('folders', () {
    testWidgets('folder picker lists mailboxes and switches the selection', (
      WidgetTester tester,
    ) async {
      _tallSurface(tester);
      final store = InMemoryMailCredentialStore()..write(_creds);
      final gateway = FakeMailGateway(
        inbox: <MailMessageHeader>[_header()],
        folders: const <MailFolder>[
          MailFolder.inbox(),
          MailFolder(path: 'Sent', name: 'Sent', role: MailFolderRole.sent),
        ],
      );
      await pumpScreen(
        tester,
        const MailScreen(),
        overrides: _mail(gateway, store),
      );
      await tester.pumpAndSettle();

      // Open the folder picker and choose "Sent" (localised to "Gesendet").
      await tester.tap(find.byIcon(Icons.folder_outlined));
      await tester.pumpAndSettle();
      expect(find.text('Gesendet'), findsOneWidget);
      await tester.tap(find.text('Gesendet'));
      await tester.pumpAndSettle();

      // The list was re-fetched for the Sent mailbox and the title updated.
      expect(gateway.fetchedMailboxes, contains('Sent'));
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text('Gesendet'),
        ),
        findsOneWidget,
      );
    });
  });

  group('search', () {
    testWidgets('searches the server and shows non-local results', (
      WidgetTester tester,
    ) async {
      final store = InMemoryMailCredentialStore()..write(_creds);
      final gateway = FakeMailGateway(
        searchResults: <MailMessageHeader>[
          MailMessageHeader(
            id: '9',
            subject: 'Rechnung 2026',
            from: const MailAddress(
              email: 'buchhaltung@hs-anhalt.de',
              name: 'Buchhaltung',
            ),
            date: DateTime.utc(2026, 3, 1, 8),
            isSeen: true,
            hasAttachments: false,
          ),
        ],
      );
      await pumpScreen(
        tester,
        const MailSearchScreen(),
        overrides: _mail(gateway, store),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'rechnung');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      expect(gateway.lastSearchQuery, 'rechnung');
      expect(find.text('Buchhaltung'), findsOneWidget);
      expect(find.text('Rechnung 2026'), findsOneWidget);
    });
  });

  group('compose', () {
    testWidgets('rejects an invalid recipient without sending', (
      WidgetTester tester,
    ) async {
      final store = InMemoryMailCredentialStore()..write(_creds);
      final gateway = FakeMailGateway();
      await pumpScreen(
        tester,
        const MailComposeScreen(),
        overrides: _mail(gateway, store),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).first, 'nonsense');
      await tester.tap(find.byIcon(Icons.send_outlined));
      await tester.pumpAndSettle();

      expect(
        find.text('Bitte gib eine gültige Empfängeradresse ein.'),
        findsOneWidget,
      );
      expect(gateway.sendCalls, 0);
    });

    testWidgets('sends a message and confirms', (WidgetTester tester) async {
      final store = InMemoryMailCredentialStore()..write(_creds);
      final gateway = FakeMailGateway();
      await pumpScreen(
        tester,
        const MailComposeScreen(),
        overrides: _mail(gateway, store),
      );
      await tester.pumpAndSettle();

      // Field order: To, Cc, Subject, Body.
      await tester.enterText(find.byType(TextFormField).at(0), 'x@y.de');
      await tester.enterText(find.byType(TextFormField).at(2), 'Betreff');
      await tester.enterText(find.byType(TextFormField).at(3), 'Text');
      await tester.tap(find.byIcon(Icons.send_outlined));
      await tester.pumpAndSettle();

      expect(gateway.sendCalls, 1);
      expect(gateway.sent.single.to, <String>['x@y.de']);
      expect(find.text('Nachricht gesendet.'), findsOneWidget);
    });

    testWidgets('prefills recipients and subject from a reply draft', (
      WidgetTester tester,
    ) async {
      final store = InMemoryMailCredentialStore()..write(_creds);
      final gateway = FakeMailGateway();
      await pumpScreen(
        tester,
        const MailComposeScreen(
          draft: ComposeDraft(
            to: <String>['alice@hs-anhalt.de'],
            cc: <String>['bob@hs-anhalt.de'],
            subject: 'Re: Hallo',
          ),
        ),
        overrides: _mail(gateway, store),
      );
      await tester.pumpAndSettle();

      expect(find.text('alice@hs-anhalt.de'), findsOneWidget);
      expect(find.text('bob@hs-anhalt.de'), findsOneWidget);
      expect(find.text('Re: Hallo'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.send_outlined));
      await tester.pumpAndSettle();

      expect(gateway.sent.single.to, <String>['alice@hs-anhalt.de']);
      expect(gateway.sent.single.cc, <String>['bob@hs-anhalt.de']);
    });
  });
}
