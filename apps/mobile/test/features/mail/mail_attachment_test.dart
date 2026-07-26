// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import 'package:campus_koethen/features/mail/presentation/mail_attachment_view.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('isTrustedImageSender', () {
    test('accepts hs-anhalt.de and its subdomains', () {
      expect(isTrustedImageSender('prof@hs-anhalt.de'), isTrue);
      expect(isTrustedImageSender('a.b@mail.hs-anhalt.de'), isTrue);
      expect(isTrustedImageSender('X@HS-Anhalt.DE'), isTrue);
    });

    test('rejects anything else', () {
      expect(isTrustedImageSender('spammer@example.com'), isFalse);
      expect(isTrustedImageSender('fake@hs-anhalt.de.evil.com'), isFalse);
      expect(isTrustedImageSender('no-domain'), isFalse);
      expect(isTrustedImageSender(''), isFalse);
    });
  });
}
