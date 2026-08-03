// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import 'package:campus_koethen/features/requests/domain/request_gateway.dart';
import 'package:campus_koethen/features/requests/domain/request_models.dart';
import 'package:campus_koethen/features/requests/domain/request_validation.dart';
import 'package:flutter_test/flutter_test.dart';

RequestDraft _draft({
  RequestKind kind = RequestKind.feedback,
  String title = 'Ein Titel',
  String? category = 'general',
  Money? amount,
  String purpose = '',
  String description = 'Eine Beschreibung.',
  String? contactEmail,
}) => RequestDraft(
  id: 'draft-1',
  kind: kind,
  createdAt: DateTime(2026, 5, 12),
  updatedAt: DateTime(2026, 5, 12),
  title: title,
  category: category,
  amount: amount,
  purpose: purpose,
  description: description,
  contactEmail: contactEmail,
);

void main() {
  group('money', () {
    test('accepts both notations and normalises to a full stop', () {
      expect(Money.tryParse('12,50')?.amount, '12.50');
      expect(Money.tryParse('12.50')?.amount, '12.50');
      expect(Money.tryParse(' 8 ')?.amount, '8');
    });

    test('rejects anything that is not a plain non-negative amount', () {
      // A rejected value is never silently rounded into something else.
      for (final String input in <String>[
        '',
        'abc',
        '-5',
        '1.234',
        '1..2',
        '1,2,3',
        '1e3',
      ]) {
        expect(Money.tryParse(input), isNull, reason: 'accepted "$input"');
      }
    });

    test('never becomes a binary float', () {
      // 0.1 + 0.2 != 0.3 in floating point; an application for €4.30 must not
      // become €4.2999999 anywhere on the way.
      const Money money = Money(amount: '4.30');
      expect(money.amount, '4.30');
      expect(money.minorUnits, 430);
      expect(Money.tryParse('0.1')!.minorUnits, 10);
      expect(Money.tryParse('0.3')!.minorUnits, 30);
    });

    test('knows zero', () {
      expect(Money.tryParse('0')!.isZero, isTrue);
      expect(Money.tryParse('0.00')!.isZero, isTrue);
      expect(Money.tryParse('0.01')!.isZero, isFalse);
    });
  });

  group('validation', () {
    test('a complete piece of feedback passes', () {
      expect(RequestValidation.validate(_draft()).isValid, isTrue);
    });

    test('title, category and description are required', () {
      final RequestValidation result = RequestValidation.validate(
        _draft(title: '   ', category: null, description: ''),
      );
      expect(
        result.errorFor(RequestField.title),
        RequestFieldError.titleMissing,
      );
      expect(
        result.errorFor(RequestField.category),
        RequestFieldError.categoryMissing,
      );
      expect(
        result.errorFor(RequestField.description),
        RequestFieldError.descriptionMissing,
      );
    });

    test('an over-long title or description is rejected', () {
      final RequestValidation result = RequestValidation.validate(
        _draft(
          title: 'x' * (RequestValidation.titleMaxLength + 1),
          description: 'y' * (RequestValidation.descriptionMaxLength + 1),
        ),
      );
      expect(
        result.errorFor(RequestField.title),
        RequestFieldError.titleTooLong,
      );
      expect(
        result.errorFor(RequestField.description),
        RequestFieldError.descriptionTooLong,
      );
    });

    test('feedback needs neither an amount nor a purpose', () {
      final RequestValidation result = RequestValidation.validate(_draft());
      expect(result.errorFor(RequestField.amount), isNull);
      expect(result.errorFor(RequestField.purpose), isNull);
    });

    test('a finance application needs both', () {
      final RequestValidation result = RequestValidation.validate(
        _draft(kind: RequestKind.financeApplication),
      );
      expect(
        result.errorFor(RequestField.amount),
        RequestFieldError.amountMissing,
      );
      expect(
        result.errorFor(RequestField.purpose),
        RequestFieldError.purposeMissing,
      );
    });

    test('an amount of zero is a mistake, not a rounding problem', () {
      final RequestValidation result = RequestValidation.validate(
        _draft(
          kind: RequestKind.financeApplication,
          amount: Money.tryParse('0'),
          purpose: 'Material',
        ),
      );
      expect(
        result.errorFor(RequestField.amount),
        RequestFieldError.amountZero,
      );
    });

    test('a complete finance application passes', () {
      final RequestValidation result = RequestValidation.validate(
        _draft(
          kind: RequestKind.financeApplication,
          amount: Money.tryParse('120,50'),
          purpose: 'Material für die Erstsemesterwoche',
        ),
      );
      expect(result.isValid, isTrue);
    });

    test('contact details stay optional', () {
      expect(
        RequestValidation.validate(_draft(contactEmail: null)).isValid,
        isTrue,
      );
      expect(
        RequestValidation.validate(_draft(contactEmail: '  ')).isValid,
        isTrue,
      );
    });

    test('but a given address has to look like one', () {
      expect(
        RequestValidation.validate(
          _draft(contactEmail: 'not-an-address'),
        ).errorFor(RequestField.contactEmail),
        RequestFieldError.contactEmailInvalid,
      );
      expect(
        RequestValidation.validate(
          _draft(contactEmail: 'jemand@example.org'),
        ).isValid,
        isTrue,
      );
    });
  });

  group('drafts', () {
    test('a blank draft knows it is blank', () {
      final RequestDraft blank = RequestDraft(
        id: 'x',
        kind: RequestKind.feedback,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );
      expect(blank.isEmpty, isTrue);
      expect(_draft().isEmpty, isFalse);
    });

    test('round-trips through JSON, amount included', () {
      final RequestDraft draft = _draft(
        kind: RequestKind.financeApplication,
        amount: Money.tryParse('99.99'),
        purpose: 'Druckkosten',
        contactEmail: 'a@b.de',
      );
      final RequestDraft? back = RequestDraft.fromJson(draft.toJson());

      expect(back, isNotNull);
      expect(back!.kind, RequestKind.financeApplication);
      expect(back.amount?.amount, '99.99');
      expect(back.amount?.currency, 'EUR');
      expect(back.purpose, 'Druckkosten');
      expect(back.contactEmail, 'a@b.de');
    });

    test('a malformed stored draft is skipped, not fatal', () {
      expect(RequestDraft.fromJson(<String, dynamic>{}), isNull);
      expect(RequestDraft.fromJson(<String, dynamic>{'id': 'x'}), isNull);
      expect(RequestDraft.fromJson('nonsense'), isNull);
    });
  });

  group('submission gateway', () {
    test(
      'reports that nothing is connected instead of faking success',
      () async {
        // The whole point: no invented endpoint, no simulated confirmation.
        final SubmissionResult result = await const NotConnectedRequestGateway()
            .submit(_draft());
        expect(result, isA<SubmissionNotConnected>());
        expect(result, isNot(isA<SubmissionAccepted>()));
      },
    );
  });

  group('submitted cases', () {
    SubmittedRequest submitted(String? url) => SubmittedRequest(
      id: 'case-1',
      kind: RequestKind.feedback,
      title: 'Titel',
      submittedAt: DateTime(2026, 5, 12),
      status: RequestStatus.submitted,
      trackingUrl: url,
    );

    test('only an https link counts as safe to open', () {
      // A link that arrives from a server is untrusted input; handing an
      // arbitrary scheme to the operating system is how that becomes a bug.
      expect(
        submitted('https://example.org/case/1').hasSafeTrackingUrl,
        isTrue,
      );
      expect(submitted('http://example.org').hasSafeTrackingUrl, isFalse);
      expect(submitted('javascript:alert(1)').hasSafeTrackingUrl, isFalse);
      expect(submitted('file:///etc/passwd').hasSafeTrackingUrl, isFalse);
      expect(submitted('https://').hasSafeTrackingUrl, isFalse);
      expect(submitted(null).hasSafeTrackingUrl, isFalse);
    });

    test('status identifiers are stable and unique', () {
      final Set<String> seen = <String>{};
      for (final RequestStatus status in RequestStatus.values) {
        expect(seen.add(status.storageValue), isTrue);
        expect(RequestStatus.fromStorage(status.storageValue), status);
      }
      expect(RequestStatus.fromStorage('made-up'), isNull);
    });
  });
}
