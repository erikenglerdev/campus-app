// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import 'dart:async';

import 'package:campus_koethen/features/mail/application/mail_account_controller.dart';
import 'package:campus_koethen/features/mail/application/mail_compose_controller.dart';
import 'package:campus_koethen/features/mail/application/mail_folders.dart';
import 'package:campus_koethen/features/mail/application/mail_inbox_controller.dart';
import 'package:campus_koethen/features/mail/application/mail_providers.dart';
import 'package:campus_koethen/features/mail/application/mail_search_controller.dart';
import 'package:campus_koethen/features/mail/application/mail_sync_controller.dart';
import 'package:campus_koethen/features/mail/data/mail_cache.dart';
import 'package:campus_koethen/features/mail/domain/mail_credentials.dart';
import 'package:campus_koethen/features/mail/domain/mail_failure.dart';
import 'package:campus_koethen/features/mail/domain/mail_folder.dart';
import 'package:campus_koethen/features/mail/domain/mail_gateway.dart';
import 'package:campus_koethen/features/mail/domain/mail_message.dart';
import 'package:campus_koethen/core/prefs/settings_controller.dart';
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
  MemoryMailCache? cache,
}) {
  final ProviderContainer container = ProviderContainer(
    overrides: <Override>[
      mailGatewayProvider.overrideWithValue(gateway),
      mailCredentialStoreProvider.overrideWithValue(store),
      if (cache != null) mailCacheStoreProvider.overrideWithValue(cache),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

MailMessageHeader _hdr(String id) => MailMessageHeader(
  id: id,
  subject: 'Subject $id',
  from: const MailAddress(email: 'alice@hs-anhalt.de', name: 'Alice'),
  date: DateTime.utc(2026, 7, 20, 9, int.parse(id)),
  isSeen: false,
  hasAttachments: false,
);

MailMessageDetail _dtl(String id) => MailMessageDetail(
  id: id,
  subject: 'Subject $id',
  from: const MailAddress(email: 'alice@hs-anhalt.de', name: 'Alice'),
  to: const <MailAddress>[MailAddress(email: 'stud@hs-anhalt.de')],
  date: DateTime.utc(2026, 7, 20, 9, int.parse(id)),
  body: 'Body $id',
);

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

    test(
      'stores an optional display name and exposes it in the state',
      () async {
        final gateway = FakeMailGateway();
        final store = InMemoryMailCredentialStore();
        final container = _container(gateway: gateway, store: store);
        final controller = container.read(
          mailAccountControllerProvider.notifier,
        );
        await container.read(mailAccountControllerProvider.future);

        await controller.signIn(
          email: 'stud@hs-anhalt.de',
          password: 'pw',
          displayName: '  Max Mustermensch  ',
        );

        final state = container
            .read(mailAccountControllerProvider)
            .requireValue;
        expect(state.displayName, 'Max Mustermensch', reason: 'trimmed');
        expect(await store.read(), isNotNull);
        expect((await store.read())!.displayName, 'Max Mustermensch');
        // The address stays the sole identity; the name is only cosmetic.
        expect(state.emailAddress, 'stud@hs-anhalt.de');
      },
    );

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
    test('serves the INBOX from the offline cache', () async {
      final store = InMemoryMailCredentialStore()..write(_creds);
      final cache = MemoryMailCache();
      await cache.saveHeaders(<MailMessageHeader>[_hdr('7')]);
      final container = _container(
        gateway: FakeMailGateway(),
        store: store,
        cache: cache,
      );
      await container.read(mailAccountControllerProvider.future);

      final result = await container.read(mailInboxControllerProvider.future);
      expect(result, hasLength(1));
      expect(result.first.id, '7');
    });

    test(
      'a non-inbox folder fetch maps a timeout to a typed failure',
      () async {
        final store = InMemoryMailCredentialStore()..write(_creds);
        final gateway = FakeMailGateway(
          fetchInboxError: const MailFailure(MailFailureKind.timeout),
        );
        final container = _container(gateway: gateway, store: store);
        await container.read(mailAccountControllerProvider.future);
        // A non-INBOX folder is fetched online, so it can fail with a timeout.
        container
            .read(selectedMailboxProvider.notifier)
            .select(const MailFolder(path: 'Archiv', name: 'Archiv'));

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
      },
    );
  });

  group('sync', () {
    test(
      'caches headers and prefetches new bodies, accumulating over time',
      () async {
        final store = InMemoryMailCredentialStore()..write(_creds);
        final cache = MemoryMailCache();
        final gateway = FakeMailGateway(
          inbox: <MailMessageHeader>[_hdr('1')],
          detailsById: <String, MailMessageDetail>{'1': _dtl('1')},
        );
        final container = _container(
          gateway: gateway,
          store: store,
          cache: cache,
        );
        await container.read(mailAccountControllerProvider.future);

        await container.read(mailSyncControllerProvider.notifier).syncNow();
        expect(
          (await cache.readHeaders()).map((MailMessageHeader h) => h.id),
          <String>['1'],
        );
        expect(await cache.cachedMessageIds(), <String>{'1'});

        // The server now shows a newer message and message 1 has scrolled off.
        gateway.inbox = <MailMessageHeader>[_hdr('2')];
        gateway.detailsById = <String, MailMessageDetail>{'2': _dtl('2')};
        await container.read(mailSyncControllerProvider.notifier).syncNow();

        // Accumulated: the previously cached message stays, the new one is added.
        expect(
          (await cache.readHeaders())
              .map((MailMessageHeader h) => h.id)
              .toSet(),
          <String>{'1', '2'},
        );
        expect(await cache.cachedMessageIds(), <String>{'1', '2'});
      },
    );

    test('downloads attachment bytes only when the setting is on', () async {
      final store = InMemoryMailCredentialStore()..write(_creds);
      final cache = MemoryMailCache();
      final gateway = FakeMailGateway(
        inbox: <MailMessageHeader>[_hdr('1')],
        detailsById: <String, MailMessageDetail>{'1': _dtl('1')},
      );
      final container = _container(
        gateway: gateway,
        store: store,
        cache: cache,
      );
      await container.read(mailAccountControllerProvider.future);

      await container.read(mailSyncControllerProvider.notifier).syncNow();
      expect(gateway.lastIncludeAttachmentBytes, isFalse);

      await container
          .read(settingsProvider.notifier)
          .setMailDownloadAttachments(true);
      // Force a fresh prefetch by using a message not yet cached.
      gateway.inbox = <MailMessageHeader>[_hdr('2')];
      gateway.detailsById = <String, MailMessageDetail>{'2': _dtl('2')};
      await container.read(mailSyncControllerProvider.notifier).syncNow();
      expect(gateway.lastIncludeAttachmentBytes, isTrue);
    });
  });

  group('search', () {
    test('runs a server search over the selected mailbox', () async {
      final store = InMemoryMailCredentialStore()..write(_creds);
      final gateway = FakeMailGateway(
        searchResults: <MailMessageHeader>[_hdr('9')],
      );
      final container = _container(gateway: gateway, store: store);
      await container.read(mailAccountControllerProvider.future);

      await container
          .read(mailSearchControllerProvider.notifier)
          .run('  Rechnung ');

      expect(gateway.lastSearchQuery, 'Rechnung', reason: 'trimmed');
      expect(gateway.lastSearchMailbox, 'INBOX');
      final result = container.read(mailSearchControllerProvider).requireValue;
      expect(result.map((MailMessageHeader h) => h.id), <String>['9']);
    });

    test('a blank query clears without hitting the server', () async {
      final store = InMemoryMailCredentialStore()..write(_creds);
      final gateway = FakeMailGateway(
        searchResults: <MailMessageHeader>[_hdr('9')],
      );
      final container = _container(gateway: gateway, store: store);
      await container.read(mailAccountControllerProvider.future);

      await container.read(mailSearchControllerProvider.notifier).run('   ');

      expect(gateway.lastSearchQuery, isNull);
      expect(
        container.read(mailSearchControllerProvider).requireValue,
        isEmpty,
      );
    });
  });

  group('mergeInboxHeaders', () {
    test('unions by id, newest first, keeping cached ones', () {
      final List<MailMessageHeader> merged = mergeInboxHeaders(
        <MailMessageHeader>[_hdr('1'), _hdr('2')],
        <MailMessageHeader>[_hdr('3'), _hdr('2')],
      );
      expect(merged.map((MailMessageHeader h) => h.id), <String>[
        '3',
        '2',
        '1',
      ]);
    });
  });

  group('folders', () {
    test(
      'lists the mailboxes from the server for a signed-in account',
      () async {
        final store = InMemoryMailCredentialStore()..write(_creds);
        final gateway = FakeMailGateway(
          folders: const <MailFolder>[
            MailFolder.inbox(),
            MailFolder(path: 'Sent', name: 'Sent', role: MailFolderRole.sent),
            MailFolder(
              path: 'Archiv',
              name: 'Archiv',
              role: MailFolderRole.archive,
            ),
          ],
        );
        final container = _container(gateway: gateway, store: store);
        await container.read(mailAccountControllerProvider.future);

        final List<MailFolder> folders = await container.read(
          mailFoldersProvider.future,
        );
        expect(
          folders.map((MailFolder f) => f.path),
          containsAll(<String>['INBOX', 'Sent', 'Archiv']),
        );
      },
    );

    test('stays empty while signed out', () async {
      final container = _container(
        gateway: FakeMailGateway(
          folders: const <MailFolder>[MailFolder.inbox()],
        ),
        store: InMemoryMailCredentialStore(),
      );
      await container.read(mailAccountControllerProvider.future);
      expect(await container.read(mailFoldersProvider.future), isEmpty);
    });
  });

  group('send', () {
    const OutgoingMessage message = OutgoingMessage(
      to: <String>['x@y.de'],
      subject: 'Hi',
      text: 'Body',
    );

    Future<MailComposeController> composer(ProviderContainer container) async {
      await container.read(mailAccountControllerProvider.future);
      return container.read(mailComposeControllerProvider.notifier);
    }

    test('submits the message via SMTP and reports success', () async {
      final store = InMemoryMailCredentialStore()..write(_creds);
      final gateway = FakeMailGateway();
      final container = _container(gateway: gateway, store: store);
      final c = await composer(container);

      final bool sent = await c.send(message);

      expect(sent, isTrue);
      expect(gateway.sendCalls, 1);
      expect(gateway.sent.single.to, <String>['x@y.de']);
    });

    test('does not double-send while a send is in flight', () async {
      final store = InMemoryMailCredentialStore()..write(_creds);
      final gateway = FakeMailGateway();
      final container = _container(gateway: gateway, store: store);
      final c = await composer(container);

      final Future<bool> f1 = c.send(message);
      final Future<bool> f2 = c.send(message);
      final List<bool> results = await Future.wait(<Future<bool>>[f1, f2]);

      expect(results, containsAll(<bool>[true, false]));
      expect(gateway.sendCalls, 1, reason: 'the second trigger is ignored');
    });

    test('a failed SMTP send throws and never records a send', () async {
      final store = InMemoryMailCredentialStore()..write(_creds);
      final gateway = FakeMailGateway(
        sendError: const MailFailure(MailFailureKind.network),
      );
      final container = _container(gateway: gateway, store: store);
      final c = await composer(container);

      await expectLater(c.send(message), throwsA(isA<MailFailure>()));
      expect(gateway.sent, isEmpty);
    });

    test('stores the Sent copy separately and reports the result', () async {
      final store = InMemoryMailCredentialStore()..write(_creds);
      final gateway = FakeMailGateway(sentCopy: SentCopyResult.appended);
      final container = _container(gateway: gateway, store: store);
      final c = await composer(container);

      final SentCopyResult result = await c.appendSentCopy(message);

      expect(result, SentCopyResult.appended);
      expect(gateway.appendCalls, 1);
      expect(gateway.appended.single.to, <String>['x@y.de']);
    });

    test('a failed Sent copy is reported, not thrown', () async {
      final store = InMemoryMailCredentialStore()..write(_creds);
      final gateway = FakeMailGateway(sentCopy: SentCopyResult.appendFailed);
      final container = _container(gateway: gateway, store: store);
      final c = await composer(container);

      expect(await c.appendSentCopy(message), SentCopyResult.appendFailed);
    });
  });
}
