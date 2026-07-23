// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Sommer

import 'package:campus_koethen/features/mail/application/mail_providers.dart';
import 'package:campus_koethen/features/mail/domain/mail_credentials.dart';
import 'package:campus_koethen/features/mail/domain/mail_message.dart';
import 'package:campus_koethen/features/mail/presentation/compose_draft.dart';
import 'package:campus_koethen/features/mail/presentation/mail_compose_screen.dart';
import 'package:campus_koethen/features/mail/presentation/mail_message_screen.dart';
import 'package:campus_koethen/features/mail/presentation/mail_screen.dart';
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
  InMemoryMailCredentialStore store,
) {
  return <Override>[
    mailGatewayProvider.overrideWithValue(gateway),
    mailCredentialStoreProvider.overrideWithValue(store),
  ];
}

/// The sign-in form is a tall, scrolling [ListView]. A tall surface keeps every
/// field and button laid out and hittable, so tests need no manual scrolling.
void _tallSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

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

    testWidgets('shows the inbox when an account is stored', (
      WidgetTester tester,
    ) async {
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
      expect(find.text('Posteingang'), findsOneWidget);
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
        detail: const MailMessageDetail(
          id: '1',
          subject: 'Betreff',
          from: MailAddress(email: 'alice@hs-anhalt.de', name: 'Alice'),
          to: <MailAddress>[MailAddress(email: 'stud@hs-anhalt.de')],
          date: null,
          body: 'Dies ist der Nachrichtentext.',
          hasUnsupportedAttachments: false,
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
