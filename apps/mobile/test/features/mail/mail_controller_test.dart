// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Sommer

import 'dart:async';

import 'package:campus_koethen/features/mail/application/mail_account_controller.dart';
import 'package:campus_koethen/features/mail/application/mail_compose_controller.dart';
import 'package:campus_koethen/features/mail/application/mail_inbox_controller.dart';
import 'package:campus_koethen/features/mail/application/mail_providers.dart';
import 'package:campus_koethen/features/mail/domain/mail_credentials.dart';
import 'package:campus_koethen/features/mail/domain/mail_failure.dart';
import 'package:campus_koethen/features/mail/domain/mail_gateway.dart';
import 'package:campus_koethen/features/mail/domain/mail_message.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_mail.dart';

const MailCredentials _creds = MailCredentials(
  emailAddress: 'stud@hs-anhalt.de',
  password: 'pw',
);

ProviderContainer _container({
  required FakeMailGateway gateway,
  required InMemoryMailCredentialStore store,
}) {
  final ProviderContainer container = ProviderContainer(
    overrides: <Override>[
      mailGatewayProvider.overrideWithValue(gateway),
      mailCredentialStoreProvider.overrideWithValue(store),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('account load', () {
    test('starts signed out when the store is empty', () async {
      final container = _container(
        gateway: FakeMailGateway(),
        store: InMemoryMailCredentialStore(),
      );
      final MailAccountState state = await container.read(
        mailAccountControllerProvider.future,
      );
      expect(state.emailAddress, isNull);
      expect(state.isSignedIn, isFalse);
    });

    test(
      'restores a stored account on start (address only, no password in state)',
      () async {
        final store = InMemoryMailCredentialStore()..write(_creds);
        final container = _container(gateway: FakeMailGateway(), store: store);

        final MailAccountState state = await container.read(
          mailAccountControllerProvider.future,
        );
        expect(state.isSignedIn, isTrue);
        expect(state.emailAddress, 'stud@hs-anhalt.de');
        // The exposed state must never carry the password.
        expect(state.toString().contains('pw'), isFalse);
      },
    );
  });

  group('sign in', () {
    test('verifies IMAP+SMTP then stores credentials on success', () async {
      final gateway = FakeMailGateway();
      final store = InMemoryMailCredentialStore();
      final container = _container(gateway: gateway, store: store);
      final controller = container.read(mailAccountControllerProvider.notifier);

      await container.read(mailAccountControllerProvider.future);
      await controller.signIn(email: '  stud@hs-anhalt.de ', password: 'pw');

      expect(gateway.verifyCalls, 1);
      expect(store.writes, 1, reason: 'credentials stored only after verify');
      final state = container.read(mailAccountControllerProvider).requireValue;
      expect(state.isSignedIn, isTrue);
      expect(state.emailAddress, 'stud@hs-anhalt.de');
    });

    test('rejects an invalid email without ever calling the server', () async {
      final gateway = FakeMailGateway();
      final store = InMemoryMailCredentialStore();
      final container = _container(gateway: gateway, store: store);
      final controller = container.read(mailAccountControllerProvider.notifier);
      await container.read(mailAccountControllerProvider.future);

      await expectLater(
        controller.signIn(email: 'not-an-email', password: 'pw'),
        throwsA(
          isA<MailFailure>().having(
            (e) => e.kind,
            'kind',
            MailFailureKind.invalidEmail,
          ),
        ),
      );
      expect(gateway.verifyCalls, 0);
      expect(store.writes, 0);
    });

    test('does NOT store credentials when verification fails', () async {
      final gateway = FakeMailGateway(
        verifyError: const MailFailure(MailFailureKind.invalidCredentials),
      );
      final store = InMemoryMailCredentialStore();
      final container = _container(gateway: gateway, store: store);
      final controller = container.read(mailAccountControllerProvider.notifier);
      await container.read(mailAccountControllerProvider.future);

      await expectLater(
        controller.signIn(email: 'stud@hs-anhalt.de', password: 'wrong'),
        throwsA(isA<MailFailure>()),
      );
      expect(store.writes, 0);
      expect(
        container.read(mailAccountControllerProvider).requireValue.isSignedIn,
        isFalse,
      );
    });

    test('surfaces a secure-storage failure and stays signed out', () async {
      final gateway = FakeMailGateway();
      final store = InMemoryMailCredentialStore(available: false);
      final container = _container(gateway: gateway, store: store);
      final controller = container.read(mailAccountControllerProvider.notifier);
      await container.read(mailAccountControllerProvider.future);

      await expectLater(
        controller.signIn(email: 'stud@hs-anhalt.de', password: 'pw'),
        throwsA(
          isA<MailFailure>().having(
            (e) => e.kind,
            'kind',
            MailFailureKind.secureStorageUnavailable,
          ),
        ),
      );
      expect(
        container.read(mailAccountControllerProvider).requireValue.isSignedIn,
        isFalse,
      );
    });
  });

  group('sign out', () {
    test('clears credentials completely', () async {
      final store = InMemoryMailCredentialStore()..write(_creds);
      final container = _container(gateway: FakeMailGateway(), store: store);
      final controller = container.read(mailAccountControllerProvider.notifier);
      await container.read(mailAccountControllerProvider.future);

      await controller.signOut();

      expect(store.clears, greaterThanOrEqualTo(1));
      expect(await store.read(), isNull);
      expect(
        container.read(mailAccountControllerProvider).requireValue.isSignedIn,
        isFalse,
      );
    });
  });

  group('inbox', () {
    test('loads headers for the signed-in account', () async {
      final headers = <MailMessageHeader>[
        MailMessageHeader(
          id: '42',
          subject: 'Hallo',
          from: const MailAddress(email: 'a@b.de', name: 'Alice'),
          date: DateTime.utc(2026, 7, 23, 8),
          isSeen: false,
          hasAttachments: true,
        ),
      ];
      final store = InMemoryMailCredentialStore()..write(_creds);
      final gateway = FakeMailGateway(inbox: headers);
      final container = _container(gateway: gateway, store: store);
      await container.read(mailAccountControllerProvider.future);

      final result = await container.read(mailInboxControllerProvider.future);
      expect(result, hasLength(1));
      expect(result.first.subject, 'Hallo');
    });

    test('maps a timeout to a typed failure', () async {
      final store = InMemoryMailCredentialStore()..write(_creds);
      final gateway = FakeMailGateway(
        fetchInboxError: const MailFailure(MailFailureKind.timeout),
      );
      final container = _container(gateway: gateway, store: store);
      await container.read(mailAccountControllerProvider.future);

      // Drive the inbox the way a screen does — subscribe and inspect the
      // resulting AsyncValue — rather than awaiting `.future`, which waits for a
      // *next* value that a one-shot failing build never produces.
      final Completer<AsyncValue<List<MailMessageHeader>>> settled =
          Completer<AsyncValue<List<MailMessageHeader>>>();
      container.listen<AsyncValue<List<MailMessageHeader>>>(
        mailInboxControllerProvider,
        (_, AsyncValue<List<MailMessageHeader>> next) {
          if (!next.isLoading && !settled.isCompleted) settled.complete(next);
        },
        fireImmediately: true,
      );

      final AsyncValue<List<MailMessageHeader>> result = await settled.future;
      expect(result.hasError, isTrue);
      expect(
        result.error,
        isA<MailFailure>().having(
          (e) => e.kind,
          'kind',
          MailFailureKind.timeout,
        ),
      );
    });
  });

  group('send', () {
    Future<MailComposeController> composer(ProviderContainer container) async {
      await container.read(mailAccountControllerProvider.future);
      return container.read(mailComposeControllerProvider.notifier);
    }

    test('sends once and reports the Sent copy result', () async {
      final store = InMemoryMailCredentialStore()..write(_creds);
      final gateway = FakeMailGateway(sentCopy: SentCopyResult.appended);
      final container = _container(gateway: gateway, store: store);
      final c = await composer(container);

      final outcome = await c.send(to: 'x@y.de', subject: 'Hi', text: 'Body');

      expect(gateway.sendCalls, 1);
      expect(gateway.sent.single.to, 'x@y.de');
      expect(outcome!.sentCopy, SentCopyResult.appended);
    });

    test('does not double-send while a send is in flight', () async {
      final store = InMemoryMailCredentialStore()..write(_creds);
      final gateway = FakeMailGateway();
      final container = _container(gateway: gateway, store: store);
      final c = await composer(container);

      final f1 = c.send(to: 'x@y.de', subject: 'Hi', text: 'Body');
      final f2 = c.send(to: 'x@y.de', subject: 'Hi', text: 'Body');
      await Future.wait(<Future<void>>[f1.then((_) {}), f2.then((_) {})]);

      expect(gateway.sendCalls, 1, reason: 'the second trigger is ignored');
    });

    test('a failed SMTP send throws and never reports success', () async {
      final store = InMemoryMailCredentialStore()..write(_creds);
      final gateway = FakeMailGateway(
        sendError: const MailFailure(MailFailureKind.network),
      );
      final container = _container(gateway: gateway, store: store);
      final c = await composer(container);

      await expectLater(
        c.send(to: 'x@y.de', subject: 'Hi', text: 'Body'),
        throwsA(isA<MailFailure>()),
      );
      expect(gateway.sent, isEmpty);
    });

    test(
      'a successful send with a failed Sent copy still counts as sent',
      () async {
        final store = InMemoryMailCredentialStore()..write(_creds);
        final gateway = FakeMailGateway(sentCopy: SentCopyResult.appendFailed);
        final container = _container(gateway: gateway, store: store);
        final c = await composer(container);

        final outcome = await c.send(to: 'x@y.de', subject: 'Hi', text: 'Body');

        expect(gateway.sendCalls, 1);
        expect(outcome!.sentCopy, SentCopyResult.appendFailed);
      },
    );
  });
}
