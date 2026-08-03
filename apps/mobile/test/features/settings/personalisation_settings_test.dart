// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import 'package:campus_koethen/app/app_sections.dart';
import 'package:campus_koethen/core/locale/locale_mode.dart';
import 'package:campus_koethen/core/prefs/key_value_store.dart';
import 'package:campus_koethen/core/prefs/preference_keys.dart';
import 'package:campus_koethen/core/prefs/settings_controller.dart';
import 'package:campus_koethen/core/theme/accent_palette.dart';
import 'package:campus_koethen/core/theme/app_colors.dart';
import 'package:campus_koethen/core/theme/app_density.dart';
import 'package:campus_koethen/core/theme/app_dimensions.dart';
import 'package:campus_koethen/core/theme/app_motion.dart';
import 'package:campus_koethen/core/theme/app_theme.dart';
import 'package:campus_koethen/features/settings/presentation/dashboard_settings_screen.dart';
import 'package:campus_koethen/features/settings/presentation/navigation_settings_screen.dart';
import 'package:campus_koethen/features/settings/presentation/personalisation_tiles.dart';
import 'package:campus_koethen/features/today/domain/dashboard_card.dart';
import 'package:campus_koethen/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../../support/pump_app.dart';

/// Pumps a widget inside a MaterialApp whose theme is built from the live
/// settings — the only way to assert that a preference actually reaches the
/// rendered theme rather than just the store.
Future<ProviderContainer> pumpThemed(
  WidgetTester tester,
  Widget child, {
  KeyValueStore? store,
  Locale locale = AppLocales.german,
  Size surface = const Size(390, 1800),
}) async {
  tester.view.physicalSize = surface;
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  final ProviderContainer container = ProviderContainer(
    overrides: <Override>[
      keyValueStoreProvider.overrideWithValue(store ?? InMemoryKeyValueStore()),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: Consumer(
        builder: (BuildContext context, WidgetRef ref, Widget? _) {
          final AppSettings settings = ref.watch(settingsProvider);
          return MaterialApp(
            locale: locale,
            supportedLocales: AppLocales.supported,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            theme: AppTheme.light(
              accent: settings.accentPalette,
              density: settings.displayDensity,
              motion: AppMotion.resolve(
                systemDisablesAnimations: false,
                userPrefersReducedMotion: settings.reducedMotion,
              ),
            ),
            home: child,
          );
        },
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  group('accent colour', () {
    testWidgets('offers exactly the six curated palettes', (
      WidgetTester tester,
    ) async {
      await pumpThemed(tester, const Scaffold(body: AccentColorTile()));
      // Six swatches, each its own button for a screen reader.
      expect(find.byType(InkWell), findsNWidgets(6));
      expect(find.bySemanticsLabel('Campus-Violett'), findsWidgets);
      expect(find.bySemanticsLabel('Petrol'), findsWidgets);
    });

    testWidgets('picking one repaints the app and names the choice', (
      WidgetTester tester,
    ) async {
      await pumpThemed(tester, const Scaffold(body: AccentColorTile()));

      // The current choice is stated in words, not only as a filled circle.
      expect(find.text('Campus-Violett'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Petrol').first);
      await tester.pumpAndSettle();

      expect(find.text('Petrol'), findsOneWidget);
      final AppColors colors = Theme.of(
        tester.element(find.byType(AccentColorTile)),
      ).extension<AppColors>()!;
      expect(colors.primary, AccentPalette.deepTeal.light.primary);
    });

    testWidgets('the selected swatch carries a check, not just a colour', (
      WidgetTester tester,
    ) async {
      await pumpThemed(tester, const Scaffold(body: AccentColorTile()));
      expect(find.byIcon(Icons.check), findsOneWidget);
    });
  });

  group('density', () {
    testWidgets('switching to compact tightens the rendered theme', (
      WidgetTester tester,
    ) async {
      final ProviderContainer container = await pumpThemed(
        tester,
        const Scaffold(body: DensityTile()),
      );

      double rowHeight() => Theme.of(
        tester.element(find.byType(DensityTile)),
      ).listTileTheme.minTileHeight!;
      final double comfortable = rowHeight();

      await container
          .read(settingsProvider.notifier)
          .setDisplayDensity(DisplayDensity.compact);
      await tester.pumpAndSettle();

      expect(rowHeight(), lessThan(comfortable));
      // …but never below the minimum touch target.
      expect(rowHeight(), greaterThanOrEqualTo(AppSizes.minTouchTarget));
      expect(find.text('Kompakt'), findsWidgets);
    });
  });

  group('reduced motion', () {
    testWidgets('the switch reaches the theme', (WidgetTester tester) async {
      final ProviderContainer container = await pumpThemed(
        tester,
        const Scaffold(body: ReducedMotionTile()),
      );

      AppMotion motion() => Theme.of(
        tester.element(find.byType(ReducedMotionTile)),
      ).extension<AppMotion>()!;
      expect(motion().reduced, isFalse);

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      expect(motion().reduced, isTrue);
      expect(motion().medium, Duration.zero);
      expect(container.read(settingsProvider).reducedMotion, isTrue);
    });
  });

  group('navigation settings', () {
    testWidgets('Today and More are shown as fixed and cannot be changed', (
      WidgetTester tester,
    ) async {
      await pumpThemed(tester, const NavigationSettingsScreen());

      expect(find.byIcon(Icons.lock_outline), findsWidgets);
      expect(find.text('Heute'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Mehr'), 200);
      expect(find.text('Mehr'), findsOneWidget);
      expect(find.byIcon(Icons.lock_outline), findsWidgets);
      // Neither is offered as a checkbox.
      expect(find.widgetWithText(CheckboxListTile, 'Heute'), findsNothing);
    });

    testWidgets('a fourth pick is unavailable rather than silently evicting', (
      WidgetTester tester,
    ) async {
      await pumpThemed(tester, const NavigationSettingsScreen());

      final CheckboxListTile mail = tester.widget<CheckboxListTile>(
        find.widgetWithText(CheckboxListTile, 'Studentische E-Mail'),
      );
      expect(
        mail.onChanged,
        isNull,
        reason: 'three are already chosen, so a fourth must be disabled',
      );

      // Freeing a slot makes it available again.
      final CheckboxListTile news = tester.widget<CheckboxListTile>(
        find.widgetWithText(CheckboxListTile, 'News'),
      );
      expect(news.value, isTrue);
      news.onChanged!(false);
      await tester.pumpAndSettle();

      final CheckboxListTile mailAgain = tester.widget<CheckboxListTile>(
        find.widgetWithText(CheckboxListTile, 'Studentische E-Mail'),
      );
      expect(mailAgain.onChanged, isNotNull);
    });

    testWidgets('a choice is persisted', (WidgetTester tester) async {
      final InMemoryKeyValueStore store = InMemoryKeyValueStore();
      await pumpThemed(tester, const NavigationSettingsScreen(), store: store);

      final CheckboxListTile news = tester.widget<CheckboxListTile>(
        find.widgetWithText(CheckboxListTile, 'News'),
      );
      news.onChanged!(false);
      await tester.pumpAndSettle();

      final CheckboxListTile map = tester.widget<CheckboxListTile>(
        find.widgetWithText(CheckboxListTile, 'Lageplan'),
      );
      map.onChanged!(true);
      await tester.pumpAndSettle();

      final List<String>? stored = store.getStringList(
        PreferenceKeys.navigationMiddle,
      );
      expect(stored, contains(AppSection.campusMap.storageValue));
      expect(stored, isNot(contains(AppSection.news.storageValue)));
      expect(stored, hasLength(3));
    });
  });

  group('dashboard settings', () {
    testWidgets('every card is listed, pending ones are marked', (
      WidgetTester tester,
    ) async {
      await pumpThemed(tester, const DashboardSettingsScreen());

      expect(find.byType(Switch), findsNWidgets(DashboardCard.values.length));
      // The cards that are not wired up yet say so instead of pretending.
      final int pending = DashboardCard.values
          .where((DashboardCard c) => !c.isImplemented)
          .length;
      expect(
        find.text('Folgt in einer späteren Version'),
        findsNWidgets(pending),
      );
    });

    testWidgets('moving a card up changes the stored order', (
      WidgetTester tester,
    ) async {
      final InMemoryKeyValueStore store = InMemoryKeyValueStore();
      final ProviderContainer container = await pumpThemed(
        tester,
        const DashboardSettingsScreen(),
        store: store,
      );

      final DashboardCard second = container
          .read(settingsProvider)
          .dashboard
          .configurable[1];

      await tester.tap(find.byTooltip('Nach oben').at(1));
      await tester.pumpAndSettle();

      expect(container.read(settingsProvider).dashboard.order.first, second);
      expect(
        store.getStringList(PreferenceKeys.dashboardCardOrder)?.first,
        second.storageValue,
      );
    });

    testWidgets('the first card cannot move up and the last not down', (
      WidgetTester tester,
    ) async {
      await pumpThemed(tester, const DashboardSettingsScreen());

      // byTooltip finds the Tooltip; the button is its ancestor.
      IconButton buttonFor(Finder tooltip) => tester.widget<IconButton>(
        find.ancestor(of: tooltip, matching: find.byType(IconButton)).first,
      );
      final IconButton firstUp = buttonFor(find.byTooltip('Nach oben').first);
      final IconButton lastDown = buttonFor(find.byTooltip('Nach unten').last);
      expect(firstUp.onPressed, isNull);
      expect(lastDown.onPressed, isNull);
    });

    testWidgets('switching a card off persists', (WidgetTester tester) async {
      final InMemoryKeyValueStore store = InMemoryKeyValueStore();
      final ProviderContainer container = await pumpThemed(
        tester,
        const DashboardSettingsScreen(),
        store: store,
      );

      await container
          .read(settingsProvider.notifier)
          .setDashboard(
            container
                .read(settingsProvider)
                .dashboard
                .withVisibility(DashboardCard.canteen, visible: false),
          );
      await tester.pumpAndSettle();

      expect(
        store.getStringList(PreferenceKeys.dashboardHiddenCards),
        contains(DashboardCard.canteen.storageValue),
      );
    });
  });

  testWidgets('the settings render in English', (WidgetTester tester) async {
    await pumpThemed(
      tester,
      const Scaffold(body: AccentColorTile()),
      locale: AppLocales.english,
    );
    expect(find.text('Accent colour'), findsOneWidget);
    expect(find.text('Campus violet'), findsOneWidget);
  });

  testWidgets('the accent picker survives doubled text on a narrow phone', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await pumpScreen(
      tester,
      const Scaffold(body: AccentColorTile()),
      textScaler: const TextScaler.linear(2),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
