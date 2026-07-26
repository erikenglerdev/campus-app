// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../network/api_failure.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';

/// Centred loading indicator with a screen reader label.
class LoadingView extends StatelessWidget {
  const LoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Semantics(
        label: context.l10n.commonLoadingSemanticLabel,
        liveRegion: true,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const CircularProgressIndicator(),
              const SizedBox(height: AppSpacing.lg),
              Text(
                context.l10n.commonLoading,
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Generic empty state: icon, headline and explanation.
class EmptyView extends StatelessWidget {
  const EmptyView({
    required this.title,
    required this.message,
    this.icon = Icons.inbox_outlined,
    this.action,
    super.key,
  });

  final String title;
  final String message;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final TextTheme text = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              icon,
              size: AppSizes.illustrationIcon,
              color: colors.textSecondary,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(title, style: text.titleMedium, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message,
              style: text.bodyMedium?.copyWith(color: colors.textSecondary),
              textAlign: TextAlign.center,
            ),
            if (action != null) ...<Widget>[
              const SizedBox(height: AppSpacing.xl),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// Error state with a retry action.
///
/// The [ApiFailure] is mapped to a localised message; the raw API message is
/// never shown so the UI stays in the user's language.
class ErrorView extends StatelessWidget {
  const ErrorView({required this.onRetry, this.failure, super.key});

  final Object? failure;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return EmptyView(
      icon: Icons.error_outline,
      title: l10n.errorGenericTitle,
      message: messageFor(l10n, failure),
      action: FilledButton.icon(
        onPressed: onRetry,
        icon: const Icon(Icons.refresh),
        label: Text(l10n.actionRetry),
      ),
    );
  }

  /// Maps a caught error onto a localised, user-facing message.
  static String messageFor(AppLocalizations l10n, Object? failure) {
    if (failure is! ApiFailure) return l10n.errorGenericMessage;
    return switch (failure.kind) {
      ApiFailureKind.network => l10n.errorNetworkMessage,
      ApiFailureKind.timeout => l10n.errorTimeoutMessage,
      ApiFailureKind.notFound => l10n.errorNotFoundMessage,
      ApiFailureKind.server => l10n.errorServerMessage,
      ApiFailureKind.badRequest => l10n.errorGenericMessage,
      ApiFailureKind.unknown => l10n.errorGenericMessage,
    };
  }
}
