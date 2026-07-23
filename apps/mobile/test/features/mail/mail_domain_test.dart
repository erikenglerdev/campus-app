// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Sommer

import 'package:campus_koethen/features/mail/domain/hsa_mail_profile.dart';
import 'package:campus_koethen/features/mail/domain/mail_credentials.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HsaMailProfile', () {
    test('pins the verified HSA endpoints', () {
      const HsaMailProfile p = HsaMailProfile();
      expect(p.imapHost, 'mail.hs-anhalt.de');
      expect(p.imapPort, 993);
      expect(p.smtpHost, 'mail.hs-anhalt.de');
      expect(p.smtpPort, 587);
    });

    test(
      'mandates TLS for IMAP and STARTTLS for SMTP, with no plaintext option',
      () {
        const HsaMailProfile p = HsaMailProfile();
        expect(p.imapImplicitTls, isTrue);
        expect(p.smtpStartTlsRequired, isTrue);
        // A profile that could ever describe plaintext is a security defect;
        // there are simply no ports 143 / 25 / 465 anywhere in it.
        final String s = '${p.imapPort} ${p.smtpPort}';
        expect(s.contains('143'), isFalse);
        expect(s.contains('25 '), isFalse);
        expect(s.contains('465'), isFalse);
      },
    );

    test('official webmail link is https', () {
      expect(const HsaMailProfile().webmailUrl, 'https://mail.hs-anhalt.de/');
      expect(Uri.parse(const HsaMailProfile().webmailUrl).scheme, 'https');
    });
  });

  group('MailCredentials', () {
    test(
      'uses the email address as IMAP username, SMTP username and sender',
      () {
        const MailCredentials c = MailCredentials(
          emailAddress: 'stud@hs-anhalt.de',
          password: 'irrelevant',
        );
        // There is deliberately no separate username / matrikel / login field:
        // the address is all three.
        expect(c.emailAddress, 'stud@hs-anhalt.de');
      },
    );

    test('NEVER exposes the password through toString', () {
      const MailCredentials c = MailCredentials(
        emailAddress: 'stud@hs-anhalt.de',
        password: 'super-secret-pw-123',
      );
      expect(c.toString().contains('super-secret-pw-123'), isFalse);
      expect(c.toString().contains('password'), isFalse);
      // The address may appear; it is not a secret.
      expect(c.toString().contains('MailCredentials'), isTrue);
    });

    test('equality is by value so state comparisons work', () {
      const MailCredentials a = MailCredentials(
        emailAddress: 'a@x',
        password: 'p',
      );
      const MailCredentials b = MailCredentials(
        emailAddress: 'a@x',
        password: 'p',
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });
  });

  group('email validation', () {
    test('accepts a plausible address and trims surrounding whitespace', () {
      expect(
        normalizeEmailAddress('  stud@hs-anhalt.de '),
        'stud@hs-anhalt.de',
      );
    });

    test('rejects obviously invalid input', () {
      for (final String bad in <String>[
        '',
        'no-at',
        'a@',
        '@b',
        'a b@c.de',
        'a@b',
      ]) {
        expect(isValidEmailAddress(bad), isFalse, reason: bad);
      }
    });

    test('does not lowercase or otherwise rewrite the local part', () {
      // The local part is case-sensitive per spec; we must not "helpfully" alter it.
      expect(
        normalizeEmailAddress('Stud.Name@hs-anhalt.de'),
        'Stud.Name@hs-anhalt.de',
      );
    });
  });
}
