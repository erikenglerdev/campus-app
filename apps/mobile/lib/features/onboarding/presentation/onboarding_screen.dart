// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_routes.dart';
import '../../../core/prefs/settings_controller.dart';
import '../../../core/theme/app_metrics.dart';
import '../../../core/theme/app_motion.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../l10n/l10n.dart';
import 'onboarding_steps.dart';

/// First-run setup.
///
/// Every step is optional. Nothing here is a gate: a step whose backend source
/// is unavailable — no canteens published yet, no timetable groups synced —
/// says so and moves on, because a student who cannot finish the setup cannot
/// use the app at all.
///
/// Skipping counts as answering. The completion flag is set whether the user
/// walks through the steps or presses "skip all", so the app never asks twice
/// unprompted; restarting the setup is an explicit action in the settings.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pages = PageController();
  int _index = 0;

  static const List<OnboardingStep> _steps = <OnboardingStep>[
    OnboardingStep.welcome,
    OnboardingStep.campus,
    OnboardingStep.content,
  ];

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await ref.read(settingsProvider.notifier).setOnboardingCompleted(true);
    if (!mounted) return;
    GoRouter.of(context).go(AppRoutes.news);
  }

  void _goTo(int index) {
    if (index < 0 || index >= _steps.length) return;
    setState(() => _index = index);
    // Reduced motion means no motion here either — the tokens already know.
    final AppMotion motion = context.motion;
    if (motion.reduced) {
      _pages.jumpToPage(index);
    } else {
      _pages.animateToPage(index, duration: motion.medium, curve: motion.curve);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final AppMetrics metrics = context.metrics;
    final bool isLast = _index == _steps.length - 1;

    return Scaffold(
      // The step counter lives in the body, right above the bar it describes:
      // "Schritt 3 von 5" and "Alles überspringen" cannot share an app bar on
      // a 320 px phone with scaled text. The action itself collapses to an
      // icon at that point, keeping its tooltip and accessible name.
      appBar: AppBar(
        automaticallyImplyLeading: false,
        titleSpacing: 0,
        actions: <Widget>[
          if (MediaQuery.textScalerOf(context).scale(14) > 20)
            IconButton(
              onPressed: _finish,
              tooltip: l10n.onboardingSkipAll,
              icon: const Icon(Icons.skip_next_outlined),
            )
          else
            TextButton(onPressed: _finish, child: Text(l10n.onboardingSkipAll)),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Padding(
              padding: EdgeInsets.fromLTRB(
                metrics.screenPadding,
                0,
                metrics.screenPadding,
                AppSpacing.xs,
              ),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  l10n.onboardingStepOf(_index + 1, _steps.length),
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ),
            ),
            LinearProgressIndicator(
              value: (_index + 1) / _steps.length,
              semanticsLabel: l10n.onboardingStepOf(_index + 1, _steps.length),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pages,
                // Driven by the buttons only: a half-finished swipe on a
                // setup flow makes it unclear which step you are answering.
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _steps.length,
                itemBuilder: (BuildContext context, int index) => Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: metrics.screenPadding,
                  ),
                  child: OnboardingStepView(step: _steps[index]),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(metrics.screenPadding),
              // OverflowBar, not a Row: three labelled buttons do not fit
              // beside each other on a narrow phone, let alone with scaled
              // text. It lays out horizontally while there is room and stacks
              // when there is not, instead of overflowing.
              child: OverflowBar(
                alignment: MainAxisAlignment.end,
                overflowAlignment: OverflowBarAlignment.end,
                spacing: AppSpacing.sm,
                overflowSpacing: AppSpacing.xs,
                children: <Widget>[
                  if (_index > 0)
                    TextButton(
                      onPressed: () => _goTo(_index - 1),
                      child: Text(l10n.onboardingBack),
                    ),
                  if (!isLast)
                    TextButton(
                      onPressed: () => _goTo(_index + 1),
                      child: Text(l10n.onboardingSkip),
                    ),
                  FilledButton(
                    onPressed: isLast ? _finish : () => _goTo(_index + 1),
                    child: Text(
                      isLast ? l10n.onboardingFinish : l10n.onboardingNext,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
