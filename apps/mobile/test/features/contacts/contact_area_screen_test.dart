// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import 'package:campus_koethen/core/network/api_meta.dart';
import 'package:campus_koethen/core/network/loaded.dart';
import 'package:campus_koethen/features/contacts/application/contacts_providers.dart';
import 'package:campus_koethen/features/contacts/data/contact_models.dart';
import 'package:campus_koethen/features/contacts/presentation/contact_area_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show Ref;
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../../support/pump_app.dart';

const ContactArea _area = ContactArea(
  slug: 'stura',
  name: 'Studierendenrat',
  sortOrder: 0,
  persons: <ContactPerson>[
    ContactPerson(
      name: 'Alex Beispiel',
      role: 'Vorsitz',
      description: 'Zuständig für die Gremienarbeit und Sprechstunden.',
      email: 'alex@example.org',
      phone: '+49 3496 000000',
      website: 'https://example.org/alex',
    ),
  ],
);

Override _areaOverride(ContactArea area) =>
    contactAreaProvider('stura').overrideWith(
      (Ref ref) async => Loaded<ContactArea>(value: area, meta: ApiMeta.empty),
    );

void main() {
  testWidgets('the person list stays compact: only name and role are shown', (
    WidgetTester tester,
  ) async {
    await pumpScreen(
      tester,
      const ContactAreaScreen(slug: 'stura'),
      overrides: <Override>[_areaOverride(_area)],
    );
    await tester.pumpAndSettle();

    expect(find.text('Alex Beispiel'), findsOneWidget);
    expect(find.text('Vorsitz'), findsOneWidget);
    // The rich fields are NOT shown inline in the list.
    expect(
      find.text('Zuständig für die Gremienarbeit und Sprechstunden.'),
      findsNothing,
    );
    expect(find.text('alex@example.org'), findsNothing);
  });

  testWidgets(
    'tapping a person opens a sheet with every field Strapi delivers',
    (WidgetTester tester) async {
      await pumpScreen(
        tester,
        const ContactAreaScreen(slug: 'stura'),
        overrides: <Override>[_areaOverride(_area)],
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Alex Beispiel'));
      await tester.pumpAndSettle();

      expect(
        find.text('Zuständig für die Gremienarbeit und Sprechstunden.'),
        findsOneWidget,
      );
      expect(find.text('alex@example.org'), findsOneWidget);
      expect(find.text('+49 3496 000000'), findsOneWidget);
      expect(find.text('https://example.org/alex'), findsOneWidget);
    },
  );

  testWidgets('a person with only a name still opens without crashing', (
    WidgetTester tester,
  ) async {
    await pumpScreen(
      tester,
      const ContactAreaScreen(slug: 'stura'),
      overrides: <Override>[
        _areaOverride(
          const ContactArea(
            slug: 'stura',
            name: 'Studierendenrat',
            sortOrder: 0,
            persons: <ContactPerson>[ContactPerson(name: 'Nur Name')],
          ),
        ),
      ],
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Nur Name'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    // The name appears both in the list and in the opened sheet.
    expect(find.text('Nur Name'), findsWidgets);
  });
}
