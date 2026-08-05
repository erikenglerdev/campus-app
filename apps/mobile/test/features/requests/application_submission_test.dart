// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import 'package:campus_koethen/features/requests/domain/application_files.dart';
import 'package:campus_koethen/features/requests/domain/application_location.dart';
import 'package:campus_koethen/features/requests/domain/idempotency_key.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('file slots', () {
    test('the two mandatory slots are the ones the API demands', () {
      expect(
        ApplicationFileSlot.values
            .where((ApplicationFileSlot s) => s.isRequired)
            .map((ApplicationFileSlot s) => s.field)
            .toSet(),
        <String>{'finance_request', 'student_card'},
      );
    });

    test('field names match the multipart contract exactly', () {
      // These strings are the wire format. A typo here is a 400 that no test
      // of ours would otherwise catch.
      expect(ApplicationFileSlot.financeRequest.field, 'finance_request');
      expect(ApplicationFileSlot.studentCard.field, 'student_card');
      expect(ApplicationFileSlot.annexA.field, 'annex_a');
      expect(ApplicationFileSlot.annexB.field, 'annex_b');
    });

    test('the finance request is PDF only', () {
      expect(ApplicationFileSlot.financeRequest.accepts('antrag.pdf'), isTrue);
      expect(ApplicationFileSlot.financeRequest.accepts('antrag.PDF'), isTrue);
      expect(ApplicationFileSlot.financeRequest.accepts('foto.png'), isFalse);
      expect(
        ApplicationFileSlot.financeRequest.accepts('antrag.docx'),
        isFalse,
      );
    });

    test('the student card also takes a photo', () {
      for (final String name in <String>[
        'ausweis.pdf',
        'ausweis.png',
        'ausweis.jpg',
        'ausweis.jpeg',
      ]) {
        expect(
          ApplicationFileSlot.studentCard.accepts(name),
          isTrue,
          reason: name,
        );
      }
      expect(ApplicationFileSlot.studentCard.accepts('ausweis.gif'), isFalse);
    });

    test('a file without an extension is refused, not guessed', () {
      expect(ApplicationFileSlot.financeRequest.accepts('antrag'), isFalse);
      expect(ApplicationFileSlot.studentCard.accepts(''), isFalse);
    });

    test('the content type follows the extension', () {
      expect(
        ApplicationFileSlot.financeRequest.contentTypeFor('a.pdf'),
        'application/pdf',
      );
      expect(
        ApplicationFileSlot.studentCard.contentTypeFor('a.jpeg'),
        'image/jpeg',
      );
      expect(
        ApplicationFileSlot.studentCard.contentTypeFor('a.png'),
        'image/png',
      );
      expect(ApplicationFileSlot.studentCard.contentTypeFor('a.gif'), isNull);
    });

    test('25 MB is the documented ceiling', () {
      expect(ApplicationFileSlot.maxBytes, 25 * 1024 * 1024);
      expect(ApplicationFileSlot.financeRequest.acceptsSize(0), isTrue);
      expect(
        ApplicationFileSlot.financeRequest.acceptsSize(
          ApplicationFileSlot.maxBytes,
        ),
        isTrue,
      );
      expect(
        ApplicationFileSlot.financeRequest.acceptsSize(
          ApplicationFileSlot.maxBytes + 1,
        ),
        isFalse,
      );
    });

    test('slots survive a round trip through storage', () {
      for (final ApplicationFileSlot slot in ApplicationFileSlot.values) {
        expect(ApplicationFileSlot.fromStorage(slot.field), slot);
      }
      expect(ApplicationFileSlot.fromStorage('annex_z'), isNull);
      expect(ApplicationFileSlot.fromStorage(null), isNull);
    });
  });

  group('idempotency key', () {
    test('a generated key satisfies the documented format', () {
      final String key = IdempotencyKey.generate();
      expect(IdempotencyKey.isValid(key), isTrue);
      expect(key.length, greaterThanOrEqualTo(16));
      expect(key.length, lessThanOrEqualTo(128));
    });

    test('it looks like a UUID v4, as the API recommends', () {
      final String key = IdempotencyKey.generate();
      expect(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ).hasMatch(key),
        isTrue,
        reason: key,
      );
    });

    test('two keys differ', () {
      // The whole mechanism rests on this: a repeated key with different data
      // is a 409, and a repeated key with the same data must not file twice.
      final Set<String> keys = <String>{
        for (int i = 0; i < 50; i++) IdempotencyKey.generate(),
      };
      expect(keys, hasLength(50));
    });

    test('too short, too long and non-ASCII are rejected', () {
      expect(IdempotencyKey.isValid('short'), isFalse);
      expect(IdempotencyKey.isValid('x' * 129), isFalse);
      expect(IdempotencyKey.isValid('x' * 128), isTrue);
      expect(IdempotencyKey.isValid('schlüssel-mit-umlaut-1234'), isFalse);
      expect(IdempotencyKey.isValid('key with space 1234'), isTrue);
      expect(IdempotencyKey.isValid('key\nwith\nnewline'), isFalse);
    });
  });

  group('locations', () {
    test('a well-formed location is read', () {
      final ApplicationLocation? location = ApplicationLocation.fromJson(
        <String, dynamic>{'id': 4, 'name': 'Zentrale'},
      );
      expect(location?.id, 4);
      expect(location?.name, 'Zentrale');
    });

    test('anything malformed is dropped rather than guessed', () {
      // Third-party responses are validated, never trusted (CLAUDE.md §4).
      expect(ApplicationLocation.fromJson(null), isNull);
      expect(ApplicationLocation.fromJson(<String, dynamic>{'id': 1}), isNull);
      expect(
        ApplicationLocation.fromJson(<String, dynamic>{'id': '1', 'name': 'A'}),
        isNull,
      );
      expect(
        ApplicationLocation.fromJson(<String, dynamic>{'id': 1, 'name': ''}),
        isNull,
      );
    });

    test('a partly broken list keeps the usable entries', () {
      final List<ApplicationLocation> locations = ApplicationLocation.listFrom(
        <Object?>[
          <String, dynamic>{'id': 1, 'name': 'Standort A'},
          <String, dynamic>{'id': null, 'name': 'kaputt'},
          'auch kaputt',
          <String, dynamic>{'id': 4, 'name': 'Zentrale'},
        ],
      );
      expect(locations.map((ApplicationLocation l) => l.id), <int>[1, 4]);
    });
  });
}
