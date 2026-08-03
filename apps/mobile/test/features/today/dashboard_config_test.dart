// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import 'package:campus_koethen/app/app_sections.dart';
import 'package:campus_koethen/features/today/domain/dashboard_card.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('dashboard config', () {
    test('the default order leads with what is happening now', () {
      expect(DashboardConfig.defaults.order.first, DashboardCard.nextClass);
      expect(DashboardConfig.defaults.order.take(4), <DashboardCard>[
        DashboardCard.nextClass,
        DashboardCard.todaysAgenda,
        DashboardCard.canteen,
        DashboardCard.news,
      ]);
      expect(DashboardConfig.defaults.hidden, isEmpty);
      // `visible` only ever contains cards whose source is wired up.
      expect(
        DashboardConfig.defaults.visible,
        DashboardCard.values.where((DashboardCard c) => c.isImplemented),
      );
    });

    test('hiding a card removes it from visible but keeps its position', () {
      final DashboardConfig config = DashboardConfig.defaults.withVisibility(
        DashboardCard.canteen,
        visible: false,
      );
      expect(config.visible, isNot(contains(DashboardCard.canteen)));
      expect(config.order, contains(DashboardCard.canteen));
      expect(config.isVisible(DashboardCard.canteen), isFalse);

      // Switching it back on restores the original slot rather than appending.
      final DashboardConfig restored = config.withVisibility(
        DashboardCard.canteen,
        visible: true,
      );
      expect(restored.visible, DashboardConfig.defaults.visible);
    });

    test('reordering moves exactly one card', () {
      final DashboardConfig config = DashboardConfig.defaults.reordered(
        DashboardCard.canteen,
        0,
      );
      expect(config.order.first, DashboardCard.canteen);
      expect(config.order.length, DashboardCard.values.length);
      expect(config.order.toSet().length, DashboardCard.values.length);
    });

    test('reordering past the end clamps instead of throwing', () {
      final DashboardConfig config = DashboardConfig.defaults.reordered(
        DashboardCard.nextClass,
        999,
      );
      expect(config.order.last, DashboardCard.nextClass);
      expect(config.order.length, DashboardCard.values.length);
    });

    test('a card added in a later version appears for existing users', () {
      // An older installation only knows about two cards. The rest must be
      // appended, not silently dropped.
      final DashboardConfig config = DashboardConfig.fromStorage(
        order: <String>[
          DashboardCard.news.storageValue,
          DashboardCard.canteen.storageValue,
        ],
      );
      expect(config.order.take(2), <DashboardCard>[
        DashboardCard.news,
        DashboardCard.canteen,
      ]);
      expect(config.order.length, DashboardCard.values.length);
      for (final DashboardCard card in DashboardCard.values) {
        expect(config.order, contains(card));
      }
    });

    test('unknown and duplicate identifiers are repaired', () {
      final DashboardConfig config = DashboardConfig.fromStorage(
        order: <String>[
          'a-card-that-was-removed',
          DashboardCard.news.storageValue,
          DashboardCard.news.storageValue,
          '',
        ],
        hidden: <String>['nonsense', DashboardCard.mailStatus.storageValue],
      );
      expect(config.order.first, DashboardCard.news);
      expect(config.order.length, DashboardCard.values.length);
      expect(config.order.toSet().length, DashboardCard.values.length);
      expect(config.hidden, <DashboardCard>{DashboardCard.mailStatus});
    });

    test('an empty store is the product default, not an empty dashboard', () {
      expect(DashboardConfig.fromStorage(), DashboardConfig.defaults);
    });

    test('round-trips through storage', () {
      final DashboardConfig config = DashboardConfig.defaults
          .reordered(DashboardCard.quickActions, 0)
          .withVisibility(DashboardCard.news, visible: false);
      expect(
        DashboardConfig.fromStorage(
          order: config.orderToStorage(),
          hidden: config.hiddenToStorage(),
        ),
        config,
      );
    });
  });

  group('personal-service cards', () {
    test('mail and grades cards are bound to their service', () {
      expect(DashboardCard.mailStatus.requiresService, AppSection.mail);
      expect(DashboardCard.gradesStatus.requiresService, AppSection.grades);
    });

    test('public cards require no service at all', () {
      for (final DashboardCard card in <DashboardCard>[
        DashboardCard.nextClass,
        DashboardCard.todaysAgenda,
        DashboardCard.canteen,
        DashboardCard.news,
        DashboardCard.quickActions,
      ]) {
        expect(card.requiresService, isNull);
      }
    });

    test('storage identifiers are unique', () {
      final Set<String> seen = <String>{};
      for (final DashboardCard card in DashboardCard.values) {
        expect(seen.add(card.storageValue), isTrue);
      }
    });

    test('an unimplemented card is never rendered, only ever configurable', () {
      // The dashboard must not draw an empty frame for a feature that does not
      // exist yet — but settings still list the card so the order is stable.
      final Iterable<DashboardCard> pending = DashboardCard.values.where(
        (DashboardCard c) => !c.isImplemented,
      );
      for (final DashboardCard card in pending) {
        expect(DashboardConfig.defaults.visible, isNot(contains(card)));
        expect(DashboardConfig.defaults.configurable, contains(card));
      }
      expect(
        DashboardConfig.defaults.visible,
        isNotEmpty,
        reason: 'at least one card has to be real',
      );
    });
  });
}
