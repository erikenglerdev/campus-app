// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import 'package:campus_koethen/features/grades/application/grade_account_controller.dart';
import 'package:campus_koethen/features/grades/application/grades_controller.dart';
import 'package:campus_koethen/features/grades/application/grades_providers.dart';
import 'package:campus_koethen/features/grades/domain/grade_credentials.dart';
import 'package:campus_koethen/features/grades/domain/grade_failure.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_grades.dart';

const GradeCredentials _creds = GradeCredentials(
  username: 'testuser',
  password: 'test-pw',
);

ProviderContainer _container({
  required FakeGradesGateway gateway,
  required InMemoryGradeCredentialStore store,
  required InMemoryGradeCacheStore cache,
  required MutableClock clock,
}) {
  final ProviderContainer container = ProviderContainer(
    overrides: <Override>[
      gradesGatewayProvider.overrideWithValue(gateway),
      gradeCredentialStoreProvider.overrideWithValue(store),
      gradeCacheStoreProvider.overrideWithValue(cache),
      gradeClockProvider.overrideWithValue(clock),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  final DateTime t0 = DateTime.utc(2026, 7, 26, 12);

  group('account', () {
    test('starts signed out when the store is empty', () async {
      final c = _container(
        gateway: FakeGradesGateway(),
        store: InMemoryGradeCredentialStore(),
        cache: InMemoryGradeCacheStore(),
        clock: MutableClock(t0),
      );
      final GradeAccountState s = await c.read(
        gradeAccountControllerProvider.future,
      );
      expect(s.isSignedIn, isFalse);
    });

    test('restores a stored account (username only, no password)', () async {
      final store = InMemoryGradeCredentialStore()..write(_creds);
      final c = _container(
        gateway: FakeGradesGateway(),
        store: store,
        cache: InMemoryGradeCacheStore(),
        clock: MutableClock(t0),
      );
      final GradeAccountState s = await c.read(
        gradeAccountControllerProvider.future,
      );
      expect(s.username, 'testuser');
      expect(s.toString().contains('test-pw'), isFalse);
    });

    test(
      'signIn verifies via the portal, then stores creds and seeds cache',
      () async {
        final gateway = FakeGradesGateway(report: sampleReport());
        final store = InMemoryGradeCredentialStore();
        final cache = InMemoryGradeCacheStore();
        final c = _container(
          gateway: gateway,
          store: store,
          cache: cache,
          clock: MutableClock(t0),
        );
        await c.read(gradeAccountControllerProvider.future);

        await c
            .read(gradeAccountControllerProvider.notifier)
            .signIn(username: '  testuser ', password: 'test-pw');

        expect(gateway.fetchCalls, 1);
        expect(store.writes, 1);
        expect(store.lastWritten?.username, 'testuser');
        expect(cache.reportWrites, 1, reason: 'the initial report is cached');
        expect(await cache.readLastSuccessfulSync(), t0);
        expect(await cache.readLastAttemptedSync(), t0);
        expect(
          c.read(gradeAccountControllerProvider).requireValue.isSignedIn,
          isTrue,
        );
      },
    );

    test('does NOT store credentials when the portal rejects them', () async {
      final gateway = FakeGradesGateway(
        error: const GradeFailure(GradeFailureKind.invalidCredentials),
      );
      final store = InMemoryGradeCredentialStore();
      final cache = InMemoryGradeCacheStore();
      final c = _container(
        gateway: gateway,
        store: store,
        cache: cache,
        clock: MutableClock(t0),
      );
      await c.read(gradeAccountControllerProvider.future);

      await expectLater(
        c
            .read(gradeAccountControllerProvider.notifier)
            .signIn(username: 'testuser', password: 'wrong'),
        throwsA(isA<GradeFailure>()),
      );
      expect(store.writes, 0);
      expect(cache.reportWrites, 0);
      expect(
        c.read(gradeAccountControllerProvider).requireValue.isSignedIn,
        isFalse,
      );
    });

    test('surfaces a secure-storage failure and stays signed out', () async {
      final gateway = FakeGradesGateway(report: sampleReport());
      final store = InMemoryGradeCredentialStore(available: false);
      final c = _container(
        gateway: gateway,
        store: store,
        cache: InMemoryGradeCacheStore(),
        clock: MutableClock(t0),
      );
      await c.read(gradeAccountControllerProvider.future);

      await expectLater(
        c
            .read(gradeAccountControllerProvider.notifier)
            .signIn(username: 'testuser', password: 'test-pw'),
        throwsA(
          isA<GradeFailure>().having(
            (GradeFailure e) => e.kind,
            'kind',
            GradeFailureKind.secureStorageUnavailable,
          ),
        ),
      );
      expect(
        c.read(gradeAccountControllerProvider).requireValue.isSignedIn,
        isFalse,
      );
    });

    test(
      'deleteEverything wipes credentials, cache, key and timestamps',
      () async {
        final store = InMemoryGradeCredentialStore()..write(_creds);
        final cache = InMemoryGradeCacheStore();
        await cache.writeReport(sampleReport());
        await cache.writeLastSuccessfulSync(t0);
        final c = _container(
          gateway: FakeGradesGateway(),
          store: store,
          cache: cache,
          clock: MutableClock(t0),
        );
        await c.read(gradeAccountControllerProvider.future);

        await c
            .read(gradeAccountControllerProvider.notifier)
            .deleteEverything();

        expect(store.clears, greaterThanOrEqualTo(1));
        expect(cache.clears, greaterThanOrEqualTo(1));
        expect(await cache.readReport(), isNull);
        expect(
          c.read(gradeAccountControllerProvider).requireValue.isSignedIn,
          isFalse,
        );
      },
    );
  });

  group('sync policy', () {
    Future<ProviderContainer> signedIn({
      required FakeGradesGateway gateway,
      required InMemoryGradeCacheStore cache,
      required MutableClock clock,
    }) async {
      final store = InMemoryGradeCredentialStore()..write(_creds);
      final c = _container(
        gateway: gateway,
        store: store,
        cache: cache,
        clock: clock,
      );
      await c.read(gradeAccountControllerProvider.future);
      // Keep the controller alive like a screen would.
      c.listen(gradesControllerProvider, (_, _) {});
      await c.read(gradesControllerProvider.future);
      return c;
    }

    test('first open without a cache syncs', () async {
      final gateway = FakeGradesGateway(report: sampleReport());
      final cache = InMemoryGradeCacheStore();
      final c = await signedIn(
        gateway: gateway,
        cache: cache,
        clock: MutableClock(t0),
      );

      await c.read(gradesControllerProvider.notifier).maybeAutoSync();

      expect(gateway.fetchCalls, 1);
      expect(await cache.readReport(), isNotNull);
    });

    test('a cache younger than 24h prevents an automatic net call', () async {
      final gateway = FakeGradesGateway(report: sampleReport());
      final cache = InMemoryGradeCacheStore();
      await cache.writeLastAttemptedSync(t0.subtract(const Duration(hours: 1)));
      final c = await signedIn(
        gateway: gateway,
        cache: cache,
        clock: MutableClock(t0),
      );

      await c.read(gradesControllerProvider.notifier).maybeAutoSync();

      expect(gateway.fetchCalls, 0);
    });

    test('after 24h exactly one automatic attempt runs', () async {
      final gateway = FakeGradesGateway(report: sampleReport());
      final cache = InMemoryGradeCacheStore();
      await cache.writeLastAttemptedSync(
        t0.subtract(const Duration(hours: 25)),
      );
      final c = await signedIn(
        gateway: gateway,
        cache: cache,
        clock: MutableClock(t0),
      );

      await c.read(gradesControllerProvider.notifier).maybeAutoSync();

      expect(gateway.fetchCalls, 1);
    });

    test('concurrent automatic syncs cause only one portal call', () async {
      final gateway = FakeGradesGateway(
        report: sampleReport(),
        delay: const Duration(milliseconds: 30),
      );
      final cache = InMemoryGradeCacheStore();
      final c = await signedIn(
        gateway: gateway,
        cache: cache,
        clock: MutableClock(t0),
      );

      final notifier = c.read(gradesControllerProvider.notifier);
      await Future.wait(<Future<void>>[
        notifier.maybeAutoSync(),
        notifier.maybeAutoSync(),
      ]);

      expect(gateway.fetchCalls, 1);
    });

    test('manual refresh bypasses the 24h gate', () async {
      final gateway = FakeGradesGateway(report: sampleReport());
      final cache = InMemoryGradeCacheStore();
      await cache.writeLastAttemptedSync(t0); // just attempted
      final c = await signedIn(
        gateway: gateway,
        cache: cache,
        clock: MutableClock(t0),
      );

      await c.read(gradesControllerProvider.notifier).refresh();

      expect(gateway.fetchCalls, 1);
    });

    test('a failed sync keeps the old cache and lastSuccessfulSync', () async {
      final gateway = FakeGradesGateway(
        error: const GradeFailure(GradeFailureKind.timeout),
      );
      final cache = InMemoryGradeCacheStore();
      await cache.writeReport(sampleReport('Alt'));
      await cache.writeLastSuccessfulSync(t0.subtract(const Duration(days: 2)));
      final c = await signedIn(
        gateway: gateway,
        cache: cache,
        clock: MutableClock(t0),
      );

      await c.read(gradesControllerProvider.notifier).refresh();

      final GradesViewState s = c.read(gradesControllerProvider).requireValue;
      expect(s.error?.kind, GradeFailureKind.timeout);
      expect(s.report, isNotNull, reason: 'the old cache stays visible');
      expect(s.report!.entries.single.title, 'Alt');
      expect(
        cache.reportWrites,
        1,
        reason: 'the failed sync did not overwrite',
      );
      expect(
        await cache.readLastSuccessfulSync(),
        t0.subtract(const Duration(days: 2)),
      );
    });

    test('lastSuccessfulSync changes only on success', () async {
      final gateway = FakeGradesGateway(report: sampleReport());
      final cache = InMemoryGradeCacheStore();
      final c = await signedIn(
        gateway: gateway,
        cache: cache,
        clock: MutableClock(t0),
      );

      await c.read(gradesControllerProvider.notifier).refresh();

      expect(await cache.readLastSuccessfulSync(), t0);
    });

    test(
      'a failed auto attempt is not retried on every build; manual still works',
      () async {
        final gateway = FakeGradesGateway(
          error: const GradeFailure(GradeFailureKind.portalUnavailable),
        );
        final cache = InMemoryGradeCacheStore();
        final clock = MutableClock(t0);
        final c = await signedIn(gateway: gateway, cache: cache, clock: clock);
        final notifier = c.read(gradesControllerProvider.notifier);

        await notifier
            .maybeAutoSync(); // attempt #1 (fails, records lastAttempt)
        await notifier.maybeAutoSync(); // within 24h → skipped
        expect(gateway.fetchCalls, 1);

        // The user can still force a sync.
        await notifier.refresh();
        expect(gateway.fetchCalls, 2);
      },
    );
  });
}
